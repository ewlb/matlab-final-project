function [vec,peakVal] = findTranslationPhaseCorr(varargin) %#codegen
%findTranslationPhaseCorr Determine translation using phase correlation.
%
%   [vec,peakVal] = findTranslationPhaseCorr(MOVING, FIXED) estimates the
%   translation of MOVING necessary to align MOVING with the
%   fixed image FIXED. The output VEC is a two element vector of the form
%   [deltaX, deltaY]. The scalar peakVal is the peak value of the phase
%   correlation matrix used to estimate translation.
%
%   [vec,peakVal] = findTranslationPhaseCorr(D) estimates the translation
%   of MOVING necesary to align MOVING with the fixed image FIXED. D is a
%   phase correlation matrix of the form returned by:
%
%       D = phasecorr(fixed,moving).

%   Copyright 2013-2018 The MathWorks, Inc.

narginchk(1,2)

if nargin == 1
    d = varargin{1};
else
    moving = varargin{1};
    fixed  = varargin{2};
    % Compute phase correlation matrix, D
    d = phasecorr(fixed,moving);
end

% Shift spectra to center so that peak finding is better conditioned for
% small rotations and translations
d = fftshift(d);

% Use simple global maximum peak finding. Surface fit using 3x3
% neighborhood to refine xpeak,ypeak location to sub-pixel accuracy.
subpixel = true;
[xpeak,ypeak,peakVal] = findpeak(d,subpixel);

% For even input grid sizes: fftshift([1 0 0 0]) = [0 0 1 0]
%                            fftshift([1 0 0]) = [0 1 0]
% Center is based on convention of how fftshift handles even/odd grids.
gridYCenter = round(1 + (size(d,1)-1)/2); 
gridXCenter = round(1 + (size(d,2)-1)/2);

% vec is relative offset from grid center
xpeak = xpeak-gridXCenter;
ypeak = ypeak-gridYCenter;

% Ensure that we consistently return double for the offset vector and for
% the peak correlation value.
vec = double([xpeak, ypeak]);
peakVal = double(peakVal);

% If the peak value was uniform, we have no confidence in our estimate and
% should return a zero offset
if all(d(:) == peakVal)
    vec = [0,0];
end


