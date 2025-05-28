function mustBeEXR(fileName)
% Helper function that throws an error if a file is not a valid EXR file

%   Copyright 2022, The MathWorks, Inc.
    if ~isexr(fileName)
        error(message("images:exrfileio:InvalidEXRFile"));
    end
end