function angle = colorangle(RGB1,RGB2)
f = @(x,n) validateattributes(x, ...
    {'single','double','uint8','uint16'}, ...
    {'real','nonsparse','nonempty','vector','numel',3}, ...
    mfilename,['RGB' num2str(n)],n);

% illuminant
f(RGB1,1);

% reference
f(RGB2,2);

if ~isa(RGB1, class(RGB2))
    error(message('images:validate:differentClassMatrices','RGB1','RGB2'));
end

RGB1 = im2double(RGB1(:));
RGB2 = im2double(RGB2(:));
N1 = norm(RGB1);
N2 = norm(RGB2);
if isequal(RGB1,RGB2)
    angle = 0;
else
    angle = acos(RGB1' * RGB2 / (N1 * N2));
    angle = 180 / pi * angle;
end

%   Copyright 2016-2022 The MathWorks, Inc.