function [R,xp] = radon(varargin) %#codegen
%RADON Radon transform.
%
% Syntax
% ------
%
% R = radon(I)
% R = radon(I,theta)
% [R,xp] = radon(___)
%
% Input Specs
% ------------
%
% I:
%   2-D numeric matrix
%   grayscale
%   single, double, int8, int16, int32, int64
%   uint8, uint16, uint32, uint64 or logical
%
% theta:
%    numeric scalar or numeric vector
%    Default: 0:179
%
% Output Specs
% ------------
%
% R: Radon Transform
%   numeric column vector or numeric matrix
%
% xp: Radial coordinates
%    numeric vector
%

% Copyright 2022 The MathWorks, Inc.

narginchk(1,2);

% Validate Input Image
validateattributes(varargin{1},{'numeric','logical'},{'2d','nonsparse'},mfilename,'I',1);

I = varargin{1};

if (nargin < 2)
    theta = 0:179;
else
    validateattributes(varargin{2},{'double'},{'real','nonsparse','vector'},mfilename,'THETA',2);
    theta = varargin{2};
end

numAngles = size(theta,1) * size(theta,2);

% Convert to Radians
thetaR = pi*theta/180;

I1 = double(I);
M = size(I,1);
N = size(I,2);

% Where is the coordinate system's origin?
xOrigin = max(1,floor((N+1)/2));
yOrigin = max(1,floor((M+1)/2));

% used in output size computation
yDistance = M - yOrigin;
xDistance = N - xOrigin;

% r-values for first and last row of output
rLast = ceil(sqrt(yDistance*yDistance + xDistance*xDistance)) + 1;
rFirst = -rLast;

% number of rows in output
rSize = rLast - rFirst + 1;

if nargout == 2
    xp = coder.nullcopy(zeros(rSize, 1));
    xp(:) = rFirst:rLast;
end

if isreal(I1)
    R = coder.nullcopy(zeros(rSize, numAngles));
else
    R = coder.nullcopy(complex(zeros(rSize, numAngles)));
end

R = radonImpl(R, I1, thetaR, numAngles, xOrigin, yOrigin, rSize, rFirst);
end

%==========================================================================
function R = radonImpl(R, I, thetaR, numAngles, xOrigin, yOrigin, rSize, rFirst)
coder.inline('always');
coder.internal.prefer_const(I, thetaR, numAngles, ...
    xOrigin, yOrigin, rSize, rFirst)

M = size(I,1);
N = size(I,2);

coder.internal.treatAsParfor;
for i = 1:numAngles
    angle = thetaR(i);
    R(:,i) = computeRadonForEachAngle(angle, I, M, N, ...
        xOrigin, yOrigin, rSize, rFirst);
end
end

%==========================================================================
function R = computeRadonForEachAngle(angle, I, M, N, xOrigin, yOrigin, rSize, rFirst)
coder.inline('always');
coder.internal.prefer_const(angle,I, M, N, ...
    xOrigin, yOrigin, rSize, rFirst);

if isnan(angle) || ~isfinite(angle)
    outImage = zeros(rSize,1);
    outImage(1:2,:) = NaN;
    if isreal(I)
        R = outImage;
    else
        R = complex(outImage,outImage);
    end
    return;
end

outReal = zeros(rSize,1);

if ~isreal(I)
    outImag = zeros(rSize,1);
end

cosine = cos(angle);
sine = sin(angle);

xCosTable = coder.nullcopy(zeros(2*N,1));
ySinTable = coder.nullcopy(zeros(2*M,1));

for col = 1:N
    x = col - xOrigin;
    xCosTable(2*col-1) = (x - 0.25)*cosine;
    xCosTable(2*col) = (x + 0.25)*cosine;
end

for row = 1:M
    y = yOrigin - row;
    ySinTable(2*row-1) = (y - 0.25)*sine;
    ySinTable(2*row) = (y + 0.25)*sine;
end

if coder.isRowMajor
    coder.loop.interchange('col', 'row');
end

for col = 1:coder.internal.indexInt(N)
    for row = 1:coder.internal.indexInt(M)

        pixelReal = real(I(row,col));

        if pixelReal ~= 0
            pixel = 0.25*pixelReal;

            r = xCosTable(2*col-1)+ySinTable(2*row-1)-rFirst+1;
            outReal = incrementRadon(outReal, pixel, r);

            r = xCosTable(2*col)+ySinTable(2*row-1)-rFirst+1;
            outReal = incrementRadon(outReal, pixel, r);

            r = xCosTable(2*col-1)+ySinTable(2*row)-rFirst+1;
            outReal = incrementRadon(outReal, pixel, r);

            r = xCosTable(2*col)+ySinTable(2*row)-rFirst+1;
            outReal = incrementRadon(outReal, pixel, r);
        end

        if ~isreal(I)
            pixelImag = imag(I(row,col));
            if pixelImag ~= 0
                pixel = 0.25*pixelImag;

                r = xCosTable(2*col-1)+ySinTable(2*row-1)-rFirst+1;
                outImag = incrementRadon(outImag, pixel, r);

                r = xCosTable(2*col)+ySinTable(2*row-1)-rFirst+1;
                outImag = incrementRadon(outImag, pixel, r);

                r = xCosTable(2*col-1)+ySinTable(2*row)-rFirst+1;
                outImag = incrementRadon(outImag, pixel, r);

                r = xCosTable(2*col)+ySinTable(2*row)-rFirst+1;
                outImag = incrementRadon(outImag, pixel, r);
            end
        end
    end
end

if isreal(I)
    R = outReal;
else
    R = complex(outReal,outImag);
end
end

%==========================================================================
function P = incrementRadon(P, pixel, r)
coder.inline('always');
r1 = coder.internal.indexInt(r);
delta = r - double(r1);
P(r1,1) = P(r1,1) + pixel * (1-delta);
P(r1+1, 1) = P(r1+1,1) + pixel * delta;
end