function PlotBoundary(Boundary,connectivity,coordinates,CtrlVar,varargin)
    
    % PlotBoundary(Boundary,connectivity,coordinates,CtrlVar)
    % Plots/labels boundary nodes, edges and elements
    % if Boundary=[], it is created by a call to FindBoundary(connectivity,coordinates)
    %
    % For just plotting the boundary edges, do: 
    % figure ; PlotBoundary(MUA.Boundary,MUA.connectivity,MUA.coordinates,CtrlVar,'k')
    %
    % CtrlVar.PlotBooundaryElements
    % CtrlVar.PlotBoundaryLabels
    % CtrlVar.PlotBoundaryNodes
    
    if nargin < 4
        CtrlVar.PlotLabels=0;
        CtrlVar.MeshColor='k';
        CtrlVar.NodeColor='k';
        CtrlVar.PlotXYscale=1;
        CtrlVar.PlotNodesSymbolSize=3;
        CtrlVar.PlotNodesSymbol='o';
        CtrlVar.PlotNodes=0;
        CtrlVar.PlotMesh=1;
        CtrlVar.time=NaN;
        CtrlVar.PlotBoundaryLabels=0;
        CtrlVar.PlotBooundaryElements=0;
        CtrlVar.PlotBoundaryNodes=0;
    else
        if ~isfield(CtrlVar,'PlotLabels') ; CtrlVar.PlotLabels=0; end
        if ~isfield(CtrlVar,'MeshColor') ; CtrlVar.MeshColor='k'; end
        if ~isfield(CtrlVar,'NodeColor') ; CtrlVar.NodeColor='k'; end
        if ~isfield(CtrlVar,'PlotXYscale') ; CtrlVar.PlotXYscale=1; end
        if ~isfield(CtrlVar,'PlotNodesSymbol') ; CtrlVar.PlotNodesSymbol='o'; end
        if ~isfield(CtrlVar,'PlotNodesSymbolSize') ; CtrlVar.PlotNodesSymbolSize=3; end
        if ~isfield(CtrlVar,'PlotNodes') ; CtrlVar.PlotNodes=0; end
        if ~isfield(CtrlVar,'PlotMesh') ; CtrlVar.PlotMesh=1; end
        if ~isfield(CtrlVar,'time') ; CtrlVar.time=NaN; end
        if ~isfield(CtrlVar,'PlotBoundaryLabels'); CtrlVar.PlotBoundaryLabels=0;  end
        if ~isfield(CtrlVar,'PlotBoundaryElements'); CtrlVar.PlotBoundaryElements=0; end
        if ~isfield(CtrlVar,'PlotBoundaryNodes'); CtrlVar.PlotBoundaryNodes=0; end
    end
    
    
    if isempty(Boundary)
        %[Boundary.Nodes,Boundary.EdgeCornerNodes,Boundary.FreeElements,Boundary.Edges]=FindBoundaryNodes(connectivity,coordinates);
        [Boundary,~]=FindBoundary(connectivity,coordinates);
    end
    
    
    x=coordinates(:,1) ; y=coordinates(:,2);
    
    Boundary.Edges=Boundary.Edges';
    plot(x(Boundary.Edges)/CtrlVar.PlotXYscale, y(Boundary.Edges)/CtrlVar.PlotXYscale,varargin{:}) ;
    
    % plot boundary elements,  do not label nodes or elements here because
    % the labelling will be incorrect
    CtrlVar.PlotLabels=0;
    if CtrlVar.PlotBoundaryElements
        PlotFEmesh(coordinates,connectivity(Boundary.FreeElements,:),CtrlVar)
    end
    
    hold on
    
    if CtrlVar.PlotBoundaryNodes
        plot(coordinates(Boundary.EdgeCornerNodes,1)/CtrlVar.PlotXYscale,coordinates(Boundary.EdgeCornerNodes,2)/CtrlVar.PlotXYscale,'ok')
        plot(coordinates(Boundary.Nodes,1)/CtrlVar.PlotXYscale,coordinates(Boundary.Nodes,2)/CtrlVar.PlotXYscale,'xr')
    end
    
   
    
    % this gives correct labeling of nodes and elemetns
    if CtrlVar.PlotBoundaryLabels
        labels = arrayfun(@(n) {sprintf(' N%d', n)}, Boundary.Nodes(:));
        text(coordinates(Boundary.Nodes,1)/CtrlVar.PlotXYscale,coordinates(Boundary.Nodes,2)/CtrlVar.PlotXYscale,labels)
        
        xEle=Nodes2EleMean(connectivity,coordinates(:,1));
        yEle=Nodes2EleMean(connectivity,coordinates(:,2));
        labels = arrayfun(@(n) {sprintf(' T%d', n)}, Boundary.FreeElements(:));
        text(xEle(Boundary.FreeElements)/CtrlVar.PlotXYscale,yEle(Boundary.FreeElements)/CtrlVar.PlotXYscale,labels,...
            'HorizontalAlignment', 'center', 'Color', 'blue');
        
    end
    
    %title(sprintf('boundary t=%-g ',CtrlVar.time)) ; xlabel('x (km)') ; ylabel('y (km)')
    axis equal tight    
    hold off
    

    
end