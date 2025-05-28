function sam = createNet()
% Helper function that creates the SAM object. Loading SAM MAT file into
% MATLAB is the most expensive portion of creating the SAM object. Ensuring
% this is done only once in the entire MATLAB session

    persistent samnet
    if isempty(samnet)
        samnet = segmentAnythingModel();
    end

    sam = samnet;
end

% Copyright 2023 The MathWorks, Inc.