#ifndef LAB8_CONFIG_H
#define LAB8_CONFIG_H

/* Laboratorio 8: seguimiento con realimentacion de estados y accion integral.
 * El modo inicial es MONITOR (DAC=0). Los enclavamientos deben habilitarse
 * conscientemente despues de revalidar el banco y antes de cerrar el lazo.
 */
#define LAB8_MODO_MONITOR          (0u)
#define LAB8_MODO_LAZO_ABIERTO     (1u)
#define LAB8_MODO_INTEGRAL         (2u)

#define LAB8_DISENO_LENTO          (1u) /* polo integral z=0.60 */
#define LAB8_DISENO_RAPIDO         (2u) /* polo integral z=0.30 */

#define LAB8_MODO                  LAB8_MODO_MONITOR
#define LAB8_DISENO                LAB8_DISENO_LENTO

/* Cambiar a 1 SOLO despues de completar cada comprobacion fisica. */
#define LAB8_AUTORIZAR_ESCALON         (0u)
#define LAB8_PLANTA_VERIFICADA         (0u)
#define LAB8_ADC_DAC_REVALIDADOS       (0u)
#define LAB8_AUTORIZAR_LAZO_CERRADO   (0u)

#if LAB8_MODO > LAB8_MODO_INTEGRAL
#error Modo de laboratorio 8 invalido.
#endif
#if LAB8_DISENO < LAB8_DISENO_LENTO || LAB8_DISENO > LAB8_DISENO_RAPIDO
#error Diseno integral invalido.
#endif
#if LAB8_MODO == LAB8_MODO_LAZO_ABIERTO && LAB8_AUTORIZAR_ESCALON != 1u
#error No se autoriza el escalon abierto hasta revalidar alimentacion y salida segura.
#endif
#if LAB8_MODO == LAB8_MODO_INTEGRAL && \
   (LAB8_PLANTA_VERIFICADA != 1u || LAB8_ADC_DAC_REVALIDADOS != 1u || \
    LAB8_AUTORIZAR_LAZO_CERRADO != 1u)
#error CONTROL BLOQUEADO: validar planta, ADC/DAC y habilitar explicitamente.
#endif

/* Clock_1 heredado = 100 kHz. Period = cuentas-1. */
#define LAB8_TS_CUENTAS              (200u)
#define LAB8_TS_US                   (LAB8_TS_CUENTAS*10u)
#define LAB8_TOLERANCIA_US           (LAB8_TS_US/10u)
#define LAB8_N_MUESTRAS              (600u)
#define LAB8_PRETRIGGER              (32u)
#define LAB8_FIN_REFERENCIA          (333u)
#define LAB8_FIN_ESCALON_ABIERTO     (128u)
#define LAB8_INICIO_MS               (3000u)
/* La amplitud de 500 mV fue seleccionada mediante un barrido previo: para
 * ambos controladores, el modelo identificado conserva al menos 20 % de
 * margen respecto del limite de +/-1 V. El valor entero permite aplicar
 * comprobaciones de seguridad durante la compilacion. */
#define LAB8_ESCALON_ABIERTO_MV      (500)
#define LAB8_ESCALON_ABIERTO_V       ((float)LAB8_ESCALON_ABIERTO_MV/1000.0f)
#define LAB8_REFERENCIA_MV           (500)
#define LAB8_REFERENCIA_V            ((float)LAB8_REFERENCIA_MV/1000.0f)

#if LAB8_ESCALON_ABIERTO_MV == 0 || \
    LAB8_ESCALON_ABIERTO_MV > 500 || LAB8_ESCALON_ABIERTO_MV < -500
#error El escalon abierto debe ser no nulo y estar entre -500 mV y +500 mV.
#endif
#if LAB8_REFERENCIA_MV <= 0 || LAB8_REFERENCIA_MV > 500
#error La referencia cerrada debe estar entre 1 mV y 500 mV.
#endif
#if LAB8_FIN_ESCALON_ABIERTO <= LAB8_PRETRIGGER
#error La ventana del escalon abierto es invalida.
#endif

/* La HAL limita el mando solicitado a +/-1 V. LAB8_U_LIMITE_FISICO_V
 * contempla el redondeo del DAC negativo (aprox. -1.003 V a codigo 95).
 * El umbral de salida admite el sobrepasamiento previsto para 500 mV, pero
 * detiene la adquisicion ante una excursion incompatible con el modelo. */
#define LAB8_U_MIN_V                 (-1.000f)
#define LAB8_U_MAX_V                 (1.000f)
#define LAB8_U_LIMITE_FISICO_V       (1.020f)
#define LAB8_Y_FALLO_V               (0.750f)

/* Conversion ADC/DAC comprobada para el banco actual. Las constantes se
 * concentran aqui para que simulacion, telemetria y HAL usen la misma escala. */
#define LAB8_ADC_OFFSET_VOLTS          (2.353802067f)
#define LAB8_ADC_VOLTS_PER_PLANT_VOLT  (0.210251951f)
#define LAB8_DAC_POSITIVE_GAIN         (3.842612000f)
#define LAB8_DAC_NEGATIVE_GAIN         (2.640105691f)
#define LAB8_DAC_VOLTS_PER_COUNT       (0.004f)

#endif
