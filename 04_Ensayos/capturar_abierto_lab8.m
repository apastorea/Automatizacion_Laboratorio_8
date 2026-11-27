function outputFolder = capturar_abierto_lab8(expectedStep_mV,label,serialPortName)
%CAPTURAR_ABIERTO_LAB8 Captura UART y Rigol del pulso abierto de Lab 8.
%   La captura conserva la pantalla original del osciloscopio, las ondas de
%   CH1=J5 y CH2=J7 y la telemetria completa. El firmware debe estar en modo
%   ABIERTO y configurado con el mismo escalon. Se admiten +/-50 mV para
%   comprobar polaridad y +/-500 mV para el ensayo principal. El disparo se
%   toma desde CH2, cuya transicion resulto mas limpia y repetible.
%   Si SERIALPORTNAME se omite, se utiliza el único puerto serie disponible.

arguments
    expectedStep_mV (1,1) double {mustBeMember(expectedStep_mV,[-500 -50 50 500])}
    label (1,1) string = "abierto_lab8"
    serialPortName (1,1) string = ""
end

expectedRows = 600;
expectedPulseSamples = 96;
expectedMode = "ABIERTO";
serialPortName = resolveSerialPort(serialPortName);
baudRate = 57600;
scopeTimeScale = 0.05;
if abs(expectedStep_mV) <= 50
    scopeCh1Scale = 0.05;
    scopeCh2Scale = 0.05;
    triggerMagnitude = 0.02;
else
    scopeCh1Scale = 0.20;
    scopeCh2Scale = 0.20;
    triggerMagnitude = 0.25;
end
armDelay = 2.75;
forceTime = 3.45;

if expectedStep_mV > 0
    triggerSlope = "POS";
    triggerLevel = triggerMagnitude;
else
    triggerSlope = "NEG";
    triggerLevel = -triggerMagnitude;
end

scriptFolder = fileparts(mfilename("fullpath"));
stamp = string(datetime("now",Format="yyyyMMdd_HHmmss_SSS"));
safeLabel = regexprep(label,"[^A-Za-z0-9_-]","_");
outputFolder = fullfile(scriptFolder,"Capturas_Sincronizadas", ...
    stamp + "_" + safeLabel);
mkdir(outputFolder);

devices = visadevlist;
rigolRow = contains(devices.ResourceName,"0x1AB1",IgnoreCase=true) & ...
    contains(devices.SerialNumber,"DS1ZE275014864",IgnoreCase=true);
assert(nnz(rigolRow)==1,"No se encontro exactamente un Rigol DS1202Z-E.");
resourceName = devices.ResourceName(rigolRow);

scope = visadev(resourceName);
scope.Timeout = 20;
scope.ByteOrder = "little-endian";
cleanupScope = onCleanup(@() clearInstrument(scope));
configureScope(scope,scopeTimeScale,scopeCh1Scale,scopeCh2Scale, ...
    triggerSlope,triggerLevel);

port = serialport(serialPortName,baudRate,Timeout=1);
configureTerminator(port,"LF");
flush(port);
cleanupPort = onCleanup(@() clearInstrument(port));

fprintf("CAPTURA_LISTA: Lab8 ABIERTO %+.0f mV preparado. " + ...
    "Presione SW3/RESET una vez.\n",expectedStep_mV);
lines = strings(0,1);
startupDetected = false;
armed = false;
forceChecked = false;
forcedTrigger = false;
finished = false;
detectedMode = "";
detectedDesign = "";
detectedStep_mV = NaN;
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
                forceChecked = false;
                fprintf("PSoC: anuncio de arranque LAB8 detectado.\n");
            elseif startsWith(line,"# LAB8 control_integral")
                detectedMode = extractToken(line,"modo=([A-Z_]+)");
                fprintf("PSoC: modo=%s.\n",detectedMode);
            elseif startsWith(line,"# LAB8 diseno=")
                detectedDesign = extractToken(line,"diseno=([A-Z_]+)");
            elseif startsWith(line,"# LAB8 ensayo_abierto")
                stepToken = extractToken(line,"escalon_mV=(-?[0-9]+)");
                detectedStep_mV = str2double(stepToken);
                fprintf("PSoC: escalon configurado=%+.0f mV.\n",detectedStep_mV);
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
        if armed && ~forceChecked && elapsed >= forceTime
            stateBeforeForce = upper(strip(writeread(scope,":TRIG:STAT?")));
            forceChecked = true;
            if ismember(stateBeforeForce,["WAIT","RUN","AUTO"])
                writeline(scope,":TFOR");
                forcedTrigger = true;
                fprintf("RIGOL: TFOR de respaldo a t=%.3f s.\n",elapsed);
            end
        end
    end
    pause(0.005);
end

writelines(lines,fullfile(outputFolder,"psoc_uart.txt"));
assert(startupDetected,"No se detecto el anuncio de arranque Lab8.");
assert(finished,"La telemetria Lab8 no termino antes del timeout.");

headerIndex = find(startsWith(lines,"k,t_us,"),1,"first");
endIndex = find(startsWith(lines,"# LAB8 END;"),1,"first");
assert(~isempty(headerIndex) && ~isempty(endIndex) && endIndex>headerIndex, ...
    "No se encontro la tabla UART completa.");
csvFile = fullfile(outputFolder,"psoc_uart.csv");
writelines(lines(headerIndex:endIndex-1),csvFile);
T = readtable(csvFile,TextType="string",VariableNamingRule="preserve");
assert(height(T)==expectedRows,"Se esperaban %d filas y llegaron %d.", ...
    expectedRows,height(T));
requiredVariables = ["k","t_us","y_rel_mV","u_solicitada_mV", ...
    "u_nominal_mV","dac_pos","dac_neg","cpu_us","intervalo_us","flags"];
assert(all(ismember(requiredVariables,string(T.Properties.VariableNames))), ...
    "Faltan columnas obligatorias en la telemetria Lab8.");

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
uRequested = double(T.u_solicitada_mV);
uNominal = double(T.u_nominal_mV);
dacPositive = double(T.dac_pos);
dacNegative = double(T.dac_neg);
pulseMask = abs(uRequested) >= 0.5*abs(expectedStep_mV);
assert(nnz(pulseMask)>0,"La telemetria no contiene el pulso abierto.");
pulseIndices = find(pulseMask);
latePulse = pulseIndices(max(1,end-23):end);
deltaY_uart_mV = median(yRelative(latePulse));

if expectedStep_mV > 0
    dacPolarityValid = max(dacPositive(pulseMask))>0 && ...
        max(dacNegative(pulseMask))==0;
else
    dacPolarityValid = max(dacNegative(pulseMask))>0 && ...
        max(dacPositive(pulseMask))==0;
end

scopeMetrics = metricas_rigol_abierto_lab8(ch1,ch2,expectedStep_mV);
uartSummary = struct( ...
    "rows",height(T),"nonzeroFlags",nnz(flags), ...
    "maxCpu_us",max(cpu),"medianPeriod_us",median(periods(2:end)), ...
    "minPeriod_us",min(periods(2:end)),"maxPeriod_us",max(periods(2:end)), ...
    "pulseSamples",nnz(pulseMask), ...
    "requestedPulseMedian_mV",median(uRequested(pulseMask)), ...
    "nominalPulseMedian_mV",median(uNominal(pulseMask)), ...
    "deltaYLatePulse_mV",deltaY_uart_mV, ...
    "dacPositivePeak",max(dacPositive),"dacNegativePeak",max(dacNegative));

stepMatches = detectedStep_mV==expectedStep_mV && ...
    sign(uartSummary.requestedPulseMedian_mV)==sign(expectedStep_mV) && ...
    abs(uartSummary.requestedPulseMedian_mV-expectedStep_mV)<=1;
responseSignValid = sign(deltaY_uart_mV)==sign(expectedStep_mV) && ...
    abs(deltaY_uart_mV)>=0.70*abs(expectedStep_mV) && ...
    abs(deltaY_uart_mV)<=1.30*abs(expectedStep_mV);
scopeSignValid = sign(scopeMetrics.deltaCH1_mV)==sign(expectedStep_mV) && ...
    abs(scopeMetrics.deltaCH1_mV)>=0.75*abs(expectedStep_mV) && ...
    abs(scopeMetrics.deltaCH1_mV)<=1.25*abs(expectedStep_mV);
preliminaryValid = startupDetected && armed && finished && ...
    detectedMode==expectedMode && height(T)==expectedRows && ...
    uartSummary.nonzeroFlags==0 && scopeFinished && ...
    nnz(pulseMask)==expectedPulseSamples && stepMatches && ...
    dacPolarityValid && responseSignValid && scopeSignValid;

metadata = struct;
metadata.capturedAt = string(datetime("now",TimeZone="local", ...
    Format="yyyy-MM-dd'T'HH:mm:ssXXX"));
metadata.expectedMode = expectedMode;
metadata.detectedMode = detectedMode;
metadata.detectedDesign = detectedDesign;
metadata.expectedStep_mV = expectedStep_mV;
metadata.detectedStep_mV = detectedStep_mV;
metadata.resource = resourceName;
metadata.serialPort = serialPortName;
metadata.baudRate = baudRate;
metadata.scopeState = scopeState;
metadata.scopeFinished = scopeFinished;
metadata.originalScopeImage = "pantalla_rigol_original.png";
metadata.forcedTrigger = forcedTrigger;
metadata.stateBeforeForce = stateBeforeForce;
metadata.scopeConfiguration = struct("time_s_div",scopeTimeScale, ...
    "ch1_V_div",scopeCh1Scale,"ch2_V_div",scopeCh2Scale, ...
    "triggerSource","CHAN2","triggerSlope",triggerSlope, ...
    "trigger_V",triggerLevel, ...
    "acquisition","HRES","armDelay_s",armDelay,"forceTime_s",forceTime);
metadata.uart = uartSummary;
metadata.scope = scopeMetrics;
metadata.waveformDetails = struct("CH1",detailsCh1,"CH2",detailsCh2);
metadata.checks = struct("stepMatches",stepMatches, ...
    "dacPolarityValid",dacPolarityValid,"responseSignValid",responseSignValid, ...
    "scopeSignValid",scopeSignValid);
metadata.preliminaryValid = preliminaryValid;
writestruct(metadata,fullfile(outputFolder,"metadatos.json"));

fprintf("CAPTURA_COMPLETA: %s\n",outputFolder);
fprintf("VALIDACION_PRELIMINAR: %d; pulso=%+.0f mV; muestras=%d; " + ...
    "DeltaJ5=%.1f mV; DeltaJ7_UART=%.1f mV; flags=%d.\n", ...
    preliminaryValid,uartSummary.requestedPulseMedian_mV,nnz(pulseMask), ...
    scopeMetrics.deltaCH1_mV,deltaY_uart_mV,uartSummary.nonzeroFlags);
assert(preliminaryValid, ...
    "La captura se guardo, pero no supero la validacion preliminar.");

clear cleanupPort cleanupScope
end

function configureScope(scope,timeScale,ch1Scale,ch2Scale,slope,level)
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
    ":TRIG:EDGE:SOUR CHAN2"
    ":TRIG:EDGE:SLOP " + slope
    ":TRIG:EDGE:LEV " + compose("%.9g",level)
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
assert(numel(preamble)>=10,"Preambulo de onda Rigol incompleto.");
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

function serialPortName = resolveSerialPort(requestedPort)
availablePorts = string(serialportlist("available"));
assert(~isempty(availablePorts),"No hay puertos serie disponibles.");
if strlength(requestedPort)>0
    match = strcmpi(availablePorts,requestedPort);
    assert(nnz(match)==1, ...
        "El puerto %s no está disponible. Puertos detectados: %s.", ...
        requestedPort,strjoin(availablePorts,", "));
    serialPortName = availablePorts(match);
    return
end
assert(isscalar(availablePorts), ...
    "Hay varios puertos disponibles (%s). Indique el puerto del KitProg.", ...
    strjoin(availablePorts,", "));
serialPortName = availablePorts;
end
