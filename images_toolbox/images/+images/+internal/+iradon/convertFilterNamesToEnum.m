function code = convertFilterNamesToEnum(name) %#codegen
% Helper function that converts filter name character arrays into
% enumerations

%   Copyright 2022 The MathWorks, Inc.

    switch(name)
        case 'ram-lak'
            code = images.internal.iradon.FilterNames.RamLak;
        case 'shepp-logan'
            code = images.internal.iradon.FilterNames.SheppLogan;
        case 'cosine'
            code = images.internal.iradon.FilterNames.Cosine;
        case 'hamming'
            code = images.internal.iradon.FilterNames.Hamming;
        case 'hann'
            code = images.internal.iradon.FilterNames.Hann;
        case 'none'
            code = images.internal.iradon.FilterNames.None;
        otherwise
            % If code reaches here, it indicates an invalid filter name
            % was provided. However, these are identified at compile time
            % as they are compile time constants. Hence, using an assert is
            % sufficient.
            assert(false, "Unsupported Filter Name");
            code = images.internal.iradon.FilterNames.Invalid;
    end
end