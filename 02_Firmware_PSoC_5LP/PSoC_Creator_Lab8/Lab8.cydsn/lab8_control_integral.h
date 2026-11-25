#ifndef LAB8_CONTROL_INTEGRAL_H
#define LAB8_CONTROL_INTEGRAL_H

/*
 * Nucleo matematico portable del controlador integral.
 * No depende de PSoC Creator: recibe tensiones en V y conserva el estado
 * del observador, del integrador y de los contadores de proteccion.
 */
typedef struct {
    float A[2][2];
    float B[2];
    float C[2];
    float Kx[2];
    float Ki;
    float L[2];
    float u_min_V;
    float u_max_V;
} lab8_parametros_t;

typedef struct {
    float x_pred[2];
    float x_control[2];
    float xi;
    float u_aplicado_V;
    float u_solicitado_V;
    float innovacion_V;
    float error_V;
    unsigned int saturaciones;
    unsigned int antiwindup_bloqueos;
} lab8_estado_t;

void lab8_reiniciar(lab8_estado_t *estado, float x0_est1, float x0_est2);

/* Observador actual y ley u=-Kx*xhat-Ki*xi. Retorna el mando limitado.
 * La integral se actualiza con xi[k+1]=xi[k]+r[k]-y[k], salvo bloqueo
 * condicional de anti-windup cuando el error empuja mas hacia saturacion.
 */
float lab8_calcular_paso(const lab8_parametros_t *parametros,
                         lab8_estado_t *estado,
                         float referencia_V,
                         float salida_medida_V);

#endif
