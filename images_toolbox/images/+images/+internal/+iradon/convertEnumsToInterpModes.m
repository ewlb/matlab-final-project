function name = convertEnumsToInterpModes(code) %#codegen
% Convert interpolation mode enumerations into names stored as character
% arrays

%   Copyright 2022 The MathWorks, Inc.

    switch(code)
        case images.internal.iradon.InterpModes.Linear
            name = 'linear';
        case images.internal.iradon.InterpModes.Nearest
            name = 'nearest';
        case images.internal.iradon.InterpModes.Spline
            name = 'spline';
        case images.internal.iradon.InterpModes.PChip
            name = 'pchip';
        case images.internal.iradon.InterpModes.V5Cubic
            name = 'v5cubic';
        otherwise
            % If code reaches here, it indicates an invalid interpolation
            % mode enum was provided. However, these are identified at
            % compile time as they are compile time constants. Hence, using
            % an assert is sufficient.
            assert(false, "Unsupported Interpolation Mode");
            name = 'invalidMode';
    end
end