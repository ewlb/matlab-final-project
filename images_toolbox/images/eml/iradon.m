function [img,H] = iradon(varargin) %#codegen
%IRADON Inverse Radon transform.
%
% Syntax
% ------
%
% I = iradon(R,theta)
% I = iradon(R,theta,interp,filter,frequency_scaling,output_size)
% [I,H] = iradon(___)
%
% Input Specs
% -----------
%
%  R : Parallel beam projection data
%  numeric column vector | numeric matrix
%
%  theta : Projection angles
%   numeric vector | numeric scalar | []
%   numeric scalar: Projections are taken at angles m*theta, where m = 0,1,2,...,size(R,2)-1.
%   [] : Automatically set the incremental angle between projections to 180/size(R,2)
%
%  interp : Type of interpolation
%   'linear' (default) | 'nearest' | 'spline' | 'pchip' | 'v5cubic'
%
%   filter:  Filter
%  'Ram-Lak' (default) | 'Shepp-Logan' | 'Cosine' | 'Hamming' | 'Hann' | 'None'
%
%  frequency_scaling: Scale factor
%   1 (default) | positive number in the range (0, 1]
%
%  output_size : Number of rows and columns in the reconstructed image
%  if not specified, output_size = 2*floor(size(R,1)/(2*sqrt(2)))
%
% Output Specs
% ------------
%
%  I : Grayscale image
%   numeric matrix, single | double
%  If input projection data R is data type single, then I is single; otherwise I is double.
%
%  H : Frequency response
%  numeric vector, double

% Copyright 2022 The MathWorks, Inc.

narginchk(2,6);

[pIn, thetaIn, filter, d, interp, N] = images.internal.iradon.parseInputs(varargin{:});

% Determine if single precision computation has to be enabled. Cast the
% inputs p and theta accordingly.
[pLocal, theta, useSingleForComp, isMixedInputs] = images.internal.iradon.postProcessInputs(pIn, thetaIn);

% Design the filter used to filter the projections
[pLocal, H] = images.internal.iradon.filterProjections(pLocal, filter, d, useSingleForComp, isMixedInputs);

% Define the x & y axes for the reconstructed image so that the origin
% (center) is in the spot which RADON would choose.
center = floor((N + 1)/2);
xleft = -center + 1;
x = (1:N) - 1 + xleft;

ytop = center - 1;
y = (N:-1:1).' - N + ytop;

len = size(pIn,1);
ctrIdx = ceil(len/2);     % index of the center of the projections

% Zero pad the projections to size 1+2*ceil(N/sqrt(2)) if this
% quantity is greater than the length of the projections
imgDiag = 2*ceil(N/sqrt(2))+1;  % largest distance through image.
if size(pLocal,1) < imgDiag
    rz = imgDiag - size(pLocal,1);  % how many rows of zeros
    p = [zeros(ceil(rz/2), size(pLocal,2)); pLocal; zeros(floor(rz/2), size(pLocal,2))];
    ctrIdx = ctrIdx+ceil(rz/2);
else
    p = pLocal;
end

% Backprojection - vectorized in (x,y), looping over theta
if ismember( coder.const(interp), [ images.internal.iradon.InterpModes.Nearest, ...
                                    images.internal.iradon.InterpModes.Linear ] )
    img = iradonImpl(N, theta, x, y, p, interp);
else
    interpStr = images.internal.iradon.convertEnumsToInterpModes(interp);

    % Generate trigonometric tables
    costheta = cos(theta);
    sintheta = sin(theta);

    % Allocate memory for the image
    img = zeros(N,'like',p);
    rowsP = size(p,1);

    parfor i=1:length(theta)
        proj = p(:,i);
        taxis = (1:rowsP) - ctrIdx;
        t = x.*costheta(i) + y.*sintheta(i);
        projContrib = interp1(taxis,proj,t(:),interpStr);
        img = img + reshape(projContrib,N,N);
    end
end

img = img*pi/(2*length(theta));


%==========================================================================
function img = iradonImpl(N, theta, x, y, p, interpolation)
coder.inline('always');
coder.internal.prefer_const(N, theta, x, y, p, interpolation);

% This code should not be reachable.
coder.internal.assert( ( interpolation == images.internal.iradon.InterpModes.Linear || ...
                         interpolation == images.internal.iradon.InterpModes.Nearest ), ...
                         'images:iradon:invalidInterp' );

numAngles = size(theta,1) * size(theta,2);

%back projected output image
img = zeros(N,N, class(p));
imgRows = size(img,1);
imgCols = size(img,2);

rowsP = coder.internal.indexInt(size(p,1));
ctrIdx = coder.internal.indexInt(floor(rowsP/2));

projData = p(:);

if coder.const(interpolation == images.internal.iradon.InterpModes.Linear)
    for k = 1:numAngles
        cosTheta = cos(theta(k));
        sinTheta = sin(theta(k));
        if coder.isColumnMajor
            parfor col =  1:imgCols
                for row = 1:imgRows
                    t = x(col)*cosTheta + y(row)*sinTheta;
                    a = eml_cast(t, coder.internal.indexIntClass, 'floor');
                    index0 = coder.internal.indexPlus(a, ctrIdx);
                    index1 = coder.internal.indexPlus(index0,1);
                    index2 = coder.internal.indexPlus(index0,2);
                    offset = coder.internal.indexTimes(k-1,rowsP);
                    img(row,col) = img(row,col) + (t - double(a))*projData(coder.internal.indexPlus(index2, offset)) ...
                        + (double(a)+1-t)*projData(coder.internal.indexPlus(index1, offset)); %#ok<*PFBNS>
                end
            end
        else % Row-Major
            parfor row = 1:imgRows
                for col =  1:imgCols
                    t = x(col)*cosTheta + y(row)*sinTheta;
                    a = eml_cast(t, coder.internal.indexIntClass, 'floor');
                    index0 = coder.internal.indexPlus(a, ctrIdx);
                    index1 = coder.internal.indexPlus(index0,1);
                    index2 = coder.internal.indexPlus(index0,2);
                    offset = coder.internal.indexTimes(k-1,rowsP);
                    img(row,col) = img(row,col) + (t - double(a))*projData(coder.internal.indexPlus(index2, offset)) ...
                        + (double(a)+1-t)*projData(coder.internal.indexPlus(index1, offset));
                end
            end
        end
    end

else
    for k = 1:numAngles
        cosTheta = cos(theta(k));
        sinTheta = sin(theta(k));
        if coder.isColumnMajor
            parfor col =  1:imgCols
                for row = 1:imgRows
                    t = x(col)*cosTheta + y(row)*sinTheta;
                    a = eml_cast(t + 0.5, coder.internal.indexIntClass, 'floor');
                    index = coder.internal.indexPlus(coder.internal.indexPlus(a,1), ctrIdx);
                    offset = coder.internal.indexTimes(k-1,rowsP);
                    img(row,col) = img(row,col)+ projData(coder.internal.indexPlus(index,offset));
                end
            end
        else % Row-Major
            parfor row = 1:imgRows
                for col =  1:imgCols
                    t = x(col)*cosTheta + y(row)*sinTheta;
                    a = eml_cast(t + 0.5, coder.internal.indexIntClass, 'floor');
                    index = coder.internal.indexPlus(coder.internal.indexPlus(a,1), ctrIdx);
                    offset = coder.internal.indexTimes(k-1,rowsP);
                    img(row,col) = img(row,col)+ projData(coder.internal.indexPlus(index, offset));
                end
            end

        end
    end
end
