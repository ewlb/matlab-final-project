function M = proPhotoRGBToXYZTransform() %#codegen
%PROPHOTORGBTOXYZTRANSFORM Return the 3x3 matrix used to convert ProPhoto
%RGB to XYZ 
%
%   M = proPhotoRGBToXYZTransform() returns the matrix to convert
%   ProPhoto RGB triplets to XYZ triplets.
%
%   Reference: RGB/XYZ Matrices, Bruce Lindbloom,
%   http://www.brucelindbloom.com/Eqn_RGB_XYZ_Matrix.html

%   Copyright 2022 The MathWorks, Inc.

    xr = 0.734699; yr = 0.265301;
    xg = 0.159597; yg = 0.840403;
    xb = 0.036598; yb = 0.000105;
    
    M = images.color.internal.computeM(whitepoint('d50'), xr, yr, xg, yg, xb, yb);
end