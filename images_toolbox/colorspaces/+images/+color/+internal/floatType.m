function type = floatType(x)
% floatType Returns floating-point type based on type of input
%
%    type = images.color.internal.floatType(x)
%
%    Returns 'single' if input is single; otherwise returns double.

%  Copyright 2014-2020 The MathWorks, Inc.

switch class(x)
    case 'single'
        type = 'single';
    case 'double'
        type = 'double';
    otherwise
        type = 'double';
end
end
