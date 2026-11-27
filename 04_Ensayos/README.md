# Plan de ensayos — Control integral

Para los diseños lento (p_i=0.6) y rápido (p_i=0.3), registrar condiciones idénticas: referencia nominal 0→500 mV→0, Ts=2 ms y observador actual E2. U2.1 y U2.2 son las dos etapas de una única planta física entre J5 y J7.

Por ensayo conservar: firmware y configuración exactos; CSV UART con t_us, y, r, u solicitado/aplicado, integral, innovación, CPU, flags y saturaciones; CH1/CH2 del Rigol en CSV, PNG de pantalla y metadatos; fuente, sonda y escalas.

Medir tiempos de subida, establecimiento, sobrepasamiento, error final,
esfuerzos, saturaciones, comportamiento de ruido y cuantización bajo el mismo
protocolo para ambos diseños.

La validación principal se completó el 27/11/2026 con un pulso abierto de
`+500 mV` y una corrida separada de cada controlador a `500 mV`. Cada
adquisición conserva 600 muestras UART, 1200 puntos por canal, metadatos y la
pantalla original del RIGOL. Las capturas de `±50 mV` se mantienen únicamente
como diagnóstico previo. Al finalizar, el PSoC se compiló y programó nuevamente
en MONITOR.

## Captura sincronizada segura

El capturador principal `capturar_monitor_lab8.m` registra simultáneamente las
600 muestras UART de Lab8 y una adquisición del Rigol mediante `visadev`, que
es la interfaz verificada en este banco. Espera exclusivamente firmware en
modo `MONITOR`, con los DAC en cero y todos los enclavamientos deshabilitados.
Genera
`psoc_uart.csv`, las formas de onda de CH1/CH2,
`pantalla_rigol_original.png` obtenida directamente del instrumento y
`metadatos.json` dentro de `Capturas_Sincronizadas/`.

Los tres capturadores aceptan el puerto serie como último argumento. Si sólo
hay uno disponible, lo seleccionan automáticamente; cuando hay varios se debe
indicar explícitamente el puerto del KitProg, por ejemplo:

```matlab
capturar_monitor_lab8("monitor_nuevo_psoc","COM9")
capturar_abierto_lab8(500,"abierto_pos_500mV","COM9")
capturar_integral_lab8("LENTO","integral_lento_500mV","COM9")
```

La configuración actual usa ambas sondas en 10X, adquisición `HRES`,
200 mV/div por canal para los ensayos de 500 mV y disparo desde CH2/J7 a
250 mV. CH2 se eligió como fuente de disparo porque su frente es más limpio que
el punto de mando. Para una presentación adicional del transitorio puede
guardarse una segunda pantalla a 10--20 ms/div, manteniendo la captura general
a 200 ms/div; esto mejora la lectura visual sin cambiar la referencia.

La revalidación del 27/11/2026 con la placa de reemplazo completó 600 muestras
en modo `MONITOR`, sin banderas y con ambos DAC en cero. El período mediano fue
de 2000 us, el jitter pico de 1 us y el máximo de ejecución de la ISR de 52 us.
La adquisición definitiva quedó en
`Capturas_Sincronizadas/20261127_120903_334_monitor_post_reconexion/`.

`lab8_ensayo_sincronizado.py` y `capturar_lab8_monitor.cmd` quedan como ruta
alternativa para equipos con un backend VISA de Python funcional.

La validación preliminar exige: anuncio Lab8, modo coincidente, 600 filas,
banderas nulas y adquisición única terminada. No autoriza por sí sola el
escalón abierto ni el lazo integral.

### Verificación principal en lazo abierto

`capturar_abierto_lab8.m` automatiza el ensayo con la planta conectada, CH1 en
J5 y CH2 en J7. El pulso comienza en `k=32`, dura 96 muestras (192 ms) y vuelve
automáticamente a cero. El firmware sólo puede compilar este modo con
`LAB8_AUTORIZAR_ESCALON=1`, y el preprocesador rechaza amplitudes nulas o fuera
de `[-500,+500] mV`.

Para cada polaridad:

1. ajustar en `lab8_config.h` el modo `LAB8_MODO_LAZO_ABIERTO`, la autorización
   a `1` y `LAB8_ESCALON_ABIERTO_MV` a `500` o `-500`;
2. compilar y programar únicamente con el operador presente, fuente limitada
   en corriente, masa común y posibilidad inmediata de cortar alimentación;
3. ejecutar `capturar_abierto_lab8(500,"abierto_pos_500mV")` o
   `capturar_abierto_lab8(-500,"abierto_neg_500mV")` y presionar una vez SW3;
4. no avanzar si hay banderas, polaridad DAC incorrecta o ausencia de
   respuesta. Un disparo forzado sólo es aceptable si ambos flancos y la meseta
   completa permanecen visibles y los metadatos lo consignan explícitamente.

El capturador conserva `pantalla_rigol_original.png`, los CSV de CH1/CH2, la
telemetría UART cruda y tabulada y `metadatos.json`. Además verifica las
96 muestras activas, la polaridad del DAC, el signo de la respuesta y la
temporización. La corrida positiva principal quedó en
`20261127_121349_269_abierto_pos_500mV_post_reconexion/`: 500 mV solicitados,
507 mV nominales, 492 mV de salida tardía por UART, 508 mV en CH2, código 33,
59 us máximos de ISR y cero banderas. CH1 se conservó como dato crudo, pero no
se utilizó cuantitativamente porque su amplitud no coincidió con la conversión
calibrada del DAC. Finalizado el ensayo, se regresó el firmware a MONITOR.

Las corridas de 50 mV que siguen son un antecedente diagnóstico y no sustituyen
la revalidación principal a 500 mV. La corrida `abierto_pos_50mV` del 25/11/2026 obtuvo 46 mV nominales,
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
`resumen_abierto_pos_500mV.csv` o `resumen_abierto_neg_500mV.csv`, la figura
comparativa correspondiente y una copia estable de la pantalla original del
RIGOL.

Para cualquiera de los lazos integrales válidos, ejecutar:

```matlab
analizar_integral_lab8
```

El analizador valida la referencia, el seguimiento, los límites, saturaciones,
anti-windup, banderas y temporización, y alinea la transición del RIGOL con
`k=32`. La corrida lenta principal obtuvo 498 mV estacionarios, 2 mV de error,
2.980 mV RMS, 12 ms de subida, 10.4 % de sobrepasamiento, mando nominal entre
-190 mV y 707 mV, cero saturaciones y 119 us máximos de ISR. La adquisición
cruda está en
`Capturas_Sincronizadas/20261127_121727_646_integral_lento_500mV_post_reconexion/`.

La corrida rápida obtuvo 498 mV estacionarios, 2 mV de error, 2.429 mV RMS,
10 ms de subida, 14.6 % de sobrepasamiento, mando nominal entre -253 mV y
769 mV, cero saturaciones y 118 us máximos de ISR. La adquisición cruda está en
`Capturas_Sincronizadas/20261127_121849_376_integral_rapido_500mV_post_reconexion/`.
Los entregables estables se guardan como `resumen_integral_lento.csv`,
`resumen_integral_rapido.csv`, las dos figuras procesadas y las dos pantallas
originales del RIGOL.
