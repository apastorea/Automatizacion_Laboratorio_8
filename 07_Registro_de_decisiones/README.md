# Registro de decisiones

## Parámetros de diseño

- Período de muestreo: 2 ms.
- Referencia principal: pulso de 500 mV.
- Polos dominantes: 0.80 ± j0.25.
- Polo integral lento: 0.60.
- Polo integral rápido: 0.30.
- Polos del estimador actual: 0.20 ± j0.10.
- Modelo empleado para calcular ganancias: modelo identificado.
- Límites físicos del mando: -1.000 V y +1.000 V.
- Anti-windup: bloqueo condicional del integrador.

## Selección de la condición experimental

- Se evaluaron referencias de 50, 100, 250, 500, 750 y 1000 mV.
- La selección se realizó con el modelo identificado, que también se utiliza
  para calcular el controlador y el estimador.
- Con 500 mV, el mayor mando simulado fue 744.9 mV: queda 25.5 % de margen y no
  aparecen muestras saturadas.
- Con 750 mV ya aparecen dos muestras saturadas; con 1000 mV aparecen 26.
- La cuantización positiva del DAC pasa de representar 30.74 % de una
  referencia de 50 mV a 3.07 % de una referencia de 500 mV.
- El RMSE de lectura caracterizado, 3.374 mV, pasa de 6.75 % a 0.675 % de la
  referencia.

## Antecedente experimental de baja amplitud — 25/11/2026

- Modo MONITOR comprobado con 600 muestras y salida DAC nula.
- Escalones abiertos de +50 mV y -50 mV completados sin banderas.
- Escala del DAC verificada en los códigos +3 y -5 del punto de trabajo.
- Controlador lento ensayado con 49 mV estacionarios y 3.209 mV RMS.
- Controlador rápido ensayado con 48 mV estacionarios y 2.843 mV RMS.
- Período medido entre 1999 y 2001 us; tiempo máximo de ISR de 118 us.
- Capturas UART, formas de onda y pantallas originales del RIGOL archivadas.
- Modelo Simulink verificado sin puertos ni líneas desconectados.
- Informe actualizado con validación de modelos, mapas de polos, comparación
  simulación--experimento y comprobación de escala del DAC.
- Estas corridas se consideran diagnósticas porque la amplitud de 50 mV deja
  una relación desfavorable frente al ruido y la cuantización.
- Estado final del PSoC: `MONITOR`, DAC en cero y autorizaciones deshabilitadas.

## Protocolo pendiente a 500 mV

- Revalidar MONITOR antes de habilitar cualquier actuación.
- Ejecutar primero los escalones abiertos de +500 mV y -500 mV.
- Ejecutar luego el lazo lento y, tras volver a MONITOR, el lazo rápido.
- Conservar para cada corrida UART, ondas CH1/CH2, pantalla original del RIGOL,
  metadatos y configuración exacta del firmware.
- Volver a programar MONITOR al terminar.

Si se cambia una ganancia, un límite, el período de muestreo o la configuración
de hardware, se debe registrar aquí y repetir las verificaciones afectadas.
