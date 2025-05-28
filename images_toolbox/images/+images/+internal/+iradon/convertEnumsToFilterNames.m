function name = convertEnumsToFilterNames(code) %#codegen
% Convert filter name enumerations into names stored as character arrays

%   Copyright 2022 The MathWorks, Inc.

    switch(code)
        case images.internal.iradon.FilterNames.RamLak
            name = 'ram-lak';
        case images.internal.iradon.FilterNames.SheppLogan
            name = 'shepp-logan';
        case images.internal.iradon.FilterNames.Cosine
            name = 'cosine';
        case images.internal.iradon.FilterNames.Hamming
            name = 'hamming';
        case images.internal.iradon.FilterNames.Hann
            name = 'hann';
        case images.internal.iradon.FilterNames.None
            name = 'none';
        otherwise
            % If code reaches here, it indicates an invalid filter name
            % enum was provided. However, these are identified at compile
            % time as they are compile time constants. Hence, using an
            % assert is sufficient.
            assert(false, "Unsupported Filter Name");
            name = 'invalidFilter';
    end
end