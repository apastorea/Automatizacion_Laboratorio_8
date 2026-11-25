function metrics = metricas_rigol_abierto_lab8(ch1,ch2,step_mV)
%METRICAS_RIGOL_ABIERTO_LAB8 Extrae base y meseta aun con disparo forzado.
%   Usa los extremos temporales como nivel de reposo y detecta la meseta por
%   amplitud. Esto permite validar una pantalla que contenga el pulso completo
%   aunque el instante t=0 coincida con el flanco de retorno a cero.

arguments
    ch1 table
    ch2 table
    step_mV (1,1) double {mustBeMember(step_mV,[-50 50])}
end

assert(height(ch1)==height(ch2) && height(ch1)>=100, ...
    "Las formas de onda Rigol son incompatibles o demasiado cortas.");
assert(all(ismember(["time_s","voltage_V"], ...
    string(ch1.Properties.VariableNames))),"CH1 no tiene tiempo y tension.");
assert(all(ismember(["time_s","voltage_V"], ...
    string(ch2.Properties.VariableNames))),"CH2 no tiene tiempo y tension.");

n = height(ch1);
edgeCount = max(20,floor(0.12*n));
edgeMask = false(n,1);
edgeMask(1:edgeCount) = true;
edgeMask(end-edgeCount+1:end) = true;
baseline1 = median(ch1.voltage_V(edgeMask));
baseline2 = median(ch2.voltage_V(edgeMask));

signedDeviation = sign(step_mV).*(ch1.voltage_V-baseline1);
candidateAmplitude = quantile(signedDeviation,0.90);
responseMask = signedDeviation >= 0.45*candidateAmplitude;
assert(candidateAmplitude>=0.020 && nnz(responseMask)>=20, ...
    "La pantalla Rigol no contiene una meseta de al menos 20 mV.");

response1 = median(ch1.voltage_V(responseMask));
response2 = median(ch2.voltage_V(responseMask));
delta1 = (response1-baseline1)*1000;
delta2 = (response2-baseline2)*1000;
pulseTimes = ch1.time_s(responseMask);

metrics = struct("baselineCH1_mV",baseline1*1000, ...
    "baselineCH2_mV",baseline2*1000,"responseCH1_mV",response1*1000, ...
    "responseCH2_mV",response2*1000,"deltaCH1_mV",delta1, ...
    "deltaCH2_mV",delta2,"gainCH2overCH1",delta2/delta1, ...
    "pulseStart_s",min(pulseTimes),"pulseEnd_s",max(pulseTimes), ...
    "pulseVisible_s",max(pulseTimes)-min(pulseTimes), ...
    "responsePoints",nnz(responseMask),"expectedSign",sign(step_mV));
end
