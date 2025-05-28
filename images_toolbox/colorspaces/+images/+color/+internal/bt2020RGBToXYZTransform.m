function M = bt2020RGBToXYZTransform()
%bt20202RGBToXYZTransform Return the 3x3 matrix used to convert BT.2020
%RGB to XYZ 
%
%   M = bt2020RGBToXYZTransform() returns the matrix to convert
%   BT.2020 RGB triplets to XYZ triplets.
%
%   Reference: RGB/XYZ Matrices, Bruce Lindbloom,
%   http://www.brucelindbloom.com/Eqn_RGB_XYZ_Matrix.html

%   Copyright 2020 The MathWorks, Inc.

    xr = 0.708; yr = 0.292;
    xg = 0.170; yg = 0.797;
    xb = 0.131; yb = 0.046;
    
    M = images.color.internal.computeM(whitepoint('d65'), xr, yr, xg, yg, xb, yb);
end