%% LABORATORIO 8 - COMPARACION ENTRE DAC IDEAL Y CUANTIZADO
% Simulacion reproducible; no comunica con PSoC, UART ni osciloscopio.
% Compara las MISMAS ganancias Kx/Ki y observador E2 (actual) en:
%   1) DAC ideal: salida continua, con limites de saturacion.
%   2) DAC cuantizado: mismos limites y pasos de conversion por rama.
% El controlador y el estimador se disenan con el modelo identificado;
% el nominal se conserva como caso de incertidumbre para la comparacion.
% El pulso dura 602 ms y coincide con la ventana usada en los ensayos.
clear; clc; close all;
fprintf('\n=== LABORATORIO 8 | DAC IDEAL vs CUANTIZADO (SIMULACION) ===\n');

%% 1. Parametros de referencia
Ts = 0.002; N = 600;
t = (0:N-1)'*Ts;
r = zeros(N,1);
r(33:333) = 0.050;       % r=50 mV desde t=64 hasta t=664 ms
p_control = [0.80+0.25i, 0.80-0.25i];
p_integral = [0.60, 0.30];          % lento / rapido
p_obs = [0.20+0.10i, 0.20-0.10i];   % observador ACTUAL E2
disenos = {'integral_lento','integral_rapido'};
plantas = {'nominal','identificada'};

% Limites del mando y escalas comprobadas en los codigos de ensayo.
lim.u_min = -0.115;   lim.u_max = 0.107;  % precuantizacion, V
lim.q_pos = 0.015370448;                  % V / codigo (positivo)
lim.q_neg = 0.010560423;                  % V / codigo (negativo)
lim.cod_pos = 7; lim.cod_neg = 11;
lim.antiwindup = true;

%% 2. Planta nominal (mismo orden de estados del script original)
R5 = 150e3; R6 = 47e3; R1 = 15e3; R2 = 47e3;
C1 = 100e-9; C3 = 100e-9;
F = [-1/(R5*C1), 0; -1/(R2*C3), -1/(R1*C3)];
G = [-1/(R6*C1); 0];
C = [0 1]; D = 0;
[A,B,~,~] = ssdata(c2d(ss(F,G,C,D),Ts,'zoh'));

% Planta identificada: modelo previo, SIN nueva identificacion experimental.
Kid = 1.002941; tau1 = 0.00906915; tau2 = 0.000774399;
gananciaEtapa1 = R5/R6;
gananciaEtapa2 = Kid/gananciaEtapa1;
Fid = [-1/tau1, 0; -gananciaEtapa2/tau2, -1/tau2];
Gid = [-gananciaEtapa1/tau1; 0];
[Aid,Bid,~,~] = ssdata(c2d(ss(Fid,Gid,C,D),Ts,'zoh'));

% Validaciones previas
assert(rank(ctrb(Aid,Bid))==2 && rank(obsv(Aid,C))==2, ...
    'Modelo identificado no controlable u observable.');
assert(rank(obsv(Aid,C*Aid))==2, ...
    'El observador actual E2 no puede disenarse por dualidad.');

%% 3. Ganancias identificadas: identicas para DAC ideal y cuantizado
Ad = Aid; Bd = Bid;
L = place(Ad',(C*Ad)',p_obs).';  % Observador ACTUAL identificado
Aa = [Ad zeros(2,1); -C 1];
Ba = [Bd;0];
assert(rank(ctrb(Aa,Ba))==3,'Modelo ampliado no controlable.');

%% 4. Directorio de salida (NO sobrescribe ensayos originales)
carpeta = fileparts(mfilename('fullpath'));
salida = fullfile(carpeta,'..','05_Resultados','Comparacion_DAC');
figuras = fullfile(salida,'figuras');
if ~isfolder(salida),mkdir(salida);end
if ~isfolder(figuras),mkdir(figuras);end

resumen = table();
fprintf('Ts=%.3f ms; intervalo de analisis de regimen: 550 a 660 ms\n',Ts*1000);

for i = 1:2
    K = place(Aa,Ba,[p_control, p_integral(i)]);
    Kx = K(1:2); Ki = K(3);
    fprintf('\n%s (z_integral=%.2f): Kx=[%.7f %.7f], Ki=%.7f\n', ...
         disenos{i},p_integral(i),Kx(1),Kx(2),Ki);

    for j = 1:2
        if j==1
            Ap=A; Bp=B;
        else
            Ap=Aid; Bp=Bid;
        end

        % La unica diferencia entre ambos recorridos es la cuantizacion.
        ideal = simular_caso(Ap,Bp,Ad,Bd,C,L,Kx,Ki,r,lim,false);
        cuant = simular_caso(Ap,Bp,Ad,Bd,C,L,Kx,Ki,r,lim,true);

        % Ventana de 110 ms con referencia constante.
        idx = (t>=0.55) & (t<=0.66) & (r>0);
        mI = calcular_residual(ideal,r,idx,false);
        mQ = calcular_residual(cuant,r,idx,true);
        etiqueta = string(disenos{i});
        modelo = string(plantas{j});

        fprintf('  Planta %s\n',plantas{j});
        fprintf('    Ideal: RMS %.6g mV | pico-pico %.6g mV | banda %.2f%%\n', ...
            mI.rms_mV,mI.ypico_pico_mV,mI.banda_pct);
        fprintf('    Cuant: RMS %.6g mV | pico-pico %.6g mV | banda %.2f%% | niveles %d\n', ...
            mQ.rms_mV,mQ.ypico_pico_mV,mQ.banda_pct,mQ.niveles);
        fprintf('    Saturaciones solicitadas: ideal %d / cuant %d\n', ...
            nnz(ideal.saturado),nnz(cuant.saturado));

        modos = {'ideal','cuantizado'};
        met = {mI,mQ};
        est = {ideal,cuant};
        for k = 1:2
            S = est{k}; m = met{k};
            fila = table(etiqueta,modelo,string(modos{k}),p_integral(i), ...
                m.error_medio_mV,m.rms_mV,m.error_max_mV, ...
                m.ypico_pico_mV,m.banda_pct,m.niveles, ...
                nnz(S.saturado),1000*max(abs(S.u)), ...
                'VariableNames',{'diseno','planta','DAC','polo_integral', ...
                'error_medio_mV','error_RMS_mV','error_max_mV', ...
                'salida_pp_mV','muestras_banda_2pct','niveles_DAC', ...
                'saturaciones','mando_max_abs_mV'});
            resumen = [resumen; fila]; %#ok<AGROW>
        end

        % Un CSV por combinacion (comparacion muestra a muestra).
        datos = table(t,r,ideal.y,cuant.y,ideal.u,cuant.u, ...
            ideal.u_solicitado,cuant.u_solicitado,ideal.xi,cuant.xi, ...
            'VariableNames',{'t_s','r_V','y_ideal_V','y_cuant_V', ...
            'u_ideal_V','u_cuant_V','u_solicitado_ideal_V', ...
            'u_solicitado_cuant_V','xi_ideal_V','xi_cuant_V'});
        pref = [disenos{i},'_',plantas{j}];
        writetable(datos,fullfile(salida,[pref,'.csv']));

        % Tres paneles para distinguir transitorio, regimen y mando.
        f = figure('Color','w','Name',pref);
        tiledlayout(3,1,'TileSpacing','compact');

        nexttile; hold on;
        stairs(t*1000,r*1000,'k--','LineWidth',1.2);
        stairs(t*1000,ideal.y*1000,'LineWidth',1.2);
        stairs(t*1000,cuant.y*1000,'LineWidth',1.1);
        xlim([0 760]); grid on;
        title(sprintf('%s / %s — respuesta completa', ...
            strrep(disenos{i},'_',' '),plantas{j}));
        ylabel('Salida [mV]');
        legend('Referencia','DAC ideal','DAC cuantizado','Location','best');

        nexttile; hold on;
        stairs(t*1000,ideal.y*1000,'LineWidth',1.2);
        stairs(t*1000,cuant.y*1000,'LineWidth',1.1);
        yline(50,'k--','Referencia');
        yline(51,':','Limite +2%');
        yline(49,':','Limite -2%');
        xlim([540 670]); ylim([45 55]); grid on;
        ylabel('Salida [mV]');
        title('Detalle de regimen permanente (550 a 660 ms)');

        nexttile; hold on;
        stairs(t*1000,ideal.u*1000,'LineWidth',1.2);
        stairs(t*1000,cuant.u*1000,'LineWidth',1.1);
        xlim([540 670]); grid on;
        ylabel('Mando [mV]'); xlabel('Tiempo [ms]');
        legend('DAC ideal','DAC cuantizado','Location','best');

        exportgraphics(f,fullfile(figuras,[pref,'_DAC.png']), ...
            'Resolution',220);
    end
end

disp(' ');
disp('=== RESUMEN DE LAS OCHO SIMULACIONES ===');
disp(resumen);
% Control de reproduccion del rediseno basado en el modelo identificado.
% Orden: lento/nominal, lento/identificada, rapido/nominal, rapido/identificada.
rms_referencia = [2.0880;3.0793;0.8575;1.5417];
rms_cuantizado = resumen.error_RMS_mV(resumen.DAC=="cuantizado");
desvio = max(abs(rms_cuantizado-rms_referencia));
fprintf('Comprobacion de reproducibilidad: desviacion RMS maxima = %.5f mV\n',desvio);
assert(desvio<0.02, ...
   'El DAC cuantizado no reproduce el baseline identificado: revisar parametros.');
writetable(resumen,fullfile(salida,'resumen_ideal_vs_cuantizado.csv'));
fprintf('\nResultados de simulacion guardados en:\n%s\n',salida);
fprintf('Simulacion finalizada; los resultados experimentales se procesan por separado.\n');

%% Funciones locales (modelo matematico; no hardware)
function S = simular_caso(Ap,Bp,A,B,C,L,Kx,Ki,r,lim,esCuant)
    N = numel(r);
    x = zeros(2,1); z = zeros(2,1); xi = 0;
    S.y = zeros(N,1); S.u = zeros(N,1);
    S.u_solicitado = zeros(N,1); S.xi = zeros(N,1);
    S.saturado = false(N,1);

    for k=1:N
        y = C*x;
        innov = y - C*z;
        xhat = z + L*innov;  % Observador ACTUAL
        us = -Kx*xhat - Ki*xi;
        u_pre = min(lim.u_max,max(lim.u_min,us)); % MISMOS LIMITES

        if esCuant
            if u_pre>=0
                codigo = min(lim.cod_pos,max(0,round(u_pre/lim.q_pos)));
                ua = codigo*lim.q_pos;
            else
                codigo = min(lim.cod_neg,max(0,round(-u_pre/lim.q_neg)));
                ua = -codigo*lim.q_neg;
            end
        else
            ua = u_pre; % DAC ideal: continuo, aun limitado.
        end

        e = r(k)-y;
        bloqueado = lim.antiwindup && ...
          ((us>lim.u_max && e>0) || (us<lim.u_min && e<0));
        if ~bloqueado
            xi_proximo = xi + e;
        else
            xi_proximo = xi;
        end

        S.y(k)=y; S.u(k)=ua; S.u_solicitado(k)=us;
        S.xi(k)=xi; S.saturado(k)=(us~=u_pre);

        % El modelo y el observador usan la tension realmente aplicada.
        x = Ap*x + Bp*ua;
        z = A*xhat + B*ua;
        xi = xi_proximo;
        assert(all(isfinite([x;z;xi;ua])), ...
            'Simulacion interrumpida: NaN o Inf.');
    end
end

function m = calcular_residual(S,r,idx,esCuant)
    error = r(idx)-S.y(idx);
    salida = S.y(idx);
    m.error_medio_mV = 1000*mean(error);
    m.rms_mV = 1000*sqrt(mean(error.^2));
    m.error_max_mV = 1000*max(abs(error));
    m.ypico_pico_mV = 1000*(max(salida)-min(salida));
    m.banda_pct = 100*mean(abs(error)<=0.001); % ±1 mV para 50 mV
    if esCuant
        m.niveles = numel(unique(S.u(idx)));
    else
        m.niveles = NaN; % DAC continuo; no tiene niveles discretos.
    end
end
