# Plan de ensayos — Control integral

Para los diseños lento (p_i=0.6) y rápido (p_i=0.3), registrar condiciones idénticas: referencia nominal inicial 0→50 mV→0, Ts=2 ms y observador actual E2.

Por ensayo conservar: firmware y configuración exactos; CSV UART con t_us, y, r, u solicitado/aplicado, integral, innovación, CPU, flags y saturaciones; CH1/CH2 del Rigol en CSV, PNG de pantalla y metadatos; fuente, sonda y escalas.

Medir tiempos de subida, establecimiento, sobrepasamiento, error final, esfuerzos, saturaciones, comportamiento de ruido y cuantización. Tres repeticiones de cada diseño después de validar montaje.

La etapa física MONITOR, los escalones abiertos de `+50 mV` y `-50 mV` y una
corrida de cada lazo integral a `+50 mV` se ejecutaron el 25/11/2026. Las
adquisiciones fueron válidas; cada una conserva 600 muestras UART, 1200 puntos
por canal y la pantalla original del RIGOL. Al finalizar, el PSoC se compiló y
programó nuevamente en MONITOR. Antes de repetir una medición se deben revisar
la conexión, los límites de la fuente y la configuración segura del firmware.

## Captura sincronizada segura

El capturador principal `capturar_monitor_lab8.m` registra simultáneamente las
600 muestras UART de Lab8 y una adquisición del Rigol mediante `visadev`, que
es la interfaz verificada en este banco. Espera exclusivamente firmware en
modo `MONITOR`, con los DAC en cero y todos los enclavamientos deshabilitados.
Genera
`psoc_uart.csv`, las formas de onda de CH1/CH2,
`pantalla_rigol_original.png` obtenida directamente del instrumento y
`metadatos.json` dentro de `Capturas_Sincronizadas/`.

`lab8_ensayo_sincronizado.py` y `capturar_lab8_monitor.cmd` quedan como ruta
alternativa para equipos con un backend VISA de Python funcional.

La validación preliminar exige: anuncio Lab8, modo coincidente, 600 filas,
banderas nulas y adquisición única terminada. No autoriza por sí sola el
escalón abierto ni el lazo integral.

### Revalidación bipolar en lazo abierto

`capturar_abierto_lab8.m` automatiza el siguiente peldaño experimental con la
planta conectada, CH1 en J5 y CH2 en J7. Se ejecutan dos corridas separadas,
primero `+50 mV` y luego `-50 mV`; cada pulso comienza en `k=32`, dura
96 muestras (192 ms) y vuelve automáticamente a cero. El firmware sólo puede
compilar este modo con `LAB8_AUTORIZAR_ESCALON=1`, y el preprocesador rechaza
amplitudes nulas o fuera de `[-50,+50] mV`.

Para cada polaridad:

1. ajustar en `lab8_config.h` el modo `LAB8_MODO_LAZO_ABIERTO`, la autorización
   a `1` y `LAB8_ESCALON_ABIERTO_MV` a `50` o `-50`;
2. compilar y programar únicamente con el operador presente, fuente limitada
   en corriente, masa común y posibilidad inmediata de cortar alimentación;
3. ejecutar `capturar_abierto_lab8(50,"abierto_pos_50mV")` o
   `capturar_abierto_lab8(-50,"abierto_neg_50mV")` y presionar una vez SW3;
4. no avanzar si hay banderas, polaridad DAC incorrecta, ausencia de respuesta
   o cambio de J5 fuera de 20--100 mV. Un disparo forzado sólo es aceptable si
   ambos flancos y la meseta completa permanecen visibles y los metadatos lo
   consignan explícitamente.

El capturador conserva `pantalla_rigol_original.png`, los CSV de CH1/CH2, la
telemetría UART cruda y tabulada y `metadatos.json`. Además verifica las
96 muestras activas, el signo de J5/J7, el código del DAC correspondiente y la
temporización. Finalizadas ambas corridas, regresar el firmware a MONITOR antes
de analizar o modificar el montaje.

La corrida `abierto_pos_50mV` del 25/11/2026 obtuvo 46 mV nominales,
47.6 mV en J5, 43 mV tardíos por UART, ganancia 0.935, subida de 22 ms,
59 us máximos de ISR y cero banderas. El pulso completo de 192 ms quedó visible
en el RIGOL. La corrida `abierto_neg_50mV` obtuvo -53 mV nominales, -54.0 mV
en J5, -49 mV tardíos por UART, ganancia 0.925, subida de 24 ms, 59 us máximos
de ISR y cero banderas. También conservó ambos flancos y la meseta completa.

## Análisis y entregables estables

Después de una captura válida, ejecutar:

```matlab
analizar_monitor_lab8
```

La función selecciona la adquisición MONITOR válida más reciente, comprueba la
continuidad de las 600 muestras, la temporización, las banderas y la salida nula.
Genera `05_Resultados/resumen_monitor_fisico_lab8.csv`, una figura comparativa
UART/RIGOL y una copia estable de `pantalla_rigol_monitor_original.png` para el
informe. La imagen original fechada siempre permanece en
`Capturas_Sincronizadas/`.

Para un escalón abierto válido, ejecutar pasando explícitamente su carpeta o,
para procesar automáticamente la captura abierta más reciente:

```matlab
analizar_abierto_lab8
```

El script valida los 600 registros, la ventana activa, la polaridad DAC, el
signo de la respuesta, la temporización y las banderas. Genera el resumen
`resumen_abierto_pos_50mV.csv` o `resumen_abierto_neg_50mV.csv`, la figura
comparativa correspondiente y una copia estable de la pantalla original del
RIGOL.

Para cualquiera de los lazos integrales válidos, ejecutar:

```matlab
analizar_integral_lab8
```

El analizador valida la referencia, el seguimiento, los límites, saturaciones,
anti-windup, banderas y temporización, y alinea la transición del RIGOL con
`k=32`. La corrida del 25/11/2026 obtuvo 49 mV estacionarios ante 50 mV, error
RMS de 3.209 mV, subida de 16 ms, sobrepasamiento de 20 %, mando nominal entre
-21 mV y 77 mV, cero saturaciones y 118 us máximos de ISR. Genera
`05_Resultados/resumen_integral_lento.csv`, `ensayo_integral_lento.png` y una
copia estable de `pantalla_rigol_integral_lento_original.png`.

La corrida rápida separada obtuvo 48 mV estacionarios, error RMS de 2.843 mV,
subida de 12 ms, sobrepasamiento de 18 %, mando nominal entre -32 mV y 77 mV,
cero saturaciones y 117 us máximos de ISR. Sus entregables estables son
`resumen_integral_rapido.csv`, `ensayo_integral_rapido.png` y
`pantalla_rigol_integral_rapido_original.png`. La adquisición cruda permanece en
`Capturas_Sincronizadas/20261125_020830_577_integral_rapido/`.
