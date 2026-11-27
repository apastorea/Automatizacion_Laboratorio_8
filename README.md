# Laboratorio 8 — Seguimiento integral de una planta en cascada

Este repositorio contiene el diseño, la simulación y la validación experimental
de dos controladores digitales con acción integral y estimador de estado actual
para una única planta analógica de segundo orden. La planta está formada por
las etapas U2.1 y U2.2 conectadas en cascada entre J5 y J7. El período de
muestreo es de 2 ms y
los diseños se diferencian por el tercer polo del sistema ampliado: 0.60 para el
controlador lento y 0.30 para el rápido.

El trabajo incluye:

- diseño por ubicación de polos con el modelo identificado de la planta;
- comparación frente al modelo calculado a partir de los componentes;
- simulaciones reproducibles en MATLAB y Simulink;
- firmware PSoC 5LP con saturación, anti-windup, telemetría y parada segura;
- selección documentada de una referencia de 500 mV a partir de la resolución
  de medida, la cuantización del DAC y el margen del actuador;
- protocolo de ensayos MONITOR, escalón abierto de +500 mV y lazo cerrado
  con ambos controladores;
- datos UART y RIGOL, capturas originales del osciloscopio y métricas procesadas;
- informe IEEE escrito en LaTeX.

## Resultados principales

La validación abierta vigente de 500 mV arrojó un RMSE de 14.417 mV para el
modelo identificado y de 36.079 mV para el modelo calculado a partir de los
componentes. Esto representa una reducción del 60.0 % y confirma el modelo
identificado como base de síntesis. El barrido de amplitudes seleccionó
500 mV para los ensayos principales: en simulación con ese modelo, el mayor
esfuerzo fue 0.745 V, con 25.5 % de margen respecto del límite de 1 V y sin
saturación. A esta escala, un paso del DAC positivo representa 3.07 % de la
referencia y el RMSE de lectura caracterizado representa 0.675 %.

Las corridas físicas principales se realizaron con 500 mV. La verificación
abierta aplicó 507 mV nominales, obtuvo 492 mV por UART y 508 mV en CH2. En
lazo cerrado, los diseños lento y rápido alcanzaron 498 mV, con 2 mV de error
estacionario; sus tiempos de subida fueron 12 ms y 10 ms, y sus
sobrepasamientos, 10.4 % y 14.6 %. No hubo saturaciones, activaciones de
anti-windup ni banderas de falla.

El período medido permaneció entre 1999 y 2001 us. El peor tiempo de ISR fue
119 us, equivalente al 5.95 % del período. Las capturas físicas de 50 mV se
conservan sólo como diagnóstico de polaridad y baja amplitud. Al finalizar, la
placa quedó programada en modo `MONITOR`, con ambos DAC en cero y todos los
enclavamientos de actuación deshabilitados.

## Estructura

- `01_Modelado_MATLAB/`: diseño, análisis, Simulink y scripts de validación.
- `02_Firmware_PSoC_5LP/`: workspace de PSoC Creator y prueba del núcleo de control.
- `04_Ensayos/`: capturadores y adquisiciones crudas sincronizadas.
- `05_Resultados/`: tablas, figuras y resúmenes reproducibles.
- `06_Informe_IEEE/Informe_Lab8/`: fuente LaTeX y PDF final
  `Informe_Lab8_Automatizacion_Aldo_Pastore_v2.pdf`.
- `07_Registro_de_decisiones/`: parámetros y estado final del trabajo.

## Reproducción

Desde MATLAB, con `01_Modelado_MATLAB` como carpeta activa:

```matlab
diseno_control_integral_lab8
comparar_dac_ideal_cuantizado_lab8
analizar_adc_ruido_lab8
verificar_simulink_lab8
cerrar_aportes_lab8
```

El firmware se abre desde
`02_Firmware_PSoC_5LP/PSoC_Creator_Lab8/Lab8.cywrk`. La configuración incluida
en el repositorio es la segura: `LAB8_MODO_MONITOR` y autorizaciones en cero.

Los archivos `04_Ensayos/README.md` y `05_Resultados/README.md` detallan el
protocolo de captura, la organización de los datos y el origen de cada figura.
