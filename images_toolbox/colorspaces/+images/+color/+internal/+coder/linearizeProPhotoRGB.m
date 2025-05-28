function [linearR,linearG,linearB] = linearizeProPhotoRGB(R,G,B) %#codegen
%linearizeProPhotoRGB Linearize unencoded ProPhoto RGB tristimulous values
%
%   The transfer function for ProPhoto RGB is below:
%     f(u) = 0,               u < 0
%     f(u) = u*16,            0 <= u < Et
%     f(u) = u^(1/1.8),       Et <= u < 1
%     f(u) = 1                u >= 1
%
%   where u represents a color value and with parameters:
%     Et = 1/512
%
%   This code, however, does not clip the values outside the range [0, 1].
%
%   The tristimulous input values are expected to be single or double.

%   Copyright 2022 The MathWorks, Inc.

linearR = parametricCurveA(R);
linearG = parametricCurveA(G);
linearB = parametricCurveA(B);

%--------------------------------------------------------------------------
function y = parametricCurveA(x)

Et = cast(1/512,'like',x);

if x < 16*Et
    y = x/16;
else
    y = x^1.8;
end
