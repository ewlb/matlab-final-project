function code = convertInterpModesToEnum(name) %#codegen
% Helper function that converts interpolation mode character arrays into
% enumerations

%   Copyright 2022 The MathWorks, Inc.

    switch(name)
        case 'linear'
            code = images.internal.iradon.InterpModes.Linear;
        case 'nearest'
            code = images.internal.iradon.InterpModes.Nearest;
        case 'spline'
            code = images.internal.iradon.InterpModes.Spline;
        case 'pchip'
            code = images.internal.iradon.InterpModes.PChip;
        case 'cubic'
            code = images.internal.iradon.InterpModes.PChip;
        case 'v5cubic'
            code = images.internal.iradon.InterpModes.V5Cubic;
        otherwise
            % If code reaches here, it indicates an invalid interpolation
            % name was provided. However, these are identified at compile
            % time as they are compile time constants. Hence, using an
            % assert is sufficient.
            assert(false, "Unsupported Interpolation Mode");
            code = images.internal.iradon.InterpModes.Invalid;
    end
end