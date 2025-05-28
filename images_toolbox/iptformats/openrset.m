function openrset(filename)

matlab.images.internal.errorIfgpuArray(filename);
filename = matlab.images.internal.stringToChar(filename);

if isrset(filename)
    images.compatibility.imtool.r2023b.imtool(filename)
else
    error(message('images:openrset:invalidRSet', filename));
end

%   Copyright 2009-2023 The MathWorks, Inc.