clear all
clc
syms h1 h2 u1 u2 Q A1 A2 H c13 c23 c7 qout1 qout2 d1 d2
%Defini��o das entradas
u=[u1;u2];
%Defini��o dos estados
x=[h1;h2];        
%Equa��es diferenciais
%------------------------------------------
% Se h2 =< 0.405
qout1 = u1*sqrt(h1)/sqrt(c13*u1^2 + c23);
qout2 = c7*u2*sqrt(h2);

dh1dt = (Q - qout1)/A1;
dh2dt = (qout1 - qout2)/A2;  
sys1 = [dh1dt dh2dt];
%------------------------------------------
% Se h2 > 0.405
qout1 = u1*sqrt(h1-h2+H)/sqrt(c13*u1^2 + c23);
qout2 = c7*u2*sqrt(h2);

dh1dt = (Q - qout1)/A1;
dh2dt = (qout1 - qout2)/A2;  
sys2 = [dh1dt dh2dt];
%------------------------------------------
%% Lineariza��o do Sistema - Matrizes com Simb�lico
Am1=jacobian(sys1,x);
Bm1=jacobian(sys1,u);
Cm1= eye(2);
Dm1=zeros(size(Bm1));
%% -------------------------------------------
Am2=jacobian(sys2,x);
Bm2=jacobian(sys2,u);
Cm2= eye(2);
Dm2=zeros(size(Bm2));

%% Par�metros do modelo
d1 = 0.13 ;       % Di�metro do Tanque 1
d2 = 0.06 ;       % Di�metro do Tanque 2

A1 = (pi/4)*d1^4;  % m^2 tank1 and tank2 area
A2 = (pi/4)*d2^4;  % m^2 tank1 and tank2 area

h1 = 0.405 ;      % m - Conection heigth
h2 = 0.405 ;      % m - Conection heigth
H = 0.405  ;      % m - Conection heigth

Q = 150*0.001/3600;          % Vaz�o de entrada [L/h]

c13 = 3.4275e7  ;  % s2/m5 - valve constant
c23 = 0.9128e7  ;  % s2/m5 - valve constant
c7  = 2.7154e-4 ;  % s2/m5 - valve constant

u1 = 0.2142 ;
u2 = 0.2411 ;

%Matrizes com valores num�ricos

Am1=double(subs(Am1));
Bm1=double(subs(Bm1));
%-------------------------------------------
Am2=double(subs(Am2));
Bm2=double(subs(Bm2));

% State Space
Ts=0.1;
Dinamica_1 = ss(Am1,Bm1,Cm1,Dm1);
Dinamica_1d = c2d(Dinamica_1,Ts,'zoh');
%-------------------------------------------
Dinamica_2 = ss(Am2,Bm2,Cm2,Dm2);
Dinamica_2d = c2d(Dinamica_2,Ts,'zoh');

%MPC
nx = length(Dinamica_1d.A);    % Numero de estados
ny = size(Dinamica_1d.C,1);    % Numero de variaveis controladas
nu = size(Dinamica_1d.B,2);    % Numero de variaveis manipuladas

sysi1.A = [Dinamica_1d.A, Dinamica_1d.B; zeros(nu,nx), eye(nu)];
sysi1.B = [Dinamica_1d.B; eye(nu)];
sysi1.C = [Dinamica_1d.C, zeros(ny,nu)];
%--------------------------
sysi2.A = [Dinamica_2d.A, Dinamica_2d.B; zeros(nu,nx), eye(nu)];
sysi2.B = [Dinamica_2d.B; eye(nu)]; 
sysi2.C = [Dinamica_2d.C, zeros(ny,nu)];

nx = length(sysi1.A); % atualiza��o do numero de estados

%% Parametros do controlador

Hp = 10; Hc = 3;  

q = [1,1]; r = [0.1,0.1];
ysp = [0; 0];

xk = zeros(nx,1); uk_1 = [0.2142;0.2411];

%% Implementa��o MPC

nsim = 1000       ;    % N�mero de Simula��es
du0  = zeros(nu*Hc,1); % Estimativa inicial para o otimizador

% Modelo da planta
unc = 1 ; % incerteza de modelagem (unc = 1, modelo � perfeito)

planta.A = sysi1.A;
planta.B = sysi1.B*unc;
planta.C = sysi1.C*unc;

% Filtro de Kalman
W = 0.00001*eye(nx); % Variancia do modelo
V = 0.00001*eye(ny); % Variancia da medicao
xmk = xk; % Estado do modelo (valor inicial)
P = W;    % Variancia do erro (valor inicial)

% Restri��es

dumax = ([0.1;0.1;0.1;0.1;0.1;0.1]/10)*3; dumin = -dumax;
umax = [0.6;0.6];  umin = [0.01; 0.01];
Mtil=[];
Itil=[];
auxM=zeros(nu,Hc*nu);
for in=1:Hc
    auxM=[eye(nu) auxM(:,1:(Hc-1)*nu)];
    Mtil=[Mtil;auxM];
    Itil=[Itil;eye(nu)];
end
Ain = [Mtil;-Mtil];
Bin = @(uk_1) [repmat(umax,Hc,1) - Itil*uk_1; Itil*uk_1 - repmat(umin,Hc,1)];
Aeq = [];
beq = [];
umax = [0.95;0.95];  umin = [0.01; 0.01];

%CONTADOR
dinamica1=0;dinamica2=0;

% Implementa��o
% h0 = [ 0 0] ;
h0 = [ 0.405 0.405] ;
for k = 1:nsim
    if k== 1
        ysp(1) = 0.65;
        ysp(2) = 0.28;
    elseif k == 200
        ysp(1) = 0.35;
    elseif k == 300
        ysp(2) = 0.678;
    elseif k == 400
        Q = 30*0.001/3600;
    end
Q_ra(k) = Q;
    
    if  h0(2) >= 0.405
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
    % MPC DINAMICA 1
    du = fmincon(@(du) fob_MPC(xmk,du,Hp,Hc,sysi1,ysp-[0.405;0.405],q,r),du0,Ain,Bin(uk_1),Aeq,beq,dumin,dumax);
    
    uk(:,k) = uk_1 + du(1:nu);
    uk_1 = uk(:,k); 
    
    % Planta                                 
    tspan = ([0 0.1] + (k-1)*[0.1 0.1])';

    [t,ys] = ode45(@(t,h)twotanksODE(t,h,uk_1,Q),tspan, h0) ;
    
    yk(:,k) = ys(end,:) + mvnrnd(zeros(ny,1),V);     

    h0 = yk(:,k) ;
    yk_kalman= yk -[0.405;0.405];
    % Filtro de kalman - predicao
    xmk = (sysi1.A)*xmk + sysi1.B*(du(1:nu));
    ymk(:,k) = sysi1.C*xmk;
    P = sysi1.A*P*sysi1.A' + W;
    % Filtro de Kalman - correcao
    K = P*sysi1.C'/(sysi1.C*P*sysi1.C' + V);
    xmk = xmk + K*(yk_kalman(:,k) - ymk(:,k));
    P = (eye(nx) - K*sysi1.C)*P;
    
    dinamica1=dinamica1+1;
    else
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
    % MPC Din�mica 2
    du = fmincon(@(du) fob_MPC(xmk,du,Hp,Hc,sysi2,ysp-[0.405;0.405],q,r),du0,Ain,Bin(uk_1),Aeq,beq,dumin,dumax);
    
    uk(:,k) = uk_1 + du(1:nu);
    uk_1 = uk(:,k); % valor de u em k_1


    % Planta                                 
    tspan = ([0 0.1] + (k-1)*[0.1 0.1])';

    [t,ys] = ode45(@(t,h)twotanksODE(t,h,uk_1,Q),tspan, h0);
    
    yk(:,k) = ys(end,:) + mvnrnd(zeros(ny,1),V);     

    h0 = yk(:,k) ;
    yk_kalman= yk -[0.405;0.405];
    % Filtro de kalman - predicao
    xmk = (sysi2.A)*xmk + sysi2.B*(du(1:nu));
    ymk(:,k) = sysi2.C*xmk;
    P = sysi2.A*P*sysi2.A' + W;
    % Filtro de Kalman - correcao
    K = P*sysi2.C'/(sysi2.C*P*sysi2.C' + V);
    xmk = xmk + K*(yk_kalman(:,k) - ymk(:,k));
    P = (eye(nx) - K*sysi2.C)*P;
    
    dinamica2=dinamica2+1;
    end
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Atualizacao de variaveis
    du0 = [du(nu+1:end);zeros(nu,1)]; % Estimativa inicial do otmizador

    sp(:,k) = ysp;
    k
end
%% Graficos

figure(1)

    subplot(3,1,1)
    plot(1:nsim,sp(1,:),'--r',1:nsim,yk(1,:))%,'.k',1:nsim,ymk(1,:)+[0.405;0.405])
    ylabel(['y_' num2str(1)])
    subplot(3,1,2)
    plot(1:nsim,sp(2,:),'--r',1:nsim,yk(2,:))%,'.k',1:nsim,ymk(2,:)+[0.405;0.405])
    ylabel(['y_' num2str(2)])
    subplot(3,1,3)
    plot(1:nsim,1000*3600*Q_ra)
    grid on

xlabel('k')
legend('Setpoint','Medicao','Modelo','Location','Best')
figure(2)
for iu = 1:nu
    subplot(nu,1,iu)
    stairs(1:nsim,uk(iu,:),'k')
    ylabel(['u_' num2str(iu)])
    grid on
end
xlabel('k')