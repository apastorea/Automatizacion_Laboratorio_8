%% LABORATORIO 8 - VALIDACION FINAL DEL MODELO Y LOS CONTROLADORES
% Procesa las capturas abiertas, verifica la ubicacion de polos y compara
% simulacion y experimento para los dos controladores integrales.
% Los pulsos se reservan para validacion: no se ajustan parametros ni se
% identifica un modelo nuevo. Este script no comunica con el hardware.

clear; clc; close all;

scriptFolder = fileparts(mfilename("fullpath"));
rootFolder = fileparts(scriptFolder);
resultsFolder = fullfile(rootFolder, "05_Resultados");
figureFolder = fullfile(resultsFolder, "figuras");
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end

Ts = 0.002;
C = [0 1];

%% Modelos de planta
R5 = 150e3;
R6 = 47e3;
R1 = 15e3;
R2 = 47e3;
C1 = 100e-9;
C3 = 100e-9;
Fnom = [-1/(R5*C1) 0; -1/(R2*C3) -1/(R1*C3)];
Gnom = [-1/(R6*C1); 0];
[Anom, Bnom] = discretizarZoh(Fnom, Gnom, Ts);

Kidentificada = 1.002941;
tau1 = 0.00906915;
tau2 = 0.000774399;
gananciaEtapa1 = R5/R6;
gananciaEtapa2 = Kidentificada/gananciaEtapa1;
Fid = [-1/tau1 0; -gananciaEtapa2/tau2 -1/tau2];
Gid = [-gananciaEtapa1/tau1; 0];
[Aid, Bid] = discretizarZoh(Fid, Gid, Ts);

%% Validacion independiente con el escalon abierto de 500 mV
captureRoot = fullfile(rootFolder, "04_Ensayos", "Capturas_Sincronizadas");
captureFolders = fullfile(captureRoot, ...
    "20261127_121349_269_abierto_pos_500mV_post_reconexion");
testNames = "500_mV";

requiredVariables = ["k" "t_us" "y_cal_mV" "u_nominal_mV" "flags"];
validationRows = table();

figValidation = figure("Color", "w", "Position", [100 100 1050 760]);
layoutValidation = tiledlayout(figValidation, 1, 1, ...
    "TileSpacing", "compact", "Padding", "compact");

for testIndex = 1:numel(testNames)
    csvPath = fullfile(captureFolders(testIndex), "psoc_uart.csv");
    assert(isfile(csvPath), "No se encontro %s.", csvPath);
    data = readtable(csvPath);
    assert(all(ismember(requiredVariables, string(data.Properties.VariableNames))), ...
        "Faltan variables obligatorias en %s.", csvPath);
    assert(~anymissing(data(:, requiredVariables)), ...
        "La captura %s contiene datos faltantes.", testNames(testIndex));
    assert(all(data.flags == 0), ...
        "La captura %s contiene banderas no nulas.", testNames(testIndex));

    k = data.k;
    timeMs = data.t_us*1e-3;
    inputV = data.u_nominal_mV*1e-3;
    baselineMask = k < 32;
    baselineMv = median(data.y_cal_mV(baselineMask), "omitmissing");
    measuredV = (data.y_cal_mV-baselineMv)*1e-3;

    nominalV = simulateDiscrete(Anom, Bnom, C, inputV);
    identifiedV = simulateDiscrete(Aid, Bid, C, inputV);
    analysisMask = k >= 32 & k <= 180;
    plateauMask = k >= 96 & k <= 127;

    nominalMetrics = validationMetrics(measuredV, nominalV, analysisMask, plateauMask);
    identifiedMetrics = validationMetrics(measuredV, identifiedV, analysisMask, plateauMask);
    validationRows = [validationRows; ...
        buildValidationRow(testNames(testIndex), "nominal", nominalMetrics); ...
        buildValidationRow(testNames(testIndex), "identificada", identifiedMetrics)]; %#ok<AGROW>

    ax = nexttile(layoutValidation);
    relativeTimeMs = timeMs - timeMs(find(k == 32, 1, "first"));
    hold(ax, "on");
    plot(ax, relativeTimeMs, 1000*measuredV, "Color", [0 0.4470 0.7410], ...
        "LineWidth", 1.35, "DisplayName", "Medicion UART");
    plot(ax, relativeTimeMs, 1000*nominalV, "--", ...
        "Color", [0.8500 0.3250 0.0980], "LineWidth", 1.35, ...
        "DisplayName", "Modelo nominal");
    plot(ax, relativeTimeMs, 1000*identifiedV, "-.", ...
        "Color", [0.4660 0.6740 0.1880], "LineWidth", 1.45, ...
        "DisplayName", "Modelo identificado");
    stairs(ax, relativeTimeMs, 1000*inputV, ":", ...
        "Color", [0.25 0.25 0.25], "LineWidth", 1.1, ...
        "DisplayName", "Mando aplicado");
    hold(ax, "off");
    grid(ax, "on");
    xlim(ax, [-40 320]);
    ylabel(ax, "Tension [mV]");
    title(ax, "Escalon abierto de 500 mV");
    legend(ax, "Location", "best", "NumColumns", 2);
end
xlabel(layoutValidation, "Tiempo relativo al escalon [ms]");
title(layoutValidation, "Validacion de los modelos con la adquisicion actual");
exportgraphics(figValidation, ...
    fullfile(figureFolder, "validacion_modelos_abierto_500mV.png"), ...
    "Resolution", 220);
close(figValidation);

writetable(validationRows, ...
    fullfile(resultsFolder, "validacion_modelos_abierto_500mV.csv"));

%% Verificacion explicita de polos
dominantPoles = [0.80+0.25i 0.80-0.25i];
integralPoles = [0.60 0.30];
designNames = ["lento" "rapido"];
observerPoles = [0.20+0.10i 0.20-0.10i];
Aa = [Aid zeros(2, 1); -C 1];
Ba = [Bid; 0];
L = place(Aid', (C*Aid)', observerPoles).';
observerErrorMatrix = (eye(2)-L*C)*Aid;

poleRows = table();
controllerPoles = cell(1, 2);
controllerGains = cell(1, 2);
maxPlacementError = zeros(1, 2);
for designIndex = 1:2
    desired = [dominantPoles integralPoles(designIndex)].';
    controllerGains{designIndex} = place(Aa, Ba, desired.');
    achieved = eig(Aa-Ba*controllerGains{designIndex});
    controllerPoles{designIndex} = achieved;
    maxPlacementError(designIndex) = setDistance(achieved, desired);
    poleRows = [poleRows; poleTableRows("control", designNames(designIndex), ...
        achieved, maxPlacementError(designIndex))]; %#ok<AGROW>
end
achievedObserver = eig(observerErrorMatrix);
observerPlacementError = setDistance(achievedObserver, observerPoles.');
poleRows = [poleRows; poleTableRows("observador", "actual", ...
    achievedObserver, observerPlacementError)];
poleRows = [poleRows; poleTableRows("planta", "identificada_abierta", ...
    eig(Aid), NaN)];
assert(max(maxPlacementError) < 1e-9, ...
    "La ubicacion de polos del controlador no coincide con el objetivo.");
assert(observerPlacementError < 1e-9, ...
    "La ubicacion de polos del observador no coincide con el objetivo.");
writetable(poleRows, fullfile(resultsFolder, "verificacion_polos_lab8.csv"));

figPoles = figure("Color", "w", "Position", [100 100 1050 470]);
layoutPoles = tiledlayout(figPoles, 1, 2, ...
    "TileSpacing", "compact", "Padding", "compact");
theta = linspace(0, 2*pi, 500);

ax1 = nexttile(layoutPoles);
hold(ax1, "on");
plot(ax1, cos(theta), sin(theta), "k:", "LineWidth", 1.0, ...
    "DisplayName", "Circulo unitario");
scatter(ax1, real(controllerPoles{1}), imag(controllerPoles{1}), ...
    70, "o", "LineWidth", 1.5, "DisplayName", "Integral lento");
scatter(ax1, real(controllerPoles{2}), imag(controllerPoles{2}), ...
    70, "x", "LineWidth", 1.8, "DisplayName", "Integral rapido");
hold(ax1, "off");
axis(ax1, "equal");
xlim(ax1, [-1.05 1.05]);
ylim(ax1, [-1.05 1.05]);
grid(ax1, "on");
xlabel(ax1, "Parte real");
ylabel(ax1, "Parte imaginaria");
title(ax1, "Polos del sistema aumentado");
legend(ax1, "Location", "southoutside", "NumColumns", 3);

ax2 = nexttile(layoutPoles);
hold(ax2, "on");
plot(ax2, cos(theta), sin(theta), "k:", "LineWidth", 1.0, ...
    "DisplayName", "Circulo unitario");
scatter(ax2, real(eig(Aid)), imag(eig(Aid)), ...
    70, "square", "LineWidth", 1.5, "DisplayName", "Planta identificada");
scatter(ax2, real(achievedObserver), imag(achievedObserver), ...
    70, "diamond", "LineWidth", 1.5, "DisplayName", "Error del observador");
hold(ax2, "off");
axis(ax2, "equal");
xlim(ax2, [-1.05 1.05]);
ylim(ax2, [-1.05 1.05]);
grid(ax2, "on");
xlabel(ax2, "Parte real");
ylabel(ax2, "Parte imaginaria");
title(ax2, "Planta y observador actual");
legend(ax2, "Location", "southoutside", "NumColumns", 3);
exportgraphics(figPoles, fullfile(figureFolder, "mapa_polos_lab8.png"), ...
    "Resolution", 220);
close(figPoles);

%% Comparacion directa entre simulacion identificada y experimento
simulationSummary = readtable(fullfile(resultsFolder, ...
    "resumen_integral_lab8.csv"), TextType="string");
comparisonRows = table();
for designIndex = 1:2
    designToken = "integral_" + designNames(designIndex);
    simMask = simulationSummary.diseno == designToken & ...
        simulationSummary.modelo == "identificado";
    assert(nnz(simMask) == 1, ...
        "No hay una fila unica para %s/identificado.", designToken);
    simRow = simulationSummary(simMask, :);
    simDetail = readtable(fullfile(resultsFolder, designToken + ...
        "_identificado.csv"));
    regimeMask = simDetail.t_s >= 0.550 & simDetail.t_s <= 0.660 & ...
        simDetail.r_V > 0;
    simRmsMv = 1000*sqrt(mean((simDetail.r_V(regimeMask) - ...
        simDetail.y_V(regimeMask)).^2, "omitmissing"));
    simWindowMs = practicalWindowMetric(1000*simDetail.t_s, ...
        1000*simDetail.y_V, 1000*simDetail.r_V, 10, 10, 0.8);

    experimentSummary = readtable(fullfile(resultsFolder, ...
        "resumen_integral_" + designNames(designIndex) + ".csv"), ...
        TextType="string");
    experimentFolder = fullfile(captureRoot, ...
        conditionalFolder(designNames(designIndex)));
    experimentData = readtable(fullfile(experimentFolder, "psoc_uart.csv"));
    expWindowMs = practicalWindowMetric(experimentData.t_us*1e-3, ...
        experimentData.y_rel_mV, experimentData.r_mV, 10, 10, 0.8);

    comparisonRows = [comparisonRows; table( ...
        designNames(designIndex), ...
        simRow.tr_ms, experimentSummary.rise_time_ms, ...
        simRow.Mp_pct, experimentSummary.overshoot_pct, ...
        simRow.ess_mV, experimentSummary.steady_error_mV, ...
        simRmsMv, experimentSummary.rms_error_mV, ...
        simRow.u_min_mV, experimentSummary.u_nominal_min_mV, ...
        simRow.u_max_mV, experimentSummary.u_nominal_max_mV, ...
        simWindowMs, expWindowMs, ...
        VariableNames=["diseno" "tr_sim_ms" "tr_exp_ms" ...
        "Mp_sim_pct" "Mp_exp_pct" "ess_sim_mV" "ess_exp_mV" ...
        "rms_sim_mV" "rms_exp_mV" "umin_sim_mV" "umin_exp_mV" ...
        "umax_sim_mV" "umax_exp_mV" "ventana20_sim_ms" ...
        "ventana20_exp_ms"])]; %#ok<AGROW>
end
writetable(comparisonRows, fullfile(resultsFolder, ...
    "comparacion_simulacion_experimento_integral.csv"));

%% Verificacion de la escala DAC en la condicion experimental vigente
openData = readtable(fullfile(captureFolders, "psoc_uart.csv"));
openPulseMask = openData.k >= 32 & openData.k <= 127;
dacCode = median(openData.dac_pos(openPulseMask), "omitmissing");
nominalOutputMv = median(openData.u_nominal_mV(openPulseMask), "omitmissing");
modelMvPerCode = 15.370448;
appliedMvPerCode = nominalOutputMv/dacCode;
relativeDifferencePct = 100*(appliedMvPerCode-modelMvPerCode)/modelMvPerCode;
dacScale = table("positiva", dacCode, modelMvPerCode, nominalOutputMv, ...
    appliedMvPerCode, relativeDifferencePct, ...
    VariableNames=["rama" "codigo" "mV_por_codigo_modelo" ...
    "salida_nominal_mV" "mV_por_codigo_aplicado" ...
    "diferencia_relativa_pct"]);
writetable(dacScale, fullfile(resultsFolder, ...
    "revalidacion_escala_dac_500mV.csv"));

fprintf("\nCIERRE LAB8 COMPLETADO\n");
fprintf("RMSE a 500 mV, modelo nominal: %.3f mV\n", ...
    nominalMetrics.rmse_mV);
fprintf("RMSE a 500 mV, modelo identificado: %.3f mV\n", ...
    identifiedMetrics.rmse_mV);
fprintf("Ajuste a 500 mV, modelo nominal: %.2f %%\n", ...
    nominalMetrics.fit_nrmse_pct);
fprintf("Ajuste a 500 mV, modelo identificado: %.2f %%\n", ...
    identifiedMetrics.fit_nrmse_pct);
fprintf("Error maximo de ubicacion de control: %.3g\n", ...
    max(maxPlacementError));
fprintf("Error de ubicacion del observador: %.3g\n", ...
    observerPlacementError);
disp(comparisonRows);
disp(dacScale);

%% Funciones locales
function [A, B] = discretizarZoh(F, G, Ts)
    augmented = expm([F G; zeros(1, 3)]*Ts);
    A = augmented(1:2, 1:2);
    B = augmented(1:2, 3);
end

function y = simulateDiscrete(A, B, C, u)
    state = zeros(size(A, 1), 1);
    y = zeros(size(u));
    for sampleIndex = 1:numel(u)
        y(sampleIndex) = C*state;
        state = A*state + B*u(sampleIndex);
    end
end

function metrics = validationMetrics(measured, predicted, mask, plateauMask)
    residual = measured(mask) - predicted(mask);
    metrics.rmse_mV = 1000*sqrt(mean(residual.^2, "omitmissing"));
    denominator = norm(measured(mask) - mean(measured(mask), "omitmissing"));
    metrics.fit_nrmse_pct = 100*(1 - norm(residual)/denominator);
    if any(plateauMask)
        metrics.measured_plateau_mV = 1000*median(measured(plateauMask), ...
            "omitmissing");
        metrics.predicted_plateau_mV = 1000*median(predicted(plateauMask), ...
            "omitmissing");
        metrics.plateau_bias_mV = metrics.predicted_plateau_mV - ...
            metrics.measured_plateau_mV;
    else
        metrics.measured_plateau_mV = NaN;
        metrics.predicted_plateau_mV = NaN;
        metrics.plateau_bias_mV = NaN;
    end
end

function row = buildValidationRow(testName, modelName, metrics)
    row = table(testName, modelName, metrics.rmse_mV, ...
        metrics.fit_nrmse_pct, metrics.measured_plateau_mV, ...
        metrics.predicted_plateau_mV, metrics.plateau_bias_mV, ...
        VariableNames=["ensayo" "modelo" "rmse_mV" "fit_nrmse_pct" ...
        "meseta_medida_mV" "meseta_predicha_mV" "sesgo_meseta_mV"]);
end

function distance = setDistance(achieved, desired)
    distances = abs(achieved(:) - desired(:).');
    distance = max(min(distances, [], 2));
end

function rows = poleTableRows(component, design, poles, placementError)
    poleCount = numel(poles);
    rows = table(repmat(component, poleCount, 1), ...
        repmat(design, poleCount, 1), real(poles(:)), imag(poles(:)), ...
        abs(poles(:)), abs(poles(:)) < 1, ...
        repmat(placementError, poleCount, 1), ...
        VariableNames=["componente" "diseno" "parte_real" ...
        "parte_imaginaria" "modulo" "estable" "error_ubicacion_max"]);
end

function timeMs = practicalWindowMetric(tMs, yMv, rMv, halfBandMv, ...
        windowSamples, requiredOccupancy)
    pulseMask = rMv > 0;
    startIndex = find(pulseMask, 1, "first");
    endIndex = find(pulseMask, 1, "last");
    timeMs = NaN;
    if isempty(startIndex) || isempty(endIndex)
        return;
    end
    referenceMv = median(rMv(pulseMask), "omitmissing");
    lastCandidate = endIndex-windowSamples+1;
    for sampleIndex = startIndex:lastCandidate
        window = yMv(sampleIndex:sampleIndex+windowSamples-1);
        inside = abs(window-referenceMv) <= halfBandMv;
        if mean(inside) >= requiredOccupancy && ...
                abs(median(window, "omitmissing")-referenceMv) <= halfBandMv
            timeMs = tMs(sampleIndex)-tMs(startIndex);
            return;
        end
    end
end

function folderName = conditionalFolder(designName)
    if designName == "lento"
        folderName = ...
            "20261127_121727_646_integral_lento_500mV_post_reconexion";
    else
        folderName = ...
            "20261127_121849_376_integral_rapido_500mV_post_reconexion";
    end
end
