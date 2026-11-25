# Resultados — Simulación y validación física

Al ejecutar MATLAB desde `01_Modelado_MATLAB` se generan cuatro CSV de
simulación, dos PNG comparativos y un resumen. Estos archivos no son resultados
de banco.

`resumen_monitor_fisico_lab8.csv` contiene las métricas calculadas desde la
captura física válida. En `figuras/` se conservan tanto la comparación
reproducible UART/RIGOL como `pantalla_rigol_monitor_original.png`, copia sin
posprocesado de la pantalla entregada por el DS1202Z-E. Los CSV fuente y los
metadatos completos se mantienen en la carpeta fechada dentro de
`04_Ensayos/Capturas_Sincronizadas/`.

`resumen_abierto_pos_50mV.csv` resume la corrida física positiva del
25/11/2026: 46 mV nominales, 47.6 mV medidos en J5, 43 mV tardíos por UART,
ganancia 0.935, subida de 22 ms, 59 us máximos de ISR y cero banderas. Las
figuras estables son `ensayo_abierto_pos_50mV.png` y
`pantalla_rigol_abierto_pos_50mV_original.png`; esta última es una copia sin
posprocesado de la pantalla propia del instrumento.

`resumen_abierto_neg_50mV.csv` resume la corrida física negativa del mismo día:
-53 mV nominales, -54.0 mV medidos en J5, -49 mV tardíos por UART, ganancia
0.925, subida de 24 ms, 59 us máximos de ISR y cero banderas. Las figuras
estables son `ensayo_abierto_neg_50mV.png` y
`pantalla_rigol_abierto_neg_50mV_original.png`.

`resumen_integral_lento.csv` documenta el primer cierre de lazo físico: 50 mV
de referencia, 49 mV estacionarios, error de 1 mV, RMS de 3.209 mV, subida de
16 ms, sobrepasamiento de 20 %, mando nominal entre -21 mV y 77 mV, cero
saturaciones, cero bloqueos de anti-windup, cero fallas y 118 us máximos de ISR.
Las figuras estables son `ensayo_integral_lento.png` y
`pantalla_rigol_integral_lento_original.png`; la captura cruda fechada permanece
en `04_Ensayos/Capturas_Sincronizadas/20261125_015059_578_integral_lento/`.

`resumen_integral_rapido.csv` documenta la corrida separada del segundo diseño:
50 mV de referencia, 48 mV estacionarios, error de 2 mV, RMS de 2.843 mV,
subida de 12 ms, sobrepasamiento de 18 %, mando nominal entre -32 mV y 77 mV,
cero saturaciones, cero bloqueos de anti-windup, cero fallas y 117 us máximos
de ISR. Las figuras estables son `ensayo_integral_rapido.png` y
`pantalla_rigol_integral_rapido_original.png`; la captura cruda fechada permanece
en `04_Ensayos/Capturas_Sincronizadas/20261125_020830_577_integral_rapido/`.

En toda futura corrida se deben conservar separados datos crudos y procesados,
con procedencia, fecha, configuración de firmware y estado del banco.

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
