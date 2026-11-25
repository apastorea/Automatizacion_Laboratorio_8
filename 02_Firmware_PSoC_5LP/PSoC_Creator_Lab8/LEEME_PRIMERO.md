# Proyecto PSoC Creator del Laboratorio 8

El workspace correcto es `Lab8.cywrk` y el proyecto es
`Lab8.cydsn/Lab8.cyprj`.

## Organización

- TopDesign, asignación de pines y componentes ADC/DAC.
- Temporizadores, UART y capa de hardware `lab5_hardware.*`.
- `lab8_control_integral.*`: observador actual, integral del error y anti-windup condicional.
- Matrices, controlador y observador calculados con el modelo identificado.
- `lab8_config.h`: selección entre diseño lento (`z_i=0.60`) y rápido (`z_i=0.30`).
- `main.c`: referencia pulsada de 50 mV, telemetría de `xi`, innovación, saturación y anti-windup.
- Mensajes UART y archivos de captura etiquetados como Lab8.

## Secuencia segura

1. Abrir `Lab8.cywrk` en PSoC Creator 4.4.
2. Confirmar en `lab8_config.h` que `LAB8_MODO` sea `LAB8_MODO_MONITOR` y que todos los enclavamientos permanezcan en cero.
3. Generar la aplicación y compilar Lab8. MONITOR mantiene ambos DAC en código cero.
4. Revalidar alimentación, masa, ADC, DAC, sentido de la planta y período de 2 ms con el osciloscopio.
5. Para la prueba abierta, habilitar solo `LAB8_AUTORIZAR_ESCALON` y seleccionar `LAB8_MODO_LAZO_ABIERTO`.
6. Para el control integral, habilitar los tres enclavamientos y seleccionar `LAB8_MODO_INTEGRAL`. Probar primero el diseño lento y después el rápido.
7. Guardar cada CSV UART y captura del Rigol junto con el firmware exacto.

Los ensayos de ambos controladores se completaron el 25/11/2026. La versión
entregada permanece en `LAB8_MODO_MONITOR`, con los DAC en cero y todos los
enclavamientos deshabilitados.
