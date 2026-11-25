/* lab5_config.h - Configuracion comun del Laboratorio 5. */
#ifndef LAB5_CONFIG_H
#define LAB5_CONFIG_H

#define LAB5_MODE_MONITOR             (0u)
#define LAB5_MODE_CONTROL             (1u)
#define LAB5_MODE_CALIBRATION         (2u)
#define LAB5_MODE_STATIC_DIAGNOSTIC   (3u)

#define LAB5_DESIGN_TS1_OSCILLATORY   (0u)
#define LAB5_DESIGN_TS1_DEADBEAT      (1u)
#define LAB5_DESIGN_TS2_OSCILLATORY   (2u)
#define LAB5_DESIGN_TS2_DEADBEAT      (3u)

#include "lab5_experiment.h"

/* Clock_1 = 100 kHz; 575 y 192 cuentas dan 5,750 y 1,920 ms. */
#if LAB5_DESIGN == LAB5_DESIGN_TS1_OSCILLATORY
    #define LAB5_DESIGN_NAME          "TS1_OSCILLATORY"
    #define LAB5_TS_COUNTS            (575u)
    #define LAB5_CONTROLLER_B0        (2.373542275f)
    #define LAB5_CONTROLLER_B1        (-1.260475531f)
    #define LAB5_CONTROLLER_B2        (0.000750518f)
    #define LAB5_CONTROLLER_A1        (-0.882907002f)
    #define LAB5_CONTROLLER_A2        (-0.117092998f)
#elif LAB5_DESIGN == LAB5_DESIGN_TS1_DEADBEAT
    #define LAB5_DESIGN_NAME          "TS1_DEADBEAT"
    #define LAB5_TS_COUNTS            (575u)
    #define LAB5_CONTROLLER_B0        (2.124749039f)
    #define LAB5_CONTROLLER_B1        (-1.128353264f)
    #define LAB5_CONTROLLER_B2        (0.000671849f)
    #define LAB5_CONTROLLER_A1        (-0.895180618f)
    #define LAB5_CONTROLLER_A2        (-0.104819382f)
#elif LAB5_DESIGN == LAB5_DESIGN_TS2_OSCILLATORY
    #define LAB5_DESIGN_NAME          "TS2_OSCILLATORY"
    #define LAB5_TS_COUNTS            (192u)
    #define LAB5_CONTROLLER_B0        (8.101351127f)
    #define LAB5_CONTROLLER_B1        (-7.234509218f)
    #define LAB5_CONTROLLER_B2        (0.549350883f)
    #define LAB5_CONTROLLER_A1        (-0.579642185f)
    #define LAB5_CONTROLLER_A2        (-0.420357815f)
#elif LAB5_DESIGN == LAB5_DESIGN_TS2_DEADBEAT
    #define LAB5_DESIGN_NAME          "TS2_DEADBEAT"
    #define LAB5_TS_COUNTS            (192u)
    #define LAB5_CONTROLLER_B0        (5.703739609f)
    #define LAB5_CONTROLLER_B1        (-5.093441345f)
    #define LAB5_CONTROLLER_B2        (0.386769360f)
    #define LAB5_CONTROLLER_A1        (-0.704047945f)
    #define LAB5_CONTROLLER_A2        (-0.295952055f)
#else
    #error LAB5_DESIGN invalido.
#endif

#define LAB5_DESIGN_REVISION          (2u)
#define LAB5_TS_US                    (LAB5_TS_COUNTS * 10u)
#define LAB5_TS_TOLERANCE_US          (LAB5_TS_US / 10u)

/* Ganancias de Lab4 revalidadas fisicamente en J5/J7 el 20/11/2026. */
#define LAB5_ADC_OFFSET_VOLTS          (2.353802067f)
#define LAB5_ADC_VOLTS_PER_PLANT_VOLT  (0.210251951f)
#define LAB5_DAC_POSITIVE_GAIN         (3.842612000f)
#define LAB5_DAC_NEGATIVE_GAIN         (2.640105691f)
#define LAB5_DAC_VOLTS_PER_COUNT       (0.004f)
#define LAB5_ACTUATOR_OFFSET_VOLTS      (0.017209f)
#define LAB5_ACTUATOR_SLOPE             (0.98171f)
#define LAB5_OUTPUT_MAX_VOLTS          (1.0f)
#define LAB5_OUTPUT_MIN_VOLTS          (-1.0f)

#if LAB5_MODE > LAB5_MODE_STATIC_DIAGNOSTIC
    #error LAB5_MODE invalido.
#endif
#if LAB5_MODE == LAB5_MODE_CONTROL && !LAB5_CALIBRATED
    #error Revalidar calibracion de Lab5 antes de habilitar el control.
#endif
#if LAB5_SAMPLE_COUNT < 64u || LAB5_SAMPLE_COUNT > 1024u
    #error LAB5_SAMPLE_COUNT debe estar entre 64 y 1024.
#endif
#if LAB5_PRETRIGGER_SAMPLES < 8u || \
    LAB5_PRETRIGGER_SAMPLES >= LAB5_SAMPLE_COUNT
    #error Pretrigger invalido.
#endif

#endif
