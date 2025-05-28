classdef MatrixAdapter < images.internal.adapters.BigImageAdapter
% Get height, width, class and channel information using Matrix adapter.

% Copyright 2019-2020 The MathWorks, Inc.
    
    properties
        Data
    end
    
    methods
        function obj = MatrixAdapter(varName, data)
            obj.DataSource = varName;
            obj.Data = data;
            
            obj.Height = size(data,1);
            obj.Width = size(data,2);
            obj.IOBlockSize = [1024 1024];
            obj.PixelDatatype = class(data);
            obj.Channels = size(data,3);
        end
        
        
        function data = readBlock(~, ~, ~)
            % Not used. We instead provide a readRegion and
            % computeRegionNNZ directly. A
            data = [];
            assert(false);
        end
        
        function data = readRegion(obj, level, regionStartIntrinsic, regionEndIntrinsic)
            assert(level==1);
            rows = [regionStartIntrinsic(1), regionEndIntrinsic(1)];
            cols = [regionStartIntrinsic(2), regionEndIntrinsic(2)];
            data = obj.Data(rows(1):rows(2), cols(1):cols(2),:);
            
        end
        
        function pctNNZ = computeRegionNNZ(obj, level, regionStartIntrinsic, regionEndIntrinsic)
            assert(level==1);
            data = obj.readRegion(level, regionStartIntrinsic, regionEndIntrinsic);
            pctNNZ = nnz(data)/numel(data);
        end
        
    end
end

