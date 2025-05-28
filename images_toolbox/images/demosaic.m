function RGB = demosaic(I, sensorAlignment)

matlab.images.internal.errorIfgpuArray(I);
validateattributes(I,{'uint8','uint16','uint32'},{'real','2d'}, ...
    mfilename, 'I',1);

sensorAlignment = validatestring(sensorAlignment, ...
    {'gbrg', 'grbg', 'bggr', 'rggb'}, mfilename, ...
    'sensorAlignment',2);

sizeI = size(I);
if (sizeI(1) < 5 || sizeI(2) < 5)
    error(message('images:demosaic:invalidImageSize'));
end

RGB = images.internal.builtins.demosaic(I, sensorAlignment);

%   Copyright 2007-2022 The MathWorks, Inc.