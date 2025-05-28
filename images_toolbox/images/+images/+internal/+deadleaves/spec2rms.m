function [rrms] = spec2rms( spect, dx)
% spec2rms  Computes RMS value from 2-D Noise power spectrum,
% array of single frequency quadrant
% [rrms] = spec2rms( spec, dx)
% spec = NPS with zero frequency value at (1,1)
% dx   = the original data sampling interval in mm
% rrms = output rms value
%
% Peter D. Burns, pdburns@ieee.org 5 Nov. 2015

[n , m] = size(spect);
fxm = 1/(2*dx);
dfx =  fxm/(n-1);
dfy =  fxm/(m-1);

s1 = sum(spect(1,2:m-1)) + sum(spect(n,2:m-1));
s2 = sum(spect(2:n-1,1)) + sum(spect(2:n-1,m));
s3 = sum(sum(spect(2:n-1,2:m-1)));
ss = (spect(1,1)+spect(n,m) + (2*(s1 + s2)) + 4*s3)*(dfx*dfy);

rrms = sqrt(ss);
