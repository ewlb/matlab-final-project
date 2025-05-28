function Gmag = imgradientdog(I,sigma)
%IMGRADIENTDOG Derivative of gaussian gradient of input image I.

% Copyright 2014-2024 The MathWorks, Inc.

if (sigma <= 0)
    error('Expected sigma to be positive');
end
 
filtRadius = ceil(2*sigma);

x = -filtRadius(1):filtRadius(1);
hx = -x.*exp(-(x.*x)/(2*sigma(1)*sigma(1))); 
normalizationFactor = sum(hx(1:filtRadius(1)));
hx = hx/normalizationFactor;

if numel(filtRadius) > 1
    y = -filtRadius(2):filtRadius(2);
    hy = -y.*exp(-(y.*y)/(2*sigma(2)*sigma(2)));
    normalizationFactor = sum(hy(1:filtRadius(1)));
    hy = hy/normalizationFactor;
    hy = hy.';
else
    hy = hx.';
end

% Compute directional gradient
if isinteger(I)
    I = double(I);
end
Gx = imfilter(I,hx,'replicate');
Gy = imfilter(I,hy,'replicate');

% Compute gradient magnitude
Gmag = hypot(Gx,Gy);
