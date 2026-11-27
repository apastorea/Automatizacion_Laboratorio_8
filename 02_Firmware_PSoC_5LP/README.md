# Firmware PSoC 5LP — Laboratorio 8

El proyecto se encuentra en `PSoC_Creator_Lab8/Lab8.cywrk` y está organizado
para ejecutar el seguimiento con acción integral, el estimador actual y la
telemetría de cada muestra.

Características implementadas:

- ganancias calculadas directamente con el modelo identificado; el modelo de
  componentes queda para comparación fuera de línea;
- observador actual con polos `0.20 +/- j0.10`;
- control integral lento (`z_i=0.60`) y rápido (`z_i=0.30`);
- límites precuantización `-1 V / +1 V`;
- corrección del observador con la tensión efectivamente cuantizada;
- anti-windup condicional;
- referencia principal `0 -> 500 mV -> 0`, seleccionada mediante barrido de
  amplitud y margen de actuación;
- telemetría UART de estados, integral, innovación, DAC, tiempos y banderas;
- pulso abierto bipolar parametrizado en milivoltios y limitado por compilación
  a una magnitud máxima de 500 mV;
- parada segura y enclavamientos de compilación.

El modo predeterminado es `LAB8_MODO_MONITOR`: adquiere y transmite, pero mantiene el DAC en cero. Para el procedimiento de habilitación consulte `PSoC_Creator_Lab8/LEEME_PRIMERO.md`.

Los ensayos preliminares de 50 mV se conservan como diagnóstico de baja
amplitud. La configuración revisada de 500 mV se entrega bloqueada en
`LAB8_MODO_MONITOR`, con todas las autorizaciones en cero; antes de aplicarla
debe seguirse la secuencia de comprobación indicada en el proyecto.
