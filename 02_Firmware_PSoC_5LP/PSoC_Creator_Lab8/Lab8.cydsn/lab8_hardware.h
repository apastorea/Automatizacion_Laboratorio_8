/*
 * lab8_hardware.h - Capa de acceso al hardware del Laboratorio 8.
 *
 * Asignacion comprobada en TopDesign:
 *   DAC_P -> Vout_2 -> P3[7] (pin fisico 37) -> J3
 *   DAC_N -> Vout_3 -> P0[0]                  -> J2
 */
#ifndef LAB8_HARDWARE_H
#define LAB8_HARDWARE_H

#include "project.h"

void Lab8HardwareInit(void);
float Lab8HardwareReadPlant(int16 *raw_counts, float *adc_volts);
float Lab8HardwareWriteOutput(float requested_volts, uint8 *dac_positive,
                              uint8 *dac_negative, uint8 *saturated);
void Lab8HardwareZeroOutput(void);
float Lab8Clamp(float value, float lower, float upper);

#endif
