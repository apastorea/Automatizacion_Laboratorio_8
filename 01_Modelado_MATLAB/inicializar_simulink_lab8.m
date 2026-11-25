% INICIALIZAR_SIMULINK_LAB8 Define los parametros del modelo Simulink.
% Seleccione "lento"/"rapido" y "nominal"/"identificada" antes de
% ejecutar este script si desea reemplazar los valores predeterminados.

if ~exist("lab8Diseno", "var")
    lab8Diseno = "lento";
end
if ~exist("lab8Planta", "var")
    lab8Planta = "identificada";
end

mustBeMember(lab8Diseno, ["lento", "rapido"]);
mustBeMember(lab8Planta, ["nominal", "identificada"]);

TsLab8 = 0.002;

R5 = 150e3;
R6 = 47e3;
R1 = 15e3;
R2 = 47e3;
C1 = 100e-9;
C3 = 100e-9;
Fnominal = [-1/(R5*C1), 0; -1/(R2*C3), -1/(R1*C3)];
Gnominal = [-1/(R6*C1); 0];
Cplanta = [0, 1];
Dplanta = 0;

sistemaNominal = c2d(ss(Fnominal, Gnominal, Cplanta, Dplanta), ...
    TsLab8, "zoh");
[Anominal, Bnominal, ~, ~] = ssdata(sistemaNominal);

gananciaIdentificada = 1.002941;
tau1Identificada = 0.00906915;
tau2Identificada = 0.000774399;
gananciaEtapa1 = R5/R6;
gananciaEtapa2 = gananciaIdentificada/gananciaEtapa1;
Fidentificada = [-1/tau1Identificada, 0; ...
    -gananciaEtapa2/tau2Identificada, -1/tau2Identificada];
Gidentificada = [-gananciaEtapa1/tau1Identificada; 0];
sistemaIdentificado = c2d(ss(Fidentificada, Gidentificada, ...
    Cplanta, Dplanta), TsLab8, "zoh");
[Aidentificada, Bidentificada, ~, ~] = ssdata(sistemaIdentificado);

if lab8Planta == "nominal"
    AplantaLab8 = Anominal;
    BplantaLab8 = Bnominal;
else
    AplantaLab8 = Aidentificada;
    BplantaLab8 = Bidentificada;
end

AobservadorLab8 = Aidentificada;
BobservadorLab8 = Bidentificada;
CobservadorLab8 = Cplanta;
LobservadorLab8 = [-1.860494423644; 0.175152235280];

if lab8Diseno == "lento"
    KxLab8 = [1.654553831423, 5.539689791255];
    KiLab8 = -0.223449848701;
else
    KxLab8 = [0.591027144837, 2.690253516042];
    KiLab8 = -0.391037235226;
end

uMinLab8 = -0.115;
uMaxLab8 = 0.107;
referenciaLab8 = 0.050;
inicioReferenciaLab8 = 0.064;
finReferenciaLab8 = 0.666;
tiempoFinalLab8 = 1.198;
