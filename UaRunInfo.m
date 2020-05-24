classdef (ConstructOnLoad) UaRunInfo
    
    properties
        
        Inverse
        Forward
        BackTrack
        CPU
        Message
        MeshAdapt
        File
        Mapping
        
    end
    
    
    methods
        
        function obj = UaRunInfo()
            
            
            obj.File.fid = NaN ;
            obj.File.Name = NaN ;
            
            
            obj.Inverse.Iterations = 0;
            obj.Inverse.J = NaN ;
            obj.Inverse.I = NaN ;
            obj.Inverse.R = NaN ;
            obj.Inverse.StepSize = NaN ;
            obj.Inverse.GradNorm = NaN ;
            obj.Inverse.GradNorm = NaN ;
            obj.Inverse.ConjGradUpdate = 0 ;
            obj.Inverse.fmincon=struct;
            obj.Inverse.fminunc=struct;
            
            obj.Forward.uvConverged=0;
            obj.Forward.uvIterations=NaN;

            obj.Forward.hConverged=0;
            obj.Forward.hIterations=NaN;
            
            obj.Forward.Converged=0;
            obj.Forward.Iterations=NaN;
            obj.Forward.IterationsTotal=0;
            obj.Forward.Residual=NaN;
            
            obj.Forward.dtRestart=NaN;
            
            obj.Forward.iCounter=0;
            N=1000; % initial memory allocation
            obj.Forward.time=zeros(N,1)+NaN;
            obj.Forward.dt=zeros(N,1)+NaN;
            obj.Forward.uvhIterations=zeros(N,1)+NaN;
            obj.Forward.uvhResidual=zeros(N,1)+NaN;
            obj.Forward.uvhBackTrackSteps=zeros(N,1)+NaN;
            obj.Forward.uvhActiveSetIterations=zeros(N,1)+NaN;
            obj.Forward.uvhActiveSetCyclical=zeros(N,1)+NaN;
            obj.Forward.uvhActiveSetConstraints=zeros(N,1)+NaN;
            
            
            obj.Forward.ActiveSetConverged=NaN;
            
            obj.Forward.AdaptiveTimeSteppingResetCounter=0;
            
            obj.BackTrack.Converged=NaN;
            obj.BackTrack.iarm=0;
            obj.BackTrack.Infovector=NaN;
            obj.BackTrack.nFuncEval=NaN;
            obj.BackTrack.nExtrapolationSteps=NaN;
            
            
            obj.CPU.Total=0;
            obj.CPU.Assembly.uv=0;
            obj.CPU.Solution.uv=0;
            obj.CPU.Assembly.uvh=0;
            obj.CPU.Solution.uvh=0;
            obj.CPU.WallTime="";
            
            
            obj.Message="" ;
            
            obj.MeshAdapt.Method="";
            obj.MeshAdapt.isChanged=false;
            obj.MeshAdapt.Mesh.Nele=NaN;
            obj.MeshAdapt.Mesh.Nnodes=NaN;
            obj.MeshAdapt.Mesh.RunStepNumber=NaN;
            obj.MeshAdapt.Mesh.time=NaN;
            
            obj.Mapping.nNewNodes=NaN;
            obj.Mapping.nOldNodes=NaN;
            obj.Mapping.nIdenticalNodes=NaN;
            obj.Mapping.nNotIdenticalNodes=NaN;
            obj.Mapping.nNotIdenticalNodesOutside=NaN;
            obj.Mapping.nNotIdenticalNodesInside=NaN;
            
            
        end
        
    end
    
    methods (Static)
        function obj = loadobj(s)
            
            obj=s;
            
            % Make sure the loaded UaRunInfo is up-to date
            % add in here any new modifications
            if ~isfield(s.Forward,'AdaptiveTimeSteppingResetCounter')
                obj.Forward.AdaptiveTimeSteppingResetCounter=0;
            end
            
            if ~isfield(s.Forward,'uvhIterations')
                
                N=1000; % initial memory allocation
                obj.Forward.time=zeros(N,1)+NaN;
                obj.Forward.dt=zeros(N,1)+NaN;
                obj.Forward.uvhIterations=zeros(N,1)+NaN;
                obj.Forward.uvhResidual=zeros(N,1)+NaN;
                obj.Forward.uvhBackTrackSteps=zeros(N,1)+NaN;
                obj.Forward.uvhActiveSetIterations=zeros(N,1)+NaN;
                obj.Forward.uvhActiveSetCyclical=zeros(N,1)+NaN;
                obj.Forward.uvhActiveSetConstraints=zeros(N,1)+NaN;
                
            end
            
            if ~isfield(s.BackTrack,'iarm')
                
                obj.BackTrack.Converged=NaN;
                obj.BackTrack.iarm=NaN;
                obj.BackTrack.Infovector=NaN;
                obj.BackTrack.nFuncEval=NaN;
                obj.BackTrack.nExtrapolationSteps=NaN;
                
                
            end
            
        end
        
    end
    
end
