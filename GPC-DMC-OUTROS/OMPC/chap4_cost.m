%%%  Determine total OMPC cost, including bits not depending on d.o.f.
%%%  nc is the control horizon.
%%%
%%% Assume model x(k+1)=Ax(k)+Bu(k), y= Cx+Du
%%%
%%%  Overall cost
%%%% J = x SX x + 2*x SXC c + c SC c
%%
%%%%% Control law and predictions based on Q, R
%%%%% Regulation case only based on LQR feedback for
%%%%%     J =sum x'Qx+u'Ru
%%%%
%%%%   [SX,SC,SXC,Spsi]=chap4_cost(A,B,C,D,Q,R,nc)
%%%%
%%%% Code by JA Rossiter (2014)

function [SX,SC,SXC,Spsi]=chap4_cost(A,B,C,D,Q,R,nc)

nx = size(A,1);
nxc=nx*nc;
nu=size(B,2);
nuc=nu*nc;

%%%%%  Feedback loop is of the form  u = -Kx+c
%%%%%  Find LQR optimal feedback
[K] = dlqr(A,B,Q,R);
Phi=A-B*K;

%%% Build autonomous model
ID=diag(ones(1,(nc-1)*nu));
ID=[zeros((nc-1)*nu,nu),ID];
ID=[ID;zeros(nu,nuc)];
Psi=[A-B*K,[B,zeros(nx,nuc-nu)];zeros(nuc,nx),ID];
Gamma=[eye(nx),zeros(nx,nuc)];
Kz = [K,-eye(nu),zeros(nu,nuc-nu)];

%%%% Solve for the cost parameters using lyapunov
W=Psi'*Gamma'*Q*Gamma*Psi+Kz'*R*Kz;
Spsi=dlyap(Psi',W);

%%% Split cost into parts
%%%% J = [x,c] Spsi [x;c]
%%%% J = x SX x + 2*x SXC c + c SC c
SX=Spsi(1:nx,1:nx);
SXC=Spsi(1:nx,nx+1:end);
SC=Spsi(nx+1:end,nx+1:end);




