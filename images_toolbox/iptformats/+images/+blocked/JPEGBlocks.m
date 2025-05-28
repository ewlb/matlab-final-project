classdef JPEGBlocks < images.blocked.GenericImageBlocks
    properties(Dependent)
        JPEGQuality (1,1) double
               
        CompressionMode (1,1) string
    end
    
    properties(Access = private)
        JPEGQuality_ (1,1) double = 75
        CompressionMode_ (1,1) string = "Lossy"
    end
    
    methods
        
        function jq = get.JPEGQuality(obj)
            jq = obj.JPEGQuality_;
        end
        function set.JPEGQuality(obj, jq)
            obj.JPEGQuality_ = jq;
            obj.WriteArguments = {'Quality', obj.JPEGQuality_, 'Mode', obj.CompressionMode_};
        end
        
        function m = get.CompressionMode(obj)
            m = obj.CompressionMode_;
        end
        function set.CompressionMode(obj, m)
            m = validatestring(m, ["Lossy", "Lossless"]);
            obj.CompressionMode_ = m;
            obj.WriteArguments = {'Quality', obj.JPEGQuality_, 'Mode', obj.CompressionMode_};
        end
    end
end
%   Copyright 2020-2022 The MathWorks, Inc.
