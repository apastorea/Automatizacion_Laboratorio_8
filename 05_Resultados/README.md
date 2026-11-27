# Resultados — Simulación y validación física

La planta ensayada es una sola cascada de segundo orden entre J5 y J7. U2.1 y
U2.2 son sus dos etapas internas de primer orden; no constituyen dos plantas
independientes. El modelo calculado y el identificado son dos representaciones
de esa misma planta.

Al ejecutar MATLAB desde `01_Modelado_MATLAB` se generan cuatro CSV de
simulación, dos PNG comparativos y un resumen. Estos archivos no son resultados
de banco.

`resumen_monitor_fisico_lab8.csv` contiene las métricas calculadas desde la
captura física válida. En `figuras/` se conservan tanto la comparación
reproducible UART/RIGOL como `pantalla_rigol_monitor_original.png`, copia sin
posprocesado de la pantalla entregada por el DS1202Z-E. Los CSV fuente y los
metadatos completos se mantienen en la carpeta fechada dentro de
`04_Ensayos/Capturas_Sincronizadas/`.

La validación principal se completó con 500 mV. El pulso abierto positivo
solicitó 500 mV, aplicó 507 mV nominales con código 33, alcanzó 492 mV por UART
y 508 mV en CH2. No hubo banderas y el máximo tiempo de ISR fue 59 us. La
captura original permanece en
`04_Ensayos/Capturas_Sincronizadas/20261127_121349_269_abierto_pos_500mV_post_reconexion/`.
La traza CH1 se conserva como dato crudo, pero no se emplea para calcular el
mando porque su amplitud no coincidió con la conversión calibrada del DAC.

`resumen_integral_lento.csv` documenta la corrida principal del diseño lento:
500 mV de referencia, 498 mV estacionarios, 2 mV de error, 2.980 mV RMS,
12 ms de subida, 10.4 % de sobrepasamiento y mando nominal entre -190 mV y
707 mV. No se registraron saturaciones, anti-windup ni fallas, y la ISR alcanzó
119 us. La captura cruda está en
`04_Ensayos/Capturas_Sincronizadas/20261127_121727_646_integral_lento_500mV_post_reconexion/`.

`resumen_integral_rapido.csv` documenta la corrida principal del diseño rápido:
500 mV de referencia, 498 mV estacionarios, 2 mV de error, 2.429 mV RMS,
10 ms de subida, 14.6 % de sobrepasamiento y mando nominal entre -253 mV y
769 mV. Tampoco hubo saturaciones, anti-windup o fallas; la ISR alcanzó 118 us.
La captura cruda está en
`04_Ensayos/Capturas_Sincronizadas/20261127_121849_376_integral_rapido_500mV_post_reconexion/`.

Las figuras estables `ensayo_integral_lento.png` y
`ensayo_integral_rapido.png` muestran la salida UART, CH2 del RIGOL y el mando
solicitado/nominal. Las pantallas originales se guardan por separado como
`pantalla_rigol_integral_lento_original.png` y
`pantalla_rigol_integral_rapido_original.png`. Las capturas de 50 mV se
conservan como diagnóstico histórico de baja amplitud, no como evidencia
principal del desempeño.

## Verificaciones de cierre

`cerrar_aportes_lab8.m` genera cuatro archivos que conectan directamente el
diseño con las mediciones:

- `validacion_modelos_abierto_lab8.csv`: RMSE, ajuste NRMSE y sesgo de meseta
  para los modelos de componentes e identificado;
- `verificacion_polos_lab8.csv`: polos solicitados, polos obtenidos y error
  numérico de ubicación;
- `revalidacion_escala_dac_lab8.csv`: escala calculada desde J5 en los códigos
  +3 y -5;
- `comparacion_simulacion_experimento_integral.csv`: comparación directa de
  subida, sobrepasamiento, error, RMS, mando y llegada a la meseta.

Las figuras `validacion_modelos_abierto_lab8.png` y `mapa_polos_lab8.png` se
conservan en `figuras/` y son las mismas utilizadas en el informe.
