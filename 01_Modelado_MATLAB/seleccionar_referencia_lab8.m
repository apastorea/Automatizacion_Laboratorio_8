%% LABORATORIO 8 - SELECCION DE LA AMPLITUD DE REFERENCIA
% Autor: Aldo Pastore
% Objetivo:
%   seleccionar una referencia que permita evaluar los controladores sin que
%   la cuantizacion ni el ruido dominen la medicion y sin perder margen de
%   actuacion. Se ensayan cuatro amplitudes sobre una unica planta fisica,
%   representada por los modelos identificado y nominal, con ambos polos
%   integrales y el DAC bipolar cuantizado.
%
% Criterio de aceptacion:
%   1) el modelo identificado se usa para decidir la condicion experimental;
%   2) ninguna muestra puede saturar;
%   3) el peor esfuerzo solicitado debe ser menor o igual al 80 % del limite
%      de +/-1 V, dejando 20 % de reserva para incertidumbre y transitorios;
%   4) se elige la mayor amplitud candidata que cumple 1), 2) y 3).
% El modelo nominal se conserva como contraste de sensibilidad y no se
% confunde con una segunda planta fisica.
%
% Alcance:
%   simulacion reproducible; no abre puertos, no programa el PSoC y no aplica
%   tension a la planta. Las tensiones se expresan en V y el tiempo en s.

clear; clc; close all;
set(groot,"defaultFigureVisible","off");

%% Configuracion del barrido
Ts = 0.002;
numeroMuestras = 600;
tiempo = (0:numeroMuestras-1)'*Ts;
indiceInicio = 33;
indiceFin = 333;
referencias_V = [0.250; 0.500; 0.750; 1.000];
limiteActuador_V = 1.0;
fraccionMaximaActuador = 0.80;

% Caracterizacion fisica conservada en el firmware del banco.
pasoDacPositivo_V = 0.015370448;
pasoDacNegativo_V = 0.010560423;
codigoMaximoPositivo = 65;
codigoMaximoNegativo = 95;
errorRmsLectura_V = 0.003374325;

%% Modelos discretos y ganancias del regulador
R5 = 150e3; R6 = 47e3; R1 = 15e3; R2 = 47e3;
C1 = 100e-9; C3 = 100e-9;
C = [0 1]; D = 0;

Fnominal = [-1/(R5*C1), 0; -1/(R2*C3), -1/(R1*C3)];
Gnominal = [-1/(R6*C1); 0];
[Anominal,Bnominal,~,~] = ssdata(c2d( ...
    ss(Fnominal,Gnominal,C,D),Ts,"zoh"));

gananciaIdentificada = 1.002941;
tau1Identificada = 0.00906915;
tau2Identificada = 0.000774399;
gananciaEtapa1 = R5/R6;
gananciaEtapa2 = gananciaIdentificada/gananciaEtapa1;
Fidentificada = [-1/tau1Identificada, 0; ...
    -gananciaEtapa2/tau2Identificada, -1/tau2Identificada];
Gidentificada = [-gananciaEtapa1/tau1Identificada; 0];
[Aidentificada,Bidentificada,~,~] = ssdata(c2d( ...
    ss(Fidentificada,Gidentificada,C,D),Ts,"zoh"));

polosDominantes = [0.80+0.25i 0.80-0.25i];
polosIntegrales = [0.60 0.30];
polosObservador = [0.20+0.10i 0.20-0.10i];
L = place(Aidentificada',(C*Aidentificada)',polosObservador).';
Aampliada = [Aidentificada zeros(2,1); -C 1];
Beampliada = [Bidentificada; 0];

assert(rank(ctrb(Aidentificada,Bidentificada)) == 2, ...
    "El modelo identificado no es controlable.");
assert(rank(obsv(Aidentificada,C*Aidentificada)) == 2, ...
    "No puede construirse el estimador actual.");
assert(rank(ctrb(Aampliada,Beampliada)) == 3, ...
    "El modelo ampliado no es controlable.");

modelos = {Anominal,Bnominal,"nominal"; ...
           Aidentificada,Bidentificada,"identificado"};
nombresDiseno = ["lento" "rapido"];

%% Barrido de amplitud
resumen = table();
curvasSeleccionadas = cell(2,1);

for indiceReferencia = 1:numel(referencias_V)
    referencia_V = referencias_V(indiceReferencia);
    referencia = zeros(numeroMuestras,1);
    referencia(indiceInicio:indiceFin) = referencia_V;

    for indiceDiseno = 1:numel(polosIntegrales)
        K = place(Aampliada,Beampliada, ...
            [polosDominantes polosIntegrales(indiceDiseno)]);
        Kx = K(1:2);
        Ki = K(3);

        for indiceModelo = 1:size(modelos,1)
            Aplanta = modelos{indiceModelo,1};
            Bplanta = modelos{indiceModelo,2};
            nombreModelo = string(modelos{indiceModelo,3});

            simulacion = simularCaso(Aplanta,Bplanta, ...
                Aidentificada,Bidentificada,C,L,Kx,Ki,referencia, ...
                limiteActuador_V,pasoDacPositivo_V,pasoDacNegativo_V, ...
                codigoMaximoPositivo,codigoMaximoNegativo);
            metricas = calcularMetricas(simulacion,referencia,tiempo, ...
                indiceInicio,indiceFin,referencia_V,Ts);

            nombreDiseno = nombresDiseno(indiceDiseno);
            fila = table(referencia_V,nombreDiseno,nombreModelo, ...
                metricas.tr_ms,metricas.ts_ms,metricas.sobrepasamiento_pct, ...
                metricas.errorEstacionario_mV,metricas.errorRms_mV, ...
                metricas.uSolicitadaMin_V,metricas.uSolicitadaMax_V, ...
                metricas.uSolicitadaPicoAbs_V,metricas.margenActuador_pct, ...
                metricas.saturaciones, ...
                100*pasoDacPositivo_V/referencia_V, ...
                100*errorRmsLectura_V/referencia_V, ...
                'VariableNames',{'referencia_V','diseno','modelo', ...
                'tr_ms','ts_ms','sobrepasamiento_pct', ...
                'error_estacionario_mV','error_RMS_mV', ...
                'u_solicitada_min_V','u_solicitada_max_V', ...
                'u_solicitada_pico_abs_V','margen_actuador_pct', ...
                'saturaciones','paso_DAC_positivo_pct_referencia', ...
                'error_RMS_lectura_pct_referencia'});
            resumen = [resumen; fila]; %#ok<AGROW>

            if referencia_V == 0.500 && nombreModelo == "identificado"
                curvasSeleccionadas{indiceDiseno} = simulacion;
            end
        end
    end
end

%% Eleccion mediante el peor caso de cada amplitud
seleccion = table(referencias_V,zeros(size(referencias_V)), ...
    zeros(size(referencias_V)),zeros(size(referencias_V)), ...
    zeros(size(referencias_V)),zeros(size(referencias_V)), ...
    zeros(size(referencias_V)),zeros(size(referencias_V)), ...
    false(size(referencias_V)), ...
    'VariableNames',{'referencia_V','u_pico_identificado_V', ...
    'margen_identificado_pct','saturaciones_identificado', ...
    'u_pico_nominal_V','margen_nominal_pct','saturaciones_nominal', ...
    'paso_DAC_positivo_pct','cumple_criterio'});

for indiceReferencia = 1:numel(referencias_V)
    filasIdentificado = resumen.referencia_V == referencias_V(indiceReferencia) & ...
        resumen.modelo == "identificado";
    filasNominal = resumen.referencia_V == referencias_V(indiceReferencia) & ...
        resumen.modelo == "nominal";
    seleccion.u_pico_identificado_V(indiceReferencia) = ...
        max(resumen.u_solicitada_pico_abs_V(filasIdentificado));
    seleccion.margen_identificado_pct(indiceReferencia) = ...
        min(resumen.margen_actuador_pct(filasIdentificado));
    seleccion.saturaciones_identificado(indiceReferencia) = ...
        sum(resumen.saturaciones(filasIdentificado));
    seleccion.u_pico_nominal_V(indiceReferencia) = ...
        max(resumen.u_solicitada_pico_abs_V(filasNominal));
    seleccion.margen_nominal_pct(indiceReferencia) = ...
        min(resumen.margen_actuador_pct(filasNominal));
    seleccion.saturaciones_nominal(indiceReferencia) = ...
        sum(resumen.saturaciones(filasNominal));
    seleccion.paso_DAC_positivo_pct(indiceReferencia) = ...
        100*pasoDacPositivo_V/referencias_V(indiceReferencia);
    seleccion.cumple_criterio(indiceReferencia) = ...
        seleccion.saturaciones_identificado(indiceReferencia) == 0 && ...
        seleccion.u_pico_identificado_V(indiceReferencia) <= ...
            fraccionMaximaActuador*limiteActuador_V;
end

indiceValido = find(seleccion.cumple_criterio,1,"last");
assert(~isempty(indiceValido), ...
    "Ninguna referencia candidata cumple el margen de actuacion.");
referenciaSeleccionada_V = seleccion.referencia_V(indiceValido);
assert(abs(referenciaSeleccionada_V-0.500) < 1e-12, ...
    "La referencia seleccionada cambio; revisar firmware e informe.");

%% Resultados y archivos reproducibles
carpeta = fileparts(mfilename("fullpath"));
salida = fullfile(carpeta,"..","05_Resultados","Seleccion_Referencia");
figuras = fullfile(salida,"figuras");
if ~isfolder(salida), mkdir(salida); end
if ~isfolder(figuras), mkdir(figuras); end

writetable(resumen,fullfile(salida,"barrido_referencias_lab8.csv"));
writetable(seleccion,fullfile(salida,"criterio_seleccion_referencia_lab8.csv"));

disp("RESUMEN DEL CRITERIO DE SELECCION");
disp(seleccion);
fprintf("Referencia seleccionada: %.0f mV\n", ...
    1000*referenciaSeleccionada_V);
fprintf("Paso DAC positivo relativo: %.3f %%\n", ...
    100*pasoDacPositivo_V/referenciaSeleccionada_V);
fprintf("Error RMS de lectura relativo: %.3f %%\n", ...
    100*errorRmsLectura_V/referenciaSeleccionada_V);

estilo = crearEstiloGrafico();
figuraBarrido = figure(Color=estilo.background, ...
    Name="Seleccion de referencia",Position=[100 100 940 540]);
ejesBarrido = axes(figuraBarrido);
aplicarEstiloEjes(ejesBarrido,estilo);
colororder(ejesBarrido,estilo.plotColors);
hold(ejesBarrido,"on");
hIdentificado = plot(ejesBarrido,1000*seleccion.referencia_V, ...
    seleccion.u_pico_identificado_V,"o-",LineWidth=1.7,MarkerSize=6);
hNominal = plot(ejesBarrido,1000*seleccion.referencia_V, ...
    seleccion.u_pico_nominal_V,"s-",LineWidth=1.3,MarkerSize=5);
yline(ejesBarrido,fraccionMaximaActuador*limiteActuador_V,"--", ...
    "Criterio: 80 % del actuador",LineWidth=1.2, ...
    Color=estilo.annotation,HandleVisibility="off");
yline(ejesBarrido,limiteActuador_V,":","Limite fisico configurado", ...
    LineWidth=1.2,Color=estilo.annotation,HandleVisibility="off");
xline(ejesBarrido,1000*referenciaSeleccionada_V,"-.", ...
    "Seleccion: 500 mV",LineWidth=1.2,Color=estilo.annotation, ...
    LabelOrientation="horizontal",HandleVisibility="off");
xlabel("Amplitud de referencia [mV]",Color=estilo.text);
ylabel("Peor esfuerzo solicitado |u| [V]",Color=estilo.text);
title("Seleccion de referencia y margen del actuador", ...
    FontSize=12,FontWeight="normal",Color=estilo.text);
ylim([0 1.15]);
leyendaBarrido = legend([hIdentificado hNominal], ...
    "Modelo identificado","Modelo nominal", ...
    Location="northwest",Box="off");
leyendaBarrido.TextColor = estilo.text;
exportgraphics(figuraBarrido,fullfile(figuras, ...
    "seleccion_referencia_margen_actuador.png"),Resolution=240, ...
    BackgroundColor=estilo.background);

figuraRespuesta = figure(Color=estilo.background, ...
    Name="Respuesta a 500 mV",Position=[100 100 940 680]);
tiledlayout(2,1,TileSpacing="compact");
referenciaSeleccionada = zeros(numeroMuestras,1);
referenciaSeleccionada(indiceInicio:indiceFin) = referenciaSeleccionada_V;

ejesSalida = nexttile; hold on;
aplicarEstiloEjes(ejesSalida,estilo);
colororder(ejesSalida,estilo.plotColors);
hReferencia = stairs(1000*tiempo,1000*referenciaSeleccionada,"--", ...
    Color=estilo.reference,LineWidth=1.2);
hSalida = gobjects(2,1);
for indiceDiseno = 1:2
    hSalida(indiceDiseno) = stairs(1000*tiempo, ...
        1000*curvasSeleccionadas{indiceDiseno}.y, ...
        LineWidth=1.3);
end
xlim([0 760]);
ylabel("Salida y [mV]",Color=estilo.text);
title("Respuesta simulada de la planta a 500 mV", ...
    FontSize=12,FontWeight="normal",Color=estilo.text);
leyendaSalida = legend([hReferencia;hSalida],"Referencia", ...
    "Integral lento","Integral rapido",Location="best",Box="off");
leyendaSalida.TextColor = estilo.text;

ejesMando = nexttile; hold on;
aplicarEstiloEjes(ejesMando,estilo);
colororder(ejesMando,estilo.plotColors);
hMando = gobjects(2,1);
for indiceDiseno = 1:2
    hMando(indiceDiseno) = stairs(1000*tiempo, ...
        curvasSeleccionadas{indiceDiseno}.u, ...
        LineWidth=1.3);
end
yline(fraccionMaximaActuador*limiteActuador_V,"--","+80 %", ...
    Color=estilo.annotation,HandleVisibility="off");
yline(-fraccionMaximaActuador*limiteActuador_V,"--","-80 %", ...
    Color=estilo.annotation,HandleVisibility="off");
xlim([0 760]); ylim([-1 1]);
xlabel("Tiempo [ms]",Color=estilo.text);
ylabel("Mando cuantizado u [V]",Color=estilo.text);
leyendaMando = legend(hMando,"Integral lento","Integral rapido", ...
    Location="south",Orientation="horizontal",Box="off");
leyendaMando.TextColor = estilo.text;
exportgraphics(figuraRespuesta,fullfile(figuras, ...
    "respuesta_simulada_referencia_500mV.png"),Resolution=240, ...
    BackgroundColor=estilo.background);

%% Funciones locales
function S = simularCaso(Aplanta,Bplanta,Aobservador,Bobservador,C,L, ...
        Kx,Ki,referencia,limiteActuador,pasoPositivo,pasoNegativo, ...
        codigoMaximoPositivo,codigoMaximoNegativo)
    numeroMuestras = numel(referencia);
    x = zeros(2,1);
    z = zeros(2,1);
    xi = 0;
    S.y = zeros(numeroMuestras,1);
    S.u = zeros(numeroMuestras,1);
    S.uSolicitada = zeros(numeroMuestras,1);
    S.saturado = false(numeroMuestras,1);

    for k = 1:numeroMuestras
        y = C*x;
        innovacion = y-C*z;
        xEstimado = z+L*innovacion;
        uSolicitada = -Kx*xEstimado-Ki*xi;
        uLimitada = min(limiteActuador,max(-limiteActuador,uSolicitada));

        if uLimitada >= 0
            codigo = min(codigoMaximoPositivo, ...
                max(0,round(uLimitada/pasoPositivo)));
            uAplicada = codigo*pasoPositivo;
        else
            codigo = min(codigoMaximoNegativo, ...
                max(0,round(-uLimitada/pasoNegativo)));
            uAplicada = -codigo*pasoNegativo;
        end

        error = referencia(k)-y;
        bloquearIntegral = ...
            (uSolicitada > limiteActuador && error > 0) || ...
            (uSolicitada < -limiteActuador && error < 0);
        if ~bloquearIntegral
            xiSiguiente = xi+error;
        else
            xiSiguiente = xi;
        end

        S.y(k) = y;
        S.u(k) = uAplicada;
        S.uSolicitada(k) = uSolicitada;
        S.saturado(k) = uSolicitada ~= uLimitada;

        x = Aplanta*x+Bplanta*uAplicada;
        z = Aobservador*xEstimado+Bobservador*uAplicada;
        xi = xiSiguiente;
        assert(all(isfinite([x;z;xi;uAplicada])), ...
            "La simulacion produjo NaN o Inf.");
    end
end

function m = calcularMetricas(S,referencia,tiempo,indiceInicio,indiceFin, ...
        amplitud,Ts)
    yActiva = S.y(indiceInicio:indiceFin);
    tiempoActivo = tiempo(indiceInicio:indiceFin);
    indice10 = find(yActiva >= 0.1*amplitud,1,"first");
    indice90 = find(yActiva >= 0.9*amplitud,1,"first");
    m.tr_ms = NaN;
    if ~isempty(indice10) && ~isempty(indice90)
        m.tr_ms = 1000*(tiempoActivo(indice90)-tiempoActivo(indice10));
    end

    fueraBanda = find(abs(yActiva-amplitud) > 0.02*amplitud);
    m.ts_ms = NaN;
    if isempty(fueraBanda)
        m.ts_ms = 0;
    elseif fueraBanda(end) < numel(yActiva)
        m.ts_ms = 1000*fueraBanda(end)*Ts;
    end

    m.sobrepasamiento_pct = max(0,100*(max(yActiva)-amplitud)/amplitud);
    ventanaRegimen = tiempo >= 0.550 & tiempo <= 0.660 & referencia > 0;
    errorRegimen = referencia(ventanaRegimen)-S.y(ventanaRegimen);
    m.errorEstacionario_mV = 1000*mean(errorRegimen,"omitmissing");
    m.errorRms_mV = 1000*sqrt(mean(errorRegimen.^2,"omitmissing"));
    m.uSolicitadaMin_V = min(S.uSolicitada,[],"omitmissing");
    m.uSolicitadaMax_V = max(S.uSolicitada,[],"omitmissing");
    m.uSolicitadaPicoAbs_V = max(abs(S.uSolicitada),[],"omitmissing");
    m.margenActuador_pct = 100*(1-m.uSolicitadaPicoAbs_V);
    m.saturaciones = nnz(S.saturado);
end

function estilo = crearEstiloGrafico()
    % Paleta centralizada para exportaciones claras y consistentes.
    estilo.background = [1.00 1.00 1.00];
    estilo.axes = [1.00 1.00 1.00];
    estilo.text = [0.15 0.15 0.15];
    estilo.grid = [0.82 0.82 0.82];
    estilo.annotation = [0.35 0.35 0.35];
    estilo.reference = [0.10 0.10 0.10];
    estilo.plotColors = [0.00 0.45 0.74; 0.85 0.33 0.10];
end

function aplicarEstiloEjes(ejes,estilo)
    set(ejes,Color=estilo.axes,XColor=estilo.text,YColor=estilo.text, ...
        GridColor=estilo.grid,GridAlpha=0.65,FontName="Arial", ...
        FontSize=9,LineWidth=0.8,Box="on");
    grid(ejes,"on");
end
