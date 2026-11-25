/* lab5_experiment.h - Seleccion segura y reproducible del ensayo. */
#ifndef LAB5_EXPERIMENT_H
#define LAB5_EXPERIMENT_H

/* Compatibilidad HAL heredada de Lab5; control antiguo DESHABILITADO. */
#define LAB5_MODE                    LAB5_MODE_MONITOR
#define LAB5_DESIGN                  LAB5_DESIGN_TS2_DEADBEAT
#define LAB5_CALIBRATED              (0u)
#define LAB5_CALIBRATION_SOURCE      "LAB5_J5_J7_20261120_231219"
#define LAB5_REFERENCE_STEP_VOLTS    (0.050f)
#define LAB5_SAMPLE_COUNT            (256u)
#define LAB5_PRETRIGGER_SAMPLES      (32u)
#define LAB5_START_DELAY_MS          (3000u)
#define LAB5_STATIC_OUTPUT_VOLTS     (-0.200f)

#endif
