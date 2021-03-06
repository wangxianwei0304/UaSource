function hx = happly (v, beta, x)
%HAPPLY apply Householder reflection to a vector
% Example:
%   hx = happly (v,beta,x) ;        % computes hx = x - v * (beta * (v' *x)) ;
% See also: testall

%   Copyright 2006-2007, Timothy A. Davis.
%   http://www.cise.ufl.edu/research/sparse


hx = x - v * (beta * (v' *x)) ;
