/* lab5_hardware.h - Interfaz fisica heredada del Lab4. */
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
