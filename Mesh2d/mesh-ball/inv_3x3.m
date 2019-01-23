function [II,DA] = inv_3x3(AA)
%INV_3X3 calc. the inverses for a block of 3-by-3 matrices.
%   [IA,DA] = INV_3X3(AA) returns a set of 'inverses' IA and
%   an array of determinants DA for the set of 3-by-3 linear 
%   systems in AA. SIZE(AA), SIZE(IA) = [3,3,N], where N is 
%   the number of linear systems. DA is an N-by-1 array of 
%   determinant values. Note that each IA(:,:,K) is an 'inc-
%   omplete inverse DET(A(:,:,K)) * A(:,:,K)^(-1) to improve
%   numerical robustness. To solve a linear system, A*X = B,
%   compute (I*B)./D, given D is non-zero. 
%
%   See also INV_2X2

%   Darren Engwirda : 2018 --
%   Email           : de2363@columbia.edu
%   Last updated    : 03/05/2018

%---------------------------------------------- basic checks    
    if (  ~isnumeric(AA))
        error('inv_3x3:incorrectInputClass' , ...
            'Incorrect input class.') ;
    end
    
%---------------------------------------------- basic checks
    if (ndims(AA) ~= +3 )
        error('inv_3x3:incorrectDimensions' , ...
            'Incorrect input dimensions.');
    end
    if (size(AA,1)~= +3 || ...
        size(AA,2)~= +3 )
        error('inv_3x3:incorrectDimensions' , ...
            'Incorrect input dimensions.');
    end
    
%---------------------------------------------- build inv(A)
    II = zeros(size (AA)) ;

    DA = det_3x3(AA) ;

    II(1,1,:) = ...
    AA(3,3,:) .* AA(2,2,:) ... 
  - AA(3,2,:) .* AA(2,3,:) ;

    II(1,2,:) = ...
    AA(3,2,:) .* AA(1,3,:) ...
  - AA(3,3,:) .* AA(1,2,:) ;

    II(1,3,:) = ...
    AA(2,3,:) .* AA(1,2,:) ...
  - AA(2,2,:) .* AA(1,3,:) ;

    II(2,1,:) = ...
    AA(3,1,:) .* AA(2,3,:) ...
  - AA(3,3,:) .* AA(2,1,:) ;

    II(2,2,:) = ...
    AA(3,3,:) .* AA(1,1,:) ...
  - AA(3,1,:) .* AA(1,3,:) ;

    II(2,3,:) = ...
    AA(2,1,:) .* AA(1,3,:) ...
  - AA(2,3,:) .* AA(1,1,:) ;

    II(3,1,:) = ...
    AA(3,2,:) .* AA(2,1,:) ...
  - AA(3,1,:) .* AA(2,2,:) ;

    II(3,2,:) = ...
    AA(3,1,:) .* AA(1,2,:) ...
  - AA(3,2,:) .* AA(1,1,:) ;

    II(3,3,:) = ...
    AA(2,2,:) .* AA(1,1,:) ... 
  - AA(2,1,:) .* AA(1,2,:) ;

end

function [DA]    = det_3x3(AA)

    DA = ...
    AA(1,1,:) .* ( ...
	AA(2,2,:) .* AA(3,3,:) ... 
  - AA(2,3,:) .* AA(3,2,:) ...
	    ) - ... 
    AA(1,2,:) .* ( ...
	AA(2,1,:) .* AA(3,3,:) ... 
  - AA(2,3,:) .* AA(3,1,:) ...
	    ) + ...
	AA(1,3,:) .* ( ...
	AA(2,1,:) .* AA(3,2,:) ... 
  - AA(2,2,:) .* AA(3,1,:) ...
	    ) ;

end



