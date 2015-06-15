function [MUA,FEmeshTriRep]=genmesh2d(CtrlVar,MeshBoundaryCoordinates,edge,face,GmeshBackgroundScalarField)

%
% FEmeshTriRep is an instance of matlab TriRep class. Only based on the corner nodes of
%    triangles! Interior and edge nodes of higher order elements missing


options.output=false;

switch lower(CtrlVar.MeshGenerator)
    
    case 'mesh2d'
        hdata.fun = @hfun;
        hdata.args  = {CtrlVar.MeshSize};
        
        if nargin<3 || isempty(edge) || isempty(face)
            [coordinates,connectivity] = mesh2d(MeshBoundaryCoordinates,[],hdata,options);
        else
            [coordinates,connectivity]=meshfaces(MeshBoundaryCoordinates,edge,face,hdata,options);
        end
        
    case 'gmesh'
        
        if nargin<5;
            GmeshBackgroundScalarField=[];
        end
        
        
        [coordinates,connectivity]=GmeshInterfaceRoutine(CtrlVar,MeshBoundaryCoordinates,GmeshBackgroundScalarField);
        
        
    otherwise
        error('Mesh generator not correctly defined. Define variable CtrlVar.MeshGenerator {mesh2d|gmesh} ')
end


% make sure that FE nodes are labelled clockwise
%temp=connectivity; connectivity(:,2)=temp(:,3); connectivity(:,3)=temp(:,2); clear temp;


[coordinates,connectivity]=ChangeElementType(coordinates,connectivity,CtrlVar.TriNodes);

%if CtrlVar.doplots==1 && CtrlVar.PlotMesh==1; figure ; subplot(1,2,1) ; spy(M) ; end
%[i,j]=find(M); bw=max(i-j)+1;
%fprintf(CtrlVar.fidlog,' initial bandwidth : %-i , ',bw);

if CtrlVar.sweep==1
    [coordinates,connectivity] = ElementSweep(coordinates,connectivity,CtrlVar.SweepAngle);
    [coordinates,connectivity] = NodalSweep(coordinates,connectivity,CtrlVar.SweepAngle);
end

if CtrlVar.CuthillMcKee==1
    M=connectivity2adjacency(connectivity);
    [coordinates,connectivity] = CuthillMcKeeFE(coordinates,connectivity,M);
end

%if CtrlVar.doplots==1 && CtrlVar.PlotMesh==1 ; subplot(1,2,2); spy(M) ; end
%[i,j]=find(M); bw=max(i-j)+1;
%fprintf(CtrlVar.fidlog,' final bandwidth : %-i \n',bw);
clear M

% removing possible duplicate nodes
% There should in principle be no need to do this
% but this is fast so not much time is lost.
% tolerance=100*eps;
% [coordinates,connectivity]=RemoveDuplicateNodes(coordinates,connectivity,tolerance);


connectivity=TestAndCorrectForInsideOutElements(CtrlVar,coordinates,connectivity);

FEmeshTriRep=CreateFEmeshTriRep(connectivity,coordinates);
MUA=CreateMUA(CtrlVar,connectivity,coordinates);

if  CtrlVar.doplots==1 && CtrlVar.PlotMesh==1
     figure(1500+CtrlVar.GmeshMeshingAlgorithm) ; hold off ; PlotFEmesh(coordinates,connectivity,CtrlVar)
end

end

