/*
 * lab5_hardware.h - Capa de acceso al hardware utilizada en el Laboratorio 8.
 *
 * El nombre del archivo se conserva por compatibilidad con la base del
 * proyecto. La asignacion fisica comprobada en TopDesign es:
 *   DAC_P -> Vout_2 -> P3[7] (pin fisico 37) -> J3
 *   DAC_N -> Vout_3 -> P0[0]                  -> J2
 */
#ifndef LAB5_HARDWARE_H
#define LAB5_HARDWARE_H

#include "project.h"

void Lab5HardwareInit(void);
float Lab5HardwareReadPlant(int16 *raw_counts, float *adc_volts);
float Lab5HardwareWriteOutput(float requested_volts, uint8 *dac_positive,
                              uint8 *dac_negative, uint8 *saturated);
void Lab5HardwareZeroOutput(void);
float Lab5Clamp(float value, float lower, float upper);

#endif
