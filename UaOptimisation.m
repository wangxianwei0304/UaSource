function  [p,UserVar,RunInfo]=UaOptimisation(UserVar,RunInfo,CtrlVar,MUA,func,p,plb,pub)
%
% func is the function to me minimized
%  p is the paramter set, i.e. func(p)
%
%  Func is func evaluated as a function of stepsize gamma in the direction of
%  the gradient: Func=@(gamma) func(p-gamma*dJdp);
%

narginchk(8,8)
nargoutchk(3,3)

if isempty(CtrlVar)
    
    CtrlVar.Inverse.InitialLineSearchStepSize=1;
    CtrlVar.Inverse.DataMisfit.HessianEstimate='0';
    CtrlVar.Inverse.MinimumAbsoluteLineSearchStepSize=1e-5;
    CtrlVar.Inverse.MinimumRelativelLineSearchStepSize=1e-4;
    CtrlVar.Inverse.MaximumNumberOfLineSeachSteps=100;
    CtrlVar.Inverse.InfoLevel=1;
    CtrlVar.Inverse.Iterations=4;
    CtrlVar.Inverse.GradientUpgradeMethod='SteepestDecent' ; %{'SteepestDecent','ConjGrad'}
    CtrlVar.NewtonAcceptRatio=0.5;
    CtrlVar.NLtol=1e-15;
    CtrlVar.doplots=1;
    CtrlVar.Inverse.StoreSolutionAtEachIteration=0;
end

p=p(:); 
p=kk_proj(p,pub,plb);


[J0,dJdp,Hess,fOuts]=func(p);
dJdp=dJdp(:);
GradNorm=norm(dJdp);
RunInfo.Inverse.ConjGradUpdate=0;

if isempty(RunInfo) ||  numel(RunInfo.Inverse.Iterations)<=1
    RunInfo.Inverse.Iterations(1)=0;
    RunInfo.Inverse.J(1)=J0;
    
    if CtrlVar.Inverse.StoreSolutionAtEachIteration
        RunInfo.Inverse.p{1}=p;
    end
    
    if isfield(fOuts,'R')
        RunInfo.Inverse.R(1)=fOuts.RegOuts.R;
    end
    if isfield(fOuts,'I')
        RunInfo.Inverse.I(1)=fOuts.MisfitOuts.I;
    end
    RunInfo.Inverse.StepSize(1)=0;
    RunInfo.Inverse.GradNorm=GradNorm;
    RunInfo.Inverse.ConjGradUpdate=0;
end





% Determine initial step size:
% If Hessian is defined, use Newton step.
% If CtrlVar.Inverse.InitialLineSearchStepSize is defined use that
%

% if norm(dJdp)<eps
%    
%     fprintf('Norm of the gradient of the objective function is less than eps. \n')
%     fprintf('No further inverse iterations needed/possible. \n')
%     return
%     
% end

% determine initial search direction and initial step size for line-search.
if ~(isempty(CtrlVar.Inverse.InitialLineSearchStepSize) ||  CtrlVar.Inverse.InitialLineSearchStepSize==0)
    gamma=CtrlVar.Inverse.InitialLineSearchStepSize;
    slope0=-dJdp'*dJdp;
else
    if ~(isdiag(Hess) && sum(diag(Hess))==0) && ~strcmpi(CtrlVar.Inverse.DataMisfit.HessianEstimate,'0')
        dp=-Hess\dJdp;
        gamma=1;
        dJdp=-dp;
        slope0=-dJdp'*dJdp;
    else
        slope0=-dJdp'*dJdp;
        gamma1=-0.01*J0/slope0 ; % linear approx
        p1=p-gamma1*dJdp;
        J1=func(p1);
        gamma=-gamma1*slope0/2/((J1-J0)/gamma1-slope0);  % quadradic approx
        if gamma<0 ; gamma=gamma1; end 
    end
    
end


dJdpModified=dJdp;

%%
fprintf('\n +++++++++++ At start of inversion:  \t J=%-g \t I=%-g \t R=%-g  |grad|=%g \t \t gamma=%-g \n \n',J0,fOuts.MisfitOuts.I,fOuts.RegOuts.R,GradNorm,gamma)


Func=@(gamma) func(p-gamma*dJdp);
J1=Func(gamma);
nFuncEval=1;


if isnan(J1)
    slope0=-dJdp'*dJdp; gamma=-0.01*J0/slope0 ;  % modification on 23 Jan, 2019. Resetting gamma
    J1=Func(gamma);
    nFuncEval=nFuncEval+1;
end





CtrlVar.BacktrackingGammaMin=CtrlVar.Inverse.MinimumAbsoluteLineSearchStepSize;
CtrlVar.BackTrackMinXfrac=CtrlVar.Inverse.MinimumRelativelLineSearchStepSize;
CtrlVar.BackTrackMaxIterations=CtrlVar.Inverse.MaximumNumberOfLineSeachSteps;
CtrlVar.InfoLevelBackTrack=CtrlVar.Inverse.InfoLevel;



It0=RunInfo.Inverse.Iterations(end);

fprintf('\n   It   #fEval      J           I          R         |grad|      gamma   #cgUpdate\n')
%fprintf('123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890\n')

fprintf('%5i  %5i %10g  %10g  %10g  %10g  %10g  %5i\n',It0,nFuncEval,J0,fOuts.MisfitOuts.I,fOuts.RegOuts.R,GradNorm,gamma,RunInfo.Inverse.ConjGradUpdate)
CtrlVar.GradientUpgradeMethod=CtrlVar.Inverse.GradientUpgradeMethod;

iBackTry=0;

for It=1:CtrlVar.Inverse.Iterations
    
    CtrlVar.BackTrackExtrapolationRatio=10;
    CtrlVar.NewtonAcceptRatio=0.90;
    [gamma,JgammaNew,BackTrackingInfoVector]=BackTracking(slope0,gamma,J0,J1,Func,CtrlVar);
    nFuncEval=nFuncEval+BackTrackingInfoVector.nFuncEval;
    
    if ~BackTrackingInfoVector.converged
        
        fprintf(' Line search has stagnated. \n')
        fprintf(' Try resetting step size and using direction of steepest decent. \n')
        slope0=-dJdp'*dJdp; gamma=-0.01*J0/slope0 ;  % modification on 20 Jan, 2019. Resetting gamma
        dJdpModified=dJdp;
        RunInfo.Inverse.ConjGradUpdate=0;
        Func=@(gamma) func(p-gamma*dJdpModified);
        J1=Func(gamma);
        
        [gamma,JgammaNew,BackTrackingInfoVector]=BackTracking(slope0,gamma,J0,J1,Func,CtrlVar);
        nFuncEval=nFuncEval+BackTrackingInfoVector.nFuncEval;
        
        if ~BackTrackingInfoVector.converged
            fprintf(' Resetting step size to 1 and using steepest decent did not help, now breaking out.\n')
            break
        end
        
    end
    %
%     if BackTrackingInfoVector.converged
%         iBackTry=0;   % After returning from a successful backtracking, update p
%         p=p-gamma*dJdpModified;
%         dJdpLast=dJdp;
%     else
%         fprintf(' Line search has stagnated,')
%         iBackTry=iBackTry+1;
%         if iBackTry==1
%             fprintf(' try resetting step size to 1.\n')
%             gamma=1;
%             continue
%         else
%             fprintf(' and resetting step size to 1 did not help, now breaking out.\n')
%             break
%         end
%     end
    
    p=p-gamma*dJdpModified;
    p=kk_proj(p,pub,plb);
    dJdpLast=dJdp;
    % Get new directional derivative
    [J0,dJdp,Hess,fOuts]=func(p);       
    nFuncEval=nFuncEval+1; % here J0 and JgammaNew must be (almost) equal

    GradNorm=norm(dJdp)/sqrt(numel(dJdp));
    
    % update search direction.
  
    
    fprintf('%5i  %5i %10g  %10g  %10g  %10g  %10g  %5i\n',It+It0,nFuncEval,J0,fOuts.MisfitOuts.I,fOuts.RegOuts.R,GradNorm,gamma,RunInfo.Inverse.ConjGradUpdate)
    
    RunInfo.Inverse.Iterations=[RunInfo.Inverse.Iterations;RunInfo.Inverse.Iterations(end)+1];
    RunInfo.Inverse.J=[RunInfo.Inverse.J;J0];
    RunInfo.Inverse.R=[RunInfo.Inverse.R;fOuts.RegOuts.R];
    RunInfo.Inverse.I=[RunInfo.Inverse.I;fOuts.MisfitOuts.I];
    RunInfo.Inverse.GradNorm=[RunInfo.Inverse.GradNorm;GradNorm];
    RunInfo.Inverse.StepSize=[RunInfo.Inverse.StepSize;gamma];
    
    if CtrlVar.Inverse.StoreSolutionAtEachIteration
        RunInfo.Inverse.p{It+1}=p;
    end
    
    if norm(dJdp) < eps
        norm(dJdp)
        fprintf('UaOptimisation: norm of gradient of the objective function smaller than epsilon.\n')
        fprintf('Exciting inverse optimisation step. \n')
        return
    end
    
    [dJdpModified,RunInfo]=NextGradient(dJdp,dJdpLast,dJdpModified,CtrlVar,RunInfo);
    
    
    
    
    Func=@(gamma) func(p-gamma*dJdpModified);
    % J0=F(0);  This is not needed because I've calculated J0 as I determined the new gradient.
    
    J1=Func(gamma);
    
    if isnan(J1)
        slope0=-dJdp'*dJdp; gamma=-0.01*J0/slope0 ;  % modification on 20 Jan, 2019. Resetting gamma
        J1=Func(gamma);
    end
    
    
end

end
