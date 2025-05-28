function [Gmag] = imgradientdog3(I,sigma)
%IMGRADIENTDOG3 3D Derivative of gaussian gradient of input image I.

% Copyright 2016-2024 The MathWorks, Inc.

if (any(sigma <= 0))
    error('Expected sigma to be positive')
end

if numel(sigma)~=3
    error('Expected sigma to be a 3-element vector')
end

filtRadius = ceil(2*sigma);

x = -filtRadius(1):filtRadius(1);
hx = -x.*exp(-(x.*x)/(2*sigma(1)*sigma(1))); 
normalizationFactor = sum(hx(1:filtRadius(1)));
hx = hx/normalizationFactor;

y = -filtRadius(2):filtRadius(2);
hy = -y.*exp(-(y.*y)/(2*sigma(2)*sigma(2)));
normalizationFactor = sum(hy(1:filtRadius(1)));
hy = hy/normalizationFactor;
hy = hy.';

z = -filtRadius(3):filtRadius(3);
hz = -z.*exp(-(z.*z)/(2*sigma(3)*sigma(3)));
normalizationFactor = sum(hz(1:filtRadius(1)));
hz = hz/normalizationFactor;
hz = reshape(hz,1,1,numel(hz));

% Compute directional gradient
if isinteger(I)
    I = double(I);
end
Gx = imfilter(I,hx,'replicate');
Gy = imfilter(I,hy,'replicate');
Gz = imfilter(I,hz,'replicate');

% Compute gradient magnitude
Gmag = sqrt( Gx.^2 + Gy.^2 + Gz.^2 );
