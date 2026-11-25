function resultado = analizar_monitor_lab8(captureDir)
%ANALIZAR_MONITOR_LAB8 Valida y documenta la captura física MONITOR de Lab8.
%   RESULTADO = ANALIZAR_MONITOR_LAB8() selecciona la captura válida más
%   reciente. También puede indicarse explícitamente la carpeta CAPTUREDIR.

ensayosDir = fileparts(mfilename("fullpath"));
lab8Dir = fileparts(ensayosDir);

if nargin < 1 || strlength(string(captureDir)) == 0
    captureDir = buscarCapturaValida(fullfile(ensayosDir, ...
        "Capturas_Sincronizadas"));
else
    captureDir = string(captureDir);
end

metadataPath = fullfile(captureDir, "metadatos.json");
uartPath = fullfile(captureDir, "psoc_uart.csv");
ch1Path = fullfile(captureDir, "chan1.csv");
ch2Path = fullfile(captureDir, "chan2.csv");
scopePath = fullfile(captureDir, "pantalla_rigol_original.png");

requeridos = [metadataPath uartPath ch1Path ch2Path scopePath];
assert(all(isfile(requeridos)), ...
    "La captura no contiene todos los artefactos requeridos.");

meta = jsondecode(fileread(metadataPath));
uart = readtable(uartPath, VariableNamingRule="preserve");
ch1 = readtable(ch1Path, VariableNamingRule="preserve");
ch2 = readtable(ch2Path, VariableNamingRule="preserve");

assert(meta.preliminaryValid, "La captura no fue validada al adquirirla.");
assert(string(meta.detectedMode) == "MONITOR", ...
    "El firmware capturado no estaba en modo MONITOR.");
assert(height(uart) == 600, "Se esperaban exactamente 600 filas UART.");
assert(~anymissing(uart), "La tabla UART contiene datos faltantes.");
assert(isequal(uart.k, (0:599).'), "La secuencia k no es continua.");
assert(all(diff(uart.t_us) > 0), "El tiempo UART no es estrictamente creciente.");
assert(all(uart.flags == 0), "Existen banderas de diagnóstico no nulas.");
assert(all(uart.dac_pos == 0) && all(uart.dac_neg == 0), ...
    "MONITOR produjo códigos DAC distintos de cero.");
assert(all(uart.u_nominal_mV == 0), ...
    "MONITOR produjo un mando nominal distinto de cero.");

periodo = uart.intervalo_us(2:end);
metricas = struct;
metricas.filas_uart = height(uart);
metricas.y_media_mV = mean(uart.y_rel_mV, "omitmissing");
metricas.y_std_mV = std(uart.y_rel_mV, 0, "omitmissing");
metricas.y_pico_abs_mV = max(abs(uart.y_rel_mV), [], "omitmissing");
metricas.adc_media_counts = mean(uart.adc_counts, "omitmissing");
metricas.adc_std_counts = std(uart.adc_counts, 0, "omitmissing");
metricas.cpu_mediana_us = median(uart.cpu_us, "omitmissing");
metricas.cpu_max_us = max(uart.cpu_us, [], "omitmissing");
metricas.periodo_mediana_us = median(periodo, "omitmissing");
metricas.periodo_min_us = min(periodo, [], "omitmissing");
metricas.periodo_max_us = max(periodo, [], "omitmissing");
metricas.jitter_pico_us = max(abs(periodo - 2000), [], "omitmissing");
metricas.flags_no_nulos = nnz(uart.flags);
metricas.u_pico_abs_mV = max(abs(uart.u_nominal_mV), [], "omitmissing");
metricas.dac_pos_pico = max(uart.dac_pos, [], "omitmissing");
metricas.dac_neg_pico = max(uart.dac_neg, [], "omitmissing");
metricas.ch1_media_mV = 1000 * mean(ch1.voltage_V, "omitmissing");
metricas.ch1_std_mV = 1000 * std(ch1.voltage_V, 0, "omitmissing");
metricas.ch2_media_mV = 1000 * mean(ch2.voltage_V, "omitmissing");
metricas.ch2_std_mV = 1000 * std(ch2.voltage_V, 0, "omitmissing");

assert(metricas.cpu_max_us < 2000, ...
    "El tiempo de ISR excede el período de muestreo.");
assert(metricas.jitter_pico_us <= 5, ...
    "El jitter UART excede el umbral de prevalidación de 5 us.");

nombres = [
    "Filas UART"
    "Media de y relativa"
    "Desviación de y relativa"
    "Pico absoluto de y relativa"
    "Tiempo CPU mediano"
    "Tiempo CPU máximo"
    "Período mediano"
    "Período mínimo"
    "Período máximo"
    "Jitter pico respecto de 2 ms"
    "Flags no nulos"
    "Pico del mando nominal"
    "Pico DAC positivo"
    "Pico DAC negativo"
    "Media CH1 RIGOL"
    "Desviación CH1 RIGOL"
    "Media CH2 RIGOL"
    "Desviación CH2 RIGOL"];
valores = [
    metricas.filas_uart
    metricas.y_media_mV
    metricas.y_std_mV
    metricas.y_pico_abs_mV
    metricas.cpu_mediana_us
    metricas.cpu_max_us
    metricas.periodo_mediana_us
    metricas.periodo_min_us
    metricas.periodo_max_us
    metricas.jitter_pico_us
    metricas.flags_no_nulos
    metricas.u_pico_abs_mV
    metricas.dac_pos_pico
    metricas.dac_neg_pico
    metricas.ch1_media_mV
    metricas.ch1_std_mV
    metricas.ch2_media_mV
    metricas.ch2_std_mV];
unidades = ["muestras"; "mV"; "mV"; "mV"; "us"; "us"; "us"; ...
    "us"; "us"; "us"; "conteo"; "mV"; "código"; "código"; ...
    "mV"; "mV"; "mV"; "mV"];
criterios = ["= 600"; "informativo"; "informativo"; "informativo"; ...
    "informativo"; "< 2000"; "= 2000"; "informativo"; ...
    "informativo"; "<= 5"; "= 0"; "= 0"; "= 0"; "= 0"; ...
    "informativo"; "informativo"; "informativo"; "informativo"];
estado = ["OK"; "INFO"; "INFO"; "INFO"; "INFO"; "OK"; "OK"; ...
    "INFO"; "INFO"; "OK"; "OK"; "OK"; "OK"; "OK"; ...
    "INFO"; "INFO"; "INFO"; "INFO"];
resumen = table(nombres, valores, unidades, criterios, estado, ...
    VariableNames=["metrica" "valor" "unidad" "criterio" "estado"]);

resultadosDir = fullfile(lab8Dir, "05_Resultados");
figurasDir = fullfile(resultadosDir, "figuras");
informeFigurasDir = fullfile(lab8Dir, "06_Informe_IEEE", ...
    "Informe_Lab8", "figuras");
if ~isfolder(figurasDir)
    mkdir(figurasDir);
end
if ~isfolder(informeFigurasDir)
    mkdir(informeFigurasDir);
end

resumenPath = fullfile(resultadosDir, "resumen_monitor_fisico_lab8.csv");
writetable(resumen, resumenPath);

fig = figure(Visible="off", Color="white", Position=[100 100 1200 780]);
tl = tiledlayout(fig, 2, 1, TileSpacing="compact", Padding="compact");

ax1 = nexttile(tl);
plot(ax1, uart.t_us / 1e6, uart.y_rel_mV, ...
    Color=[0.00 0.35 0.70], LineWidth=1.0, DisplayName="y relativa");
hold(ax1, "on");
yline(ax1, 0, "k:", LineWidth=0.8, HandleVisibility="off");
hold(ax1, "off");
grid(ax1, "on");
xlabel(ax1, "Tiempo (s)");
ylabel(ax1, "Tensión (mV)");
title(ax1, sprintf("UART MONITOR: media %.3f mV, sigma %.3f mV", ...
    metricas.y_media_mV, metricas.y_std_mV));
xlim(ax1, [0 max(uart.t_us) / 1e6]);

ax2 = nexttile(tl);
plot(ax2, ch1.time_s, 1000 * ch1.voltage_V, ...
    Color=[0.90 0.70 0.05], LineWidth=1.0, DisplayName="CH1 -- J5");
hold(ax2, "on");
plot(ax2, ch2.time_s, 1000 * ch2.voltage_V, ...
    Color=[0.00 0.65 0.70], LineWidth=1.0, DisplayName="CH2 -- J7");
hold(ax2, "off");
grid(ax2, "on");
xlabel(ax2, "Tiempo relativo al disparo (s)");
ylabel(ax2, "Tensión (mV)");
title(ax2, "Formas de onda descargadas del RIGOL en reposo");
legend(ax2, Location="best", Box="off");

title(tl, "Prevalidación física en modo MONITOR");
figuraPath = fullfile(figurasDir, "monitor_fisico_lab8_resumen.png");
exportgraphics(fig, figuraPath, Resolution=220);
exportgraphics(fig, fullfile(informeFigurasDir, ...
    "monitor_fisico_lab8_resumen.png"), Resolution=220);
close(fig);

copyfile(scopePath, fullfile(figurasDir, ...
    "pantalla_rigol_monitor_original.png"), "f");
copyfile(scopePath, fullfile(informeFigurasDir, ...
    "pantalla_rigol_monitor_original.png"), "f");

resultado = struct;
resultado.captureDir = captureDir;
resultado.resumenPath = resumenPath;
resultado.figuraPath = figuraPath;
resultado.scopeOriginal = scopePath;
resultado.metricas = metricas;
resultado.valida = true;

fprintf("CAPTURA_MONITOR_VALIDADA: %s\n", captureDir);
fprintf("RESUMEN: %s\n", resumenPath);
fprintf("FIGURA: %s\n", figuraPath);
fprintf("ISR max=%g us; periodo=%g us; jitter pico=%g us; flags=%d.\n", ...
    metricas.cpu_max_us, metricas.periodo_mediana_us, ...
    metricas.jitter_pico_us, metricas.flags_no_nulos);
end

function captureDir = buscarCapturaValida(baseDir)
carpetas = dir(baseDir);
carpetas = carpetas([carpetas.isdir]);
nombres = string({carpetas.name});
carpetas = carpetas(~ismember(nombres, [".", ".."]));
[~, orden] = sort([carpetas.datenum], "descend");

captureDir = "";
for idx = orden
    candidata = fullfile(carpetas(idx).folder, carpetas(idx).name);
    metadataPath = fullfile(candidata, "metadatos.json");
    if ~isfile(metadataPath)
        continue
    end
    meta = jsondecode(fileread(metadataPath));
    if isfield(meta, "preliminaryValid") && meta.preliminaryValid && ...
            isfield(meta, "detectedMode") && ...
            string(meta.detectedMode) == "MONITOR"
        captureDir = string(candidata);
        break
    end
end

assert(strlength(captureDir) > 0, ...
    "No se encontró una captura MONITOR válida en %s.", baseDir);
end
