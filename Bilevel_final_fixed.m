function result=Bilevel_final_fixed(Emax_interval,Emin_interval,T,Peak_load,NPro,N,Pr,W)
tic;
%The methods are not fully demonstrated!
Price=[0.353900000000000;0.353900000000000;0.353900000000000;0.353900000000000;0.353900000000000;0.353900000000000;0.353900000000000;1.22830000000000;1.22830000000000;1.22830000000000;1.22830000000000;0.778500000000000;0.778500000000000;0.778500000000000;0.778500000000000;0.778500000000000;0.778500000000000;1.33770000000000;1.33770000000000;1.33770000000000;1.33770000000000;0.778500000000000;0.778500000000000;0.353900000000000];
T_shift=15;%Ĭ����ʼ����ʱ��Ϊ��30��ʱ���
if isempty(T_shift)
    T_shift=15;
end
M_t=zeros(T,T);
for i=1:T
    if i<=T-T_shift
        M_t(i,i+T_shift)=1;
    else
        M_t(i,i-T+T_shift)=1;
    end
end
Price=M_t*Price;

Emax=cumsum(Emax_interval*M_t');%Ӧ����ƽ�ƺ����
Emin=cumsum(Emin_interval*M_t');%��ʱ�οɵ��������½�ȷ��

%%����ģ��.
%���䵽��������
%EV����
NA=5;%��������������
%Price=repmat(Price,NA,1);

load Data;
Loadprofile=Pd*Peak_load;%��ʱ�εĸ��ɷֲ�
Loadprofile=Loadprofile*M_t';
Loadprofile=Loadprofile';
%�����ʩ����
Charger_pro=[0.1,0.1,0.2,0.3,0.3]*NPro;
%�綯��������
EV_pro=[0.1,0.1,0.2,0.3,0.3];%���������ڵ綯����������
Pmax_area=reshape(ones(T,1)*Pr*Charger_pro*N,NA*T,1);

Emax_area=reshape(Emax'*EV_pro,T*NA,1);
Emin_area=reshape(Emin'*EV_pro,T*NA,1);
Emax=Emax';
Emin=Emin';
EV_un=zeros(T,NA);
for i=1:NA
    temp=zeros(T,1);
    Emax_temp=[Emax_area((i-1)*T+1);diff(Emax_area((i-1)*T+1:i*T))];%����ۼƵ���
    Pmax_temp=Pmax_area((i-1)*T+1:i*T);
    for j=1:T
        if j==1
            temp(j)=min(Emax_temp(j),Pmax_temp(j));
        else
            Emax_temp(j)=Emax_temp(j)+Emax_temp(j-1)-temp(j-1);
            temp(j)=min(Emax_temp(j),Pmax_temp(j));
        end
    end
    EV_un(:,i)=temp;
end

%Լ����������
Loadpro=[0.4 0.2 0.15 0.15 0.1];
Load_area=reshape(Loadprofile*Loadpro,T,NA);%������Ŀռ为�ɷֲ�
load PA
Load_area=PA*Peak_load;
Loadprofile=sum(Load_area);
Loadprofile=Loadprofile';
Loadprofile=M_t*Loadprofile;
Load_area=M_t*Load_area';
%Upper Level Control
x=sdpvar(T,1);%��ʱ�εĳ�繦�ʣ��Ѿ��ǳ�繦�ʣ�����Ҫ�ۺ�
y=sdpvar(T*NA,1);%Ϊ������ĳ�繦�ʣ�Ҳ�Ѿ��ۺ�
%��繦�ʵ��ۻ���ϵ
F0=[x>=0,x<=N*Pr];
A=tril(ones(T,T));%�ۻ���繦�ʾ���
F0=[F0,A*x<=Emax,A*x>=Emin];
H=eye(T,T)-1/T*ones(T,T);%���ξ���
goal0=x'*H*x+2*Loadprofile'*H*x;
%goal0=Price'*x;
%re=solvesdp(F0,goal0);

Atrans=zeros(T,T*NA);
for i=1:T
    Atrans(i,i:T:end)=1;
end
Acum=zeros(NA*T,NA*T);
for i=1:NA
    Acum((i-1)*T+1:i*T,(i-1)*T+1:i*T)=A;
end

F1=[y>=0,y<=Pmax_area,Acum*y>=Emin_area,Acum*y<=Emax_area];
y1=sdpvar(NA*T,1);
%Ȩ�ص��趨Ӱ��ϴ�
u1=sdpvar(size(y,1),1);
M1=binvar(size(y,1),1);
u2=sdpvar(size(y,1),1);
M2=binvar(size(y,1),1);
u3=sdpvar(size(Acum,1),1);
M3=binvar(size(Acum,1),1);
u4=sdpvar(size(Acum,1),1);
M4=binvar(size(Acum,1),1);
M0=100000;
F1=[F1,u1>=0,u2>=0,u3>=0,u4>=0];%������������
%The problem within each area
W1=0;
for i=1:NA
    %Lagrange Equation
    if i>NA
         F1=[F1,2*A'*A*y((i-1)*T+1:i*T)-2*A'*Emax_area((i-1)*T+1:i*T)+W1*2*y((i-1)*T+1:i*T)-2*W1*y1((i-1)*T+1:i*T)-u1((i-1)*T+1:i*T)+u2((i-1)*T+1:i*T)-A'*u3((i-1)*T+1:i*T)+A'*u4((i-1)*T+1:i*T)==0];%Dos
    else
        F1=[F1,Price+W1*2*y((i-1)*T+1:i*T)-2*W1*y1((i-1)*T+1:i*T)-u1((i-1)*T+1:i*T)-u1((i-1)*T+1:i*T)+u2((i-1)*T+1:i*T)-A'*u3((i-1)*T+1:i*T)+A'*u4((i-1)*T+1:i*T)==0];%Cost
    end
    F1=[F1,u1((i-1)*T+1:i*T)<=M0*M1((i-1)*T+1:i*T),y((i-1)*T+1:i*T)<=M0*(1-M1((i-1)*T+1:i*T))];
    F1=[F1,u2((i-1)*T+1:i*T)<=M0*M2((i-1)*T+1:i*T),Pmax_area((i-1)*T+1:i*T)-y((i-1)*T+1:i*T)<=M0*(1-M2((i-1)*T+1:i*T))];
    F1=[F1,u3((i-1)*T+1:i*T)<=M0*M3((i-1)*T+1:i*T),A*y((i-1)*T+1:i*T)-Emin_area((i-1)*T+1:i*T)<=M0*(1-M3((i-1)*T+1:i*T))];
    F1=[F1,u4((i-1)*T+1:i*T)<=M0*M4((i-1)*T+1:i*T),Emax_area((i-1)*T+1:i*T)-A*y((i-1)*T+1:i*T)<=M0*(1-M4((i-1)*T+1:i*T))];
end


%x=Atrans*y;
y1=Atrans*y;
%W=0.01;
goal1=goal0+W*(y1'*y1-2*x'*y1+x'*x);

option=sdpsettings('solver','cplex','verbose',0);
re=solvesdp(F0+F1,goal1,option);

u1=double(u1);
M2=double(M1);
u2=double(u2);
M2=double(M2);
u3=double(u3);
M3=double(M3);
u4=double(u4);
M4=double(M4);
x=double(x);
y=double(y);
y1=double(y1);
result.Cost=Price'*y1;
y1=Atrans*y;
result.gap=y1'*y1-2*x'*y1+x'*x;
result.Dos=norm(Emax_area-Acum*y);
temp=Emax_area-Acum*y;
for i=1:NA
    result.Dos_A(i)=norm(temp((i-1)*24+1:i*24));
end
y=reshape(y,T,NA);%�������ĳ�縺��
result.Cost=Price'*sum(y')';
result.Load=sum(y')+Loadprofile';
result.Loadprofile=Loadprofile;

EV_un=cumsum(EV_un);
result.EV_un=EV_un;
result.Dos_original=Emax_area-reshape(EV_un,T*NA,1);

% plot(x+Loadprofile)
% hold on;
% plot(Loadprofile,'k');
% %����ۼƵ�������
% figure
% plot(std(Load_area,0,2),'k');
% hold on
% plot(std(Load_area+y,0,2));
result.y=y;
result.x=x;
result.time=toc;
%save Result