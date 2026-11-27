function outputFolder = capturar_integral_lab8(expectedDesign,label,serialPortName)
%CAPTURAR_INTEGRAL_LAB8 Captura segura del lazo integral de Lab 8.
%   Registra UART, CH1=J5, CH2=J7 y la pantalla original del RIGOL. El
%   firmware debe anunciar modo INTEGRAL y el diseno solicitado. El disparo
%   se toma desde CH2 para evitar que el ruido del punto de mando domine la
%   sincronizacion de la pantalla.

arguments
    expectedDesign (1,1) string {mustBeMember(expectedDesign,["LENTO" "RAPIDO"])}
    label (1,1) string = "integral_lab8"
    serialPortName (1,1) string = ""
end

expectedRows = 600;
expectedMode = "INTEGRAL";
serialPortName = resolveSerialPort(serialPortName);
baudRate = 57600;
scopeTimeScale = 0.20;
% A 0.20 V/div caben los transitorios previstos sin perder resolucion.
scopeCh1Scale = 0.20;
scopeCh2Scale = 0.20;
triggerLevel = 0.25;
armDelay = 2.75;
forceTime = 4.35;
fatalMask = 63; % ADC, DAC fisico, numerico, CPU, tiempo o salida.

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
configureScope(scope,scopeTimeScale,scopeCh1Scale,scopeCh2Scale,triggerLevel);

port = serialport(serialPortName,baudRate,Timeout=1);
configureTerminator(port,"LF");
flush(port);
cleanupPort = onCleanup(@() clearInstrument(port));

fprintf("CAPTURA_LISTA: Lab8 INTEGRAL %s preparado. Presione SW3/RESET una vez.\n", ...
    expectedDesign);
lines = strings(0,1);
startupDetected = false;
armed = false;
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
                forceChecked = false;
                fprintf("PSoC: anuncio de arranque LAB8 detectado.\n");
            elseif startsWith(line,"# LAB8 control_integral")
                detectedMode = extractToken(line,"modo=([A-Z_]+)");
                fprintf("PSoC: modo=%s.\n",detectedMode);
            elseif startsWith(line,"# LAB8 diseno=")
                detectedDesign = extractToken(line,"diseno=([A-Z_]+)");
                fprintf("PSoC: diseno=%s.\n",detectedDesign);
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
            if ismember(stateBeforeForce,["WAIT" "RUN" "AUTO"])
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
requiredVariables = ["k" "t_us" "y_rel_mV" "r_mV" ...
    "u_solicitada_mV" "u_nominal_mV" "dac_pos" "dac_neg" ...
    "cpu_us" "intervalo_us" "flags"];
assert(all(ismember(requiredVariables,string(T.Properties.VariableNames))), ...
    "Faltan variables obligatorias en la telemetria Lab8.");

scopeState = upper(strip(writeread(scope,":TRIG:STAT?")));
scopeFinished = ismember(scopeState,["STOP" "TD"]);
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
reference = double(T.r_mV);
uRequested = double(T.u_solicitada_mV);
uNominal = double(T.u_nominal_mV);
referenceLevel_mV = max(reference);
assert(referenceLevel_mV>=490 && referenceLevel_mV<=510, ...
    "La telemetria no anuncia la referencia esperada de 500 mV.");
referenceMask = reference>0.5*referenceLevel_mV;
postMask = double(T.k)>=550;
fatalFlags = bitand(uint16(flags),uint16(fatalMask));
satSamples = nnz(bitand(uint16(flags),uint16(64))~=0);
antiwindupSamples = nnz(bitand(uint16(flags),uint16(128))~=0);

scopeMetrics = closedLoopScopeMetrics(ch1,ch2);
lateReference = find(referenceMask);
lateReference = lateReference(max(1,end-49):end);
steadyY_mV = median(yRelative(lateReference));
postY_mV = median(yRelative(postMask));
uartSummary = struct( ...
    "rows",height(T),"fatalFlagSamples",nnz(fatalFlags), ...
    "saturationSamples",satSamples,"antiwindupSamples",antiwindupSamples, ...
    "maxCpu_us",max(cpu),"medianPeriod_us",median(periods(2:end)), ...
    "minPeriod_us",min(periods(2:end)),"maxPeriod_us",max(periods(2:end)), ...
    "referenceSamples",nnz(referenceMask),"steadyY_mV",steadyY_mV, ...
    "postReturnY_mV",postY_mV,"maxAbsY_mV",max(abs(yRelative)), ...
    "maxRequested_mV",max(uRequested),"minRequested_mV",min(uRequested), ...
    "maxNominal_mV",max(uNominal),"minNominal_mV",min(uNominal));

modeMatches = detectedMode==expectedMode && detectedDesign==expectedDesign;
timingValid = uartSummary.minPeriod_us>=1800 && ...
    uartSummary.maxPeriod_us<=2200 && uartSummary.maxCpu_us<2000;
responseValid = steadyY_mV>=0.85*referenceLevel_mV && ...
    steadyY_mV<=1.15*referenceLevel_mV && ...
    uartSummary.maxAbsY_mV<=1.30*referenceLevel_mV && ...
    abs(postY_mV)<=0.10*referenceLevel_mV;
scopeValid = scopeMetrics.deltaCH2_mV>=0.75*referenceLevel_mV && ...
    scopeMetrics.deltaCH2_mV<=1.25*referenceLevel_mV && ...
    abs(scopeMetrics.returnCH2_mV)<=0.10*referenceLevel_mV;
preliminaryValid = startupDetected && armed && finished && scopeFinished && ...
    modeMatches && height(T)==expectedRows && nnz(referenceMask)==301 && ...
    uartSummary.fatalFlagSamples==0 && timingValid && responseValid && scopeValid;

metadata = struct;
metadata.capturedAt = string(datetime("now",TimeZone="local", ...
    Format="yyyy-MM-dd'T'HH:mm:ssXXX"));
metadata.expectedMode = expectedMode;
metadata.detectedMode = detectedMode;
metadata.expectedDesign = expectedDesign;
metadata.detectedDesign = detectedDesign;
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
    "triggerSource","CHAN2","triggerSlope","POS", ...
    "trigger_V",triggerLevel, ...
    "acquisition","HRES","armDelay_s",armDelay,"forceTime_s",forceTime);
metadata.uart = uartSummary;
metadata.scope = scopeMetrics;
metadata.waveformDetails = struct("CH1",detailsCh1,"CH2",detailsCh2);
metadata.checks = struct("modeMatches",modeMatches,"timingValid",timingValid, ...
    "responseValid",responseValid,"scopeValid",scopeValid);
metadata.preliminaryValid = preliminaryValid;
writestruct(metadata,fullfile(outputFolder,"metadatos.json"));

fprintf("CAPTURA_COMPLETA: %s\n",outputFolder);
fprintf("VALIDACION_PRELIMINAR: %d; diseno=%s; y_ss=%.1f mV; " + ...
    "retorno=%.1f mV; sat=%d; antiwindup=%d; fallos_fatales=%d.\n", ...
    preliminaryValid,detectedDesign,steadyY_mV,postY_mV,satSamples, ...
    antiwindupSamples,uartSummary.fatalFlagSamples);
assert(preliminaryValid, ...
    "La captura se guardo, pero no supero la validacion preliminar.");

clear cleanupPort cleanupScope
end

function configureScope(scope,timeScale,ch1Scale,ch2Scale,triggerLevel)
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
    ":TRIG:EDGE:SLOP POS"
    ":TRIG:EDGE:LEV " + compose("%.9g",triggerLevel)
    ":TRIG:SWE NORM"
    ];
for command = commands.'
    writeline(scope,command);
end
end

function metrics = closedLoopScopeMetrics(ch1,ch2)
n = height(ch1);
edgeCount = max(20,floor(0.15*n));
% El disparo puede ocurrir despues del flanco real por el ruido del mando.
% Para un escalon positivo, el cluster inferior representa el nivel base y
% el superior el plateau, independientemente de su posicion en el registro.
threshold1 = 0.5*(quantile(ch1.voltage_V,0.50)+ ...
    quantile(ch1.voltage_V,0.90));
threshold2 = 0.5*(quantile(ch2.voltage_V,0.50)+ ...
    quantile(ch2.voltage_V,0.90));
baseline1 = median(ch1.voltage_V(ch1.voltage_V<threshold1));
baseline2 = median(ch2.voltage_V(ch2.voltage_V<threshold2));
return2 = median(ch2.voltage_V(end-edgeCount+1:end));
response2 = median(ch2.voltage_V(ch2.voltage_V>=threshold2));
metrics = struct("baselineCH1_mV",baseline1*1000, ...
    "baselineCH2_mV",baseline2*1000, ...
    "deltaCH2_mV",(response2-baseline2)*1000, ...
    "returnCH2_mV",(return2-baseline2)*1000, ...
    "maxCH1Increment_mV",max((ch1.voltage_V-baseline1)*1000), ...
    "minCH1Increment_mV",min((ch1.voltage_V-baseline1)*1000));
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
