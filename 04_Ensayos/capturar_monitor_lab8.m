function outputFolder = capturar_monitor_lab8(label)
%CAPTURAR_MONITOR_LAB8 Captura sincronizada UART y Rigol en modo MONITOR.
%   Programa esperado: Lab8, MONITOR, 600 muestras y DAC en cero.
%   El operador debe presionar SW3/RESET después del mensaje CAPTURA_LISTA.

arguments
    label (1,1) string = "monitor_lab8"
end

expectedRows = 600;
expectedMode = "MONITOR";
serialPortName = "COM4";
baudRate = 57600;
scopeTimeScale = 0.1;
scopeCh1Scale = 0.05;
scopeCh2Scale = 0.02;
armDelay = 2.25;
rearmTime = 3.50;
forceTime = 3.60;

scriptFolder = fileparts(mfilename("fullpath"));
stamp = string(datetime("now",Format="yyyyMMdd_HHmmss_SSS"));
safeLabel = regexprep(label,"[^A-Za-z0-9_-]","_");
outputFolder = fullfile(scriptFolder,"Capturas_Sincronizadas", ...
    stamp + "_" + safeLabel);
mkdir(outputFolder);

devices = visadevlist;
rigolRow = contains(devices.ResourceName,"0x1AB1",IgnoreCase=true) & ...
    contains(devices.SerialNumber,"DS1ZE275014864",IgnoreCase=true);
assert(nnz(rigolRow)==1,"No se encontró exactamente un Rigol DS1202Z-E.");
resourceName = devices.ResourceName(rigolRow);

scope = visadev(resourceName);
scope.Timeout = 20;
scope.ByteOrder = "little-endian";
cleanupScope = onCleanup(@() clearInstrument(scope));
configureScope(scope,scopeTimeScale,scopeCh1Scale,scopeCh2Scale);

port = serialport(serialPortName,baudRate,Timeout=1);
configureTerminator(port,"LF");
flush(port);
cleanupPort = onCleanup(@() clearInstrument(port));

fprintf("CAPTURA_LISTA: Lab8 MONITOR y Rigol preparados. Presione SW3/RESET una vez.\n");
lines = strings(0,1);
startupDetected = false;
armed = false;
rearmChecked = false;
forceChecked = false;
forcedTrigger = false;
finished = false;
detectedMode = "";
detectedDesign = "";
stateBeforeForce = "";
startupClock = [];
deadline = tic;

while toc(deadline) < 90
    if port.NumBytesAvailable > 0
        line = strip(string(readline(port)));
        if strlength(line) > 0
            lines(end+1,1) = line; %#ok<AGROW>
            if startsWith(line,"# LAB8 inicio;")
                startupDetected = true;
                startupClock = tic;
                armed = false;
                rearmChecked = false;
                forceChecked = false;
                fprintf("PSoC: anuncio de arranque LAB8 detectado.\n");
            elseif startsWith(line,"# LAB8 control_integral")
                detectedMode = extractToken(line,"modo=([A-Z_]+)");
                fprintf("PSoC: modo=%s.\n",detectedMode);
            elseif startsWith(line,"# LAB8 diseno=")
                detectedDesign = extractToken(line,"diseno=([A-Z_]+)");
                fprintf("PSoC: diseño=%s.\n",detectedDesign);
            elseif startsWith(line,"# LAB8 END;")
                finished = true;
                break
            end
        end
    end

    if startupDetected
        elapsed = toc(startupClock);
        if ~armed && elapsed >= armDelay
            writeline(scope,":SING");
            armed = true;
            fprintf("RIGOL ARMADO a t=%.3f s.\n",elapsed);
        end
        if armed && ~rearmChecked && elapsed >= rearmTime
            state = upper(strip(writeread(scope,":TRIG:STAT?")));
            rearmChecked = true;
            if ismember(state,["STOP","TD"])
                writeline(scope,":SING");
                fprintf("RIGOL REARMADO: disparo anterior a la ventana.\n");
            end
        end
        if armed && ~forceChecked && elapsed >= forceTime
            stateBeforeForce = upper(strip(writeread(scope,":TRIG:STAT?")));
            forceChecked = true;
            if ismember(stateBeforeForce,["WAIT","RUN","AUTO"])
                writeline(scope,":TFOR");
                forcedTrigger = true;
                fprintf("RIGOL: TFOR temporizado a t=%.3f s.\n",elapsed);
            else
                fprintf("RIGOL: adquisición ya detenida (%s).\n", ...
                    stateBeforeForce);
            end
        end
    end
    pause(0.005);
end

writelines(lines,fullfile(outputFolder,"psoc_uart.txt"));
assert(startupDetected,"No se detectó el anuncio de arranque Lab8.");
assert(finished,"La telemetría Lab8 no terminó antes del timeout.");

headerIndex = find(startsWith(lines,"k,t_us,"),1,"first");
endIndex = find(startsWith(lines,"# LAB8 END;"),1,"first");
assert(~isempty(headerIndex) && ~isempty(endIndex) && endIndex>headerIndex, ...
    "No se encontró la tabla UART completa.");
csvFile = fullfile(outputFolder,"psoc_uart.csv");
writelines(lines(headerIndex:endIndex-1),csvFile);
T = readtable(csvFile,TextType="string",VariableNamingRule="preserve");
assert(height(T)==expectedRows,"Se esperaban %d filas y llegaron %d.", ...
    expectedRows,height(T));
requiredVariables = ["k","t_us","y_rel_mV","u_nominal_mV", ...
    "dac_pos","dac_neg","cpu_us","intervalo_us","flags"];
assert(all(ismember(requiredVariables,string(T.Properties.VariableNames))), ...
    "Faltan columnas obligatorias en la telemetría Lab8.");

scopeState = upper(strip(writeread(scope,":TRIG:STAT?")));
scopeFinished = ismember(scopeState,["STOP","TD"]);
if ~scopeFinished
    writeline(scope,":STOP");
end

captureScreen(scope,fullfile(outputFolder,"pantalla_rigol_original.png"));
[ch1,detailsCh1] = captureWaveform(scope,"CHAN1", ...
    fullfile(outputFolder,"chan1.csv"));
[ch2,detailsCh2] = captureWaveform(scope,"CHAN2", ...
    fullfile(outputFolder,"chan2.csv"));

flags = double(T.flags);
periods = double(T.intervalo_us);
cpu = double(T.cpu_us);
yRelative = double(T.y_rel_mV);
uNominal = double(T.u_nominal_mV);
dacPositive = double(T.dac_pos);
dacNegative = double(T.dac_neg);

uartSummary = struct( ...
    "rows",height(T), ...
    "nonzeroFlags",nnz(flags), ...
    "maxCpu_us",max(cpu), ...
    "medianPeriod_us",median(periods(2:end)), ...
    "minPeriod_us",min(periods(2:end)), ...
    "maxPeriod_us",max(periods(2:end)), ...
    "yRelativeMean_mV",mean(yRelative), ...
    "yRelativeStd_mV",std(yRelative), ...
    "yRelativePeakAbs_mV",max(abs(yRelative)), ...
    "uNominalPeakAbs_mV",max(abs(uNominal)), ...
    "dacPositivePeak",max(dacPositive), ...
    "dacNegativePeak",max(dacNegative));

preliminaryValid = startupDetected && armed && finished && ...
    detectedMode==expectedMode && height(T)==expectedRows && ...
    uartSummary.nonzeroFlags==0 && scopeFinished && ...
    uartSummary.dacPositivePeak==0 && uartSummary.dacNegativePeak==0;

metadata = struct;
metadata.capturedAt = string(datetime("now",TimeZone="local", ...
    Format="yyyy-MM-dd'T'HH:mm:ssXXX"));
metadata.expectedMode = expectedMode;
metadata.detectedMode = detectedMode;
metadata.detectedDesign = detectedDesign;
metadata.resource = resourceName;
metadata.serialPort = serialPortName;
metadata.baudRate = baudRate;
metadata.scopeState = scopeState;
metadata.scopeFinished = scopeFinished;
metadata.originalScopeImage = "pantalla_rigol_original.png";
metadata.forcedTrigger = forcedTrigger;
metadata.stateBeforeForce = stateBeforeForce;
metadata.scopeConfiguration = struct( ...
    "time_s_div",scopeTimeScale,"ch1_V_div",scopeCh1Scale, ...
    "ch2_V_div",scopeCh2Scale,"trigger_V",0.20, ...
    "acquisition","HRES","armDelay_s",armDelay, ...
    "rearmTime_s",rearmTime,"forceTime_s",forceTime);
metadata.uart = uartSummary;
metadata.traceStatistics = struct( ...
    "CH1",traceStatistics(ch1),"CH2",traceStatistics(ch2));
metadata.waveformDetails = struct("CH1",detailsCh1,"CH2",detailsCh2);
metadata.preliminaryValid = preliminaryValid;
writestruct(metadata,fullfile(outputFolder,"metadatos.json"));

fprintf("CAPTURA_COMPLETA: %s\n",outputFolder);
fprintf("VALIDACION_PRELIMINAR: %d; filas=%d; flags=%d; DAC+=%d; DAC-=%d.\n", ...
    preliminaryValid,height(T),uartSummary.nonzeroFlags, ...
    uartSummary.dacPositivePeak,uartSummary.dacNegativePeak);
assert(preliminaryValid, ...
    "La captura se guardó, pero no superó la validación preliminar.");

clear cleanupPort cleanupScope
end

function configureScope(scope,timeScale,ch1Scale,ch2Scale)
commands = [
    ":STOP"
    ":CHAN1:DISP ON"
    ":CHAN2:DISP ON"
    ":CHAN1:COUP DC"
    ":CHAN2:COUP DC"
    ":CHAN1:BWL 20M"
    ":CHAN2:BWL 20M"
    ":CHAN1:PROB 10"
    ":CHAN2:PROB 10"
    ":CHAN1:SCAL " + compose("%.9g",ch1Scale)
    ":CHAN2:SCAL " + compose("%.9g",ch2Scale)
    ":TIM:MODE MAIN"
    ":TIM:SCAL " + compose("%.9g",timeScale)
    ":TIM:OFFS 0"
    ":ACQ:TYPE HRES"
    ":TRIG:MODE EDGE"
    ":TRIG:EDGE:SOUR CHAN1"
    ":TRIG:EDGE:SLOP POS"
    ":TRIG:EDGE:LEV 0.20"
    ":TRIG:SWE NORM"
    ];
for command = commands.'
    writeline(scope,command);
end
end

function captureScreen(scope,fileName)
writeline(scope,":DISP:DATA? ON,OFF,PNG");
bytes = readbinblock(scope,"uint8");
fid = fopen(fileName,"w");
assert(fid~=-1,"No se pudo crear la captura PNG.");
cleanupFile = onCleanup(@() fclose(fid));
fwrite(fid,bytes,"uint8");
end

function [T,details] = captureWaveform(scope,channel,fileName)
writeline(scope,":WAV:SOUR " + channel);
writeline(scope,":WAV:MODE NORM");
writeline(scope,":WAV:FORM BYTE");
preamble = str2double(split(strip(writeread(scope,":WAV:PRE?")),","));
writeline(scope,":WAV:DATA?");
raw = double(readbinblock(scope,"uint8"));
assert(numel(preamble)>=10,"Preámbulo de onda Rigol incompleto.");
xIncrement = preamble(5);
xOrigin = preamble(6);
xReference = preamble(7);
yIncrement = preamble(8);
yOrigin = preamble(9);
yReference = preamble(10);
sample = (0:numel(raw)-1).';
time_s = (sample-xReference).*xIncrement+xOrigin;
voltage_V = (raw(:)-yOrigin-yReference).*yIncrement;
T = table(sample,time_s,raw(:),voltage_V, ...
    VariableNames=["sample","time_s","raw","voltage_V"]);
writetable(T,fileName);
details = struct("points",height(T),"xIncrement_s",xIncrement, ...
    "xOrigin_s",xOrigin,"yIncrement_V",yIncrement,"yOrigin",yOrigin, ...
    "yReference",yReference);
end

function stats = traceStatistics(T)
values = T.voltage_V;
stats = struct("points",height(T),"mean_mV",mean(values)*1000, ...
    "std_mV",std(values)*1000,"p05_mV",quantile(values,0.05)*1000, ...
    "p95_mV",quantile(values,0.95)*1000, ...
    "robustSpan_mV",(quantile(values,0.95)-quantile(values,0.05))*1000, ...
    "duration_s",T.time_s(end)-T.time_s(1));
end

function token = extractToken(line,expression)
matches = regexp(line,expression,"tokens","once");
if isempty(matches)
    token = "";
else
    token = string(matches{1});
end
end

function clearInstrument(instrument)
if ~isempty(instrument)
    clear instrument
end
end
