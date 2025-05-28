function M = linearRGBToXYZTransform(isSRGB) %#codegen
%linearRGBToXYZTransform Return the 3x3 matrix used to convert RGB to XYZ
%
%   M = linearRGB2XYZTransform(isSRGB) returns the matrix to convert linear
%   RGB triplets to XYZ triplets for either sRGB or Adobe RGB 1998.
%
%   Reference: RGB/XYZ Matrices, Bruce Lindbloom,
%   http://www.brucelindbloom.com/Eqn_RGB_XYZ_Matrix.html

%   Copyright 2015 The MathWorks, Inc.

coder.internal.prefer_const(isSRGB);

% Chromaticy coordinates
% Reference: http://www.brucelindbloom.com/index.html?WorkingSpaceInfo.html
xr = 0.64; yr = 0.33;
xb = 0.15; yb = 0.06;
if isSRGB
    xg = 0.30; yg = 0.60;
else
    % Adobe RGB 1998
    xg = 0.21; yg = 0.71;
end

% Compute the matrix to convert linear RGB to XYZ
M = images.color.internal.computeM(whitepoint('d65'),xr,yr,xg,yg,xb,yb);

