classdef InterpModes < int8
% Enumeration class that holds the interpolation modes
% This is primarily required to support input parsing during codegen for
% IRADON. 

%   Copyright 2022 The MathWorks, Inc.

    enumeration
        Linear      (0)
        Nearest     (1)
        Spline      (2)
        PChip       (3)
        V5Cubic     (4)
        Invalid     (5)
    end
        
end