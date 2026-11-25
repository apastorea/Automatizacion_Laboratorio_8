/*
 * LABORATORIO 8 - Seguimiento con control integral en espacio de estados.
 *
 * Ejecuta a Ts=2 ms la adquisicion ADC, el estimador actual, la integral
 * del error y la ley u=-Kx*xhat-Ki*xi. La capa de hardware convierte el
 * mando limitado a los dos DAC y devuelve el valor realmente aplicado.
 * La telemetria UART conserva entrada, salida, estados, innovacion, mando,
 * tiempos y banderas para reproducir cada ensayo en MATLAB.
 *
 * Configuracion entregada: MONITOR, ambos DAC en cero y enclavamientos de
 * actuacion deshabilitados en lab8_config.h.
 */
#include "project.h"
#include "lab5_hardware.h"
#include "lab8_control_integral.h"
#include "lab8_config.h"
#include <float.h>
#include <stdio.h>

#if ADC_DEFAULT_RESOLUTION != 12u || ADC_DEFAULT_CONV_MODE != ADC__HARDWARE_TRIGGER
#error TopDesign no coincide: SAR 12 bits y disparo hardware requerido.
#endif
#if ADC_DEFAULT_RANGE != ADC__VSSA_TO_VDDA
#error Rango ADC distinto al configurado para la conversion de cuentas.
#endif
#if Timer_TS_Resolution != 16u || Timer_Medicion_Resolution != 16u
#error Se requieren temporizadores de 16 bits.
#endif

typedef struct {
    float adc_V;
    float y_V;
    float y_rel_V;
    float referencia_V;
    float u_solicitada_V;
    float u_dac_nominal_V;
    float xhat1_V;
    float xhat2_V;
    float xi_V;
    float innovacion_V;
    int16 adc_cuentas;
    uint16 intervalo_us;
    uint16 cpu_us;
    uint8 dac_pos;
    uint8 dac_neg;
    uint8 banderas;
} Lab8Muestra;

#define F_ADC             (1u)
#define F_DAC_FISICO      (2u)
#define F_NUM             (4u)
#define F_CPU             (8u)
#define F_TIEMPO         (16u)
#define F_Y              (32u)
#define F_SAT_CONTROL    (64u)
#define F_ANTIWINDUP    (128u)
#define F_FATALES (F_ADC|F_DAC_FISICO|F_NUM|F_CPU|F_TIEMPO|F_Y)

static Lab8Muestra memoria[LAB8_N_MUESTRAS];
static volatile uint16 cuenta = 0u;
static volatile uint8 captura_finalizada = 0u;
static uint16 tick_anterior = 0u;
static float acumulado_cero_V = 0.0f;
static float cero_V = 0.0f;
static lab8_estado_t estado;

/* Modelo identificado adoptado para diseno, discretizado con Ts=2 ms. */
static const lab8_parametros_t parametros = {
    {{0.802095310f, 0.0f}, {-0.249628290f, 0.075573620f}},
    {-0.631610700f, 0.130459080f},
    {0.0f, 1.0f},
#if LAB8_DISENO == LAB8_DISENO_LENTO
    {1.654553831f, 5.539689791f}, -0.223449849f,
#else
    {0.591027145f, 2.690253516f}, -0.391037235f,
#endif
    {-1.860494424f, 0.175152235f},
    LAB8_U_MIN_V, LAB8_U_MAX_V
};

CY_ISR_PROTO(Lab8MuestreoISR);

static uint8 es_finito(float a)
{
    return (uint8)(a <= FLT_MAX && a >= -FLT_MAX);
}

static uint16 leer_timer_us(void)
{
    Timer_Medicion_SoftwareCapture();
    return Timer_Medicion_ReadCapture();
}

static int32 convertir_mV(float v)
{
    float c;
    if (!es_finito(v)) return 0;
    c = Lab5Clamp(1000.0f*v, -100000.0f, 100000.0f);
    return (int32)(c + ((c >= 0.0f) ? 0.5f : -0.5f));
}

static void detener_seguro(void)
{
    Timer_TS_Stop();
    Lab5HardwareZeroOutput();
    captura_finalizada = 1u;
}

CY_ISR(Lab8MuestreoISR)
{
    uint16 k = cuenta, tic_ini, intervalo = 0u, cpu_us;
    uint8 banderas = 0u, positivo = 0u, negativo = 0u, saturado = 0u;
    int16 adc_raw = 0;
    float adc_V = 0.0f, salida_V, salida_rel_V, ref_V = 0.0f;
    float u_solicitada_V = 0.0f, u_nominal_V = 0.0f;
#if LAB8_MODO == LAB8_MODO_INTEGRAL
    unsigned int saturaciones_antes = estado.saturaciones;
    unsigned int antiwindup_antes = estado.antiwindup_bloqueos;
#endif
    Lab8Muestra *m;

    registro_Write(1u);
    if (captura_finalizada || k >= LAB8_N_MUESTRAS) {
        detener_seguro();
        registro_Write(0u);
        return;
    }
    tic_ini = leer_timer_us();
    if (k > 0u) {
        intervalo = (uint16)(tick_anterior - tic_ini);
        if (intervalo < (LAB8_TS_US - LAB8_TOLERANCIA_US) ||
            intervalo > (LAB8_TS_US + LAB8_TOLERANCIA_US)) banderas |= F_TIEMPO;
    }
    tick_anterior = tic_ini;

    salida_V = Lab5HardwareReadPlant(&adc_raw, &adc_V);
    if (!es_finito(salida_V) || !es_finito(adc_V)) {
        salida_V = 0.0f;
        banderas |= F_NUM;
    }
    if (adc_raw <= 2 || adc_raw >= 4093) banderas |= F_ADC;
    if (k < LAB8_PRETRIGGER) {
        acumulado_cero_V += salida_V;
        if (k + 1u == LAB8_PRETRIGGER)
            cero_V = acumulado_cero_V/(float)LAB8_PRETRIGGER;
    }
    salida_rel_V = (k >= LAB8_PRETRIGGER) ? salida_V - cero_V : salida_V;
    if (salida_rel_V > LAB8_Y_FALLO_V || salida_rel_V < -LAB8_Y_FALLO_V)
        banderas |= F_Y;

#if LAB8_MODO == LAB8_MODO_LAZO_ABIERTO
    if (k >= LAB8_PRETRIGGER && k < LAB8_FIN_ESCALON_ABIERTO)
        u_solicitada_V = LAB8_ESCALON_ABIERTO_V;
#elif LAB8_MODO == LAB8_MODO_INTEGRAL
    if (k >= LAB8_PRETRIGGER) {
        if (k < LAB8_FIN_REFERENCIA) ref_V = LAB8_REFERENCIA_V;
        u_solicitada_V = lab8_calcular_paso(&parametros, &estado,
                                             ref_V, salida_rel_V);
        if (estado.saturaciones > saturaciones_antes) banderas |= F_SAT_CONTROL;
        if (estado.antiwindup_bloqueos > antiwindup_antes) banderas |= F_ANTIWINDUP;
    } else {
        lab8_reiniciar(&estado, 0.0f, 0.0f);
    }
#else
    u_solicitada_V = 0.0f;
#endif

    if (!es_finito(u_solicitada_V)) {
        u_solicitada_V = 0.0f;
        banderas |= F_NUM;
    }
    if ((banderas & F_FATALES) != 0u) u_solicitada_V = 0.0f;

    u_nominal_V = Lab5HardwareWriteOutput(u_solicitada_V,
                                          &positivo, &negativo, &saturado);
    if (saturado || u_nominal_V > LAB8_U_LIMITE_FISICO_V ||
        u_nominal_V < -LAB8_U_LIMITE_FISICO_V) {
        banderas |= F_DAC_FISICO;
        Lab5HardwareZeroOutput();
        u_nominal_V = 0.0f;
        positivo = 0u;
        negativo = 0u;
    }

#if LAB8_MODO == LAB8_MODO_INTEGRAL
    if (k >= LAB8_PRETRIGGER) {
        float diferencia = u_nominal_V - estado.u_aplicado_V;
        estado.x_pred[0] += parametros.B[0]*diferencia;
        estado.x_pred[1] += parametros.B[1]*diferencia;
        estado.u_aplicado_V = u_nominal_V;
    }
#endif

    m = &memoria[k];
    m->adc_V = adc_V;
    m->y_V = salida_V;
    m->y_rel_V = salida_rel_V;
    m->referencia_V = ref_V;
    m->u_solicitada_V = u_solicitada_V;
    m->u_dac_nominal_V = u_nominal_V;
    m->adc_cuentas = adc_raw;
    m->dac_pos = positivo;
    m->dac_neg = negativo;
    m->intervalo_us = intervalo;
#if LAB8_MODO == LAB8_MODO_INTEGRAL
    m->xhat1_V = estado.x_control[0];
    m->xhat2_V = estado.x_control[1];
    m->xi_V = estado.xi;
    m->innovacion_V = estado.innovacion_V;
#else
    m->xhat1_V = 0.0f;
    m->xhat2_V = 0.0f;
    m->xi_V = 0.0f;
    m->innovacion_V = 0.0f;
#endif
    cpu_us = (uint16)(tic_ini - leer_timer_us());
    m->cpu_us = cpu_us;
    if (cpu_us >= LAB8_TS_US) banderas |= F_CPU;
    m->banderas = banderas;
    cuenta = k + 1u;
    if ((banderas & F_FATALES) != 0u || cuenta >= LAB8_N_MUESTRAS)
        detener_seguro();
    registro_Write(0u);
}

static void volcar_uart(void)
{
    char linea[320];
    uint16 k;
    uint32 t_us = 0u;
    UART_Debug_PutString(
        "# LAB8 control_integral modelo_diseno=IDENTIFICADO observador=ACTUAL_E2 "
        "Ts_nominal_us=2000 modo="
#if LAB8_MODO == LAB8_MODO_MONITOR
        "MONITOR"
#elif LAB8_MODO == LAB8_MODO_LAZO_ABIERTO
        "ABIERTO"
#else
        "INTEGRAL"
#endif
        "\r\n");
    UART_Debug_PutString(
#if LAB8_DISENO == LAB8_DISENO_LENTO
        "# LAB8 diseno=LENTO polo_integral=0.60 "
#else
        "# LAB8 diseno=RAPIDO polo_integral=0.30 "
#endif
        "referencia_mV=50 DAC_cuantizado=SI antiwindup=CONDICIONAL\r\n");
    (void)snprintf(linea, sizeof linea,
        "# LAB8 ensayo_abierto escalon_mV=%d inicio_k=%u fin_k=%u duracion_ms=%lu\r\n",
        (int)LAB8_ESCALON_ABIERTO_MV, (unsigned)LAB8_PRETRIGGER,
        (unsigned)LAB8_FIN_ESCALON_ABIERTO,
        (unsigned long)(LAB8_FIN_ESCALON_ABIERTO-LAB8_PRETRIGGER)*
                       (unsigned long)LAB8_TS_US/1000ul);
    UART_Debug_PutString(linea);
    UART_Debug_PutString(
        "k,t_us,adc_counts,adc_mV,y_cal_mV,y_rel_mV,r_mV,"
        "u_solicitada_mV,u_nominal_mV,xhat1_mV,xhat2_mV,xi_mV,"
        "innovacion_mV,dac_pos,dac_neg,cpu_us,intervalo_us,flags\r\n");
    for (k = 0u; k < cuenta; ++k) {
        Lab8Muestra *m = &memoria[k];
        t_us += m->intervalo_us;
        (void)snprintf(linea, sizeof linea,
            "%u,%lu,%d,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%u,%u,%u,%u,%u\r\n",
            (unsigned)k, (unsigned long)t_us, (int)m->adc_cuentas,
            (long)convertir_mV(m->adc_V),
            (long)convertir_mV(m->y_V),
            (long)convertir_mV(m->y_rel_V),
            (long)convertir_mV(m->referencia_V),
            (long)convertir_mV(m->u_solicitada_V),
            (long)convertir_mV(m->u_dac_nominal_V),
            (long)convertir_mV(m->xhat1_V),
            (long)convertir_mV(m->xhat2_V),
            (long)convertir_mV(m->xi_V),
            (long)convertir_mV(m->innovacion_V),
            (unsigned)m->dac_pos, (unsigned)m->dac_neg,
            (unsigned)m->cpu_us, (unsigned)m->intervalo_us,
            (unsigned)m->banderas);
        UART_Debug_PutString(linea);
    }
    UART_Debug_PutString("# LAB8 END; DAC=0; reiniciar para repetir\r\n");
}

int main(void)
{
    uint16 anterior = 0u;
    uint8 intentos = 0u;
    CyGlobalIntDisable;
    lab8_reiniciar(&estado, 0.0f, 0.0f);
    Lab5HardwareInit();
    Lab5HardwareZeroOutput();
    UART_Debug_Start();
    Clock_Medicion_Start();
    Timer_Medicion_Start();
    Timer_TS_Init();
    Timer_TS_WritePeriod((uint16)(LAB8_TS_CUENTAS - 1u));
    isr_StartEx(Lab8MuestreoISR);
    isr_ClearPending();

    UART_Debug_PutString(
        "\r\n# LAB8 inicio; configurar lab8_config.h; espera 3s\r\n");
    CyDelay(LAB8_INICIO_MS);
    CyGlobalIntEnable;
    Clock_1_Start();
    Timer_TS_Enable();
    while (!captura_finalizada) {
        CyDelay(10u);
        if (cuenta == anterior) ++intentos;
        else intentos = 0u;
        anterior = cuenta;
        if (intentos >= 10u) {
            uint8 estado_interrupcion = CyEnterCriticalSection();
            detener_seguro();
            CyExitCriticalSection(estado_interrupcion);
            UART_Debug_PutString("# ERROR no llegan muestras; salida a cero\r\n");
        }
    }
    volcar_uart();
    for (;;) { CyDelay(1000u); }
}
