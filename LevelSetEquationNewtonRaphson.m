function [UserVar,RunInfo,LSF1,l]=LevelSetEquationNewtonRaphson(UserVar,RunInfo,CtrlVar,MUA,BCs,F0,F1)
    %%
    %
    %
    %  %  df/dt + u df/dx + v df/dy - div (kappa grad f) = c norm(grad f0)
    %
    
    persistent iCalls
    
    
    if ~CtrlVar.LevelSetMethod
        LSF1=F1.LSF;
        l=[];
        return
    end
    
    
    
    if isempty(iCalls)
        iCalls=0 ;
    end
    iCalls=iCalls+1;
    
    
    % Define calving rate
    % F.c=zeros(MUA.Nnodes,1)-100e3 ;
    
    
    if ~isfield(CtrlVar,'LevelSetResetInterval') || isempty(CtrlVar.LevelSetResetInterval)
        CtrlVar.LevelSetResetInterval=10000;
    end
    
    MLC=BCs2MLC(CtrlVar,MUA,BCs);
    L=MLC.LSFL ; Lrhs=MLC.LSFRhs ;
    l=Lrhs*0; 
    dl=l ; 
    dLSF=F1.LSF*0;
    
    
    iteration=0 ; rWork=inf ; rForce=inf; CtrlVar.NRitmin=0 ; gamma=1; 
   CtrlVar.LevelSetSolverMaxIterations=25;
    
    while true
     
        
        if gamma > max(CtrlVar.LSFExitBackTrackingStepLength,CtrlVar.BacktrackingGammaMin)
            
            ResidualsCriteria=(rWork<CtrlVar.LSFDesiredWorkAndForceTolerances(1)  && rForce<CtrlVar.LSFDesiredWorkAndForceTolerances(2))...
                && (rWork<CtrlVar.LSFDesiredWorkOrForceTolerances(1)  || rForce<CtrlVar.LSFDesiredWorkOrForceTolerances(2))...
                && iteration >= CtrlVar.NRitmin;
            
        else
            
            ResidualsCriteria=(rWork<CtrlVar.LSFAcceptableWorkAndForceTolerances(1)  && rForce<CtrlVar.LSFAcceptableWorkAndForceTolerances(2))...
                && (rWork<CtrlVar.LSFAcceptableWorkOrForceTolerances(1)  || rForce<CtrlVar.LSFAcceptableWorkOrForceTolerances(2))...
                && iteration >= CtrlVar.NRitmin;
            
        end
        
           
        if iteration>=CtrlVar.LevelSetSolverMaxIterations
            fprintf('LevelSetEquationNewtonRaphson: Maximum number of NR iterations (%i) reached. \n ',CtrlVar.LevelSetSolverMaxIterations)
            break
        end
        
        if ResidualsCriteria
            fprintf('LevelSetEquationNewtonRaphson: NR iteration converged in %i iterations with rWork=%g and rForce=%g \n',iteration,rWork,rForce)
            break
        end
        
        
        iteration=iteration+1 ;
        
        
        [UserVar,R,K]=LevelSetEquationAssemblyNR(UserVar,CtrlVar,MUA,F0.LSF,F0.c,F0.ub,F0.vb,F1.LSF,F1.c,F1.ub,F1.vb);
        if ~isempty(L)
            
            frhs=-R-L'*l;
            grhs=Lrhs-L*F1.LSF;
            
        else
            frhs=-R;
            grhs=[];
        end
        
        [dLSF,dl]=solveKApe(K,L,frhs,grhs,dLSF,dl,CtrlVar);
        dLSF=full(dLSF);
        
        if any(isnan(dLSF))
            save TestSave
            error('LevelSetEquationNewtonRaphson:NaNinSolution','NaN in the solution for dLSF')
        end
        
        Func=@(gamma) CalcCostFunctionLevelSetEquation(UserVar,RunInfo,CtrlVar,MUA,gamma,F1,F0,L,Lrhs,l,dLSF,dl);
        gamma=0 ; [r0,UserVar,RunInfo,rForce0,rWork0,D20]=Func(gamma);
        gamma=1 ; [r1,UserVar,RunInfo,rForce1,rWork1,D21]=Func(gamma);
        
        slope0=-2*r0 ;
        [gamma,r,BackTrackInfo]=BackTracking(slope0,1,r0,r1,Func);
        [r1Test,UserVar,RunInfo,rForce,rWork,D2]=Func(gamma);
        
        if CtrlVar.InfoLevelNonLinIt>=10 && CtrlVar.doplots==1
            nnn=50;
            gammaTestVector=zeros(nnn,1) ; rForceTestvector=zeros(nnn,1);  rWorkTestvector=zeros(nnn,1); rD2Testvector=zeros(nnn,1);
            Upper=2.2;
            Lower=-1 ;
            if gamma>0.7*Upper ; Upper=2*gamma; end
            parfor I=1:nnn
                gammaTest=(Upper-Lower)*(I-1)/(nnn-1)+Lower
                [rTest,~,~,rForceTest,rWorkTest,D2Test]=Func(gammaTest);
                gammaTestVector(I)=gammaTest ; rForceTestvector(I)=rForceTest; rWorkTestvector(I)=rWorkTest;  rD2Testvector(I)=D2Test;
            end
            
            gammaZero=min(abs(gammaTestVector)) ;
            if gammaZero~=0
                [rTest,~,~,rForceTest,rWorkTest,D2Test]=Func(0);
                gammaTestVector(nnn+1)=0 ; rForceTestvector(nnn+1)=rForceTest; rWorkTestvector(nnn+1)=rWorkTest;  rD2Testvector(nnn+1)=D2Test;
            end
            
            [gammaTestVector,ind]=unique(gammaTestVector) ; rForceTestvector=rForceTestvector(ind) ; rWorkTestvector=rWorkTestvector(ind) ; rD2Testvector=rD2Testvector(ind) ;
            [gammaTestVector,ind]=sort(gammaTestVector) ; rForceTestvector=rForceTestvector(ind) ; rWorkTestvector=rWorkTestvector(ind) ; rD2Testvector=rD2Testvector(ind) ;
            [temp,I0]=min(abs(gammaTestVector)) ;
            
            SlopeForce=-2*rForce0;
            SlopeWork=-2*rWork0;
            SlopeD2=-D20;
            CtrlVar.MinimisationQuantity=CtrlVar.LSFMinimisationQuantity;
            [ForceFig,WorkFig]=PlotCostFunctionsVersusGamma(CtrlVar,RunInfo,gamma,r,iteration,"-LSF-",...
                gammaTestVector,rForceTestvector,rWorkTestvector,rD2Testvector,...
                SlopeForce,SlopeWork,SlopeD2,rForce,rWork,D2);
            
        end
        
        
        F1.LSF=F1.LSF+gamma*dLSF;
        l=l+gamma*dl;
        if CtrlVar.InfoLevelNonLinIt>=1
            BCsError=norm(Lrhs-L*F1.LSF);
            fprintf(CtrlVar.fidlog,'Level-Set:%3u/%-2u g=%-14.7g , r/r0=%-14.7g ,  r0=%-14.7g , r=%-14.7g , rForce=%-14.7g , rWork=%-14.7g , BCsError=%-14.7g \n ',...
                iteration,BackTrackInfo.iarm,gamma,r/r0,r0,r,rForce,rWork,BCsError);
        end
        
    end
    
    LSF1=F1.LSF ; % Because I don't return F1
    
 
    
    
   
    
    
end

