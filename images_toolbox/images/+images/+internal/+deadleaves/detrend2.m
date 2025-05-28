function [out, fit] = detrend2(in, order, samp, meanout)
% [out, fit] = detrend2(in, order, samp, meanout)
% Fits and removes 2D polynomial surface from data. Used prior to, 
% e.g., noise power spectrum estimation from image data
%  in = input data array (n x m)
%  order= order of polynomial fit
%       = 1 linear, removes a plane (default)
%       = 2 quadratic
%  samp = downsampling factor for fit calculation
%       = 1  no downsampling (default)
%       = 2  2x downsampling in each direction
%          execution time is approx proportional to 1/samp
%  meanout = 0 (Default) mean of out is 0
%          = 1  mean of out is sample mean of in
%  out = data array with fit surface subtracted
%  fit = string array showing the fit equation,
%        where the x y coordinates are as rows and columns -1.
%        x = 0, 1, ..., npix - 1, 
%        y = 0, 1, ..., ncol - 1.
% Needs: mm2dpfit, mm2dpstr, mm2dpval
%
% Peter D. Burns, pdburns@ieee.org 5 Nov. 2015

if nargin < 4
  meanout = 0;
end

if nargin < 3
 samp = 1;
end
if nargin < 2
 order = 1;
end

[nlin, npix, nc]=size(in);
if nc~=1
    % beep
    assert(false, '* Error: function DETREND2 requires an N x M array *');
    out = 0;
    fit = 0;
    return
end

ndat = npix*nlin;
mmin=min(in(:));
mmax=max(in(:));

% Check 
if mmin==mmax
    out=in;
    fit=0;
    return
end

fac1 = samp;
fac2 = samp;

if samp ~=1
 temp = in;
 in = in(1:samp:nlin, 1:samp:npix);
 [nlin, npix]=size(in);
 ndat = npix*nlin;
end

 if meanout > 1e-4
  gmean = mean(mean(in));
 end

 fdat = reshape(in, ndat, 1);

x = zeros(ndat,1);
y = zeros(ndat,1);
ii=0;
for i=1:npix
for j=1:nlin
 ii=ii+1;
 x(ii)=(i-1)*fac1;
 y(ii)=(j-1)*fac2;
end
end

p   = images.internal.deadleaves.mm2dpfit(x, y, fdat, order, order);
fit = images.internal.deadleaves.mm2dpstr(p);

if samp~=1
 [nlin, npix]=size(temp);
 ndat = npix*nlin;
 x = zeros(ndat,1);
 y = zeros(ndat,1);
 ii=0;
 for i=1:npix;
 for j=1:nlin;
  ii=ii+1;
  x(ii)=i-1;
  y(ii)=j-1;
 end;
 end;

 fdat = reshape(temp, npix*nlin, 1);

end

zz  = images.internal.deadleaves.mm2dpval(p, x, y);

% Correction is by subtraction, not multiplaction by an inverse function.
out = fdat-zz;
out = reshape(out, nlin, npix);

 if meanout > 1e-4;
  out = out + gmean;
 end

return;
