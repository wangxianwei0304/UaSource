
function [UserVar,F,l,InvFinalValues,RunInfo]=...
    InvertForModelParameters(UserVar,CtrlVar,MUA,BCs,F,l,InvStartValues,Priors,Meas,BCsAdjoint,RunInfo)

narginchk(11,11)

InvFinalValues=InvStartValues;

if isempty(CtrlVar.Inverse.InitialLineSearchStepSize) ||  CtrlVar.Inverse.InitialLineSearchStepSize==0
    CtrlVar.Inverse.InitialLineSearchStepSize=InvStartValues.SearchStepSize;
end


%% Consider adding some test of input variables here, maybe see if all gs,ga fields are defined

%% Define inverse parameters and anonymous function returning objective function, directional derivative, and Hessian
%


F.AGlen=InvStartValues.AGlen ; F.AGlenmin=Priors.AGlenmin;  F.AGlenmax=Priors.AGlenmax; 
F.C=InvStartValues.C ; F.Cmin=Priors.Cmin;  F.Cmax=Priors.Cmax; 
F.b=InvStartValues.b ; F.bmin=Priors.bmin;  F.bmax=Priors.bmax; 



% p is the vector of the control variables, currenty p=[A,b,C]
% with A, b or C here only being nonempty when inverted for, 
% This mapping between A, b and C into the control variable is done by F2p
[p0,plb,pub]=F2p(CtrlVar,F); 

CtrlVar.Inverse.ResetPersistentVariables=1;
[J0,dJdp,Hessian,JGHouts,F]=JGH(p0,UserVar,CtrlVar,MUA,BCs,F,l,InvStartValues,Priors,Meas,BCsAdjoint,RunInfo);

% The parameters passed in the anonymous function are those that exist at the time the anonymous function is created.


CtrlVar.WriteRunInfoFile=0;
func=@(p) JGH(p,UserVar,CtrlVar,MUA,BCs,F,l,InvStartValues,Priors,Meas,BCsAdjoint,RunInfo);

fprintf('\n +++++++++++ At start of inversion:  \t J=%-g \t I=%-g \t R=%-g  |grad|=%g \n \n',J0,JGHouts.MisfitOuts.I,JGHouts.RegOuts.R,norm(dJdp))

dJdpTest=[];
CtrlVar.Inverse.ResetPersistentVariables=0;
%%

if CtrlVar.Inverse.TestAdjoint.isTrue
    
    
    % Get the gradient using the adjoint method
    [J,dJdp,Hessian,JGHouts]=func(p0);
    
    
    NA=numel(InvStartValues.AGlen);  % Number of A parameters to invert for
    
    if isempty(CtrlVar.Inverse.TestAdjoint.iRange)
        iRange=1:NA;
    else
        iRange=CtrlVar.Inverse.TestAdjoint.iRange;
    end
    
    switch strlength(CtrlVar.Inverse.InvertForField)
        
        case 2
            iRange=[iRange(:);iRange(:)+NA];
        case 3
            iRange=[iRange(:);iRange(:)+NA;iRange(:)+2*NA];
    end

    I=(iRange>=1) & (iRange <= numel(p0));
    iRange=iRange(I);
    
    % calc brute force gradient
    
    deltaStep=CtrlVar.Inverse.TestAdjoint.FiniteDifferenceStepSize*norm(p0);
    
    if CtrlVar.Inverse.InvertForField=="b"  % Must modify
        deltaStep=CtrlVar.Inverse.TestAdjoint.FiniteDifferenceStepSize*mean(F.h);
        %deltaStep=1;
    end
    
    dJdpTest = CalcBruteForceGradient(func,p0,CtrlVar,iRange,deltaStep);
    
else
    
    
    %%
    
    switch CtrlVar.Inverse.MinimisationMethod
        
        case 'UaOptimization'
            
            [p,RunInfo]=UaOptimisation(CtrlVar,func,p0,plb,pub,RunInfo);

        case 'MatlabOptimization'
            
            clear fminconOutputFunction fminconHessianFcn fminuncOutfun
            
            [p,RunInfo]=InversionUsingMatlabOptimizationToolbox3(CtrlVar,func,p0,plb,pub,RunInfo);
            
        otherwise
            
            fprintf(' CtrlVar.Inverse.MinimisationMethod has the value %s \n',CtrlVar.Inverse.MinimisationMethod)
            fprintf(' but can only have the values ''MatlabOptimization'' or ''UaOptimization''\n')
            error('what case? ')
    end
 
    F=p2F(CtrlVar,p,F); 
    [J,dJdp,Hessian,JGHouts,F]=JGH(p,UserVar,CtrlVar,MUA,BCs,F,l,InvStartValues,Priors,Meas,BCsAdjoint,RunInfo);
    fprintf('\n +++++++++++ At end of inversion:  \t J=%-g \t I=%-g \t R=%-g  |grad|=%g \n \n',J,JGHouts.MisfitOuts.I,JGHouts.RegOuts.R,norm(dJdp))
  
    
end


InvFinalValues=Vars2InvValues(CtrlVar,F,InvFinalValues,J,dJdp,JGHouts,RunInfo,dJdpTest); 


end
