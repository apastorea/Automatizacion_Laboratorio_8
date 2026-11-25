/* lab5_control.h - Controladores de sintesis directa. */
#ifndef LAB5_CONTROL_H
#define LAB5_CONTROL_H

typedef struct {
    float output_k1;
    float output_k2;
    float error_k1;
    float error_k2;
} Lab5ControllerState;

typedef struct {
    float b0;
    float b1;
    float b2;
    float a1;
    float a2;
} Lab5ControllerParameters;

void Lab5ControllerReset(Lab5ControllerState *state);
float Lab5ControllerStep(Lab5ControllerState *state,
                         const Lab5ControllerParameters *parameters,
                         float reference, float measurement);

#endif
