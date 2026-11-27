% LABORATORIO 8 - DISENO DEL CONTROL INTEGRAL EN ESPACIO DE ESTADOS
% Objetivo:
%   calcular los controladores lento y rapido, verificar estabilidad y
%   simular el lazo con observador actual, saturacion y DAC cuantizado.
% Requiere Control System Toolbox y no establece comunicacion con hardware.
% Convenciones:
%   x=[x1;x2], y=[0 1]*x; tensiones en V y tiempo en s.
%   xi[k+1]=xi[k]+r[k]-y[k]
%   u[k]=-Kx*xhat_actual[k]-Ki*xi[k]
% La integral se actualiza despues de calcular u[k]. La condicion de banco
% vigente utiliza 500 mV; la comprobacion abierta produjo codigo positivo 33.
clear; clc; close all;
fprintf('\nLABORATORIO 8 — PREVALIDACION MATEMATICA. NO ES UN ENSAYO FISICO.\n');

%% 1. Configuracion inicial
Ts=0.002;                  % 2 ms; 500 muestras/s
N=600;                     % 1.2 s de simulacion
t=(0:N-1)'*Ts;
r=zeros(N,1);
r(33:333)=0.500;           % Pulso 500 mV desde t=64 hasta t=664 ms
polos_dominantes=[0.80+0.25i, 0.80-0.25i];
polos_integrales=[0.60 0.30];          % Lento / rapido
polos_observador=[0.20+0.10i, 0.20-0.10i]; % E2 actual

lim.u_min=-1.000;          % limite previo a cuantizacion (V)
lim.u_max=+1.000;
lim.q_pos=0.015370448;     % V/codigo, rama positiva del modelo
lim.q_neg=0.010560423;
lim.cod_pos=65;            % 999.079 mV
lim.cod_neg=95;            % -1003.240 mV
lim.antiwindup=true;

%% 2. Modelo continuo de la planta nominal: montaje existente
R5=150e3; R6=47e3; R1=15e3; R2=47e3;
C1=100e-9; C3=100e-9;
F=[-1/(R5*C1),0; -1/(R2*C3),-1/(R1*C3)];
G=[-1/(R6*C1);0];
C=[0 1]; D=0;

[A,B,~,~]=ssdata(c2d(ss(F,G,C,D),Ts,'zoh'));
assert(rank(ctrb(A,B))==2,'La planta no es controlable.');
assert(rank(obsv(A,C))==2,'La planta no es observable.');
assert(rank(obsv(A,C*A))==2,'No es observable para el estimador actual.');

%% 3. Planta identificada utilizada para la sintesis
% La transferencia previamente obtenida se conserva SIN reajustarla.
% Ganancia K=1.002941; tau1=9.06915 ms; tau2=0.774399 ms.
% Realizacion de estados compatible con los estados nominales.
Kid=1.002941; tau1=0.00906915; tau2=0.000774399;
gananciaEtapa1=R5/R6;
gananciaEtapa2=Kid/gananciaEtapa1;
Fid=[-1/tau1,0; -gananciaEtapa2/tau2,-1/tau2];
Gid=[-gananciaEtapa1/tau1;0];
[Aid,Bid,~,~]=ssdata(c2d(ss(Fid,Gid,C,D),Ts,'zoh'));
assert(rank(ctrb(Aid,Bid))==2,'Planta identificada no controlable.');

%% 4. Modelo identificado adoptado para el diseno
% La sintesis utiliza la representacion que mejor reproduce la planta fisica.
% El modelo nominal de esa misma planta queda como caso de incertidumbre.
Ad=Aid; Bd=Bid;

%% 5. Estimador ACTUAL E2, disenado con el modelo identificado
Lactual=place(Ad',(C*Ad)',polos_observador).';
pobs=eig((eye(2)-Lactual*C)*Ad);
assert(max(abs(pobs))<1,'El observador es inestable.');

%% 6. Modelo identificado ampliado y colocacion de tres polos
% x_aug = [x1; x2; xi], con xi[k+1] = xi[k] + r[k] - C*x[k].
Aaug=[Ad zeros(2,1);-C 1];
Baug=[Bd;0];
Braug=[0;0;1];
assert(rank(ctrb(Aaug,Baug))==3, ...
       'El sistema aumentado NO es controlable: revisar modelo.');

fprintf('\nTs = %.3f ms; fs=%.1f Hz\n',Ts*1000,1/Ts);
disp('A nominal:');disp(A);
disp('B nominal:');disp(B);
disp('C:');disp(C);
disp('MODELO DE DISENO: identificado');
disp('A identificada:');disp(Ad);
disp('B identificada:');disp(Bd);
disp('L_actual E2 identificado:');disp(Lactual);
fprintf('Polos del observador: ');disp(pobs.');

resultados=table();
curvas=cell(2,2);
nombres_diseno={'integral_lento','integral_rapido'};
nombres_modelo={'nominal','identificado'};

carpeta=fileparts(mfilename('fullpath'));
salida=fullfile(carpeta,'..','05_Resultados');
figdir=fullfile(salida,'figuras');
if ~isfolder(salida),mkdir(salida);end
if ~isfolder(figdir),mkdir(figdir);end

for i=1:2
    pi=polos_integrales(i);
    Kaug=place(Aaug,Baug,[polos_dominantes pi]);
    Kx=Kaug(1,1:2); Ki=Kaug(1,3);
    polos_calc=eig(Aaug-Baug*Kaug);
    assert(max(abs(polos_calc))<1,'Los polos del controlador no son estables.');

    fprintf('\nDISENO %d — polo integral %.2f\n',i,pi);
    fprintf('Kx=[%.9f %.9f], Ki=%.9f\n',Kx(1),Kx(2),Ki);
    fprintf('Polos de lazo cerrado: ');disp(polos_calc.');

    for j=1:2
        if j==1
            Ap=A;Bp=B;
        else
            Ap=Aid;Bp=Bid;
        end

        % Estabilidad LINEAL del conjunto planta real + observador nominal
        % + acumulador de error. Estado combinado [x; z; xi].
        E=eye(2)-Lactual*C;
        M=[Ap-Bp*Kx*Lactual*C, -Bp*Kx*E, -Bp*Ki; ...
           (Ad-Bd*Kx)*Lactual*C, (Ad-Bd*Kx)*E, -Bd*Ki; ...
           -C, zeros(1,2), 1];
        rho=max(abs(eig(M)));
        assert(rho<1,sprintf(['Caso %s / %s: ', ...
            'lazo aumentado lineal inestable (rho=%.5f).'], ...
            nombres_diseno{i},nombres_modelo{j},rho));

        S=simular_integral(Ap,Bp,Ad,Bd,C,Lactual,Kx,Ki,r,lim);
        m=metricas_integral(S,t,r,33,333,Ts);
        etiqueta=string(nombres_diseno{i});
        modelo=string(nombres_modelo{j});
        fila=table(etiqueta,modelo,pi,rho, ...
          m.tr_ms,m.ts_ms,m.Mp_pct,m.ess_mV, ...
          m.u_min_mV,m.u_max_mV,m.saturaciones, ...
          'VariableNames',{'diseno','modelo','polo_integral', ...
          'rho_lineal','tr_ms','ts_ms','Mp_pct','ess_mV', ...
          'u_min_mV','u_max_mV','saturaciones'});
        resultados=[resultados;fila]; %#ok<AGROW>
        curvas{i,j}=S;

        tablaMuestras=table(t,r,S.y,S.u,S.u_solicitada,S.xi, ...
         'VariableNames',{'t_s','r_V','y_V','u_aplicado_V', ...
                          'u_solicitado_V','xi_integral_V'});
        nombre=sprintf('%s_%s.csv',nombres_diseno{i},nombres_modelo{j});
        writetable(tablaMuestras,fullfile(salida,nombre));
    end
end

disp(' ');
disp('RESUMEN DE SIMULACION (DAC cuantizado, SIN ruido):');
disp(resultados);
writetable(resultados,fullfile(salida,'resumen_integral_lab8.csv'));

%% 6. Graficas reproducibles: comparar los dos diseños por modelo
for j=1:2
    fig=figure('Color','w','Name',['Integral / ' nombres_modelo{j}]);
    tiledlayout(2,1,'TileSpacing','compact');

    nexttile;hold on;
    stairs(t*1000,r*1000,'k--','LineWidth',1.3);
    stairs(t*1000,curvas{1,j}.y*1000,'LineWidth',1.2);
    stairs(t*1000,curvas{2,j}.y*1000,'LineWidth',1.2);
    xlim([0 1200]);grid on;
    title(['Respuesta temporal — modelo ' nombres_modelo{j}]);
    ylabel('Salida y [mV]');
    legend('Referencia','Integral lento (0.6)','Integral rapido (0.3)', ...
           'Location','best');

    nexttile;hold on;
    stairs(t*1000,curvas{1,j}.u*1000,'LineWidth',1.2);
    stairs(t*1000,curvas{2,j}.u*1000,'LineWidth',1.2);
    yline(lim.u_max*1000,'k--','Limite precuantizacion +');
    yline(lim.u_min*1000,'k--','Limite precuantizacion -');
    xlim([0 1200]);grid on;
    ylabel('Mando DAC nominal [mV]');xlabel('Tiempo [ms]');
    legend('Integral lento (0.6)','Integral rapido (0.3)', ...
           'Location','best');

    ruta=fullfile(figdir,['comparacion_integral_' nombres_modelo{j} '.png']);
    exportgraphics(fig,ruta,'Resolution',220);
end
fprintf('\nCSV y graficas de SIMULACION: %s\n',salida);
fprintf(['Modelo, ganancias y protecciones verificados. Los ensayos fisicos ', ...
         'se analizan con los scripts de 04_Ensayos.\n']);

%% FUNCIONES LOCALES — NO REALIZAN COMUNICACION CON HARDWARE
function S=simular_integral(Ap,Bp,A,B,C,L,Kx,Ki,r,lim)
    N=numel(r);
    x=zeros(2,1); z=zeros(2,1); xi=0;
    S.y=zeros(N,1);S.u=zeros(N,1);
    S.u_solicitada=zeros(N,1); S.xi=zeros(N,1);
    S.saturado=false(N,1);
    for k=1:N
        y=C*x;
        innov=y-C*z;
        xhat=z+L*innov;                % CORRECCION ACTUAL
        us=-Kx*xhat-Ki*xi;             % xi[k], NO xi[k+1]
        upre=min(lim.u_max,max(lim.u_min,us));
        if upre>=0
            n=min(lim.cod_pos,max(0,round(upre/lim.q_pos)));
            ua=n*lim.q_pos;
        else
            n=min(lim.cod_neg,max(0,round(-upre/lim.q_neg)));
            ua=-n*lim.q_neg;
        end
        sat=(us~=upre);
        e=r(k)-y;
        % Anti-windup condicional: congelar integrador si e agrava
        % la saturacion, pero permitir la recuperacion desde ella.
        bloqueado=lim.antiwindup && ...
                 ((us>lim.u_max && e>0) || (us<lim.u_min && e<0));
        if ~bloqueado
            xi_nuevo=xi+e;
        else
            xi_nuevo=xi;
        end

        S.y(k)=y; S.u(k)=ua; S.u_solicitada(k)=us;
        S.xi(k)=xi; S.saturado(k)=sat;

        x=Ap*x+Bp*ua;
        z=A*xhat+B*ua;                  % PREDICCION para siguiente k
        xi=xi_nuevo;
        assert(all(isfinite([x;z;xi;ua])),'NaN/Inf: parada del modelo.');
    end
end

function m=metricas_integral(S,t,r,i_on,i_fin,Ts)
    ref=r(i_on);

    y=S.y(i_on:i_fin);
    tx=t(i_on:i_fin);
    i10=find(y>=0.1*ref,1,'first');
    i90=find(y>=0.9*ref,1,'first');
    m.tr_ms=NaN;
    if ~isempty(i10) && ~isempty(i90) && i90>=i10
        m.tr_ms=(tx(i90)-tx(i10))*1000;
    end
    m.Mp_pct=max(0,100*(max(y)-ref)/ref);
    outside=find(abs(y-ref)>0.02*ref);
    m.ts_ms=NaN;
    if isempty(outside)
        m.ts_ms=0;
    elseif outside(end)<numel(y)
        m.ts_ms=outside(end)*Ts*1000;
    end
    i_ini=max(1,numel(y)-15);
    m.ess_mV=1000*mean(ref-y(i_ini:end));
    m.u_min_mV=1000*min(S.u);
    m.u_max_mV=1000*max(S.u);
    m.saturaciones=nnz(S.saturado);
end
