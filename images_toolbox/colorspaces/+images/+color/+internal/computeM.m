function M = computeM(referenceWhite,xr,yr,xg,yg,xb,yb) %#codegen
% Given the chromaticity coordinates of an RGB systen (xr,yr), (xg,yg)
% and (xb,yb), and its reference white (Xw,Yw,Zw), return the 3-by-3
% matrix for converting linear RGB tristimuli to XYZ.

%   Copyright 2020, The Mathworks, Inc.

Xr = xr/yr;
Yr = 1;
Zr = (1 - xr - yr)/yr;

Xg = xg/yg;
Yg = 1;
Zg = (1 - xg - yg)/yg;

Xb = xb/yb;
Yb = 1;
Zb = (1 - xb - yb)/yb;

Xrgb = [Xr Xg Xb; ...
        Yr Yg Yb; ...
        Zr Zg Zb];

S = Xrgb \ referenceWhite';

S = S';

M = [S; S; S] .* Xrgb;