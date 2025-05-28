function [R,G,B] = delinearizeProPhotoRGB(linearR,linearG,linearB) %#codegen
%delinearizeProPhotoRGB Delinearize unencoded ProPhoto RGB tristimulous
%values 
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

R = parametricCurveB(linearR);
G = parametricCurveB(linearG);
B = parametricCurveB(linearB);

%--------------------------------------------------------------------------
function y = parametricCurveB(x)

% Curve parameters
Et = cast(1/512,'like',x);

if x < Et
    y = x*16;
else
    y = x^(1/1.8);
end
