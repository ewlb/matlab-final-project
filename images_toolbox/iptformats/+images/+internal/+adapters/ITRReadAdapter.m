classdef ITRReadAdapter < images.internal.adapters.BigImageAdapter
% TIFF Image Read adapter based on the Internal TIFF Reader.

    % Copyright 2018-2020 The MathWorks, Inc.
    
    properties (Access = private)
        ITRObject = [];
        ActiveLevel
        
        % Arbitrary value to ensure at least >1 block is read offline.
        MinStreamLength = 5;
    end
    
    methods
        function obj = ITRReadAdapter(dataSource, mode_)
            obj.DataSource = dataSource;
            obj.Mode = validatestring(mode_, {'r', 'w'}, mfilename, 'Mode');
            
            % Read only
            assert(obj.Mode=='r')
            
            try
                % Get information on all levels in one call
                obj.SourceMetadata = imfinfo(obj.DataSource);
            catch ME
                newException = MException('images:bigimages:couldNotReadMetadata', ME.message);
                throw(newException)
            end
            
            % Warn if TIFF file is a single strip image
            for ind = 1:numel(obj.SourceMetadata)
                if numel(obj.SourceMetadata(ind).StripOffsets) == 1
                    warning(message('images:bigimage:singleStripTiff', ind, obj.SourceMetadata(ind).Filename));
                end
            end
            
            % Ensure all images in file have the same channels and type
            numChannels = [obj.SourceMetadata.SamplesPerPixel];
            bps = [obj.SourceMetadata.BitsPerSample];
            if ~all(numChannels(1) == numChannels) || ~all(bps(1)==bps)
                warning(message('images:bigimage:tiffImagesDoNotMatch'));
            end
            
            % Determine image sizes
            obj.Height = [obj.SourceMetadata.Height];
            obj.Width = [obj.SourceMetadata.Width];
            
            % Find the 'finest' level (most pixels)
            numPixels = obj.Height.*obj.Width;
            [~, finestLevel] = max(numPixels);
            
            % Open the finest level by default
            obj.ITRObject = matlab.io.internal.BigImageTiffReader(dataSource,"ImageIndex", finestLevel);
            obj.ActiveLevel = finestLevel;
            
            % Pick channels and datatype from the finest level
            obj.Channels = obj.ITRObject.SamplesPerPixel;
            obj.PixelDatatype = obj.ITRObject.MLType;
            
            for ind = 1:numel(obj.SourceMetadata)
                if ~isempty(obj.SourceMetadata(ind).StripOffsets)                    
                    obj.IOBlockSize(ind,:) = [obj.SourceMetadata(ind).RowsPerStrip, obj.SourceMetadata(ind).Width];
                else % tiled
                    obj.IOBlockSize(ind,:) = [obj.SourceMetadata(ind).TileLength, obj.SourceMetadata(ind).TileWidth];
                end
            end
            
            obj.SupportsReadAhead = true;
        end
        
        function delete(obj)
            if ~isempty(obj.ITRObject)
                delete(obj.ITRObject);
            end
        end
        
        function s = saveobj(obj)
            s.DataSource = obj.DataSource;
            s.Mode = obj.Mode;
        end
        
        function readAhead(obj, blockOriginsXY, level, blockSize, readSize)
            % Use a asyc thread to start reading these blocks into memory.
            
            if level ~= obj.ActiveLevel
                % If this changed since the object was constructed
                obj.ITRObject = matlab.io.internal.BigImageTiffReader(obj.DataSource,"ImageIndex", level);
                obj.ActiveLevel = level;
            end
            
            if obj.ITRObject.Organization == "Strip"
                % Dont enque, use IMREAD instead
                return;
            end
            
            % Create an array of slice numbers
            IOBlockSizeYX = [obj.ITRObject.SliceHeight, obj.ITRObject.SliceWidth];
            slicesInX = ceil(obj.ITRObject.ImageWidth/obj.ITRObject.SliceWidth);
            slicesInY = ceil(obj.ITRObject.ImageHeight/obj.ITRObject.SliceHeight);
            sliceDims = [slicesInY, slicesInX];
            [x,y] = meshgrid(1:slicesInX, 1:slicesInY);
            sliceNums = x + (y-1)*slicesInX;            
            
            % Compute the slice order (may contain duplicates)
            enqueueOrder = [];
            numIOBlocksPerBlock = 1; 
            
            for ind = 1:size(blockOriginsXY,1)
                blockOriginYX = [blockOriginsXY(ind,2), blockOriginsXY(ind,1)];
                blockEndYX = blockOriginYX+blockSize-1;
                startInSliceNums = ceil(blockOriginYX./IOBlockSizeYX);
                endInSliceNums = ceil(blockEndYX./IOBlockSizeYX);
                endInSliceNums(endInSliceNums>sliceDims) = sliceDims(endInSliceNums>sliceDims);
                slicesForThisBlock = sliceNums(startInSliceNums(1):endInSliceNums(1),startInSliceNums(2):endInSliceNums(2));
                
                if numel(slicesForThisBlock)> numIOBlocksPerBlock
                    numIOBlocksPerBlock = numel(slicesForThisBlock);
                end
                
                % Actual read happens from bottom right to top left in a
                % region to 'poof' the variable into existence
                slicesForThisBlock = slicesForThisBlock';
                slicesForThisBlock = slicesForThisBlock(end:-1:1);
                
                enqueueOrder = [enqueueOrder; slicesForThisBlock(:)]; %#ok<AGROW>
            end
            
            % Increase the cache size if required to hold all the IO blocks
            % required for one call.
            obj.MaxCacheSize = max(readSize*numIOBlocksPerBlock,obj.MaxCacheSize);
            
            % Increase the stream size to hold enough IO blocks for one
            % call to read (in case readSize>1).
            obj.ITRObject.setInputStreamLimit(max(readSize*numIOBlocksPerBlock, obj.MinStreamLength));
            
            % Remove duplicates
            enqueueOrder = unique(enqueueOrder,'stable');
            
            obj.ITRObject.enqueueSlices(enqueueOrder');
        end
        
        
        function data = readBlock(obj, level, blockStart)
            % Re-open object if level is different from constructed
            if obj.ActiveLevel ~= level
                obj.ITRObject = matlab.io.internal.BigImageTiffReader(obj.DataSource,"ImageIndex", level);
                obj.ActiveLevel = level;
            end
            
            sliceNum = obj.ITRObject.computeSliceNum(blockStart);
            data = obj.ITRObject.readCompleteSlice(sliceNum);
            
            if obj.ITRObject.Photometric == "MinIsWhite" ...
                    && islogical(data)
                % g1901885 - The Tiff library flips the raw binary data.
                % Most likely not what users intent - use raw data instead
                % by undoing the flip
                data = ~data;
            end
            
            obj.updateNNZ(level, blockStart, data, false);
        end
        
        
        function data = readRegion(obj, level, regionStartIntrinsic, regionEndIntrinsic)
            if obj.ITRObject.Organization == "Strip"
                % imread (which uses rtifc) is faster
                rows = [regionStartIntrinsic(1), regionEndIntrinsic(1)];
                cols = [regionStartIntrinsic(2), regionEndIntrinsic(2)];
                data = imread(obj.SourceMetadata(1).Filename, 'PixelRegion', {rows, cols},'Index', level, 'Info', obj.SourceMetadata);
            else
                % Fall back to readBlock via the super class method
                data = readRegion@images.internal.adapters.BigImageAdapter(obj, level, regionStartIntrinsic, regionEndIntrinsic);
            end
        end
        
        function pctNNZ = computeRegionNNZ(obj, level, regionStartIntrinsic, regionEndIntrinsic)
            if obj.ITRObject.Organization == "Strip"
                data = obj.readRegion(level, regionStartIntrinsic, regionEndIntrinsic);
                pctNNZ = nnz(data)/numel(data);
            else
                pctNNZ = computeRegionNNZ@images.internal.adapters.BigImageAdapter(obj, level, regionStartIntrinsic, regionEndIntrinsic);
            end
        end
        
    end
    
    
    methods (Static)
        function obj = loadobj(s)
            obj = images.internal.adapters.ITRReadAdapter(s.DataSource, s.Mode);
        end
    end
end
