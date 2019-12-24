function PlotForceResidualVectors(msg,R,L,lambda,coordinates,CtrlVar)


x=coordinates(:,1);
y=coordinates(:,2);

Nnodes=length(coordinates);
if ~isempty(L)
    R=R+L'*lambda;
end

FigName='Nodal force residuals' ;
Position=[1010,20,500,300] ; 
FindOrCreateFigure(FigName,Position);

if ~contains(msg,'h-only')  % uvh residuals
    % uv-residuals
    
    quiver(x/CtrlVar.PlotXYscale,y/CtrlVar.PlotXYscale,R(1:Nnodes),R(Nnodes+1:2*Nnodes))
    title('Nodal Force residuals (R+transpose(L) lambda)')
    
    % h residuals
    if contains(msg,'h')
        hold on
        
        PlotScale=0.1*max(abs(R(2*Nnodes+1:end)))*min([max(x)-min(x) max(y)-min(y)])/CtrlVar.PlotXYscale;
        PlotCircles(x/CtrlVar.PlotXYscale,y/CtrlVar.PlotXYscale,R(2*Nnodes+1:end)/PlotScale,'r')
    end
    
    axis equal tight
else % h residuals only
    
    
    hold on
    title('Nodal Force residuals (R+transpose(L) lambda)')
    
    PlotScale=0.1*max(abs(R))*min([max(x)-min(x) max(y)-min(y)])/CtrlVar.PlotXYscale;
    xmax=max(x) ; xmin=min(x) ; ymax=max(y) ;ymin=min(y);
    
    [R,I]=sort(abs(R),'descend') ; x=x(I) ; y=y(I);
    N=min([1000,numel(x)]);
    R=R(1:N) ; x=x(1:N) ; y=y(1:N);
    PlotCircles(x/CtrlVar.PlotXYscale,y/CtrlVar.PlotXYscale,R/PlotScale,'r')
    axis([xmin xmax ymin ymax]/CtrlVar.PlotXYscale) ; axis equal tight
    
end
%%

drawnow
end

