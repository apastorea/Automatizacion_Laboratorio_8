/*
 * lab5_hardware.c - ADC SAR simple y salida bipolar heredados del Lab4.
 * ADC_SAR_Seq no pertenece a este laboratorio.
 */
#include "lab5_hardware.h"
#include "lab5_config.h"

static float adc_volts_per_count = 0.0f;
static int16 adc_offset_counts = 0;

float Lab5Clamp(float value, float lower, float upper)
{
    return (value > upper) ? upper : ((value < lower) ? lower : value);
}

static uint8 Lab5DacCode(float dac_volts)
{
    const float code = Lab5Clamp(dac_volts / LAB5_DAC_VOLTS_PER_COUNT,
                                 0.0f, 255.0f);
    return (uint8)(code + 0.5f);
}

void Lab5HardwareInit(void)
{
    int32 scale;
    Timer_TS_Stop();
    registro_Write(0u);
    DAC_P_Init();
    DAC_N_Init();
    DAC_P_SetRange(DAC_P_RANGE_1V);
    DAC_N_SetRange(DAC_N_RANGE_1V);
    DAC_P_SetValue(0u);
    DAC_N_SetValue(0u);
    DAC_P_Enable();
    DAC_N_Enable();
    Opamp_2_Start();
    Opamp_3_Start();
    Opamp_4_Start();
    ADC_Start();
    ADC_IRQ_Disable();
    CyDelayUs(20u);

    scale = (ADC_countsPerVolt != 0) ?
            (int32)ADC_countsPerVolt * 10 : ADC_countsPer10Volt;
    if (scale > 0) {
        adc_offset_counts = ADC_offset;
        adc_volts_per_count = 10.0f / (float)scale;
    }
}

float Lab5HardwareReadPlant(int16 *raw_counts, float *adc_volts)
{
    const int16 raw = ADC_GetResult16();
    const float volts = (float)(int16)(raw - adc_offset_counts) *
                        adc_volts_per_count;
    *raw_counts = raw;
    *adc_volts = volts;
    return (volts - LAB5_ADC_OFFSET_VOLTS) /
           LAB5_ADC_VOLTS_PER_PLANT_VOLT;
}

float Lab5HardwareWriteOutput(float requested_volts, uint8 *dac_positive,
                              uint8 *dac_negative, uint8 *saturated)
{
    const float limited = Lab5Clamp(requested_volts,
                                    LAB5_OUTPUT_MIN_VOLTS,
                                    LAB5_OUTPUT_MAX_VOLTS);
    uint8 positive = 0u;
    uint8 negative = 0u;

    *saturated = (uint8)(limited != requested_volts);
    if (limited >= 0.0f)
        positive = Lab5DacCode(limited / LAB5_DAC_POSITIVE_GAIN);
    else
        negative = Lab5DacCode(-limited / LAB5_DAC_NEGATIVE_GAIN);

    DAC_P_SetValue(positive);
    DAC_N_SetValue(negative);
    *dac_positive = positive;
    *dac_negative = negative;
    return LAB5_DAC_VOLTS_PER_COUNT *
           (LAB5_DAC_POSITIVE_GAIN * (float)positive -
            LAB5_DAC_NEGATIVE_GAIN * (float)negative);
}

void Lab5HardwareZeroOutput(void)
{
    DAC_P_SetValue(0u);
    DAC_N_SetValue(0u);
}
