function  [UserVar,F,l,Kuv,Ruv,RunInfo,L]=SSTREAM2dNR(UserVar,CtrlVar,MUA,BCs,F,l,RunInfo)
    
    
    nargoutchk(7,7)
    narginchk(7,7)
    
    
    tStart=tic;
    RunInfo.Forward.Converged=1; RunInfo.Forward.Iterations=NaN;  RunInfo.Forward.Residual=NaN;
    
    
   
    
    % MLC=BCs2MLC(CtrlVar,MUA,BCs);
    % L=MLC.ubvbL;
    % cuv=MLC.ubvbRhs;
    
    [L,cuv]=AssembleLuvSSTREAM(CtrlVar,MUA,BCs) ;
    
    
    if isempty(cuv)
        l.ubvb=[];
    elseif numel(l.ubvb)~=numel(cuv)
        l.ubvb=zeros(numel(cuv),1) ;
    end
    
    
    if any(isnan(F.C)) ; save TestSave ; error( ' C nan ') ; end
    if any(isnan(F.AGlen)) ; save TestSave ;error( ' AGlen nan ') ; end
    if any(isnan(F.S)) ; save TestSave ; error( ' S nan ') ; end
    if any(isnan(F.h)) ; save TestSave  ; error( ' h nan ') ; end
    if any(isnan(F.ub)) ; save TestSave ; error( ' ub nan ') ; end
    if any(isnan(F.vb)) ; save TestSave ; error( ' vb nan ') ; end
    if any(isnan(l.ubvb)) ; save TestSave ; error( ' ubvbLambda nan ') ; end
    if any(isnan(F.rho)) ; save TestSave  ; error( ' rho nan ') ; end
    if any(F.h<0) ; warning('MATLAB:SSTREAM2dNR:hnegative',' thickness negative ') ; end
    
    
    
    %%
    
    
    % Solves the SSTREAM equations in 2D (sparse and vectorized version) using Newton-Raphson iteration
    
    % lambda are the Lagrange parameters used to enfore the boundary conditions
    
    % Newton-Raphson is:
    % K \Delta x_i = -R ; x_{i+1}= x_{i}+ \Delta x_i
    % R=T-F
    % T : internal nodal forces
    % F : external nodal forces
    % K : tangent matrix, where K is the directional derivative of R in the direction (Delta u, \Delta v)
    
    % I need to solve
    %
    % [Kxu Kxv Luv'] [du]        =  [ -Ru ] - Luv' lambdauv
    % [Kyu Kyv     ] [dv]        =  [ -Rv ]
    % [  Luv      0] [dlambdauv]    [ Lrhsuv-Luv [u ;v ]
    %
    % All matrices are Nnodes x Nnodes, apart from:
    % Luv is #uv constraints x 2 Nnodes
    %
    
    % I write the system as
    % [Kuv  Luv^T ]  [duv]  =  [ -R(uv) - Luv^T l]
    % [Luv   0    ]  [dl]      [cuv-Luv uv]
    %
    
    
    
    
    
    
    dub=zeros(MUA.Nnodes,1) ; dvb=zeros(MUA.Nnodes,1) ; dl=zeros(numel(l.ubvb),1);
    
    
    % diffVector=zeros(CtrlVar.NRitmax+1,1)+NaN;
    rVector.gamma=zeros(CtrlVar.NRitmax+1,1)+NaN;
    rVector.rDisp=zeros(CtrlVar.NRitmax+1,1)+NaN;
    rVector.rWork=zeros(CtrlVar.NRitmax+1,1)+NaN;
    rVector.rForce=zeros(CtrlVar.NRitmax+1,1)+NaN;
    
    Kuv=[] ; 
    
    fext0=KRTFgeneralBCs(CtrlVar,MUA,F,true); % RHS with velocities set to zero, i.e. only external forces
    Ruv=KRTFgeneralBCs(CtrlVar,MUA,F);     % RHS with calculated velocitie, i.e. difference between external and internal forces
    
    RunInfo.CPU.Solution.uv=0;
    
    if ~isempty(L)
        frhs=-Ruv-L'*l.ubvb;
        grhs=cuv-L*[F.ub;F.vb];
    else
        frhs=-Ruv;
        grhs=[];
    end
    
    
    % think about deleting this and only use the call to CalcCostFunction
    % r=ResidualCostFunction(CtrlVar,MUA,L,frhs,grhs,fext0,"-uv-");
 
    Temp=CtrlVar.uvCostFunction;
    % The initial estimate must be based on residuals as both displacements and work
    % requires solving the Newton system. 
    CtrlVar.uvCostFunction="Force Residuals" ; 
    gamma=0 ; [UserVar,r] = CalcCostFunctionNR(UserVar,CtrlVar,MUA,gamma,F,fext0,L,l,cuv,dub,dvb,dl,Kuv) ; 
    
    % fprintf(' TestIng: norm(r-r0Test)=%f \n ',norm(r-r0Test))
    CtrlVar.uvCostFunction=Temp; 
        
    
  
    
    iteration=0;  ResidualReduction=1e10; RunInfo.CPU.solution.uv=0 ; RunInfo.CPU.Assembly.uv=0;
    while true

        
        
        
        switch lower(CtrlVar.uvConvergenceCriteria)
            
            case 'residuals'
                
                if r<CtrlVar.NLtol
                    
                    tEnd=toc(tStart);
                    if CtrlVar.InfoLevelNonLinIt>=1
                        fprintf(' SSTREAM(uv) (time|dt)=(%g|%g): Converged to given residual tolerance of %-g with r=%-g in %-i iterations and in %-g  sec \n',...
                            CtrlVar.time,CtrlVar.dt,CtrlVar.NLtol,r,iteration,tEnd) ;
                    end
                    RunInfo.Forward.Converged=1;
                    break
                    
                end
                
            case 'increments'
                
                if rDisp < CtrlVar.du
                    tEnd=toc(tStart);
                    if CtrlVar.InfoLevelNonLinIt>=1
                        fprintf(' SSTREAM(uv) (time|dt)=(%g|%g): Converged to given increment tolerance of du=%g with r=%-g in %-i iterations and in %-g  sec \n',...
                            CtrlVar.time,CtrlVar.dt,CtrlVar.du,r,iteration,tEnd)
                    end
                    RunInfo.Forward.Converged=1;
                    break
                    
                end
                
            case 'residuals and increments'
                
                if r<CtrlVar.NLtol && rDisp < CtrlVar.du
                    
                    tEnd=toc(tStart);
                    if CtrlVar.InfoLevelNonLinIt>=1
                        fprintf(CtrlVar.fidlog,' SSTREAM(uv) (time|dt)=(%g|%g): Converged to given residual (r=%g) and increment tolerances (du=%g) with r=%-g, du=%-g and dh=%-g in %-i iterations and in %-g  sec \n',...
                            CtrlVar.time,CtrlVar.dt,CtrlVar.NLtol,CtrlVar.du,r,rDisp,diffDh,iteration,tEnd) ;
                    end
                    RunInfo.Forward.Converged=1;
                    break
                end
                
            case 'residuals or increments'
                
                if r<CtrlVar.NLtol && rDisp < CtrlVar.du
                    
                    tEnd=toc(tStart);
                    if CtrlVar.InfoLevelNonLinIt>=1
                        fprintf(CtrlVar.fidlog,' SSTREAM(uv) (time|dt)=(%g|%g): Converged to given residual (r=%g) or increment tolerances (du=%g,dh=%g) with r=%-g, du=%-g in %-i iterations and in %-g  sec \n',...
                            CtrlVar.time,CtrlVar.dt,CtrlVar.NLtol,CtrlVar.du,r,rDisp,diffDh,iteration,tEnd) ;
                    end
                    RunInfo.Forward.Converged=1;
                    break
                end
            otherwise
                fprintf(' CtrlVar.uvConvergenceCriteria (%s) not set to a valid value.\n',CtrlVar.uvConvergenceCriteria)
                error('parameter values incorrect')
        end
        
        
        if iteration > CtrlVar.NRitmax
            
            if CtrlVar.InfoLevelNonLinIt>=1
                fprintf(' SSTREAM(uv) (time|dt)=(%g|%g): Maximum number of non-linear iterations reached. uvh iteration did not converge! \n',CtrlVar.time,CtrlVar.dt)
                fprintf(' Exiting uv iteration after %-i iterations with r=%-g \n',iteration,r)
            end
            
            if CtrlVar.WriteRunInfoFile
                fprintf(RunInfo.File.fid,' SSTREAM(uv) (time|dt)=(%g|%g): Maximum number of non-linear iterations reached. uvh iteration did not converge! \n',CtrlVar.time,CtrlVar.dt);
                fprintf(RunInfo.File.fid,' Exiting uv iteration after %-i iterations with r=%-g \n',iteration,r);
            end
            
            RunInfo.Forward.Converged=0;
            break
        end
        
        
        iteration=iteration+1;
        
        %% Newton step
        % If I want to use the Newton Decrement (work) criterion I must calculate the Newton
        % step ahead of the cost function
        if rem(iteration-1,CtrlVar.ModifiedNRuvIntervalCriterion)==0  || ResidualReduction> CtrlVar.ModifiedNRuvReductionCriterion
            
            tAssembly=tic;
            [Ruv,Kuv]=KRTFgeneralBCs(CtrlVar,MUA,F);
            RunInfo.CPU.Assembly.uv=toc(tAssembly)+RunInfo.CPU.Assembly.uv;
            NRincomplete=0;
        else
            tAssembly=tic;
            Ruv=KRTFgeneralBCs(CtrlVar,MUA,F);
            RunInfo.CPU.Assembly.uv=toc(tAssembly)+RunInfo.CPU.Assembly.uv;
            NRincomplete=1;
        end

        
        if CtrlVar.Inverse.TestAdjoint.FiniteDifferenceType=="complex step differentiation"
            CtrlVar.TestForRealValues=false;
        end
        
        if CtrlVar.TestForRealValues
            if ~isreal(Kuv) ; save TestSave Kuv ; error('SSTREAM2dNR: K not real') ;  end
            if ~isreal(L) ; save TestSave L ; error('SSTREAM2dNR: L not real') ;  end
        end
        
        if any(isnan(Kuv)) ; save TestSave Kuv ; error('SSTREAM2dNR: K nan') ;  end
        if any(isnan(L)) ; save TestSave L ; error('SSTREAM2dNR: L nan') ;  end
        
        CtrlVar.Solver.isUpperLeftBlockMatrixSymmetrical=issymmetric(Kuv) ;

        
        % [Kuv  Luv' ]  [duv]  =  [ -R(uv) - Luv' l]
        % [Luv   0    ]  [dl]      [ cuv-Luv uv      ]
        
        if ~isempty(L)
            frhs=-Ruv-L'*l.ubvb;
            grhs=cuv-L*[F.ub;F.vb];
        else
            frhs=-Ruv;
            grhs=[];
        end
   
        tSolution=tic;
        
        if CtrlVar.Solver.isUpperLeftBlockMatrixSymmetrical
            [sol,dl]=solveKApeSymmetric(Kuv,L,frhs,grhs,[dub;dvb],dl,CtrlVar);
        else
            [sol,dl]=solveKApe(Kuv,L,frhs,grhs,[dub;dvb],dl,CtrlVar);
        end
        
        RunInfo.CPU.Solution.uv=toc(tSolution)+RunInfo.CPU.Solution.uv;
        
        
        if CtrlVar.TestForRealValues
            dub=real(sol(1:MUA.Nnodes)) ; dvb=real(sol(MUA.Nnodes+1:2*MUA.Nnodes));
        else
            dub=sol(1:MUA.Nnodes) ; dvb=sol(MUA.Nnodes+1:2*MUA.Nnodes);
        end

        %% Residuals , at gamma=0;
        gamma=0 ; [UserVar,r0,rRes0,rWork0,rDisp0,D20] = CalcCostFunctionNR(UserVar,CtrlVar,MUA,gamma,F,fext0,L,l,cuv,dub,dvb,gamma*dl,Kuv) ; 
        
        if iteration==1  % save the first r value for plotting, etc
            rVector.gamma(1)=gamma; 
            rVector.rDisp(1)=rDisp0; 
            rVector.rWork(1)=rWork0; 
            rVector.rForce(1)=rRes0 ; 
        end
   
        %% calculate  residuals at full Newton step, i.e. at gamma=1
        gamma=1 ; [UserVar,r1,rRes1,rWork1,rDisp1,D21] = CalcCostFunctionNR(UserVar,CtrlVar,MUA,gamma,F,fext0,L,l,cuv,dub,dvb,dl,Kuv) ; 
 
        
        [UserVar,r,gamma,infovector,BacktrackInfo] = FindBestGamma2Dbacktracking(UserVar,CtrlVar,MUA,F,fext0,r0,r1,L,l,cuv,dub,dvb,dl);
        
        % If backtracking returns all values, then this call will not be needed.
        [UserVar,rTest,rRes,rWork,rDisp,D2] = CalcCostFunctionNR(UserVar,CtrlVar,MUA,gamma,F,fext0,L,l,cuv,dub,dvb,dl,Kuv) ; 
        rVector.gamma(iteration+1)=gamma;
        rVector.rDisp(iteration+1)=rDisp;
        rVector.rWork(iteration+1)=rWork;
        rVector.rForce(iteration+1)=rRes ;
        
        
        
        if BacktrackInfo.Converged==0
            fprintf(CtrlVar.fidlog,' SSTREAM2dNR backtracking step did not converge \n ') ;
            warning('SSTREAM2NR:didnotconverge',' SSTREAM2dNR backtracking step did not converge \n ')
            fprintf(CtrlVar.fidlog,' saving variables in SSTREAM2dNRDump \n ') ;
            save SSTREAM2dNRDump
            RunInfo.Forward.Converged=0;
            break
        end
        
        %% If requested, plot residual as function of steplength
        if CtrlVar.InfoLevelNonLinIt>=10 && CtrlVar.doplots==1
            nnn=50;
            gammaTestVector=zeros(nnn,1) ; rResTestvector=zeros(nnn,1); rWorkTestvector=zeros(nnn,1);
            
            Up=2;
            if gamma>0.7*Up ; Up=2*gamma; end
            parfor I=1:nnn
                gammaTest=Up*(I-1)/(nnn-1)+gamma/1000;
                %[~,rTest] = CalcCostFunctionNR(UserVar,CtrlVar,MUA,gammaTest,F,fext0,L,l,cuv,dub,dvb,dl)
             [~,rTest,rResTest,rWorkTest,rDispTest,D2]= CalcCostFunctionNR(UserVar,CtrlVar,MUA,gammaTest,F,fext0,L,l,cuv,dub,dvb,dl,Kuv);
             % [UserVar,r1,rRes1,rWork1,rDisp1,D21] = CalcCostFunctionNR(UserVar,CtrlVar,MUA,gamma,F,fext0,L,l,cuv,dub,dvb,dl) ; 
                gammaTestVector(I)=gammaTest ; rResTestvector(I)=rResTest; rWorkTestvector(I)=rWorkTest;
            end

            
            
            [gammaTestVector,ind]=unique(gammaTestVector) ; rResTestvector=rResTestvector(ind) ; rWorkTestvector=rWorkTestvector(ind) ;
            [gammaTestVector,ind]=sort(gammaTestVector) ; rResTestvector=rResTestvector(ind) ; rWorkTestvector=rWorkTestvector(ind) ;
            
            
            FindOrCreateFigure("SSTREAM uv rResiduals");
            slope=-2*rRes0;
            yyaxis left
            plot(gammaTestVector,rResTestvector,'o-') ; hold on ;
            plot([gammaTestVector(1) gammaTestVector(2)],[rResTestvector(1) rResTestvector(1)+(gammaTestVector(2)-gammaTestVector(1))*slope],'b-','LineWidth',2)
            ylabel('Force Residuals')
            
            if CtrlVar.uvCostFunction=="Force Residuals"
                plot(gamma,r,'Marker','h','MarkerEdgeColor','k','MarkerFaceColor','g')
            end
            
            yyaxis right
            slope=-2*rWork0;
            plot(gammaTestVector,rWorkTestvector,'o-') ; hold on ;
            plot([gammaTestVector(1) gammaTestVector(2)],[rWorkTestvector(1) rWorkTestvector(1)+(gammaTestVector(2)-gammaTestVector(1))*slope],'r-','LineWidth',2)
            ylabel('Work Residuals')
            
            if CtrlVar.uvCostFunction=="Work Residuals"
                plot(gamma,r,'Marker','h','MarkerEdgeColor','k','MarkerFaceColor','g')
            end
            
            title(sprintf('uv iteration %-i,  iarm=%-i ',iteration,BacktrackInfo.iarm)) ; xlabel(' \gamma ') ;
            
            
            
            
        end
        
%         Inodes=F.h <=CtrlVar.ThickMin ;
%         rDisp=CalcIncrementsNorm(CtrlVar,MUA,L,Inodes,F.ub,dub,F.vb,dvb);
%         diffDlambda=full(max(abs(gamma*dl))/mean(abs(l.ubvb)));
%         
        % diffVector(iteration)=r0;   % override last value, because it was just a (very accurate) estimate
        % diffVector(iteration+1)=r;
        
     
        
        
        F.ub=F.ub+gamma*dub ;
        F.vb=F.vb+gamma*dvb;
        l.ubvb=l.ubvb+gamma*dl;
        
        ResidualReduction=r/r0;
        
        if CtrlVar.InfoLevelNonLinIt>100  && CtrlVar.doplots==1
            PlotForceResidualVectors('uv',Ruv,L,l.ubvb,MUA.coordinates,CtrlVar) ; axis equal tight
        end
        
        if NRincomplete
            stri='i';
        else
            stri=[];
        end
        
        if CtrlVar.InfoLevelNonLinIt>=1
            
            fprintf(CtrlVar.fidlog,'%sNR-STREAM(uv):%3u/%-2u g=%-14.7g , r/r0=%-14.7g ,  r0=%-14.7g , r=%-14.7g , du=%-14.7g , Assembly=%f sec. Solution=%f sec.\n ',...
                stri,iteration,BacktrackInfo.iarm,gamma,r/r0,r0,r,rDisp,RunInfo.CPU.Assembly.uv,RunInfo.CPU.Solution.uv);
        end
        
        if CtrlVar.WriteRunInfoFile
            
            fprintf(RunInfo.File.fid,'%sNR-STREAM(uv):%3u/%-2u g=%-14.7g , r/r0=%-14.7g ,  r0=%-14.7g , r=%-14.7g , du=%-14.7g , Assembly=%f sec. Solution=%f sec.\n ',...
                stri,iteration,BacktrackInfo.iarm,gamma,r/r0,r0,r,rDisp,RunInfo.CPU.Assembly.uv,RunInfo.CPU.Solution.uv);
        end
        
    end
    
    
    
    if CtrlVar.InfoLevelNonLinIt>=10 && iteration >= 2 && CtrlVar.doplots==1
  
            
            FindOrCreateFigure("NR-uv r");
            yyaxis left
            semilogy(0:iteration,rVector.rForce(1:iteration+1),'x-') ;
            ylabel('rResiduals^2')
            yyaxis right
            semilogy(0:iteration,rVector.rWork(1:iteration+1),'o-') ;
            ylabel('rWork^2')
            
            title('Force and Work residuals (NR uv diagnostic step)') ; xlabel('Iteration') ;
            
  
    end
    
    if isnan(r)
        fprintf(CtrlVar.fidlog,' SSTREAM2dNR returns NAN as residual!!! \n') ;
        warning('uvSSTREAM:didnotconverge',' SSTREAM2dNR did not converge to a solution. Saving all variables in TestSaveNR.mat \n ')
        save TestSaveNR
        
    end
    
    
    RunInfo.Forward.Iterations=iteration;  RunInfo.Forward.Residual=r;
    RunInfo.Forward.IterationsTotal=RunInfo.Forward.IterationsTotal+RunInfo.Forward.Iterations;
    
    if any(isnan(F.ub)) || any(isnan(F.vb))  ; save TestSaveNR  ;  error(' nan in ub vb ') ; end
    
    
    
end

