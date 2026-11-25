# Registro de decisiones

## Parámetros de diseño

- Período de muestreo: 2 ms.
- Referencia experimental: pulso de 50 mV.
- Polos dominantes: 0.80 ± j0.25.
- Polo integral lento: 0.60.
- Polo integral rápido: 0.30.
- Polos del estimador actual: 0.20 ± j0.10.
- Modelo empleado para calcular ganancias: modelo identificado.
- Límites precuantización: -115 mV y +107 mV.
- Anti-windup: bloqueo condicional del integrador.

## Cierre experimental — 25/11/2026

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
- Estado final del PSoC: `MONITOR`, DAC en cero y autorizaciones deshabilitadas.

Si se cambia una ganancia, un límite, el período de muestreo o la configuración
de hardware, se debe registrar aquí y repetir las verificaciones afectadas.
