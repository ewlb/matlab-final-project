classdef BasicCache < handle
%BasicCache   Handle object used to cache values.


% Copyright 2020 The MathWorks, Inc.

    properties
        Value
    end
    
    methods
        function obj = BasicCache(val)
            obj.Value = val;
        end
    end
end