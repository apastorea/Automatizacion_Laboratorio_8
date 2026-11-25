function resumen = analizar_abierto_lab8(captureFolder)
%ANALIZAR_ABIERTO_LAB8 Valida y resume una captura de lazo abierto.

arguments
    captureFolder (1,1) string = ""
end

scriptFolder = fileparts(mfilename("fullpath"));
labFolder = fileparts(scriptFolder);
resultsFolder = fullfile(labFolder,"05_Resultados");
figuresFolder = fullfile(resultsFolder,"figuras");
if ~isfolder(figuresFolder)
    mkdir(figuresFolder);
end

if strlength(captureFolder)==0
    candidates = dir(fullfile(scriptFolder,"Capturas_Sincronizadas", ...
        "*_abierto_*_50mV"));
    assert(~isempty(candidates),"No hay capturas de lazo abierto.");
    [~,order] = sort([candidates.datenum],"descend");
    captureFolder = string(fullfile(candidates(order(1)).folder, ...
        candidates(order(1)).name));
end

requiredFiles = ["psoc_uart.csv","chan1.csv","chan2.csv", ...
    "metadatos.json","pantalla_rigol_original.png"];
assert(all(isfile(fullfile(captureFolder,requiredFiles))), ...
    "La carpeta no contiene todos los entregables requeridos.");

T = readtable(fullfile(captureFolder,"psoc_uart.csv"), ...
    TextType="string",VariableNamingRule="preserve");
ch1 = readtable(fullfile(captureFolder,"chan1.csv"),TextType="string");
ch2 = readtable(fullfile(captureFolder,"chan2.csv"),TextType="string");
meta = readstruct(fullfile(captureFolder,"metadatos.json"));

assert(meta.preliminaryValid,"La captura no supera la validacion preliminar.");
assert(height(T)==600 && all(double(T.k)==(0:599).'), ...
    "La telemetria no contiene 600 indices consecutivos.");
assert(nnz(double(T.flags))==0,"La captura contiene banderas de fallo.");
step_mV = double(meta.detectedStep_mV);
assert(meta.detectedMode=="ABIERTO" && ismember(step_mV,[-50 50]), ...
    "La captura no corresponde a un ensayo ABIERTO de +/-50 mV.");

metrics = metricas_rigol_abierto_lab8(ch1,ch2,step_mV);
uRequested = double(T.u_solicitada_mV);
uNominal = double(T.u_nominal_mV);
yRelative = double(T.y_rel_mV);
time_us = double(T.t_us);
period_us = double(T.intervalo_us);
cpu_us = double(T.cpu_us);
pulseMask = sign(step_mV).*uRequested>25;
pulseIndices = find(pulseMask);
assert(numel(pulseIndices)==96,"El pulso no dura las 96 muestras esperadas.");

lateIndices = pulseIndices(end-23:end);
steadyY_mV = median(yRelative(lateIndices));
steadyU_mV = median(uNominal(pulseMask));
gainUart = steadyY_mV/steadyU_mV;

signedResponse = sign(step_mV).*yRelative(pulseIndices);
threshold10 = 0.10*abs(steadyY_mV);
threshold90 = 0.90*abs(steadyY_mV);
i10 = find(signedResponse>=threshold10,1,"first");
i90 = find(signedResponse>=threshold90,1,"first");
if isempty(i10) || isempty(i90) || i90<i10
    riseTime_ms = NaN;
else
    riseTime_ms = (time_us(pulseIndices(i90))-time_us(pulseIndices(i10)))/1000;
end

resumen = table( ...
    string(meta.capturedAt),step_mV,steadyU_mV,metrics.deltaCH1_mV, ...
    steadyY_mV,metrics.deltaCH2_mV,gainUart,metrics.gainCH2overCH1, ...
    riseTime_ms,numel(pulseIndices),median(period_us(2:end)), ...
    min(period_us(2:end)),max(period_us(2:end)),max(cpu_us), ...
    nnz(double(T.flags)),logical(meta.preliminaryValid), ...
    VariableNames=["captured_at","u_requested_mV","u_nominal_mV", ...
    "delta_J5_scope_mV","y_late_uart_mV","delta_J7_scope_mV", ...
    "gain_uart","gain_scope","rise_time_uart_ms","pulse_samples", ...
    "period_median_us","period_min_us","period_max_us","cpu_max_us", ...
    "nonzero_flags","valid"]);
polarityName = "pos";
polarityTitle = "+50";
if step_mV<0
    polarityName = "neg";
    polarityTitle = "-50";
end
summaryName = "resumen_abierto_"+polarityName+"_50mV.csv";
writetable(resumen,fullfile(resultsFolder,summaryName));

scopePulseStart = metrics.pulseStart_s;
scopeTime_ms = (ch1.time_s-scopePulseStart)*1000;
uartPulseStart = time_us(pulseIndices(1));
uartTime_ms = (time_us-uartPulseStart)/1000;

fig = figure("Visible","off","Color","w","Position",[100 100 980 520]);
ax = axes(fig);
j5Plot_mV = smoothdata( ...
    (ch1.voltage_V-metrics.baselineCH1_mV/1000)*1000,"movmean",21);
j7Plot_mV = smoothdata( ...
    (ch2.voltage_V-metrics.baselineCH2_mV/1000)*1000,"movmean",21);
hold(ax,"on");
plot(ax,scopeTime_ms,j5Plot_mV, ...
    LineWidth=1.3,Color=[0.86 0.62 0.05],DisplayName="J5 - Rigol");
plot(ax,scopeTime_ms,j7Plot_mV, ...
    LineWidth=1.0,Color=[0.00 0.60 0.72],DisplayName="J7 - Rigol");
plot(ax,uartTime_ms,uNominal,"--",LineWidth=1.6, ...
    Color=[0.75 0.18 0.14],DisplayName="u nominal - UART");
plot(ax,uartTime_ms,yRelative,LineWidth=1.1, ...
    Color=[0.12 0.36 0.68],DisplayName="y relativa - UART");
xline(ax,0,":","Inicio",LabelVerticalAlignment="bottom", ...
    HandleVisibility="off");
xline(ax,192,":","Fin",LabelVerticalAlignment="bottom", ...
    HandleVisibility="off");
hold(ax,"off");
xlim(ax,[-60 260]);
ylim(ax,[-75 75]);
xlabel(ax,"Tiempo relativo al pulso (ms)");
ylabel(ax,"Tension incremental (mV)");
title(ax,"Ensayo abierto: pulso de "+polarityTitle+" mV");
grid(ax,"on");
ax.GridAlpha = 0.22;
ax.FontName = "Times New Roman";
ax.FontSize = 10;
legend(ax,"Location","northeast","Box","off");
exportgraphics(ax,fullfile(figuresFolder, ...
    "ensayo_abierto_"+polarityName+"_50mV.png"), ...
    Resolution=300);
close(fig);

copyfile(fullfile(captureFolder,"pantalla_rigol_original.png"), ...
    fullfile(figuresFolder, ...
    "pantalla_rigol_abierto_"+polarityName+"_50mV_original.png"));

fprintf("ENSAYO_ABIERTO_VALIDO: u=%.1f mV; J5=%.1f mV; " + ...
    "y_UART=%.1f mV; J7_Rigol=%.1f mV; K_UART=%.3f; tr=%.1f ms.\n", ...
    steadyU_mV,metrics.deltaCH1_mV,steadyY_mV,metrics.deltaCH2_mV, ...
    gainUart,riseTime_ms);
end
