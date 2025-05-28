classdef BigImageAdapter < handle
% BigImageAdapter object adapter used for all file I/O.

    % Copyright 2019-2020 The MathWorks, Inc.
    
    properties (SetAccess = protected, GetAccess = public)
        DataSource char
        Mode(1,1) char = 'r'
    end
    
    
    % MetaData - should be populated in constructor
    properties (SetAccess = protected, GetAccess = public)
        SourceMetadata(1,:) struct
        IOBlockSize(:,2) double {mustBeInteger, mustBePositive}
        Channels(1,:) double {mustBeInteger, mustBePositive}
        Width(1,:) double {mustBeInteger, mustBePositive}
        Height(1,:) double {mustBeInteger, mustBePositive}
        PixelDatatype(1,:) string
    end
    
    properties (Hidden)
        UseMemoryCache = true
        % CacheSize Maximum number of tiles to store in in-memory cache
        % Convervative (arbitrary) choice.
        MaxCacheSize(1,1) double = 4
        
        BlockNNZ cell= {}
        
        SupportsReadAhead = false
    end
    
    properties (Access=private)
        MemoryCache = {}
        Keys = {};
        InsertIndex = 1;
    end
    
    
    methods (Abstract)
        % Return a block of data starting at blockStart. 
        % Note: data SHOULD be partial if around the edge, and there is not
        %       enough data for a full block.
        data = readBlock(obj, level, blockStart)
    end
    
    
    % Optional methods with default implementations
    methods
        function data = readRegion(obj, level, regionStartIntrinsic, regionEndIntrinsic)
            % Note: Intrinsic => (row, col) order
            
            % This read should INCLUDE both start and end locations
            % bigimage's readRegion would have set regionEndIntrinsic
            % appropriately.
            blockSize = [obj.IOBlockSize(level,1) obj.IOBlockSize(level,2)];
            
            % Top left block start
            topLeftBlockStart = floor((regionStartIntrinsic-1)./blockSize).*blockSize;
            % Blocks start at one after
            topLeftBlockStart = topLeftBlockStart+1;
            
            % Bottom Right Block start
            botRightBlockStart = floor((regionEndIntrinsic-1)./blockSize).*blockSize;
            botRightBlockStart = botRightBlockStart+1;
                        
            % Populate from bottom right in inverse col major order
            for blkRowStart = botRightBlockStart(1):-blockSize(1):topLeftBlockStart(1)
                for blkColStart = botRightBlockStart(2):-blockSize(2):topLeftBlockStart(2)
                    blkStartInImage = [blkRowStart, blkColStart];
                    oneBlock = obj.readCachedBlock(level, blkStartInImage);
                    
                    blkStartInRegion = blkStartInImage-topLeftBlockStart+1;
                    % Note - this could be a partial block 
                    blkEndInRegion = blkStartInRegion + size(oneBlock,[1 2]) -1;
                    
                    % This trick allows data to be initialized based on
                    % actual data returned (since each level could have
                    % different types/channels).
                    if ismatrix(oneBlock) 
                        % This specialization is required to handle row vectors
                        data(blkStartInRegion(1):blkEndInRegion(1), blkStartInRegion(2):blkEndInRegion(2)) = oneBlock;
                    else
                        data(blkStartInRegion(1):blkEndInRegion(1), blkStartInRegion(2):blkEndInRegion(2),:) = oneBlock;
                    end                    
                end
            end
            
            % To account for partial blocks, compute based on read data            
            readRegionEndIntrinsic = topLeftBlockStart+size(data,[1 2])-1;
            botRightExtra = max(readRegionEndIntrinsic-regionEndIntrinsic,0);
            % Extra on top left due to having to read at block margins
            topLeftExtra = regionStartIntrinsic-topLeftBlockStart+1;
            
            % Trim extra data        
            data = data(topLeftExtra(1):end-botRightExtra(1), topLeftExtra(2):end-botRightExtra(2),:);
        end
        
        function updateNNZ(obj, level, blockStart, data, forceRecompute)
            
            % NNZ is used only on 'Mask' inputs to bigimage/Datastore. And
            % Masks _have_ to be single channel. So only compute this value
            % for single channel images. Also note we expect all images to
            % have the same number of Channels.
            if obj.Channels(1)~=1
                return
            end
            
            if numel(obj.BlockNNZ)<level || isempty(obj.BlockNNZ{level}) || numel(obj.BlockNNZ{level})==1
                % Create the table
                sizeInBlocks = ceil([obj.Height(level)/obj.IOBlockSize(level,1), ...
                    obj.Width(level)/obj.IOBlockSize(level,2)]);
                bnnzs = nan(sizeInBlocks);
                obj.BlockNNZ{level} = bnnzs;
            end
            % Compute block index
            blockSub = ceil(blockStart./obj.IOBlockSize(level,:));
            
            if forceRecompute || isnan(obj.BlockNNZ{level}(blockSub(1), blockSub(2)))
                % Update if forced (while writing) or if this block was
                % never computed before
                obj.BlockNNZ{level}(blockSub(1), blockSub(2)) = nnz(data)/numel(data);
            end
        end
        
        function pctNNZ = computeRegionNNZ(obj, level, regionStartIntrinsic, regionEndIntrinsic)
            blockSize = [obj.IOBlockSize(level,1) obj.IOBlockSize(level,2)];
            
            % Top left block start
            allBlocksStart = floor((regionStartIntrinsic-1)./blockSize).*blockSize;
            % Blocks start at one after
            allBlocksStart = allBlocksStart+1;
            % Additional data we will end up reading on top left
            topLeftPadding = regionStartIntrinsic-allBlocksStart;
            
            
            % Bottom right block end
            allBlocksEnd = ceil(regionEndIntrinsic./blockSize).*blockSize;
            botRightPadding = allBlocksEnd-regionEndIntrinsic;
            
            % End block's start
            endBlockStart = floor((regionEndIntrinsic-1)./blockSize).*blockSize;
            endBlockStart = endBlockStart+1;
            
            % Total data we would end up reading will be more
            outputSize = allBlocksEnd - allBlocksStart+1;
            
            data = false([outputSize obj.Channels]);
            
            blockStart = allBlocksStart;
            insertStart = [1 1];
            while blockStart(1) <= endBlockStart(1)
                while blockStart(2) <= endBlockStart(2)
                    
                    partNNZ = obj.getBlockPctNNZ(level, blockStart);
                    if partNNZ == 1
                        onePart = true([blockSize, obj.Channels]);
                    elseif partNNZ == 0
                        onePart = false([blockSize, obj.Channels]);
                    else
                        onePart = obj.readCachedBlock(level, blockStart);
                    end
                    
                    partSize = [size(onePart,1), size(onePart,2)]; % partial blocks may be read
                    insertEnd = insertStart+partSize-1;
                    data(insertStart(1):insertEnd(1),insertStart(2):insertEnd(2),:) = ...
                        onePart;
                    blockStart(2) = blockStart(2) + partSize(2);
                    insertStart(2) = insertStart(2)+partSize(2);
                end
                blockStart(1) = blockStart(1) + partSize(1);
                blockStart(2) = allBlocksStart(2);
                insertStart(1) = insertStart(1)+blockSize(1);
                insertStart(2) = 1;
            end
            data = data(topLeftPadding(1)+1:end-botRightPadding(1),...
                topLeftPadding(2)+1:end-botRightPadding(2),:);            
            pctNNZ = nnz(data)/numel(data);            
        end
        
    end
    
    
    % Optional methods without (useful) default implementations
    methods
        function writeMetadata(obj,resolutionLevelSizes, blockSize, channels, pixelClass, metadata)%#ok<INUSD>
            error(message('images:bigimage:NoWriteSupport'))
        end
        function appendMetadata(obj,resolutionLevelSizes, blockSize, channels, pixelClass, metadata)%#ok<INUSD>
            error(message('images:bigimage:NoWriteSupport'))
        end
        function writeBlock(obj, level, regionStartIntrinsic, data)%#ok<INUSD>
            error(message('images:bigimage:NoWriteSupport'))
        end
        function finalizeWrite(obj)%#ok<MANU>
            error(message('images:bigimage:NoWriteSupport'))
        end
    end
       
    methods (Access = private)
        function block = readCachedBlock(obj, level, blockStart)                        
            
            if ~obj.UseMemoryCache
                % Skip looking at cache
                block = readBlock(obj, level, blockStart);
                return
            end
            
            blockKey = sprintf('%d_%d_%d',level, blockStart(1), blockStart(2));
            
            matchIndex = find(strcmp(blockKey, obj.Keys));
            if isempty(matchIndex)
                % Miss, read from source
                block = obj.readBlock(level,blockStart);
                % Insert
                if (obj.InsertIndex+1)==obj.MaxCacheSize
                    obj.InsertIndex = 1;
                else
                    obj.InsertIndex = obj.InsertIndex+1;
                end
                obj.MemoryCache{obj.InsertIndex} = block;
                obj.Keys{obj.InsertIndex} = blockKey;
            else
                % Cache hit, extract
                block = obj.MemoryCache{matchIndex};
            end
        end
        
        function blkNNZPct =  getBlockPctNNZ(obj, level, blockStart)
            blkNNZPct = NaN;
            % Compute block index
            blockSub = ceil(blockStart./obj.IOBlockSize(level,:));
            if numel(obj.BlockNNZ)>=level && all(size(obj.BlockNNZ{level})>=blockSub)
                blkNNZPct = obj.BlockNNZ{level}(blockSub(1), blockSub(2));
            end
        end
    end
    
end

