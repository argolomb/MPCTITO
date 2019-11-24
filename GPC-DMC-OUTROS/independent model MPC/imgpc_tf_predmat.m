%%%%  Generate independent model prediction equations (using recursions) from %%%%  MFD model   A y(k+1) = B u(k)%%%%%%%%  yfut = H *Dufut + P*Dupast + Q*ypast+L*offset%%%%%%%%  [H,P,Q,L] = imgpc_tf_predmat(A,B,ny)%%%%%%%%  ny is the output horizon%%  %% Author: J.A. Rossiter  (email: J.A.Rossiter@shef.ac.uk)function [H,P,Q,L] = imgpc_tf_predmat(A,B,ny);%%%%% Add integral to modelsizey = size(A,1);D = [eye(sizey),-eye(sizey)];AD = convmat(A,D);nA = size(AD,2);nB = size(B,2);%%%%% offset termL=eye(sizey);for k=1:ny-1;    L=[L;eye(sizey)];end%%%%  Initialise recursion data%%%% nominal model    y =  Bo ut + B2 Dupast  + A2 ypastA2 = -AD(1:sizey,sizey+1:nA);B2 = B(1:sizey,sizey+1:nB);Bo = B(1:sizey,1:sizey);nB2 = nB-sizey;nA2 = nA-sizey;P1=Bo;P2=B2;P3=A2;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Loop updating models using recursionfor i=2:ny;      vecold = (i-2)*sizey+1:(i-1)*sizey;   vecnew = (i-1)*sizey+1:i*sizey;   Phi = P3(vecold,1:sizey);    vecufut = 1:sizey*i;   vecufut2 = 1:sizey*(i-1);   P1(vecnew,vecufut) = [(P2(vecold,1:sizey)+Phi*Bo),P1(vecold,vecufut2)];      vecupast = sizey+1:nB2;   vecypast = sizey+1:nA2;      temp = [P2(vecold,vecupast),zeros(sizey,sizey)] + Phi*B2;   P2(vecnew,1:nB2) = temp;   P3(vecnew,1:nA2) = [P3(vecold,vecypast),zeros(sizey,sizey)] + Phi*A2;endH=P1; P=P2; Q=P3;%    function [C]=convmat(A,B)%    to convolve two matrix polynomials stored as [a(0),a(1),a(2)...]%   routine works by forming a convolution matrix [a(0),0   ,0   ,...%                                                a(1),a(0),0   ,...%                                                a(2),a(1),a(0),...]function [C]=convmat(A,B)[na,ma]=size(A);[nb,mb]=size(B);orda=ma/nb;ordb=mb/na;mat = [];for i=1:orda;    s = zeros(nb,((orda-1)*na+mb));    s(:,(i-1)*na+1:(i-1)*na+mb) = B;    mat = [mat;s];end;C=A*mat;