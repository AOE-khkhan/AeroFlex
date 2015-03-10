%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     Copyright (C) 2011- Fl�vio Luiz C. Ribeiro
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
classdef airplane < handle
    properties
        membros;
        fus;
        prop; %motores
        N;
        B;
        Me;
        KG;
        CG;
        Jhep;
        Jpep;
        Jthetaep;
        Jhb;
        Jpb;
        Jthetab;
        %Jhepp;
        Jhbp;
        NUMele; % numero de elementos
        NUMmembers; % numero de membros
        membSIZES; % vetor com numero de elementos de cada membro
        membNAED; % vetor com numero de estados de aerodinamica n�o-estacionaria utilizados em cada membro (numero por n�!!)
        membNAEDtotal; % vetor com numero de elementos de AED N-EST totais para cada membro
        NUMaedstates;
    end
    methods
        function ap = airplane(membros,fus, engines)
            ap.NUMmembers = size(membros,2);
            ap.membros = membros;
            ap.NUMele = 0;
            ap.prop = engines;

            for i=1:size(membros,2) 
                ap.membSIZES(i) = size(ap.membros{i},2);
                if ~isempty(ap.membros{i}(1).node1.aero)
                    ap.membNAED(i) = ap.membros{i}(1).node1.aero.N;
                else
                    ap.membNAED(i) = 0;
                end
                ap.membNAEDtotal(i) = 3*ap.membNAED(i)*ap.membSIZES(i);
                ap.NUMele = ap.NUMele + ap.membSIZES(i);
            end
            ap.NUMaedstates = sum(ap.membNAEDtotal);
            
            for i = 1:size(ap.prop,2)
                % calculo do n�mero do n� onde est� posicionado cada motor:
                ap.prop(i).NODEpos = 1+ 3*sum(ap.membSIZES(1:(ap.prop(i).numMEMB-1)))+(ap.prop(i).numELEM-1)*3 + (ap.prop(i).numNODE-1);
            end
            % inicializa parametros constantes
            Me = [];
            KG = [];
            CG = [];
            N = [];
            B = [];

            for i = 1:ap.NUMmembers
                Me = mdiag(Me, getmemberMe(membros{i}));
                KG = mdiag(KG, getmemberKG(membros{i}));
                CG = mdiag(CG, getmemberCG(membros{i}));
                N = [N; getmemberN(membros{i})];
                B = mdiag(B, getB(membros{i}));
            end

            ap.Me = Me;
            ap.KG = KG;
            ap.CG = CG;
            ap.N = N;
            ap.B = B;
            
            if isempty(fus)
                fus = rigidfus(0, [0 0 0], zeros(3,3));
            end
            ap.fus = fus;
        end
        function updateStrJac(ap)
            Jhep = [];
            Jpep = [];
            Jthetaep = [];
            Jhb = [];
            Jpb = [];
            Jthetab = [];
            
            for i = 1:ap.NUMmembers
                ap.membros{i}(1).memberJhep = getmemberJhep(ap.membros{i});
                Jhep = mdiag(Jhep, ap.membros{i}(1).memberJhep);
                
                ap.membros{i}(1).memberJpep = getJpep(ap.membros{i},ap.membros{i}(1).memberJhep);
                Jpep = mdiag(Jpep,ap.membros{i}(1).memberJpep);
                
                %if isempty(ap.Jthetaep)
                    ap.membros{i}(1).memberJthetaep = getJthetaep(ap.membros{i},ap.membros{i}(1).memberJhep);
                    Jthetaep = mdiag(Jthetaep, ap.membros{i}(1).memberJthetaep);

                    ap.membros{i}(1).memberJhb = getmemberJhb(ap.membros{i});
                    Jhb = [Jhb; ap.membros{i}(1).memberJhb];

                    ap.membros{i}(1).memberJpb = getmemberJpb(ap.membros{i},ap.membros{i}(1).memberJhb);
                    Jpb = [Jpb; ap.membros{i}(1).memberJpb];

                    ap.membros{i}(1).memberJthetab = getmemberJthetab(ap.membros{i});
                    Jthetab = [Jthetab; ap.membros{i}(1).memberJthetab];
                %end
            end
            ap.Jhep = Jhep;
            ap.Jpep = Jpep;
            if isempty(ap.Jthetaep)
                ap.Jthetaep = Jthetaep;
                ap.Jhb = Jhb;
                ap.Jpb = Jpb;
                ap.Jthetab = Jthetab;
            end
        end
        function plotairplane3d(ap)
            hold on;
            for i = 1:ap.NUMmembers
                plotaest3d(ap.membros{i});
            end
        end
        function update(ap,strain,strainp, strainpp, lambda)
            for i = 1:ap.NUMmembers
                ap.membros{i}(1).strainm = strain((sum(ap.membSIZES(1:(i-1)))*4 + 1):(sum(ap.membSIZES(1:i))*4))';
                ap.membros{i}(1).strainpm = strainp((sum(ap.membSIZES(1:(i-1)))*4 + 1):(sum(ap.membSIZES(1:i))*4))';
                ap.membros{i}(1).strainppm = strainpp((sum(ap.membSIZES(1:(i-1)))*4 + 1):(sum(ap.membSIZES(1:i))*4))';
                ap.membros{i}(1).lambdam = lambda((sum(ap.membNAEDtotal(1:(i-1))) + 1):(sum(ap.membNAEDtotal(1:i))))';
            end
            for i = 1:ap.NUMmembers
                for j = 1:ap.membSIZES(i)
                    ap.membros{i}(j).setstrain(ap.membros{i}(1).strainm((1+(j-1)*4):(4+(j-1)*4)),ap.membros{i}(1).strainpm((1+(j-1)*4):(4+(j-1)*4)));
                end
            end
            for i = 1:ap.NUMmembers
                update(ap.membros{i});
            end
        end
        function airplanemovie(ap, t, strain,dt)
            aviobj = avifile('teste.avi', 'fps', 1/dt);
            h = figure;
            for i = 1:size(t,1);
                update(ap,strain(i,:),zeros(size(strain(i,:))),zeros(size(strain(i,:))),zeros(sum(ap.membNAEDtotal),1));
                clf(h);
                plotairplane3d(ap);
                view(45,45);
                axis([0 20 -10 10 -5 5]);
                frame = getframe(h);
                aviobj = addframe(aviobj,frame);
                [i, size(t,1)]
            end
            aviobj = close(aviobj);
        end        
        function [A Aaero Abody] = linearize(ap, straineq, betaeq, keq, manete, deltaflap, Vwind)
            if ap.NUMaedstates == 0
               lambda0 = []; 
            else
                lambda0 = zeros(ap.NUMaedstates,1);
            end
            x = [straineq'; zeros(size(straineq')); lambda0; betaeq; keq];
            xp = zeros(size(x));
            
            delta = 1e-9;

            Alin = zeros((ap.NUMaedstates+size(straineq,2)*2+10));
            Mlin = eye((ap.NUMaedstates+size(straineq,2)*2+10));
            for i = 1:size(xp,1)                
                soma = dinamicaflexODEimplicit(0, x + veclin(i, size(x,1))'*delta, xp, ap,Vwind,manete,deltaflap);
                subtr = dinamicaflexODEimplicit(0, x - veclin(i, size(x,1))'*delta, xp, ap,Vwind,manete,deltaflap);
                
                if (i >= (size(straineq,2)+1)) && (i <= (size(straineq,2)*2)) ||  ((i >= ap.NUMaedstates+size(straineq,2)*2+1) && (i <=ap.NUMaedstates+size(straineq,2)*2+6))
                    somap = dinamicaflexODEimplicit(0, x, xp + veclin(i, size(x,1))'*delta, ap,Vwind,manete,deltaflap);
                    subtrp = dinamicaflexODEimplicit(0, x, xp - veclin(i, size(x,1))'*delta, ap,Vwind,manete,deltaflap);
                    Mlin(:,i) = -(somap-subtrp)/delta/2;
                end
                Alin(:,i) = (soma-subtr)/delta/2;                
            end
            A = Mlin \ Alin;                       
            Aaero = Mlin(1:(ap.NUMaedstates+size(straineq,2)*2),1:(ap.NUMaedstates+size(straineq,2)*2)) \ Alin(1:(ap.NUMaedstates+size(straineq,2)*2),1:(ap.NUMaedstates+size(straineq,2)*2));
            Abody = Mlin((ap.NUMaedstates+size(straineq,2)*2+1):(ap.NUMaedstates+size(straineq,2)*2+10),(ap.NUMaedstates+size(straineq,2)*2+1):(ap.NUMaedstates+size(straineq,2)*2+10)) \ Alin((ap.NUMaedstates+size(straineq,2)*2+1):(ap.NUMaedstates+size(straineq,2)*2+10),(ap.NUMaedstates+size(straineq,2)*2+1):(ap.NUMaedstates+size(straineq,2)*2+10));
        end
        function [vec strainEQ] = trimairplane(ap,V,H,Vwind,tracao,deltaflap) %tracao e deltaflap s� ser�o utilizados no estudo da asa engastada
            global softPARAMS;
            strain = zeros(ap.NUMele*4,1)';
            strainp = zeros(ap.NUMele*4,1)';
            strainpp = zeros(ap.NUMele*4,1)';
            lambda = zeros(sum(ap.membNAEDtotal),1);
            updateStrJac(ap);
            
            beta = zeros(6,1);
            betap = zeros(6,1);
            if ~softPARAMS.isPINNED
                tracao = 0;
                deltaflap = 0;
            end
            
            theta = 0;
            phi = 0;
            psi = 0;
            kinetic = [theta, phi, psi, H];
            if ~softPARAMS.isPINNED
                options=optimset('MaxIter',20000,'TolFun',1e-15,'MaxFunEvals',20000,'TolX',1e-15);
                vec= fsolve(@equilibracorpo,[0 0 0],options,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,V,0,0,'longitudinal');
                theta = vec(1)
                kinetic(1) = theta;
                deltaflap = vec(2)
                tracao = vec(3)
                beta(3) = -V*sin(theta);
                beta(2) = V*cos(theta);

                %if softPARAMS.plota3d
                %    figure(100);plotairplane3d(ap);
                %end
                strainEQ = fsolve(@equilibraestrutura, strain,options,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,Vwind, tracao, [deltaflap 0 0]);
                if softPARAMS.plota3d
                    figure(100);plotairplane3d(ap);
                end
                if softPARAMS.isITER
                    for i = 1:softPARAMS.numITER
                        theta
                        deltaflap
                        tracao
                        if softPARAMS.updateStrJac == 1
                            updateStrJac(ap);
                        end
                        vecold = vec;
                        vec= fsolve(@equilibracorpo,vec,options,strainEQ, strainp, strainpp,lambda,beta,betap,kinetic,ap,V,0,0,'longitudinal');
                        vec = (vec-vecold)*0.3+ vecold;
                        theta = vec(1);
                        kinetic(1) = theta;
                        deltaflap = vec(2);
                        tracao = vec(3);
                        beta(3) = -V*sin(theta);
                        beta(2) = V*cos(theta);
                        strainEQ = fsolve(@equilibraestrutura, strainEQ,options,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,Vwind, tracao, deltaflap);
                        if softPARAMS.plota3d
                            figure(100);plotairplane3d(ap);
                        end
                    end
                end
            else
                options=optimset('MaxIter',20000,'TolFun',1e-20,'MaxFunEvals',20000,'TolX',1e-17);
                theta = 0;
                vec = [0 0 0];
                kinetic(1) = theta;
                beta(3) = -0*sin(theta);
                beta(2) = 0*cos(theta);
                strainEQ = fsolve(@equilibraestrutura, strain,options,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,Vwind, tracao, deltaflap);
                if softPARAMS.plota3d
                            figure(100);plotairplane3d(ap);
                end
            end
            theta
            deltaflap
            tracao
            
            
            %[Xp bp lambdap]= dinamicaflex(0,strainEQ, strainp, strainpp,lambda,beta,betap,kinetic,ap,Vento,Jhep,Jpep,Jthetaep,B,Jhb, Jpb, Jthetab,rho, tracao, deltaflap);
        end
        function [vecEQ strainEQ] = trimairplanefull(ap,V,H,beta_trim,psid,Vwind,tracao,deltaflap)          
            global softPARAMS;
            strain = zeros(ap.NUMele*4,1)';
            strainp = zeros(ap.NUMele*4,1)';
            strainpp = zeros(ap.NUMele*4,1)';
            lambda = zeros(sum(ap.membNAEDtotal),1);
            updateStrJac(ap);
            phieq=0;
            aoa_trim = 0.0537;
            thetaeq=0;
            beta(1)=V*sin(beta_trim);
            beta(3) = -V*sin(aoa_trim)*cos(beta_trim);
            beta(2) = V*cos(aoa_trim)*cos(beta_trim);
            beta(6)=psid*sin(phieq)*cos(thetaeq);re=-beta(6);
            beta(4)=psid*sin(phieq)*cos(thetaeq); beta(5)=-re*tan(thetaeq)/cos(phieq);
            betap = zeros(6,1);
            if ~softPARAMS.isPINNED
                tracao = 6.4560;
                deltaflap = [-16.9703 0 0];
            end
            theta = 0.0537;
            phi = 0;
            psi = 0;            
            kinetic = [theta, phi, psi, H];
            if ~softPARAMS.isPINNED
                options=optimset('MaxIter',20000,'TolFun',1e-15,'MaxFunEvals',20000,'TolX',1e-15);
                vec= fsolve(@equilibracorpo,[theta deltaflap tracao phi aoa_trim],options,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,V,psid,beta_trim,'full')
            end
        end
        function [t strain strainp lambda beta kinetic] = simulate(ap, tspan, strain0, beta0, kinetic0, Vwind, manete, deltaflap, method)
            x0 = [strain0'; zeros(ap.NUMele*4,1); zeros(ap.NUMaedstates,1); beta0; kinetic0];
            
            xp0 =zeros(size(x0));
            options = odeset('OutputFcn',@odeprog,'Events',@odeabort,'MaxStep',0.10) ;
            switch lower(method)
                case 'implicit'
                    [t X] = ode15i(@(t,x,xp)dinamicaflexODEimplicit(t,x,xp,ap, Vwind, manete(t), deltaflap(t)), tspan, x0, xp0,options);
                case 'explicit'
                    [t X] = ode15s(@(t,x)dinamicaflexODE(t,x,ap, Vwind, manete(t), deltaflap(t)), tspan, x0,options);
            end
            strain = X(:,1:ap.NUMele*4);
            strainp = X(:,(ap.NUMele*4+1):(2*ap.NUMele*4));
            lambda = X(:,(2*ap.NUMele*4+1):(2*ap.NUMele*4+ap.NUMaedstates));
            beta = X(:,(2*ap.NUMele*4+ap.NUMaedstates+1):(2*ap.NUMele*4+ap.NUMaedstates+6));
            kinetic = X(:,(2*ap.NUMele*4+ap.NUMaedstates+7):(2*ap.NUMele*4+ap.NUMaedstates+10));
        end
        
    end
end


function vec = veclin(i,numstates)
    vec = zeros(1,numstates);
    vec(1,i) = 1;
end

function zero = equilibracorpo(vec,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,V,psid,beta_trim,flagLONG)
global softPARAMS;
switch flagLONG
    case 'longitudinal'
        theta = vec(1);
        deltaflap = vec(2);
        tracao = vec(3);
        beta(3) = -V*sin(theta);
        beta(2) = V*cos(theta);
        Vento = 0;
        kinetic(1) = theta;
        %strain = vec(4:(3+size(strain,2)));
        FLAG = 0; % equilibrium dynamics
        [Xp bp lambdap kp]= dinamicaflex(0,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,Vento, tracao, [deltaflap 0 0], FLAG);
        zero = 10000*[bp(2) bp(3) bp(4)]';
    case 'full'
        theta = vec(1);
        deltaflap = vec(2:4);
        tracao = vec(5);
        phi = vec(6);
        aoa_trim = vec(7);
        vec
        beta(1)= V*sin(beta_trim);
        beta(3) = -V*sin(aoa_trim)*cos(beta_trim);
        beta(2) = V*cos(aoa_trim)*cos(beta_trim);
        beta(6)= psid*sin(phi)*cos(theta);re=-beta(6);
        beta(4)= psid*sin(phi)*cos(theta);
        beta(5)=-re*tan(theta)/cos(phi);
        beta=beta';
        Vento = 0;
        FLAG = 0; % equilibrium dynamics
        [Xp bp lambdap kp]= dinamicaflex(0,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,Vento, tracao, deltaflap, FLAG);
        zero = 10000*[bp' kp(4)]
end
end

function zero = equilibraestrutura(vec,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,V, tracao, deltaflap)
    global softPARAMS;
    strain = vec;
    %strain = vec(4:(3+size(strain,2)))
    FLAG = 0; % equilibrium dynamics
    [Xp bp lambdap]= dinamicaflex(0,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,V, tracao, deltaflap, FLAG);
    zero = (Xp);
end

function zero = equilibratudo(vec,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,V, tracao, deltaflap)
    global softPARAMS;
    strain = vec(1:size(strainp,2));
    theta = vec(size(strainp,2)+1);
    deltaflap = vec(size(strainp,2)+2);
    tracao = vec(size(strainp,2)+3);
    beta(3) = -V*sin(theta);
    beta(2) = V*cos(theta);
    Vento = 0;
    kinetic(1) = theta;
    
    %strain = vec(4:(3+size(strain,2)));
    softPARAMS.isEQ = 1;
    FLAG = 0; %equilibrium dynamics
    [Xp bp lambdap]= dinamicaflex(0,strain, strainp, strainpp,lambda,beta,betap,kinetic,ap,V, tracao, deltaflap,FLAG);
    softPARAMS.isEQ = 0;
    zero = [(Xp); bp(2); bp(3); bp(4)];
end


function f = dinamicaflexODEimplicit(t, x, xp, ap,V,manete,deltaflap)

    %x = [strain strainp lambda beta kinetic]
    %xp = [strainp strainpp lambdap betap kineticp]
    strain = x(1:ap.NUMele*4);
    strainp = x((ap.NUMele*4+1):ap.NUMele*4*2);
    lambda = x((ap.NUMele*4*2+1):(ap.NUMele*4*2+ap.NUMaedstates));
    beta = x(((ap.NUMele*4*2+ap.NUMaedstates)+1):(ap.NUMele*4*2+ap.NUMaedstates+6));
    kinetic = x((ap.NUMele*4*2+ap.NUMaedstates+7):(ap.NUMele*4*2+ap.NUMaedstates+10));
    strainpn = xp(1:ap.NUMele*4);
    strainpp = xp((ap.NUMele*4+1):ap.NUMele*4*2);
    if ap.NUMaedstates == 0
        lambdap = [];
    else
        lambdap = xp((ap.NUMele*4*2+1):(ap.NUMele*4*2+ap.NUMaedstates));
    end
    betap = xp(((ap.NUMele*4*2+ap.NUMaedstates)+1):(ap.NUMele*4*2+ap.NUMaedstates+6));
    kineticp = xp((ap.NUMele*4*2+ap.NUMaedstates+7):(ap.NUMele*4*2+ap.NUMaedstates+10));
    
    FLAG = 1; % implicit dynamic
    [strainppn bpn lambdapn kineticpn] = dinamicaflex(t,strain', strainp', strainpp',lambda,beta,betap,kinetic',ap,V, manete, deltaflap, FLAG);
    
    if isempty(lambdap)
        f = [(-strainpn+strainp);(strainppn-strainpp); (bpn-betap); (kineticpn-kineticp)];
    else
        f = [(-strainpn+strainp);(strainppn-strainpp); (lambdapn -lambdap); (bpn-betap); (kineticpn-kineticp)];
    end
    
end

function xp = dinamicaflexODE(t, x, ap,V,manete,deltaflap)
    global softPARAMS;
    %x = [strain strainp lambda beta kinetic]
    %xp = [strainp strainpp lambdap betap kineticp]
    strain = x(1:ap.NUMele*4);
    strainp = x((ap.NUMele*4+1):ap.NUMele*4*2);
    lambda = x((ap.NUMele*4*2+1):(ap.NUMele*4*2+ap.NUMaedstates));
    beta = x(((ap.NUMele*4*2+ap.NUMaedstates)+1):(ap.NUMele*4*2+ap.NUMaedstates+6));
    kinetic = x((ap.NUMele*4*2+ap.NUMaedstates+7):(ap.NUMele*4*2+ap.NUMaedstates+10));
    
    strainpp = zeros(ap.NUMele*4,1);
    betap = zeros(6,1);
    FLAG = 2; % explicit dynamic
    [strainpp bp lambdap kineticp] = dinamicaflex(t,strain', strainp', strainpp',lambda,beta,betap,kinetic',ap,V, manete, deltaflap, FLAG);

    xp = [strainp;strainpp; lambdap; bp; kineticp];
end