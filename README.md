# Laboratorio 8 — Sistemas de seguimiento con control integral

Este repositorio contiene el diseño, la simulación y la validación experimental
de dos controladores digitales con acción integral y estimador de estado actual
para una planta analógica de segundo orden. El período de muestreo es de 2 ms y
los diseños se diferencian por el tercer polo del sistema ampliado: 0.60 para el
controlador lento y 0.30 para el rápido.

El trabajo incluye:

- diseño por ubicación de polos con el modelo identificado de la planta;
- comparación frente al modelo calculado a partir de los componentes;
- simulaciones reproducibles en MATLAB y Simulink;
- firmware PSoC 5LP con saturación, anti-windup, telemetría y parada segura;
- ensayos MONITOR, escalones abiertos de ±50 mV y lazo cerrado con ambos
  controladores;
- datos UART y RIGOL, capturas originales del osciloscopio y métricas procesadas;
- informe IEEE escrito en LaTeX.

## Resultados principales

El modelo identificado obtuvo un RMSE conjunto de 5.756 mV en los escalones de
validación, frente a 6.772 mV del modelo de componentes. En lazo cerrado, el
controlador lento alcanzó 49 mV ante una referencia de 50 mV, con subida de
16 ms, sobrepasamiento de 20 % y error RMS de 3.209 mV. El rápido alcanzó
48 mV, con subida de 12 ms, sobrepasamiento de 18 % y error RMS de 2.843 mV.
No se registraron saturaciones, bloqueos de anti-windup ni fallas.

El período medido permaneció entre 1999 y 2001 us. El peor tiempo de ISR fue
118 us, equivalente al 5.9 % del período. Las escalas del DAC en los códigos de
trabajo difirieron 3.23 % en la rama positiva y 2.27 % en la negativa respecto
de los valores del modelo. Al finalizar, la placa quedó programada en modo
`MONITOR`, con ambos DAC en cero y todos los enclavamientos de actuación
deshabilitados.

## Estructura

- `01_Modelado_MATLAB/`: diseño, análisis, Simulink y scripts de validación.
- `02_Firmware_PSoC_5LP/`: workspace de PSoC Creator y prueba del núcleo de control.
- `04_Ensayos/`: capturadores y adquisiciones crudas sincronizadas.
- `05_Resultados/`: tablas, figuras y resúmenes reproducibles.
- `06_Informe_IEEE/Informe_Lab8/`: fuente LaTeX y PDF final.
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
