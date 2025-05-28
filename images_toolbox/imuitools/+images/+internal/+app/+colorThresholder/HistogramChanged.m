classdef HistogramChanged < handle
%

% Copyright 2013-2020 The MathWorks, Inc.

    events
        changed
    end
    
    properties
        newSelection = [];
    end
    
    methods
        function obj = HistogramChanged
        end
    end
end