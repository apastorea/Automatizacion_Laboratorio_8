# Firmware PSoC 5LP — Laboratorio 8

El proyecto se encuentra en `PSoC_Creator_Lab8/Lab8.cywrk` y está organizado
para ejecutar el seguimiento con acción integral, el estimador actual y la
telemetría de cada muestra.

Características implementadas:

- ganancias calculadas directamente con el modelo identificado; el modelo de
  componentes queda para comparación fuera de línea;
- observador actual con polos `0.20 +/- j0.10`;
- control integral lento (`z_i=0.60`) y rápido (`z_i=0.30`);
- límites precuantización `-115 mV / +107 mV`;
- corrección del observador con la tensión efectivamente cuantizada;
- anti-windup condicional;
- referencia `0 -> 50 mV -> 0`;
- telemetría UART de estados, integral, innovación, DAC, tiempos y banderas;
- pulso abierto bipolar parametrizado en milivoltios y limitado por compilación
  a una magnitud máxima de 50 mV;
- parada segura y enclavamientos de compilación.

El modo predeterminado es `LAB8_MODO_MONITOR`: adquiere y transmite, pero mantiene el DAC en cero. Para el procedimiento de habilitación consulte `PSoC_Creator_Lab8/LEEME_PRIMERO.md`.

El 25/11/2026 se compilaron, programaron y midieron por separado los diseños
lento y rápido. Finalizadas las capturas, el proyecto se recompiló y programó
en `LAB8_MODO_MONITOR`, con todas las autorizaciones en cero. Esta es la
configuración segura que permanece en el repositorio y en la placa.
