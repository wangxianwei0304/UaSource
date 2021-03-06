function [RunInfo,dtOut,dtRatio]=AdaptiveTimeStepping(UserVar,RunInfo,CtrlVar,MUA,F)
            
    %% dtOut=AdaptiveTimeStepping(time,dtIn,nlInfo,CtrlVar)
    %  modifies time step size
    %
    % Decision about increasing the time step size is based on the number of non-linear interations over the last few time steps.
    %     
    % The main idea is to limit the number of non-linear iteration so that the NR is within the quadradic regime 
    % Experience has shown that a target number of iterations (CtrlVar.ATSTargetIterations) within 3 to 5 is good for this purpose 
    %
    % Time step is increased if r<1 where
    %
    %     r=N/M      
    %        
    %   where
    %   N is the max number of non-linear iteration over last n time steps
    %   M is the target number of iterations
    %
    %   here 
    %     M=CtrlVar.ATSTargetIterations 
    %   and
    %     n=CtrlVar.ATSintervalUp 
    %
    %   (N does not need to be specifed.)
    %
    %  Currently the time step is only decreased if either:
    %        a) the number of non-linear iterations in last time step was larger than 25 
    %        b) number of iterations over last n times steps were all larger than 10 
    %  where n=CtrlVar.ATSintervalDown 
    %
    % There are some further modifications possible:
    %  -time step is adjusted so that time interval for making transient plots (CtrlVar.TransientPlotDt) is not skipped over
    %  -time step is not increased further than the target time step CtrlVar.ATStimeStepTarget
    %  -time step is adjusted so that total simulation time does not exceed CtrlVar.TotalTime
    %
    %
    %
    
    narginchk(5,5)
    
    persistent ItVector icount dtNotUserAdjusted dtOutLast dtModifiedOutside
    
        
    time=CtrlVar.time;
    dtIn=CtrlVar.dt ; 
    
    if isempty(dtModifiedOutside)
        dtModifiedOutside=false;
    end
    
    if isempty(ItVector) ; ItVector=zeros(max(CtrlVar.ATSintervalDown,CtrlVar.ATSintervalUp),1)+1e10; end
    if isempty(icount) ; icount=0 ; end
    
    
    % potentially dt was previously adjusted for plotting/saving purposes
    % if so then dtNotUserAdjusted is the previous unmodified time step
    % and I do want to revert to that time step. I do so only
    % however if dt has not been changed outside of function
    if ~isempty(dtOutLast) 
        if dtIn==dtOutLast  % dt not modified outside of function
            if ~isempty(dtNotUserAdjusted)   
                dtIn=dtNotUserAdjusted ; 
            end
        else
            icount=0;
            dtModifiedOutside=true;
        end
    end
    
    dtOut=dtIn ;
    
    
    
    % I first check if the previous forward calculation did not converge. If it did
    % not converge I reduced the time step and reset all info about previous
    % interations to reset the adaptive-time stepping approuch
 
    icount=icount+1;
    if ~RunInfo.Forward.Converged || dtModifiedOutside
        
        ItVector=ItVector*0+1e10;
        icount=0;
        dtModifiedOutside=false ; 
        
        if ~RunInfo.Forward.Converged 
            dtOut=dtIn/CtrlVar.ATStimeStepFactorDownNOuvhConvergence;
            fprintf(CtrlVar.fidlog,' ---------------- Adaptive Time Stepping: time step decreased from %-g to %-g due to lack of convergence in last uvh step. \n ',dtIn,dtOut);
        end
        
        
    elseif CtrlVar.AdaptiveTimeStepping && ~isnan(RunInfo.Forward.Iterations)
        
        
        ItVector(2:end)=ItVector(1:end-1) ;
        ItVector(1)=RunInfo.Forward.Iterations;
        nItVector=numel(find(ItVector<1e10));
        TimeStepUpRatio=max(ItVector(1:CtrlVar.ATSintervalUp))/CtrlVar.ATSTargetIterations ;
        TimeStepDownRatio=min(ItVector(1:CtrlVar.ATSintervalUp))/CtrlVar.ATSTargetIterations ;
        
        fprintf(CtrlVar.fidlog,' Adaptive Time Stepping:  #Non-Lin Iterations over last %-i time steps: (max|mean|min)=(%-g|%-g|%-g). Target is %-i. \t TimeStepUpRatio=%-g \n ',...
            nItVector,max(ItVector),mean(ItVector),min(ItVector),CtrlVar.ATSTargetIterations,TimeStepUpRatio);
        
        if RunInfo.Forward.Iterations==666  % This is a special forced reduction whenever RunInfo.Forward.Iterations has been set to this value
            
            icount=0;
            dtOut=dtIn/CtrlVar.ATStimeStepFactorDown;
            fprintf(CtrlVar.fidlog,' ---------------- Adaptive Time Stepping: time step decreased from %-g to %-g \n ',dtIn,dtOut);
            
        elseif icount>2 && RunInfo.Forward.Iterations>25
            icount=0;
            dtOut=dtIn/CtrlVar.ATStimeStepFactorDown;
            fprintf(CtrlVar.fidlog,' ---------------- Adaptive Time Stepping: time step decreased from %-g to %-g \n ',dtIn,dtOut);
        else
            
            if icount>CtrlVar.ATSintervalDown && nItVector >= CtrlVar.ATSintervalDown
                %if mean(ItVector(1:CtrlVar.ATSintervalDown)) > 5
                % if all iterations were greater than (target+2), reduce time step
                if all(ItVector(1:CtrlVar.ATSintervalDown) > (CtrlVar.ATSTargetIterations+2) )  ||  ( TimeStepDownRatio > 2 ) 
                    dtOut=dtIn/CtrlVar.ATStimeStepFactorDown; icount=0;
                    
                    
                    fprintf(CtrlVar.fidlog,' ---------------- Adaptive Time Stepping: time step decreased from %-g to %-g \n ',dtIn,dtOut);
                end
            end
            
            if icount>CtrlVar.ATSintervalUp && nItVector >= CtrlVar.ATSintervalUp
                if  TimeStepUpRatio<1
                    dtOut=min(CtrlVar.ATStimeStepTarget,dtIn*CtrlVar.ATStimeStepFactorUp); icount=0;

                    
                    if  CtrlVar.UaOutputsDt>0  
                        
                        Fraction=dtOut/CtrlVar.UaOutputsDt;
                        if Fraction>=1  % Make sure dt is not larger than the interval between UaOutputs
                            dtOut=CtrlVar.UaOutputsDt;
                        elseif Fraction>0.1   % if dt is greater than 10% of UaOutputs interval, round dt
                                              % so that it is an interger multiple of UaOutputsDt
                            fprintf('Adaptive Time Stepping dtout=%f \n ',dtOut);
                            dtOut=CtrlVar.UaOutputsDt/RoundNumber(CtrlVar.UaOutputsDt/dtOut,1);
                            fprintf('Adaptive Time Stepping dtout=%f \n ',dtOut);
                        end
                    end
                    
                    
                    
                    if CtrlVar.ATStimeStepTarget <= dtOut
                        dtOut=CtrlVar.ATStimeStepTarget ;
                        fprintf(CtrlVar.fidlog,' ---------------- Adaptive Time Stepping: time step has reached target time step of %-g and is therefore not increased further \n ',CtrlVar.ATStimeStepTarget);
                    else
                        if dtOut>dtIn
                            fprintf(CtrlVar.fidlog,' ---------------- Adaptive Time Stepping: time step increased from %-g to %-g \n ',dtIn,dtOut);
                        end
                    end
                    
                    
                end
            end
        end
    end
    
    if  CtrlVar.EnforceCFL ||  ~CtrlVar.Implicituvh   % If in semi-implicit step, make sure not to violate CFL condition
        
        dtcritical=CalcCFLdt2D(UserVar,RunInfo,CtrlVar,MUA,F) ; 
        
        if dtOut>dtcritical
        
           dtOut=dtcritical ;
           
           fprintf('AdaptiveTimeStepping: dt > dt (CFL) and therefore dt reduced to %f \n',dtOut) 
           
        end
    end
    
    
    if CtrlVar.ATSTdtRounding && CtrlVar.UaOutputsDt~=0
        % rounding dt to within 10% of Dt
        dtOut=CtrlVar.UaOutputsDt/round(CtrlVar.UaOutputsDt/dtOut,1,'significant') ; 
    end
    
    RunInfo.Forward.dtRestart=dtOut ;  % Create a copy of dtOut before final modifications related to plot times and end times.
                               % This is the dt to be used in further restart runs
    
    %% dtOut has now been set, but I need to see if the user wants outputs/plots at given time intervals and
    % if I am possibly overstepping one of those intervals.
    %
    dtOutCopy=dtOut;  % keep a copy of dtOut to be able to revert to previous time step
    % after this adjustment
    
    
%     if CtrlVar.WriteDumpFile && CtrlVar.WriteDumpFileTimeInterval>0
%         temp=dtOut;
%         dtOut=NoOverStepping(CtrlVar,time,dtOut,CtrlVar.WriteDumpFileTimeInterval);
%         if abs(temp-dtOut)>100*eps
%             fprintf(CtrlVar.fidlog,' Adaptive Time Stepping: dt modified to accomondate output file requirements and set to %-g \n ',dtOut);
%         end
%     end
    
    %
    if CtrlVar.UaOutputsDt>0
        temp=dtOut;
        dtOut=NoOverStepping(CtrlVar,time,dtOutCopy,CtrlVar.UaOutputsDt);
        if abs(temp-dtOut)>100*eps
            fprintf(CtrlVar.fidlog,' Adaptive Time Stepping: dt modified to accomondate user output requirements and set to %-g \n ',dtOut);
        end
    end
    
    
    
    %% make sure that run time does not exceed total run time as defined by user
    % also check if current time is very close to total time, in which case there 
    % is no need to change the time step
    if time+dtOut>CtrlVar.TotalTime && abs(time-CtrlVar.TotalTime)>100*eps
        
        dtOutOld=dtOut;
        dtOut=CtrlVar.TotalTime-time;
        
        if dtOutOld ~= dtOut
            fprintf(CtrlVar.fidlog,' Adaptive Time Stepping: dt modified to %-g to give a correct total run time of %-g \n ',dtOut,CtrlVar.TotalTime);
        end
    end
    
    
    %%
    
    if dtOutCopy~=dtOut
        dtNotUserAdjusted=dtOutCopy;
    else
        dtNotUserAdjusted=[];
    end
    
    dtOutLast=dtOut;
    
    
    dtRatio=dtOut/dtIn;
    
    %%
    if dtOut==0
        save TestSave
        error('dtOut is zero')
    end
    
    if ~isfield(RunInfo.Forward,'dt')
        RunInfo.Forward.dt=NaN;
        RunInfo.Forward.time=NaN;
    end
    
    k=find(isnan(RunInfo.Forward.time),1);
    if isempty(k)
        RunInfo.Forward.time=[RunInfo.Forward.time;RunInfo.Forward.time*0+NaN];
        RunInfo.Forward.dt=[RunInfo.Forward.dt;RunInfo.Forward.dt*0+NaN];
        k=find(isnan(RunInfo.Forward.time),1);
    end
    
    RunInfo.Forward.time(k)=time;
    RunInfo.Forward.dt(k)=dtOut;
    
    
    
end



