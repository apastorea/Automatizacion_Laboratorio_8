% VERIFICAR_SIMULINK_LAB8 Ejecuta los cuatro casos del modelo Simulink.
% Los resultados son simulados con DAC ideal limitado; no son mediciones.

clearvars;

carpetaModelo = fileparts(mfilename("fullpath"));
modelo = "lab8_control_integral";
disenos = ["lento", "lento", "rapido", "rapido"];
plantas = ["nominal", "identificada", "nominal", "identificada"];
numeroCasos = numel(disenos);

diseno = strings(numeroCasos, 1);
planta = strings(numeroCasos, 1);
picoSalida_mV = zeros(numeroCasos, 1);
mandoMinimo_mV = zeros(numeroCasos, 1);
mandoMaximo_mV = zeros(numeroCasos, 1);
errorRmsRegimen_mV = zeros(numeroCasos, 1);

for indice = 1:numeroCasos
    lab8Diseno = disenos(indice);
    lab8Planta = plantas(indice);
    inicializar_simulink_lab8;

    entrada = Simulink.SimulationInput(modelo);
    entrada = setModelParameter(entrada, "StopTime", "1.198");
    salida = sim(entrada);

    y = salida.ySimulinkLab8;
    u = salida.uSimulinkLab8;
    r = salida.rSimulinkLab8;
    ventanaRegimen = y.Time >= 0.550 & y.Time <= 0.660;

    diseno(indice) = disenos(indice);
    planta(indice) = plantas(indice);
    picoSalida_mV(indice) = 1000*max(y.Data);
    mandoMinimo_mV(indice) = 1000*min(u.Data);
    mandoMaximo_mV(indice) = 1000*max(u.Data);
    errorRmsRegimen_mV(indice) = 1000*sqrt(mean( ...
        (r.Data(ventanaRegimen) - y.Data(ventanaRegimen)).^2));
end

resumenSimulink = table(diseno, planta, picoSalida_mV, ...
    mandoMinimo_mV, mandoMaximo_mV, errorRmsRegimen_mV);
disp(resumenSimulink);

rutaSalida = fullfile(carpetaModelo, "..", "05_Resultados", ...
    "resumen_simulink_lab8.csv");
writetable(resumenSimulink, rutaSalida);
fprintf("Resumen Simulink guardado en: %s\n", rutaSalida);
