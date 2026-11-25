#include "lab8_control_integral.h"

/* Implementacion de una muestra del lazo. El orden de calculo coincide con
 * MATLAB: correccion actual, control con xi[k], anti-windup y prediccion.
 * main.c reemplaza luego el mando limitado por el valor cuantizado del DAC
 * antes de conservar la prediccion que se usara en la siguiente muestra.
 */

static float lab8_limitar(float u, float inferior, float superior)
{
    if (u < inferior) return inferior;
    if (u > superior) return superior;
    return u;
}

void lab8_reiniciar(lab8_estado_t *e, float x0_est1, float x0_est2)
{
    if (e == 0) return;
    e->x_pred[0] = x0_est1;
    e->x_pred[1] = x0_est2;
    e->x_control[0] = x0_est1;
    e->x_control[1] = x0_est2;
    e->xi = 0.0f;
    e->u_aplicado_V = 0.0f;
    e->u_solicitado_V = 0.0f;
    e->innovacion_V = 0.0f;
    e->error_V = 0.0f;
    e->saturaciones = 0u;
    e->antiwindup_bloqueos = 0u;
}

float lab8_calcular_paso(const lab8_parametros_t *p,
                         lab8_estado_t *e,
                         float referencia_V,
                         float salida_medida_V)
{
    float innov, xe0, xe1, us, ua, error;
    unsigned int bloquear_integral;

    if (p == 0 || e == 0 || p->u_max_V <= p->u_min_V) return 0.0f;

    innov = salida_medida_V -
            (p->C[0]*e->x_pred[0] + p->C[1]*e->x_pred[1]);
    xe0 = e->x_pred[0] + p->L[0]*innov;
    xe1 = e->x_pred[1] + p->L[1]*innov;

    us = -p->Kx[0]*xe0 - p->Kx[1]*xe1 - p->Ki*e->xi;
    ua = lab8_limitar(us, p->u_min_V, p->u_max_V);
    if (ua != us) ++e->saturaciones;

    error = referencia_V - salida_medida_V;
    bloquear_integral = (unsigned int)
        ((us > p->u_max_V && error > 0.0f) ||
         (us < p->u_min_V && error < 0.0f));
    if (bloquear_integral != 0u) ++e->antiwindup_bloqueos;
    else e->xi += error;

    e->x_control[0] = xe0;
    e->x_control[1] = xe1;
    e->u_solicitado_V = us;
    e->u_aplicado_V = ua;
    e->innovacion_V = innov;
    e->error_V = error;

    /* main.c corrige luego la diferencia por cuantizacion del DAC. */
    e->x_pred[0] = p->A[0][0]*xe0 + p->A[0][1]*xe1 + p->B[0]*ua;
    e->x_pred[1] = p->A[1][0]*xe0 + p->A[1][1]*xe1 + p->B[1]*ua;
    return ua;
}
