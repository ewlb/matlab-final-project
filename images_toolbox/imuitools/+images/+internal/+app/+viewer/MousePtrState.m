classdef MousePtrState < uint8
% Enumerations listing the various states of the mouse pointer

%   Copyright 2023 The MathWorks, Inc.

    enumeration
        Default     (0)
        Dropper     (1)
        Measure     (2)
        Crop        (3)
    end
end