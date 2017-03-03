function [UserVar,F]=GetSeaIceParameters(UserVar,CtrlVar,MUA,BCs,F,GF)

narginchk(6,6)
nargoutchk(2,2)

if CtrlVar.IncludeMelangeModelPhysics
    
    
    [UserVar,F.uo,F.vo,F.Co,F.mo,F.ua,F.va,F.Ca,F.ma]=DefineSeaIceParameters(UserVar,CtrlVar,MUA,BCs,GF,F.ub,F.vb,F.ud,F.vd,F.uo,F.vo,F.ua,F.va,F.s,F.b,F.h,F.S,F.B,F.rho,F.rhow,F.AGlen,F.n,F.C,F.m);
    

    %% Test values
    
    if isempty(F.uo)
        error('Ua:GetSeaIceParameters','Ocean velocity component uo is empty.')
    end
    
    
    if isempty(F.vo)
        error('Ua:GetSeaIceParameters','Ocean velocity component vo is empty.')
    end
    
    
    if all(F.mo==0)
        
        error('Ua:GetSeaIceParameters','Ocean/ice stress exponent (mo) is zero, but must have a non-zero value. ')
        
    end
    
    
    if all(F.ma==0)
        
        error('Ua:GetSeaIceParameters','atmo/ice stress exponent (ma) is zero, but must have a non-zero value. ')
        
    end
    
    
    if isempty(F.Co)
        error('Ua:GetSeaIceParameters','Ocean/ice slipperiness coefficient Co is empty.')
    end
    
    
    if isempty(F.mo)
        error('Ua:GetSeaIceParameters','Ocean/ice drag stress-exponent mo is empty.')
    end
    
    
    
    if isempty(F.Ca)
        error('Ua:GetSeaIceParameters','Atmo/ice slipperiness coefficient Ca is empty.')
    end
    
    
    
    if isempty(F.ma)
        error('Ua:GetSeaIceParameters','Atmo/ice drag stress-exponent ma is empty.')
    end

    
    [F.Co,F.mo]=TestSlipperinessInputValues(CtrlVar,MUA,F.Co,F.mo);
    [F.Ca,F.ma]=TestSlipperinessInputValues(CtrlVar,MUA,F.Ca,F.ma);
    
    
end



end