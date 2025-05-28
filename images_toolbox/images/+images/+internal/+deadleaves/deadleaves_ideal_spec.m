function [spec, f] = deadleaves_ideal_spec(N,f)
% [spec, f] = dealleaves_ideal_spec(N, f)   Computes unscaled ideal PDS for
%                                     deadleaves image
%  N/2 = size in pixels of the (N x N) deadleaves image
%  f   = (optional) spatial frequencies (cy/pixel)
% Approximation from:
%  J. McElvain, S. Campbell, J. Miller and E. Jin, Texture-based measurement
%  of spatial frequency response using the dead leaves target: extensions,
%  and application to real camera systems, Proc. SPIE 7537, 75370D (2010)
%
% Peter D. Burns, pdburns@ieee.org 7 March 2024

nn1 = round((N+1)/2);
if nargin<2
    f = (0:nn1-1)*sqrt(2)/N;
end
A = 71.015*(N.^1.8905);
spec = A./(f.^1.857);
spec(1) = spec(2);
spec = spec(:);
f = f(:);

