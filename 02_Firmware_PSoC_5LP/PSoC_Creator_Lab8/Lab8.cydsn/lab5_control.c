/* lab5_control.c - Ecuacion en diferencias comun a los cuatro disenos. */
#include "lab5_control.h"

void Lab5ControllerReset(Lab5ControllerState *state)
{
    state->output_k1 = 0.0f;
    state->output_k2 = 0.0f;
    state->error_k1 = 0.0f;
    state->error_k2 = 0.0f;
}

float Lab5ControllerStep(Lab5ControllerState *state,
                         const Lab5ControllerParameters *parameters,
                         float reference, float measurement)
{
    const float error = reference - measurement;
    const float output = -parameters->a1 * state->output_k1
                       - parameters->a2 * state->output_k2
                       + parameters->b0 * error
                       + parameters->b1 * state->error_k1
                       + parameters->b2 * state->error_k2;

    state->output_k2 = state->output_k1;
    state->output_k1 = output;
    state->error_k2 = state->error_k1;
    state->error_k1 = error;
    return output;
}
