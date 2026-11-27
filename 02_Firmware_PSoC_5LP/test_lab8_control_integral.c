/* Pruebas unitarias del nucleo numerico, independientes del hardware PSoC.
 * Verifican acumulacion integral, limitacion, anti-windup y correccion del
 * estimador con la referencia experimental seleccionada de 500 mV.
 */
#include <assert.h>
#include <math.h>
#include "PSoC_Creator_Lab8/Lab8.cydsn/lab8_control_integral.h"

static int cerca(float a, float b, float tolerancia)
{
    return fabsf(a - b) <= tolerancia;
}

int main(void)
{
    const lab8_parametros_t p = {
        {{0.802095310f, 0.0f}, {-0.249628290f, 0.075573620f}},
        {-0.631610700f, 0.130459080f},
        {0.0f, 1.0f},
        {1.654553831f, 5.539689791f},
        -0.223449849f,
        {-1.860494424f, 0.175152235f},
        -1.000f, 1.000f
    };
    lab8_estado_t e;
    float u;

    lab8_reiniciar(&e, 0.0f, 0.0f);
    u = lab8_calcular_paso(&p, &e, 0.500f, 0.0f);
    assert(cerca(u, 0.0f, 1.0e-7f));
    assert(cerca(e.xi, 0.500f, 1.0e-7f));

    u = lab8_calcular_paso(&p, &e, 0.500f, 0.0f);
    assert(cerca(u, 0.11172492f, 1.0e-6f));

    lab8_reiniciar(&e, 0.0f, 0.0f);
    e.xi = 10.0f;
    u = lab8_calcular_paso(&p, &e, 1.0f, 0.0f);
    assert(cerca(u, 1.000f, 1.0e-7f));
    assert(cerca(e.xi, 10.0f, 1.0e-7f));
    assert(e.saturaciones == 1u);
    assert(e.antiwindup_bloqueos == 1u);

    lab8_reiniciar(&e, 0.0f, 0.0f);
    (void)lab8_calcular_paso(&p, &e, 0.0f, 0.010f);
    assert(cerca(e.innovacion_V, 0.010f, 1.0e-7f));
    assert(cerca(e.x_control[0], -0.01860494f, 1.0e-6f));
    assert(cerca(e.x_control[1], 0.00175152f, 1.0e-6f));

    return 0;
}
