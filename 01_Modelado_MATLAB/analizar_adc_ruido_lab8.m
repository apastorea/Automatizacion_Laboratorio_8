%% LABORATORIO 8 — CUANTIZACION ADC Y RUIDO DE MEDICION
% Analisis SOLO EN MATLAB. No programa ni comunica con el PSoC.
%
% Compara cuatro situaciones del mismo controlador y DAC:
%   1) ADC ideal, sin ruido (DAC cuantizado: referencia conocida).
%   2) ADC cuantizado, sin ruido (hipotesis LSB ADC).
%   3) ADC cuantizado + ruido equivalente de 1 mV RMS.
%   4) ADC cuantizado + ruido equivalente de 3 mV RMS.
%
% Mantiene Ts=2 ms, dos polos integrales, E2 actual y dos modelos de la
% misma planta fisica en cascada.
% Controlador y estimador se disenan directamente con el modelo identificado.
% El LSB del ADC es una estimacion usada solo en el estudio de sensibilidad.
% Las escalas del DAC coinciden con las constantes utilizadas por el firmware;
% esta comprobacion no equivale a una calibracion multipunto del convertidor.
% El ruido es hipotetico, blanco, gaussiano en unidades de salida de planta.
% Metrica principal: error de la SALIDA FISICA simulada, NO de la medida.
%
clear; clc; close all;
fprintf('\n=== LABORATORIO 8 | ADC + DAC + RUIDO (SIMULACION) ===\n');

%% 1. Configuracion y reproducibilidad
Ts=0.002;
N=600;
t=(0:N-1)'*Ts;
r=zeros(N,1);
r(33:333)=0.500;                 % Referencia 500 mV desde 64 a 664 ms
regimen=(t>=0.550 & t<=0.660 & r>0);
p_ctrl=[0.80+0.25i, 0.80-0.25i];
p_integral=[0.60, 0.30];
p_obs=[0.20+0.10i, 0.20-0.10i];
nombres={'integral_lento','integral_rapido'};
modelos={'nominal','identificado'};
escenarios={'DAC_solo','ADC_sin_ruido','ADC_ruido_1mV','ADC_ruido_3mV'};
niveles_ruido=[0,0,1,3];         % mV RMS hipoteticos
usar_adc=[false,true,true,true];
repeticiones_ruido=20;
semilla=20261124;

% Parametros usados por el firmware y comprobados en el punto de trabajo.
lim.u_min=-1.000; lim.u_max=+1.000;
lim.q_pos=0.015370448; lim.q_neg=0.010560423;
lim.cod_pos=65; lim.cod_neg=95;
lim.antiwindup=true;
adc.volt_por_volt_planta=0.210251951;
adc.paso_ADC_mV=1.14;           % APROXIMADO, NO calibracion nueva
adc.paso_y_V=adc.paso_ADC_mV*1e-3/adc.volt_por_volt_planta;
adc.fase_V=0;                    % error de alineacion no estudiado aqui
fprintf('ADC asumido: %.3f mV/cuenta en ADC; %.3f mV/cuenta referido a planta\n', ...
    adc.paso_ADC_mV,1000*adc.paso_y_V);
fprintf('Ruido simulado (RMS salida): 0, 1, 3 mV. Monte Carlo=%d\n',repeticiones_ruido);

% Reutilizar la MISMA secuencia de ruido normalizada para ambos modelos
% y controladores, de manera que la comparacion sea justa.
rng(semilla,'twister');
ruido_estandar=randn(N,repeticiones_ruido);

%% 2. Planta nominal y modelo identificado (orden x=[x1;x2])
R5=150e3; R6=47e3; R1=15e3; R2=47e3;
C1=100e-9; C3=100e-9;
F=[-1/(R5*C1) 0;-1/(R2*C3) -1/(R1*C3)];
G=[-1/(R6*C1);0];
C=[0 1];D=0;
[A,B,~,~]=ssdata(c2d(ss(F,G,C,D),Ts,'zoh'));
Kid=1.002941; tau1=0.00906915; tau2=0.000774399;
gananciaEtapa1=R5/R6;
gananciaEtapa2=Kid/gananciaEtapa1;
Fid=[-1/tau1 0;-gananciaEtapa2/tau2 -1/tau2];
Gid=[-gananciaEtapa1/tau1;0];
[Aid,Bid,~,~]=ssdata(c2d(ss(Fid,Gid,C,D),Ts,'zoh'));
assert(rank(ctrb(Aid,Bid))==2 && rank(obsv(Aid,C))==2, ...
       'Revisar controlabilidad/observabilidad identificada.');
assert(rank(obsv(Aid,C*Aid))==2,'Estimador actual no observable.');
Ad=Aid;Bd=Bid;
L=place(Ad',(C*Ad)',p_obs).';

Aa=[Ad zeros(2,1);-C 1];
Ba=[Bd;0];
assert(rank(ctrb(Aa,Ba))==3,'Sistema aumentado no controlable.');

%% 3. Preparar directorios, tablas y casos
carpeta=fileparts(mfilename('fullpath'));
salida=fullfile(carpeta,'..','05_Resultados','Sensibilidad_ADC');
figdir=fullfile(salida,'figuras');
if ~isfolder(salida),mkdir(salida);end
if ~isfolder(figdir),mkdir(figdir);end
detalle=table();
resumen=table();
curvas=cell(2,2,4);             % primer ensayo de cada escenario

for i=1:2
    K=place(Aa,Ba,[p_ctrl p_integral(i)]);
    Kx=K(1:2);Ki=K(3);
    fprintf('\nDISENO %s (z_i=%.2f), Kx=[%.6f %.6f], Ki=%.6f\n', ...
        nombres{i},p_integral(i),Kx(1),Kx(2),Ki);

    for j=1:2
        if j==1
            Ap=A;Bp=B;
        else
            Ap=Aid;Bp=Bid;
        end
        for e=1:numel(escenarios)
            rep=1;
            if niveles_ruido(e)>0
                rep=repeticiones_ruido;
            end

            for n=1:rep
                if niveles_ruido(e)==0
                    ruido=zeros(N,1);
                else
                    ruido=ruido_estandar(:,n)*(niveles_ruido(e)*1e-3);
                end

                S=simular_adc(Ap,Bp,Ad,Bd,C,L,Kx,Ki,r,lim, ...
                               adc,usar_adc(e),ruido);
                m=calcular_metricas(S,r,regimen);
                nuevo=table(string(nombres{i}),string(modelos{j}), ...
                     string(escenarios{e}),n, ...
                     m.error_RMS_mV,m.error_max_mV,m.error_medio_mV, ...
                     m.salida_pp_mV,m.banda_pct,m.mando_max_mV, ...
                     m.saturaciones, ...
                     'VariableNames',{'diseno','modelo','escenario','repeticion', ...
                     'error_RMS_mV','error_max_mV','error_medio_mV', ...
                     'salida_pp_mV','muestras_banda_2pct','mando_max_abs_mV', ...
                     'saturaciones'});
                detalle=[detalle;nuevo]; %#ok<AGROW>
                if n==1
                    curvas{i,j,e}=S;
                end
            end

            sub=detalle(detalle.diseno==string(nombres{i}) & ...
                detalle.modelo==string(modelos{j}) & ...
                detalle.escenario==string(escenarios{e}),:);
            fila=table(string(nombres{i}),string(modelos{j}), ...
                string(escenarios{e}),niveles_ruido(e),rep, ...
                mean(sub.error_RMS_mV),max(sub.error_RMS_mV), ...
                mean(sub.error_max_mV),mean(sub.salida_pp_mV), ...
                mean(sub.muestras_banda_2pct),max(sub.saturaciones), ...
                'VariableNames',{'diseno','modelo','escenario', ...
                'ruido_RMS_hipotetico_mV','repeticiones', ...
                'error_RMS_prom_mV','error_RMS_peor_mV', ...
                'error_max_prom_mV','salida_pp_prom_mV', ...
                'banda_2pct_prom','max_saturaciones'});
            resumen=[resumen;fila]; %#ok<AGROW>
        end
    end
end

%% 4. Comprobacion interna del caso base
% Se repite el DAC cuantizado sin cuantizacion ADC y se verifica que la
% referencia seleccionada no active la saturacion en ninguno de los casos.
for i=1:2
    for j=1:2
        idx=resumen.diseno==string(nombres{i}) & ...
            resumen.modelo==string(modelos{j}) & ...
            resumen.escenario=="DAC_solo";
        obtenido=resumen.error_RMS_prom_mV(idx);
        assert(isscalar(obtenido),'Error en el indice de regresion.');
        fprintf('CASO BASE %s/%s: RMS %.4f mV\n', ...
            nombres{i},modelos{j},obtenido);
        assert(resumen.max_saturaciones(idx)==0, ...
          'La referencia de 500 mV produjo saturacion en el caso base.');
    end
end

%% 5. Informes reproducibles
writetable(resumen,fullfile(salida,'resumen_sensibilidad_ADC_lab8.csv'));
writetable(detalle,fullfile(salida,'repeticiones_sensibilidad_ADC_lab8.csv'));
disp(' ');
disp('=== RESUMEN SENSIBILIDAD ADC / RUIDO ===');
disp(resumen);

for j=1:2
    % Comparar los dos integradores con ruido hipotetico de 3 mV RMS.
    f=figure('Color','w','Name',['Sensibilidad ADC - ' modelos{j}]);
    tiledlayout(2,1,'TileSpacing','compact');
    nexttile;hold on;
    stairs(t*1000,r*1000,'k--','LineWidth',1.1);
    for i=1:2
        S=curvas{i,j,4}; % DAC+ADC y 3 mV RMS; realizacion 1
        stairs(t*1000,S.y*1000,'LineWidth',1.1);
    end
    grid on;xlim([0 760]);
    ylabel('Salida fisica simulada [mV]');
    title(['ADC cuantizado + ruido 3 mV RMS - modelo ' modelos{j}]);
    legend('Referencia','Integral lento','Integral rapido','Location','best');
    nexttile;hold on;
    stairs(t*1000,curvas{1,j,4}.y*1000,'LineWidth',1.1);
    stairs(t*1000,curvas{2,j,4}.y*1000,'LineWidth',1.1);
    yline(500,'k--','Referencia');
    yline(490,'k:','-2%');
    yline(510,'k:','+2%');
    grid on;xlim([540 660]);ylim([470 530]);
    xlabel('Tiempo [ms]');ylabel('Salida fisica [mV]');
    exportgraphics(f,fullfile(figdir,['ruido_3mV_' modelos{j} '.png']), ...
        'Resolution',220);

    % Comparacion de RMS promedio para los cuatro escenarios.
    valores=zeros(4,2);
    for e=1:4
        for i=1:2
            idx=resumen.diseno==string(nombres{i}) & ...
                resumen.modelo==string(modelos{j}) & ...
                resumen.escenario==string(escenarios{e});
            valores(e,i)=resumen.error_RMS_prom_mV(idx);
        end
    end
    f2=figure('Color','w','Name',['RMS por escenario - ' modelos{j}]);
    bar(categorical(escenarios,escenarios),valores);
    grid on;
    ylabel('Error RMS fisico [mV]');
    title(['Sensibilidad de error RMS - ' modelos{j}]);
    legend('Integral lento','Integral rapido','Location','best');
    exportgraphics(f2,fullfile(figdir,['comparacion_RMS_' modelos{j} '.png']), ...
        'Resolution',220);
end

fprintf('\nArchivos guardados en: %s\n',salida);
fprintf(['IMPORTANTE: ADC y ruido son HIPOTESIS; aun no hay medidas ', ...
         'fisicas de esta practica.\n']);
fprintf('NO programar el PSoC con esta simulacion como unica validacion.\n');

%% Funciones locales
function S=simular_adc(Ap,Bp,A,B,C,L,Kx,Ki,r,lim,adc,cuantizaADC,ruido)
    N=numel(r);
    x=zeros(2,1);z=zeros(2,1);xi=0;
    S.y=zeros(N,1);S.medida=zeros(N,1);
    S.u=zeros(N,1);S.saturado=false(N,1);
    for k=1:N
        y=C*x;
        ym=y+ruido(k);
        if cuantizaADC
            ym=adc.paso_y_V*round((ym+adc.fase_V)/adc.paso_y_V) ...
                   -adc.fase_V;
        end
        xhat=z+L*(ym-C*z);
        us=-Kx*xhat-Ki*xi;
        upre=min(lim.u_max,max(lim.u_min,us));
        if upre>=0
            codigo=min(lim.cod_pos,max(0,round(upre/lim.q_pos)));
            ua=codigo*lim.q_pos;
        else
            codigo=min(lim.cod_neg,max(0,round(-upre/lim.q_neg)));
            ua=-codigo*lim.q_neg;
        end

        e=r(k)-ym; % El firmware recibe la MEDICION, no la salida ideal.
        bloqueado=lim.antiwindup && ...
          ((us>lim.u_max && e>0)||(us<lim.u_min && e<0));
        if ~bloqueado
            xi=xi+e;
        end

        S.y(k)=y; S.medida(k)=ym; S.u(k)=ua;
        S.saturado(k)=(us~=upre);
        x=Ap*x+Bp*ua;
        z=A*xhat+B*ua;
        assert(all(isfinite([x;z;xi;ua;ym])), ...
          'Fallo numerico: NaN o Inf en la simulacion.');
    end
end

function m=calcular_metricas(S,r,idx)
    y=S.y(idx);
    e=r(idx)-y;
    m.error_RMS_mV=1000*sqrt(mean(e.^2));
    m.error_max_mV=1000*max(abs(e));
    m.error_medio_mV=1000*mean(e);
    m.salida_pp_mV=1000*(max(y)-min(y));
    m.banda_pct=100*mean(abs(e)<=0.010);
    m.mando_max_mV=1000*max(abs(S.u));
    m.saturaciones=nnz(S.saturado);
end
