function Ua2D(UserVar)

%% Driver for the 2HD �a model
% Ua2D(UserRunParameters)
%
%

if nargin==0
    UserVar=[];
end


SetUaPath() %% set path

if ~exist(fullfile(cd,'Ua2D_InitialUserInput.m'),'file')
    
    fprintf('The input-file Ua2D_InitialUserInput.m not found in the working directory (%s).\n',pwd)
    fprintf('This input-file is required for Ua to run.\n')
    return
    
end

warning('off','MATLAB:triangulation:PtsNotInTriWarnId')

%% initialize some variables
Info=UaRunInfo;
l=UaLagrangeVariables; 
Fm1=UaFields;
% these are the Lagrange variables assosiated with boundary conditions.
% not to be confused with the Lagrange variables assosiated with solving the
% adjoint problem

RunInfo=[];
Lubvb=[];
Ruv=[];

tTime=tic;


%% Define default values
CtrlVar=Ua2D_DefaultParameters();


%% Get user-defined parameter values
%  CtrlVar,UsrVar,Info,UaOuts
[UserVar,CtrlVar,MeshBoundaryCoordinates]=Ua2D_InitialUserInput(UserVar,CtrlVar);


CtrlVar.MeshBoundaryCoordinates=MeshBoundaryCoordinates;
clearvars MeshBoundaryCoordinates;

%%

if ~isfield(CtrlVar,'fidlog')
    CtrlVar.fidlog=1;
end



% do some basic test on the vality of the CtrlVar fields
CtrlVar=CtrlVarValidityCheck(CtrlVar);

% if a log file is created, the this will be the name of the logfile
CtrlVar.Logfile=[CtrlVar.Experiment,'.log'];
[status,message]=copyfile(CtrlVar.Logfile,[CtrlVar.Logfile,'~']);  %  copy potential previous logfile

[pathstr,name]=fileparts(CtrlVar.GmshFile); CtrlVar.GmshFile=[pathstr,name]; % get rid of eventual file extension

%%  A RunInfo file is created and some basic information about the run is added to that file
%   Inspecting the contents of this run info file is sometimes a convenient way of
%   checking the status of the run.

FileName=[CtrlVar.Experiment,'-RunInfo.txt'];
if CtrlVar.Restart
    CtrlVar.InfoFile = fopen(FileName,'a');
else
    CtrlVar.InfoFile = fopen(FileName,'w');
end


if CtrlVar.InfoFile<0
   fprintf('opening the file %s resulted in an error:\n',FileName)
   disp(errmsh)
   error('Error opening a file. Possibly problems with permissions.')
end
    

%%  Now initial information about the run has been defined
% write out some basic information about the type of run selected
PrintRunInfo(CtrlVar);


%% Get input data
if ~CtrlVar.InverseRun %  forward run
    
    if CtrlVar.Restart  % Forward restart run
        
        [UserVar,CtrlVarInRestartFile,MUA,BCs,F,l,RunInfo]=GetInputsForForwardRestartRun(UserVar,CtrlVar);
        
        
        % When reading the restart file the restart values of CtrlVar are all discarded,
        % however:
        CtrlVar.time=CtrlVarInRestartFile.time;
        CtrlVar.RestartTime=CtrlVarInRestartFile.time;
        CtrlVar.dt=CtrlVarInRestartFile.dt;
        CtrlVar.CurrentRunStepNumber=CtrlVarInRestartFile.CurrentRunStepNumber;
        
        
        clearvars time dt CurrentRunStepNumber
        
        
    else % New forward run (ie not a restart)
        
        [UserVar,MUA,BCs,F,l]=GetInputsForForwardRun(UserVar,CtrlVar);
        
        if CtrlVar.OnlyMeshDomainAndThenStop
            return
        end
    end
    
else % inverse run
    
    if CtrlVar.Restart %  inverse restart run
        
        [UserVar,MUA,BCs,s,b,S,B,ub,vb,ud,vd,l,alpha,rho,rhow,g,InvStartValues,Priors,Meas,BCsAdjoint,Info]=...
            GetInputsForInverseRestartRun(UserVar,CtrlVar);
        
    else % New inverse run

        % First get the usual input for a forward run
        [UserVar,MUA,BCs,F,l]=GetInputsForForwardRun(UserVar,CtrlVar);
        
        % now get the additional variables specific to an inverse run
        [UserVar,InvStartValues,Priors,Meas,BCsAdjoint]=GetInputsForInverseRun(UserVar,CtrlVar,MUA,BCs,F,l); %CtrlVar.time,AGlen,C,n,m,s,b,S,B,rho,rhow,GF,g,alpha,ub,vb,ud,vd,l);
        
         
        
    end
end

if CtrlVar.TestUserInputs==1
    CtrlVar.TestUserInputs=0;
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%    now all data specific to particular runs should have been defined %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%  For convenience I assume that the user defines S, B, s and b.  The
%  program then calculates h=s-b and then s and b from h, B and S given the
%  ice and ocean specific density.  The thickness is preserved, and s and b
%  are consistent with the floating condition for a given ice tickness h, rho and rhow.

F.h=F.s-F.b;
[F.b,F.s,F.h,GF]=Calc_bs_From_hBS(CtrlVar,MUA,F.h,F.S,F.B,F.rho,F.rhow);
%GF=GL2d(F.B,F.S,F.h,F.rhow,F.rho,MUA.connectivity,CtrlVar);



% pointers to the elements of Boundary.Edges where u and v are fixed
% Boundary.uFixedEdgesAllPtrs=logical(prod(double(ismember(Boundary.Edges,ufixednode)')));
% Boundary.vFixedEdgesAllPtrs=logical(prod(double(ismember(Boundary.Edges,vfixednode)')));
% xint, yint :  matrices of coordinates of integration points. Nele  x nip
% Xint, Yint :  vectors of unique coordinates of integration points
% [DTxy,TRIxy,DTint,TRIint,Xint,Yint,xint,yint,Iint]=TriangulationNodesIntegrationPoints(MUA);


%%
if CtrlVar.doInverseStep   % -inverse
    
    %         [db,dc] = Deblurr2D(NaN,...
    %             s,u,v,b,B,...
    %             sMeas,uMeas,vMeas,wMeas,bMeas,BMeas,xMeas,yMeas,...
    %             Experiment,...
    %             coordinates,connectivity,Nnodes,Nele,nip,nod,etaInt,gfint,AGlen,C,...
    %             Luv,Luvrhs,lambdauv,n,m,alpha,rho,rhow,g,nStep);
    %
    %x=coordinates(:,1); y=coordinates(:,2); DT = DelaunayTri(x,y); TRI=DT.Triangulation;
    %figure(21) ; trisurf(TRI,x/CtrlVar.PlotXYscale,y/CtrlVar.PlotXYscale,h) ;  title(' h')
    
    [UserVar,F,l,InvFinalValues,xAdjoint,yAdjoint,RunInfo]=InvertForModelParameters(UserVar,CtrlVar,MUA,BCs,F,l,GF,InvStartValues,Priors,Meas,BCsAdjoint,RunInfo);
    
    
    F.C=InvFinalValues.C          ; fprintf(CtrlVar.fidlog,' C set equal to InvFinalValues.C \n ');
    F.AGlen=InvFinalValues.AGlen  ; fprintf(CtrlVar.fidlog,' AGlen set equal InvFinalValues.AGlen \n ');
    F.m=InvFinalValues.m ; 
    F.n=InvFinalValues.n ;
    
    
    % this calculation not really needed as AdjointNR2D should return converged ub,vb,ud,vd values for Cest and AGlenEst
    
    
    
    if CtrlVar.doplots
        AdjointResultsPlots(UserVar,CtrlVar,MUA,BCs,s,b,h,S,B,ub,vb,ud,vd,l,alpha,rho,rhow,g,GF,...
            InvStartValues,Priors,Meas,BCsAdjoint,Info,InvFinalValues,xAdjoint,yAdjoint);
    end
    
    if CtrlVar.AdjointWriteRestartFile
        
        WriteAdjointRestartFile();
        
    end
    
    CtrlVar.UaOutputsInfostring='End of Inverse Run';
    CtrlVar.UaOutputsCounter=1;
    
    fprintf(' Calling UaOutputs. UaOutputsInfostring=%s , UaOutputsCounter=%i \n ',CtrlVar.UaOutputsInfostring,CtrlVar.UaOutputsCounter)
    
    UserVar=CreateUaOutputs(UserVar,CtrlVar,MUA,BCs,F,l,GF);
    SayGoodbye(CtrlVar);
    return  % This is the end of the (inverse) run
    
end

%% UaOutputs
CtrlVar.UaOutputsCounter=0;
if (ReminderFraction(CtrlVar.time,CtrlVar.UaOutputsDt)<1e-5 || CtrlVar.UaOutputsDt==0 )
    CtrlVar.UaOutputsInfostring='First call';
    CtrlVar.UaOutputsCounter=CtrlVar.UaOutputsCounter+1;
    
    fprintf(' Calling UaOutputs. UaOutputsInfostring=%s , UaOutputsCounter=%i \n ',CtrlVar.UaOutputsInfostring,CtrlVar.UaOutputsCounter)
    UserVar=CreateUaOutputs(UserVar,CtrlVar,MUA,BCs,F,l,GF);
    
    if CtrlVar.UaOutputsCounter>=CtrlVar.UaOutputsMaxNrOfCalls
        fprintf(' Exiting because number of calls to UaOutputs (%i) >= CtrlVar.UaOutputsMaxNrOfCalls (%i) /n',...
            CtrlVar.UaOutputsCounter,CtrlVar.UaOutputsMaxNrOfCalls)
        return
    end
end
%


CtrlVar.CurrentRunStepNumber0=CtrlVar.CurrentRunStepNumber;


%%  time loop
while 1
    
    if CtrlVar.CurrentRunStepNumber >=( CtrlVar.TotalNumberOfForwardRunSteps+CtrlVar.CurrentRunStepNumber0)
        fprintf('Exiting time loop because total number of steps reached. \n')
        break
    end
    
    if (CtrlVar.TotalTime - CtrlVar.time) <= CtrlVar.dtmin
        fprintf('Exiting time loop because total time reached. \n')
        break
    end
    
    if CtrlVar.TimeDependentRun && CtrlVar.dt <= CtrlVar.dtmin % I limit dt some small value for numerical reasons
        fprintf('Exiting time loop because time step too small (%g<%g)\n',CtrlVar.dt,CtrlVar.dtmin)
        TempFile=[CtrlVar.Experiment,'-UaDumpTimeStepTooSmall.mat']; fprintf(CtrlVar.fidlog,' saving variables in %s \n ',TempFile) ; save(TempFile,'-v7.3')
        break
    end
    
    
    CtrlVar.CurrentRunStepNumber=CtrlVar.CurrentRunStepNumber+1;
    if CtrlVar.InfoLevel >= 1 ; fprintf('\n ======> Current run step: %i <======\n',CtrlVar.CurrentRunStepNumber) ;  end
    
    if CtrlVar.PlotWaitBar 
        multiWaitbar('Run steps','Value',(CtrlVar.CurrentRunStepNumber-1-CtrlVar.CurrentRunStepNumber0)/CtrlVar.TotalNumberOfForwardRunSteps);
        multiWaitbar('Time','Value',CtrlVar.time/CtrlVar.TotalTime);
    end
    
    MUA=UpdateMUA(CtrlVar,MUA);
    
    % -adapt time step
    if CtrlVar.TimeDependentRun
        [RunInfo,CtrlVar.dt,CtrlVar.dtRatio]=AdaptiveTimeStepping(RunInfo,CtrlVar,CtrlVar.time,CtrlVar.dt);
    end
    
    
    if CtrlVar.doDiagnostic
        if CtrlVar.InDiagnosticRunsDefineIceGeometryAtEveryRunStep
            [UserVar,F.s,F.b,F.S,F.B,F.alpha]=GetGeometry(UserVar,CtrlVar,MUA,CtrlVar.time,'sbSB');
            F.h=F.s-F.b;
        end
    elseif CtrlVar.DefineOceanSurfaceAtEachTimeStep
        [UserVar,~,~,F.S,~,~]=GetGeometry(UserVar,CtrlVar,MUA,CtrlVar.time,'S');
    end
    
    [F.b,F.s,F.h,GF]=Calc_bs_From_hBS(CtrlVar,MUA,F.h,F.S,F.B,F.rho,F.rhow);

    [UserVar,F]=GetSlipperyDistribution(UserVar,CtrlVar,MUA,F,GF);
    [UserVar,F]=GetAGlenDistribution(UserVar,CtrlVar,MUA,F,GF);

    if CtrlVar.UpdateBoundaryConditionsAtEachTimeStep
        [UserVar,BCs]=GetBoundaryConditions(UserVar,CtrlVar,MUA,BCs,F,GF);
        F=StartVelocity(CtrlVar,MUA,BCs,F);  % start velocity might be a function of GF
    end
    
    
    %% adaptive meshing, adapt mesh, adapt-mesh
    if CtrlVar.AdaptMesh || CtrlVar.TimeGeometries.Flag ||  CtrlVar.FEmeshAdvanceRetreat
        

        [UserVar,RunInfo,MUA,BCs,F,l,GF]=AdaptMesh(UserVar,RunInfo,CtrlVar,MUA,BCs,F,l,GF,Ruv,Lubvb);
        CtrlVar.AdaptMeshInitial=0;
        
        if MUA.Nele==0 
            fprintf('FE mesh is empty \n ')
            break ;
        end
        
        if CtrlVar.AdaptMeshAndThenStop
            
            
            if CtrlVar.doplots  && CtrlVar.PlotMesh
                figure ; PlotFEmesh(MUA.coordinates,MUA.connectivity,CtrlVar)
            end
            
            save(CtrlVar.SaveInitialMeshFileName,'MUA') ;
            fprintf(CtrlVar.fidlog,' MUA was saved in %s .\n',CtrlVar.SaveInitialMeshFileName);
            fprintf('Exiting after remeshing because CtrlVar.AdaptMeshAndThenStop set to true. \n ')
            return
        end
        
    end
    
    %%
    
    [UserVar,F]=GetMassBalance(UserVar,CtrlVar,MUA,F,GF);
    
    
    if ~CtrlVar.TimeDependentRun % Time independent run.  Solving for velocities for a given geometry (diagnostic steo).
        
        %% Diagnostic calculation (uv)
        if CtrlVar.InfoLevel >= 1 ; fprintf(CtrlVar.fidlog,' ==> Time independent step. Current run step: %i \n',CtrlVar.CurrentRunStepNumber) ;  end

        
        [UserVar,RunInfo,F,l,Kuv,Ruv,Lubvb]= uv(UserVar,RunInfo,CtrlVar,MUA,BCs,F,l);
 

    else   % Time-dependent run
        
        %        0  : values at t      This is F0 
        %        1  : values at t+dt   This is F. 
        %       at start, F is explicit guess for values at t+dt
        %       an end,   F are converged values at t+dt
        
        if CtrlVar.Implicituvh % Fully implicit time-dependent step (uvh)
          
           
            
            fprintf(CtrlVar.fidlog,...
                '\n ===== Implicit uvh going from t=%-.10g to t=%-.10g with dt=%-g. Done %-g %% of total time, and  %-g %% of steps. \n ',...
                CtrlVar.time,CtrlVar.time+CtrlVar.dt,CtrlVar.dt,100*CtrlVar.time/CtrlVar.TotalTime,100*(CtrlVar.CurrentRunStepNumber-1-CtrlVar.CurrentRunStepNumber0)/CtrlVar.TotalNumberOfForwardRunSteps);
            
            if CtrlVar.InitialDiagnosticStep   % if not a restart step, and if not explicitly requested by user, then do not do an inital dignostic step
                %% diagnostic step, solving for uv.  Always needed at a start of a transient run. Also done if asked by the user.
                CtrlVar.InitialDiagnosticStep=0;
                
                fprintf(CtrlVar.fidlog,' initial diagnostic step at t=%-.15g \n ',CtrlVar.time);
                
                [UserVar,RunInfo,F,l,Kuv,Ruv,Lubvb]= uv(UserVar,RunInfo,CtrlVar,MUA,BCs,F,l);
                
                
                %ub0=ub ; ud0=ud ; vb0=vb ; vd0=vd;
                
                
                if (ReminderFraction(CtrlVar.time,CtrlVar.UaOutputsDt)<1e-5 || CtrlVar.UaOutputsDt==0 )
                    CtrlVar.UaOutputsInfostring='Diagnostic step';
                    CtrlVar.UaOutputsCounter=CtrlVar.UaOutputsCounter+1;
                    fprintf(' Calling UaOutputs. UaOutputsInfostring=%s , UaOutputsCounter=%i \n ',CtrlVar.UaOutputsInfostring,CtrlVar.UaOutputsCounter)
                    
                    UserVar=CreateUaOutputs(UserVar,CtrlVar,MUA,BCs,F,l,GF);
                    if CtrlVar.UaOutputsCounter>=CtrlVar.UaOutputsMaxNrOfCalls
                        fprintf(' Exiting because number of calls to UaOutputs (%i) >= CtrlVar.UaOutputsMaxNrOfCalls (%i) /n',...
                            CtrlVar.UaOutputsCounter,CtrlVar.UaOutputsMaxNrOfCalls)
                        return
                    end
                end
            end
            
            F0=F;  % 
            
            
            %% get an explicit estimate for u, v and h at the end of the time step
            
            %
            % F0 is the converged solution from the previous time step
            % F0.dubdt is based on F0 and the previous solution to F0, which is referred to as Fm1, but is not saved 
            % F0.dubdt=(F0.ub-Fm1.ub)/dt  (where dt is the time step between Fm1 and F0.)
            %
            
            F=ExplicitEstimationForUaFields(CtrlVar,F,F0,Fm1);
            %[ub1,vb1,ud1,vd1,h1]=ExplicitEstimation(CtrlVar.dt,dtRatio,CtrlVar.CurrentRunStepNumber,F.ub,F.dubdt,F.dubdtm1,F.vb,F.dvbdt,F.dvbdtm1,F.ud,F.duddt,F.duddtm1,F.vd,F.dvddt,F.dvddtm1,F.h,F.dhdt,F.dhdtm1);
            
            %% advance the solution by dt using a fully implicit method with respect to u,v and h
            uvhStep=1;
            while uvhStep==1  && CtrlVar.dt > CtrlVar.dtmin % if uvh step does not converge, it is repeated with a smaller dt value
                CtrlVar.time=CtrlVar.time+CtrlVar.dt;  % I here need the mass balance at the end of the time step, hence must increase t
                [UserVar,F]=GetMassBalance(UserVar,CtrlVar,MUA,F,GF);
                CtrlVar.time=CtrlVar.time-CtrlVar.dt; % and then take it back to t at the beginning. 

               
                %Fguessed=F;  could use norm of difference between explicit and implicit to
                %control dt
                [UserVar,RunInfo,F,l,BCs,GF,dt]=uvh(UserVar,RunInfo,CtrlVar,MUA,F0,F,l,l,BCs); 
                
                CtrlVar.dt=dt;
                
                if RunInfo.converged==0
                    
                    uvhStep=1;  % continue within while loop
                    
                    fprintf(CtrlVar.fidlog,' Warning : Reducing time step from %-g to %-g \n',CtrlVar.dt,CtrlVar.dt/10);
                    CtrlVar.dt=CtrlVar.dt/10;
                    l.ubvb=l.ubvb*0; l.h=l.h*0;
                    F.s=F0.s ; F.b=F0.b ; F.h=F0.h;   
                    F.ub=F.ub*0; F.vb=F.vb*0; F.ud=F.ud*0;F.vd=F.vd*0;
                    l.ubvb=l.ubvb*0; l.h=l.h*0;
                else
                    uvhStep=0;
                end
            end
            
            CtrlVar.time=CtrlVar.time+CtrlVar.dt;
            %CtrlVar.time=round(CtrlVar.time,14,'significant');
            
            [F.b,F.s,F.h,GF]=Calc_bs_From_hBS(CtrlVar,MUA,F.h,F.S,F.B,F.rho,F.rhow);  % This should not be needed as uvh already takes care of this.
            %[F.b,F.s,F.h]=Calc_bs_From_hBS(F.h,F.S,F.B,F.rho,F.rhow,CtrlVar,MUA.coordinates);
            
            Fm1.dhdt=F0.dhdt ;
            Fm1.dubdt=F0.dubdt ; Fm1.dvbdt=F0.dvbdt;
            Fm1.duddt=F0.duddt ; Fm1.dvddt=F0.dvddt;
            
            if CtrlVar.dt==0
                F.dhdt=[];
                F.dubdt=[]; F.dvbdt=[];
                F.dsdt=[] ; F.dbdt=[];
            else
                F.dhdt=(F.h-F0.h)/CtrlVar.dt;
                F.dsdt=(F.s-F0.s)/CtrlVar.dt;
                F.dbdt=(F.b-F0.b)/CtrlVar.dt;
                F.dubdt=(F.ub-F0.ub)/CtrlVar.dt ; F.dvbdt=(F.vb-F0.vb)/CtrlVar.dt;
                F.duddt=(F.ud-F0.ud)/CtrlVar.dt ; F.dvddt=(F.vd-F0.vd)/CtrlVar.dt;
            end
            

            % at the beginning of next times step update:  F0=F1   
            
            
            
        elseif ~CtrlVar.Implicituvh % Semi-implicit time-dependent step. Implicit with respect to h, explicit with respect to u and v.
            
            if CtrlVar.InfoLevel>0 ; fprintf(CtrlVar.fidlog,'Semi-implicit transient step. Advancing time from t=%-g to t=%-g \n',CtrlVar.time,CtrlVar.time+CtrlVar.dt);end
            
            %% Diagnostic calculation (uv)
            if CtrlVar.InfoLevel >= 1 ; fprintf(CtrlVar.fidlog,' ==> Diagnostic step (uv). Current run step: %i \n',CtrlVar.CurrentRunStepNumber) ;  end
            tSemiImplicit=tic;                  % -uv
            
            % Solving the momentum equations for uv at the beginning of the time interval
             
            F0=F;
            
            [UserVar,RunInfo,F,F0,l,Kuv,Ruv,Lubvb]= uvhSemiImplicit(UserVar,RunInfo,CtrlVar,MUA,BCs,F0,Fm1,l);

            Fm1.dhdt=F0.dhdt ;
            Fm1.dubdt=F0.dubdt ; Fm1.dvbdt=F0.dvbdt;
            Fm1.duddt=F0.duddt ; Fm1.dvddt=F0.dvddt;
                      
            CtrlVar.time=CtrlVar.time+CtrlVar.dt;
            CtrlVar.time=round(CtrlVar.time,14,'significant');
            
            %CtrlVar.hChange=1; CtrlVar.s=1; % h and s just changed
            tSemiImplicit=toc(tSemiImplicit);
            if CtrlVar.InfoLevel >= 1 && fprintf(CtrlVar.fidlog,'SSTREAM semi-implicit step in %-g sec \n ',tSemiImplicit) ; end
        end
    end
    
    %% calculations for this step are now done, only some plotting/writing issues do deal with
    
    % calculating derived quantities
    
    GF = GL2d(F.B,F.S,F.h,F.rhow,F.rho,MUA.connectivity,CtrlVar);
    
  
    %% plotting results
    
    % UaOutputs
    
    if (ReminderFraction(CtrlVar.time,CtrlVar.UaOutputsDt)<1e-5 || CtrlVar.UaOutputsDt==0 )
        CtrlVar.UaOutputsInfostring='inside transient loop and inside run-step loop';
        CtrlVar.UaOutputsCounter=CtrlVar.UaOutputsCounter+1;
        
        if CtrlVar.MassBalanceGeometryFeedback>0
            CtrlVar.time=CtrlVar.time+CtrlVar.dt;  % I here need the mass balance at the end of the time step, hence must increase t
            [UserVar,F]=GetMassBalance(UserVar,CtrlVar,MUA,F,GF);
            CtrlVar.time=CtrlVar.time-CtrlVar.dt; % and then take it back to t at the beginning. 
            %[UserVar,as,ab,dasdh,dabdh]=GetMassBalance(UserVar,CtrlVar,MUA,CtrlVar.time+CtrlVar.dt,s,b,h,S,B,rho,rhow,GF);
        end
        
        fprintf(' Calling UaOutputs. UaOutputsInfostring=%s , UaOutputsCounter=%i \n ',CtrlVar.UaOutputsInfostring,CtrlVar.UaOutputsCounter)
        
        UserVar=CreateUaOutputs(UserVar,CtrlVar,MUA,BCs,F,l,GF);
        %UserVar=CreateUaOutputs(UserVar,CtrlVar,MUA,s,b,S,B,h,ub,vb,ud,vd,uo,vo,dhdt,dsdt,dbdt,C,AGlen,m,n,rho,rhow,g,as,ab,dasdh,dabdh,GF,BCs,l);
        
        if CtrlVar.UaOutputsCounter>=CtrlVar.UaOutputsMaxNrOfCalls
            fprintf(' Exiting because number of calls to UaOutputs (%i) >= CtrlVar.UaOutputsMaxNrOfCalls (%i) /n',...
                CtrlVar.UaOutputsCounter,CtrlVar.UaOutputsMaxNrOfCalls)
            return
        end
    end
    
    if CtrlVar.WriteRestartFile==1 && mod(CtrlVar.CurrentRunStepNumber,CtrlVar.WriteRestartFileInterval)==0
        WriteRestartFile()
    end
    
    
    
  
    
end

if CtrlVar.PlotWaitBar
    multiWaitbar('Run steps','Value',(CtrlVar.CurrentRunStepNumber-CtrlVar.CurrentRunStepNumber0)/CtrlVar.TotalNumberOfForwardRunSteps);
    multiWaitbar('Time','Value',CtrlVar.time/CtrlVar.TotalTime);
end


%% plotting results

%[etaInt,xint,yint,exx,eyy,exy,Eint,e,txx,tyy,txy]=calcStrainRatesEtaInt(CtrlVar,MUA,ub,vb,AGlen,n);
%[wSurf,wSurfInt,wBedInt,wBed]=calcVerticalSurfaceVelocity(rho,rhow,h,S,B,b,ub,vb,as,ab,exx,eyy,xint,yint,MUA.coordinates,MUA.connectivity,MUA.nip,CtrlVar);

if (ReminderFraction(CtrlVar.time,CtrlVar.UaOutputsDt)<1e-5 || CtrlVar.UaOutputsDt==0 )
    CtrlVar.UaOutputsInfostring='Last call';
    CtrlVar.UaOutputsCounter=CtrlVar.UaOutputsCounter+1;
    if CtrlVar.MassBalanceGeometryFeedback>0
        CtrlVar.time=CtrlVar.time+CtrlVar.dt;
        [UserVar,F]=GetMassBalance(UserVar,CtrlVar,MUA,F,GF);
        CtrlVar.time=CtrlVar.time-CtrlVar.dt;
        %[UserVar,as,ab,dasdh,dabdh]=GetMassBalance(UserVar,CtrlVar,MUA,CtrlVar.time+CtrlVar.dt,s,b,h,S,B,rho,rhow,GF);
    end
    
    fprintf(' Calling UaOutputs. UaOutputsInfostring=%s , UaOutputsCounter=%i \n ',CtrlVar.UaOutputsInfostring,CtrlVar.UaOutputsCounter)
    UserVar=CreateUaOutputs(UserVar,CtrlVar,MUA,BCs,F,l,GF);
    %UserVar=CreateUaOutputs(UserVar,CtrlVar,MUA,s,b,S,B,h,ub,vb,ud,vd,uo,vo,dhdt,dsdt,dbdt,C,AGlen,m,n,rho,rhow,g,as,ab,dasdh,dabdh,GF,BCs,l);
    if CtrlVar.UaOutputsCounter>=CtrlVar.UaOutputsMaxNrOfCalls
        fprintf(' Exiting because number of calls to UaOutputs (%i) >= CtrlVar.UaOutputsMaxNrOfCalls (%i) /n',...
            CtrlVar.UaOutputsCounter,CtrlVar.UaOutputsMaxNrOfCalls)
        return
    end
end



%% saving outputs

if CtrlVar.WriteRestartFile==1 &&  mod(CtrlVar.CurrentRunStepNumber,CtrlVar.WriteRestartFileInterval)~=0
    
    WriteRestartFile()
    
end

if CtrlVar.PlotWaitBar ;     multiWaitbar('CloseAll'); end
tTime=toc(tTime); fprintf(CtrlVar.fidlog,' Total time : %-g sec \n',tTime) ;


if CtrlVar.fidlog~= 1 ; fclose(CtrlVar.fidlog); end
fclose(CtrlVar.InfoFile);

SayGoodbye(CtrlVar)

%% nested functions


    function WriteRestartFile
        RestartFile=CtrlVar.NameOfRestartFiletoWrite;
        fprintf(CtrlVar.fidlog,' \n ################## %s %s ################### \n Writing restart file %s  at t=%-g \n %s \n ',CtrlVar.Experiment,datestr(now),RestartFile,CtrlVar.time);
        %[DTxy,TRIxy]=TriangulationNodesIntegrationPoints(MUA);
        CtrlVarInRestartFile=CtrlVar;
        UserVarInRestartFile=UserVar;
        nStep=CtrlVar.CurrentRunStepNumber;  % later get rid of nStep from all restart files
        Itime=CtrlVar.CurrentRunStepNumber;  % later get rid of Itime from all restart files
        time=CtrlVar.time;
        dt=CtrlVar.dt;
        try
            save(RestartFile,'CtrlVarInRestartFile','UserVarInRestartFile','MUA','BCs','time','dt','F','GF','l','RunInfo','-v7.3');

            fprintf(CtrlVar.fidlog,' Writing restart file was successful. \n');
            
        catch exception
            fprintf(CtrlVar.fidlog,' Could not save restart file %s \n ',RestartFile);
            fprintf(CtrlVar.fidlog,'%s \n',exception.message);
        end
        
    end



    function WriteAdjointRestartFile
        
        
        fprintf(CtrlVar.fidlog,'Saving adjoint restart file: %s \n ',CtrlVar.NameOfAdjointRestartFiletoWrite);
        save(CtrlVar.NameOfAdjointRestartFiletoWrite,...
            'UserVar','CtrlVar','MUA','BCs','s','b','h','S','B','ub','vb','ud','vd','alpha','rho','rhow','g',...
            'as','ab','GF','BCs','l',...
            'InvStartValues','Priors','Meas','BCsAdjoint','Info','InvFinalValues','xAdjoint','yAdjoint','-v7.3');
        
        
        if CtrlVar.AGlenisElementBased
            xA=Nodes2EleMean(MUA.connectivity,MUA.coordinates(:,1));
            yA=Nodes2EleMean(MUA.connectivity,MUA.coordinates(:,2));
        else
            xA=MUA.coordinates(:,1);
            yA=MUA.coordinates(:,2);
        end
        
        if CtrlVar.CisElementBased
            xC=Nodes2EleMean(MUA.connectivity,MUA.coordinates(:,1));
            yC=Nodes2EleMean(MUA.connectivity,MUA.coordinates(:,2));
        else
            xC=MUA.coordinates(:,1);
            yC=MUA.coordinates(:,2);
        end
        
        fprintf(CtrlVar.fidlog,' saving C and m  in file %s \n ',CtrlVar.NameOfFileForSavingSlipperinessEstimate)        ;
        save(CtrlVar.NameOfFileForSavingSlipperinessEstimate,'C','m','xC','yC','MUA')
        
        fprintf(CtrlVar.fidlog,' saving AGlen and m in file %s \n ',CtrlVar.NameOfFileForSavingAGlenEstimate) ;
        save(CtrlVar.NameOfFileForSavingAGlenEstimate,'AGlen','n','xA','yA','MUA')
        
    end
































end
