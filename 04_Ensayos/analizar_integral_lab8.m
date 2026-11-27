function resumen = analizar_integral_lab8(captureFolder)
%ANALIZAR_INTEGRAL_LAB8 Resume una captura valida del lazo integral.

arguments
    captureFolder (1,1) string = ""
end

scriptFolder = fileparts(mfilename("fullpath"));
labFolder = fileparts(scriptFolder);
resultsFolder = fullfile(labFolder,"05_Resultados");
figuresFolder = fullfile(resultsFolder,"figuras");
if ~isfolder(figuresFolder), mkdir(figuresFolder); end

if strlength(captureFolder)==0
    candidates = dir(fullfile(scriptFolder,"Capturas_Sincronizadas", ...
        "*_integral_*"));
    assert(~isempty(candidates),"No hay capturas de lazo integral.");
    [~,order] = sort([candidates.datenum],"descend");
    captureFolder = string(fullfile(candidates(order(1)).folder, ...
        candidates(order(1)).name));
end

requiredFiles = ["psoc_uart.csv" "chan1.csv" "chan2.csv" ...
    "metadatos.json" "pantalla_rigol_original.png"];
assert(all(isfile(fullfile(captureFolder,requiredFiles))), ...
    "La carpeta no contiene todos los entregables requeridos.");
T = readtable(fullfile(captureFolder,"psoc_uart.csv"), ...
    TextType="string",VariableNamingRule="preserve");
ch1 = readtable(fullfile(captureFolder,"chan1.csv"),TextType="string");
ch2 = readtable(fullfile(captureFolder,"chan2.csv"),TextType="string");
meta = readstruct(fullfile(captureFolder,"metadatos.json"));
assert(meta.detectedMode=="INTEGRAL","La captura no es de lazo integral.");
assert(height(T)==600 && all(double(T.k)==(0:599).'), ...
    "La telemetria no contiene 600 indices consecutivos.");
coreValid = logical(meta.checks.modeMatches) && ...
    logical(meta.checks.timingValid) && logical(meta.checks.responseValid) && ...
    double(meta.uart.fatalFlagSamples)==0;
assert(coreValid,"La telemetria del lazo cerrado no es valida.");

k = double(T.k);
time_ms = double(T.t_us)/1000;
time_ms = time_ms-time_ms(33);
y = double(T.y_rel_mV);
r = double(T.r_mV);
uRequested = double(T.u_solicitada_mV);
uNominal = double(T.u_nominal_mV);
xi = double(T.xi_mV);
innovation = double(T.innovacion_mV);
period = double(T.intervalo_us);
cpu = double(T.cpu_us);
flags = uint16(double(T.flags));
referenceLevel_mV = max(r);
assert(referenceLevel_mV>0,"La captura no contiene una referencia positiva.");
refMask = r>0.5*referenceLevel_mV;
refIndices = find(refMask);
steadyIndices = refIndices(end-49:end);
postMask = k>=550;

ySteady = median(y(steadyIndices));
steadyError = median(r(steadyIndices)-y(steadyIndices));
steadyErrorVector = r(steadyIndices)-y(steadyIndices);
rmsError = sqrt(mean(steadyErrorVector.^2));
yPeak = max(y(refMask));
overshoot_pct = max(0,(yPeak-referenceLevel_mV)/referenceLevel_mV*100);
signedY = y(refIndices);
i10 = find(signedY>=0.1*ySteady,1,"first");
i90 = find(signedY>=0.9*ySteady,1,"first");
if isempty(i10) || isempty(i90) || i90<i10
    riseTime_ms = NaN;
else
    riseTime_ms = time_ms(refIndices(i90))-time_ms(refIndices(i10));
end
settlingTime_ms = NaN;
band = max(1,0.02*abs(ySteady));
for idx = 1:numel(refIndices)
    if all(abs(y(refIndices(idx:end))-ySteady)<=band)
        settlingTime_ms = time_ms(refIndices(idx));
        break
    end
end

% La permanencia estricta puede quedar dominada por una muestra aislada de
% ruido. Se informa tambien el primer intervalo de 20 ms con al menos 80 %
% de las muestras dentro de la banda del 2 % de la referencia y mediana
% dentro de ella.
settlingWindow2pct_ms = NaN;
windowSamples = 10;
windowBand = 0.02*referenceLevel_mV;
for idx = 1:(numel(refIndices)-windowSamples+1)
    windowIndices = refIndices(idx:idx+windowSamples-1);
    windowValues = y(windowIndices);
    occupancy = mean(abs(windowValues-referenceLevel_mV)<=windowBand);
    if occupancy >= 0.8 && ...
            abs(median(windowValues)-referenceLevel_mV)<=windowBand
        settlingWindow2pct_ms = time_ms(refIndices(idx));
        break
    end
end

fatalSamples = nnz(bitand(flags,uint16(63))~=0);
satSamples = nnz(bitand(flags,uint16(64))~=0);
antiwindupSamples = nnz(bitand(flags,uint16(128))~=0);
postMedian = median(y(postMask));
design = string(meta.detectedDesign);
designName = lower(design);

scopeTime_ms = ch1.time_s*1000;
rawJ7 = ch2.voltage_V*1000;
thresholdJ7 = 0.5*(quantile(rawJ7,0.50)+quantile(rawJ7,0.90));
baseJ7 = median(rawJ7(rawJ7<thresholdJ7));
plateauJ7 = median(rawJ7(rawJ7>=thresholdJ7));
j7 = smoothdata(rawJ7-baseJ7,"movmean",11);
scopeDelta_mV = plateauJ7-baseJ7;
scopeReturn_mV = median(rawJ7(end-max(20,floor(0.15*numel(rawJ7)))+1:end))-baseJ7;
scopeValid = scopeDelta_mV>=0.75*referenceLevel_mV && ...
    scopeDelta_mV<=1.25*referenceLevel_mV && ...
    abs(scopeReturn_mV)<=0.10*referenceLevel_mV;
edgeIndex = find(j7>=0.5*scopeDelta_mV,1,"first");
if ~isempty(edgeIndex)
    scopeTime_ms = scopeTime_ms-scopeTime_ms(edgeIndex);
end
overallValid = coreValid && scopeValid;

resumen = table(string(meta.capturedAt),design,ySteady,steadyError, ...
    rmsError,yPeak,overshoot_pct,riseTime_ms,settlingWindow2pct_ms, ...
    settlingTime_ms,postMedian, ...
    min(uRequested),max(uRequested),min(uNominal),max(uNominal), ...
    max(abs(xi)),max(abs(innovation)),satSamples,antiwindupSamples, ...
    fatalSamples,median(period(2:end)),min(period(2:end)), ...
    max(period(2:end)),max(cpu),scopeDelta_mV,scopeReturn_mV, ...
    scopeValid,overallValid, ...
    VariableNames=["captured_at" "design" "y_steady_mV" ...
    "steady_error_mV" "rms_error_mV" "y_peak_mV" "overshoot_pct" ...
    "rise_time_ms" "settling_window_2pct_ms" "settling_time_ms" ...
    "post_return_median_mV" ...
    "u_requested_min_mV" "u_requested_max_mV" "u_nominal_min_mV" ...
    "u_nominal_max_mV" "xi_peak_mV" "innovation_peak_mV" ...
    "saturation_samples" "antiwindup_samples" "fatal_flag_samples" ...
    "period_median_us" "period_min_us" "period_max_us" "cpu_max_us" ...
    "scope_delta_mV" "scope_return_mV" "scope_valid" "valid"]);
writetable(resumen,fullfile(resultsFolder, ...
    "resumen_integral_"+designName+".csv"));

fig = figure("Visible","off","Color","w","Position",[100 100 980 680]);
layout = tiledlayout(fig,2,1,TileSpacing="compact",Padding="compact");
title(layout,"Lazo integral "+designName);

ax1 = nexttile(layout);
hold(ax1,"on");
plot(ax1,time_ms,r,"k--",LineWidth=1.5,DisplayName="Referencia - UART");
plot(ax1,time_ms,y,LineWidth=1.1,Color=[0.12 0.36 0.68], ...
    DisplayName="Salida - UART");
plot(ax1,scopeTime_ms,j7,LineWidth=1.0,Color=[0.00 0.60 0.72], ...
    DisplayName="J7 - Rigol");
hold(ax1,"off");
ylabel(ax1,"Salida (mV)");
legend(ax1,"Location","best","Box","off");

ax2 = nexttile(layout);
hold(ax2,"on");
plot(ax2,time_ms,uNominal,LineWidth=0.9,Color=[0.75 0.18 0.14], ...
    DisplayName="Mando nominal - UART");
plot(ax2,time_ms,uRequested,"--",LineWidth=0.9,Color=[0.86 0.62 0.05], ...
    DisplayName="Mando solicitado - UART");
hold(ax2,"off");
xlabel(ax2,"Tiempo relativo al escalon (ms)");
ylabel(ax2,"Mando (mV)");
legend(ax2,"Location","best","Box","off");

for ax = [ax1 ax2]
    grid(ax,"on");
    ax.GridAlpha = 0.22;
    ax.FontName = "Times New Roman";
    ax.FontSize = 10;
    xlim(ax,[-100 1200]);
end
exportgraphics(layout,fullfile(figuresFolder, ...
    "ensayo_integral_"+designName+".png"),Resolution=300);
close(fig);

copyfile(fullfile(captureFolder,"pantalla_rigol_original.png"), ...
    fullfile(figuresFolder, ...
    "pantalla_rigol_integral_"+designName+"_original.png"));

fprintf("ENSAYO_INTEGRAL_VALIDO: %s; y_ss=%.1f mV; e_ss=%.1f mV; " + ...
    "tr=%.1f ms; Mp=%.1f%%; u=[%.1f,%.1f] mV; sat=%d; aw=%d.\n", ...
    design,ySteady,steadyError,riseTime_ms,overshoot_pct, ...
    min(uNominal),max(uNominal),satSamples,antiwindupSamples);
end
