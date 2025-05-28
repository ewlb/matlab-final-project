classdef bigimageDatastore < handle & ...
        matlab.mixin.Copyable & ...
        matlab.io.Datastore & ...
        matlab.io.datastore.Partitionable & ...
        matlab.io.datastore.Shuffleable & ...
        matlab.io.datastore.mixin.Subsettable
    %bigimageDatastore Datastore for use with blocks of bigimage objects
    % BIMDS = bigimageDatastore(BIGIMAGES) creates a bigimageDatastore
    % object using a vector of bigimage objects at the finest resolution
    % level available in each of them.
    %
    % BIMDS = bigimageDatastore(BIGIMAGES, LEVELS) creates a
    % bigimageDatastore object using a vector of bigimage objects at
    % corresponding resolution levels specified in the numeric array,
    % LEVELS. LEVELS should either be a scalar or a numeric integer valued
    % vector equal to the length of the BIGIMAGES vector.
    %
    % BIMDS = bigimageDatastore(..., Name, Value) provides
    % additional arguments using one or more name-value pairs. Supported
    % parameters include:
    %
    % 'BlockLocationSet'      Sets the BlockLocationSet property of the
    %                         bigimageDatastore. Specified as a scalar
    %                         blockLocationSet object. If specified,
    %                         BlockSize, Levels, and BlockOffsets cannot be
    %                         specified.
    %
    % 'BlockOffsets'          Sets the BlockOffsets property of the
    %                         bigimageDatastore. It is a 1-by-2 [rows,
    %                         columns] numeric array specifying the spacing
    %                         between two adjacent blocks. Use this
    %                         property to specify overlapping blocks.
    %                         Default value is the same as the BlockSize
    %                         property resulting in non-overlapping blocks.
    %
    % 'BlockSize'             Sets the BlockSize property of the
    %                         bigimageDatastore. It is a 1-by-2 ([rows,
    %                         cols]) numeric array specifying the size of
    %                         data to load in each call to read(). Default
    %                         value is the first bigimage's BlockSize
    %                         property.
    %
    % 'BorderSize'            Sets the BorderSize property of the
    %                         bigimageDatastore. It is a 1-by-2 [rows,
    %                         columns] numeric array specifying the
    %                         additional border pixels to include around a
    %                         block. A border size of [r,c] will result in
    %                         blocks of size BlockSize + 2*[r,c] accounting
    %                         for the border on all four sides.
    %
    % 'IncompleteBlocks'      Sets the IncompleteBlocks property. This
    %                         property controls how incomplete blocks are
    %                         handled. METHOD should be a string with one
    %                         of these values:
    %
    %                         'exclude'  - Incomplete blocks are excluded
    %                                      from read().
    %                         'same'     - Incomplete blocks are included,
    %                                      and read() returns the partial
    %                                      data as-is. data will be smaller
    %                                      than specified BlockSize for
    %                                      these incomplete blocks. This is
    %                                      the default value.
    %                         'pad'      - Incomplete blocks are padded
    %                                      based on the PadMethod property.
    %
    % 'PadMethod'             Method for padding incomplete blocks
    %                         PadMethod is one of the following:
    %                           'replicate' - Repeats the border elements
    %                           'symmetric' - Pads with mirror reflections
    %                         Or a scalar depending on the type of the
    %                         first bigimage:
    %                           - If the first bigimage is numeric, a
    %                           numeric scalar of type ClassUnderlying of
    %                           that bigimage.    
    %                           - If the first bigimage has categorical
    %                           data, the value can be one of the elements
    %                           of its Classes specified as a string. To
    %                           pad with <undefined> values, use the
    %                           missing literal.        
    %                         Subsequent bigimages which are not the same
    %                         type as the first are padded with the default
    %                         value. Default value is 0 for numeric
    %                         bigimages and missing for categorical
    %                         bigimages.
    %
    % 'ReadSize'              Number of blocks to read in a call to the
    %                         read function, specified as a positive
    %                         integer scalar. Each call to the read
    %                         function reads at most ReadSize blocks.
    %                         Default value is 1.
    %
    % bigimageDatastore properties:
    %   BlockLocationSet   - blockLocationSet object
    %   BlockOffsets       - Space between two blocks
    %   BlockSize          - Block size of a data unit
    %   BorderSize         - Padding size required around a block
    %   Images             - Source of image blocks, array of bigimage objects
    %   IncompleteBlocks   - Controls incomplete edge blocks
    %   Levels             - Resolution levels used to read blocks
    %   PadMethod          - Method for padding incomplete blocks
    %   ReadSize           - Number of blocks to read per read() call
    %
    %  bigimageDatastore methods:
    %    combine         - Create a new bigimageDatastore that horizontally
    %                      concatenates the result of read from two or more input
    %                      bigimageDatastore.
    %    hasdata         - Returns true if there is more data in the datastore
    %    numpartitions   - Returns an estimate for a reasonable number of
    %                      partitions to use with the partition function,
    %                      according to the total data size
    %    partition       - Returns a new datastore that represents a single
    %                      partitioned portion of the original datastore
    %    preview         - Reads the first block
    %    read            - Read the next block
    %    readRelative    - Read a neighboring block with a relative position
    %    reset           - Resets the datastore to the start of the data
    %    shuffle         - Shuffles the files of ImageDatastore using randperm
    %    transform       - Create an altered form of the current
    %                      bigimageDatastore by specifying a function handle that
    %                      will execute after read on the current
    %                      bigimageDatastore.
    %
    %   Example 1
    %   ---------
    %   % Create a bigimageDatastore at a specific level and block size
    %     bim = bigimage('tumor_091R.tif');
    %     subplot(2,1,1)
    %     bigimageshow(bim);
    %     subplot(2,1,2)
    %     % Create a datastore at level 2, with blocksize of [512 512]
    %     bimds = bigimageDatastore(bim, 2, 'BlockSize', [512 512]);
    %     % Read four blocks at a time
    %     bimds.ReadSize = 4;
    %     while hasdata(bimds)
    %         blocks = read(bimds);
    %         % Blocks are returned as cell arrays. Partial edge blocks
    %         % will have smaller size than interior blocks.
    %         disp(blocks);
    %         % Display the blocks
    %         montage(blocks,'Size', [1 4], 'BorderSize',5,'BackgroundColor','b');
    %         title('Press any key to continue');
    %         pause;
    %     end
    %     title('');
    %
    %   Example 2
    %   ---------
    %   % Create a bigimageDatastore with overlapping blocks
    %     bim = bigimage('tumor_091R.tif');
    %     bimds = bigimageDatastore(bim, 3, ...
    %                'BlockSize', [300 300], 'BlockOffsets', [100 100],...
    %                'IncompleteBlocks','exclude');
    %     % Read two blocks at a time
    %     bimds.ReadSize = 2;
    %     while hasdata(bimds)
    %         blocks = read(bimds);
    %         disp(blocks);
    %         % Display the blocks
    %         montage(blocks,'BorderSize',5,'BackgroundColor'   ,'b');
    %         title('Press any key to continue');
    %         pause;
    %     end
    %     title('');
    %
    %   Example 3
    %   ---------
    %   % Create a bigimageDatastore using a coarse level mask
    %     bim = bigimage('tumor_091R.tif');
    %
    %     % Create a mask at the coarsest level
    %     clevel = bim.CoarsestResolutionLevel;
    %     imcoarse = getFullLevel(bim, clevel);
    %     stainMask = ~imbinarize(rgb2gray(imcoarse));
    %     % Retain the original spatial referencing information
    %     bmask = bigimage(stainMask,...
    %                'SpatialReferencing', bim.SpatialReferencing(clevel));
    %     figure
    %     bigimageshow(bmask);
    %
    %     % Create a bigimagedatastore for blocks which have at least 90%
    %     % pixels 'on' in the stained region as defined by the mask.
    %     mbls = selectBlockLocations(bim,...
    %                'Levels', 1, ...
    %                'Masks', bmask, 'InclusionThreshold', 0.90,...
    %                'BlockSize', [256 256]);
    %     bimds = bigimageDatastore(bim, 'BlockLocationSet', mbls);
    %
    %     bimds.ReadSize = 4;
    %     figure
    %     while hasdata(bimds)
    %         blocks = read(bimds);
    %         disp(blocks);
    %         % Display the blocks
    %         montage(blocks,'BorderSize',5,'BackgroundColor'   ,'b');
    %         title('Press any key to continue');
    %         pause;
    %     end
    %     title('');
    %
    % See also bigimage, imageDatastore, blockLocationSet,
    % selectBlockLocations
    
    
    % Copyright 2018-2021 The MathWorks, Inc.
    
    properties (Access = public)
        % ReadSize Number of blocks to read per read() call
        %   Default value is 1.
        ReadSize = 1
        
        % BorderSize  Padding size required around a block
        %   Default value is [0 0].
        BorderSize = [0 0]
        
        % PadMethod  Method for padding incomplete blocks
        %   PadMethod is one of the following:
        %     'replicate' - Repeats the border elements
        %     'symmetric' - Pads with mirror reflections
        % Or a scalar depending on the type of the first bigimage:
        %      - If the first bigimage is numeric, a numeric scalar of type
        %        ClassUnderlying of that bigimage.
        %      - If the first bigimage has categorical data, the value can
        %        be one of the elements of its Classes specified as a
        %        string. To pad with <undefined> values, use the missing
        %        literal.
        % Subsequent bigimages which are not the same type as the first are
        % padded with the default value.
        %
        % Default value is 0 for numeric bigimages and missing for
        % categorical bigimages.
        %
        PadMethod = 0        
    end
    
    properties (SetAccess = private)        
        % Images Source of image blocks, array of bigimage objects
        %   This is a read-only property.
        Images
        
        % Levels Resolution levels used to read blocks
        %   This is a read-only property.
        Levels
        
        % BlockSize Block size of a data unit
        %   Default value is set from the first level BlockSize property of
        %   the first bigimage object in Images property.
        %   This is a read-only property.
        BlockSize
        
        % BlockOffsets Space between two blocks
        %   Default value is equal to the BlockSize property. Use this
        %   property to obtain overlapping blocks. For example, specifying
        %   a value of [1 1] will result in blocks that slide by 1 pixel
        %   across the rows, and then 1 pixel down the columns and so on.
        %   This is a read-only property.
        BlockOffsets
        
        % IncompleteBlocks Controls incomplete edge blocks
        %   Default value is 'same'
        %   This is a read-only property.
        IncompleteBlocks = 'same'
        
        % BlockLocationSet The set of block locations to iterate over
        %  A blockLocationSet object which contains the set of blocks that
        %  the datastore iterates over.
        %  This is a read-only property.
        BlockLocationSet
    end
    
    properties (Hidden = true)
        % InclusionThreshold Mask threshold value controlling block inclusion
        %   Default value is 0.5.  Changing this value resets the datastore.
        InclusionThreshold = 0.5
    end
    
    properties (Hidden = true, SetAccess = private)
        % Masks Masks, array of bigimage objects
        %   This is a read-only property.
        Masks = bigimage.empty()        
    end
    
    properties (Hidden = true, SetAccess = private, Dependent = true)
        Length
    end
    
    properties (Access = private)
        % Index to the next block that will be read
        NextReadIndex
        
        % Table containing NNZ% for mask regions corresponding to each
        % block.
        MaskLocationStats
        
        % Flag indicating that properties are being set during
        % construction.
        IsReady = false
    end
    
    methods (Access = public)
        function obj = bigimageDatastore(bigimages_, varargin) 
            validateattributes(bigimages_, "bigimage", {'nonempty', 'vector'}, mfilename, "bigimages", 1)
            obj.Images = bigimages_;
            
            parser = inputParser;
            parser.FunctionName = mfilename;
            parser.CaseSensitive = false;
            parser.PartialMatching = true;
            parser.KeepUnmatched = false;
            
            parser.addOptional('Levels', [], @(l)...
                validateattributes(l, "numeric", {"integer", "positive"}, mfilename, "Levels"));
            parser.addParameter('BlockSize', obj.Images(1).BlockSize(1,:), @(blockSize)...
                validateattributes(blockSize, "numeric", ...
                {"positive", "integer", "row", "numel", 2}, mfilename, "BlockSize"));
            parser.addParameter('BlockOffsets', [], @(blockOffsets)...
                validateattributes(blockOffsets, "numeric", ...
                {"positive", "integer", "row", "numel", 2}, mfilename, "BlockOffsets"));
            parser.addParameter('PadMethod',0, @(p)validatePadMethod(p, obj.Images))
            % Allow using []
            parser.addParameter('Masks', bigimage.empty(), @(x) ...
                validateattributes(x, {'bigimage'}, ...
                {}, mfilename, "Masks"));
            parser.addParameter('InclusionThreshold', [], ...
                @(icth) validateInclusionThreshold(icth, numel(obj.Images)))
            parser.addParameter('IncompleteBlocks', 'same');
            parser.addParameter('ReadSize', 1);
            parser.addParameter('BorderSize',[0 0]);
            parser.addParameter('BlockLocationSet',[]);
            parser.parse(varargin{:});
            
            obj.IsReady = false;
            
            numImages = numel(obj.Images);

            if contains('Levels', parser.UsingDefaults)
                % Pick finest level from each bigimage
                obj.Levels = [obj.Images.FinestResolutionLevel];
            else
                levels_ = parser.Results.Levels;
                if isscalar(levels_)
                    % Make it equal to number of images
                    levels_ = repmat(levels_, [1 numel(obj.Images)]);
                else
                    % Vector of levels given
                    if isscalar(obj.Images)
                        % replicate single image to match number of levels
                        obj.Images = repmat(obj.Images, [1 numel(levels_)]);
                    end
                    % Update count
                    numImages = numel(obj.Images);
                end
                
                % At this point, numel(images)==numel(levels)
                validateattributes(levels_, "numeric", {"integer","positive", "vector", "numel", numImages}, mfilename, "levels", 2)
                
                % Each level should be valid for its corresponding bigimage
                for ind = 1:numel(levels_)
                    numLevels = numel(obj.Images(ind).SpatialReferencing);
                    validateattributes(levels_(ind), "numeric", {'<=', numLevels}, mfilename, "levels", 2);
                end
                
                obj.Levels = double(levels_);
            end
            
            obj.BlockSize = parser.Results.BlockSize;
            if contains('BlockOffsets', parser.UsingDefaults)
                % Default value
                obj.BlockOffsets = obj.BlockSize;               
            else
                obj.BlockOffsets = parser.Results.BlockOffsets;
            end
            if any(obj.BlockOffsets < obj.BlockSize)
                % Overlapping blocks, turn on cache
                for ind=1:numel(obj.Images)
                    obj.Images(ind).Adapter.UseMemoryCache = true;
                end
            end
                        
            obj.BorderSize = parser.Results.BorderSize;
            
            % Choose default pad method based on class of first
            % bigimage.
            if contains('PadMethod', parser.UsingDefaults)
                if obj.Images(1).IsCategorical
                    obj.PadMethod = missing;
                else
                    obj.PadMethod = 0;
                end
            else % Explicitly specified
                obj.PadMethod = parser.Results.PadMethod;
            end
            
            obj.Masks = parser.Results.Masks;
            % Turn the memory cache on for masks, and validate channels
            for ind = 1:numel(obj.Masks)
                obj.Masks(ind).Adapter.UseMemoryCache = true;
                if obj.Masks(ind).Channels > 1
                    error(message('images:bigimage:maskChannels'))
                end
            end
            if ~isempty(obj.Masks)
                if isscalar(obj.Masks)
                    obj.Masks = repmat(obj.Masks, [1 numel(obj.Images)]);
                else
                    validateattributes(obj.Masks, "bigimage", {'numel', numImages}, mfilename, "Mask");
                end
                if contains('InclusionThreshold', parser.UsingDefaults)
                    obj.InclusionThreshold = repmat(0.5, [1 numel(obj.Masks)]);
                else
                    obj.InclusionThreshold = parser.Results.InclusionThreshold;
                end
            end

            
            str = validatestring(parser.Results.IncompleteBlocks,...
                {'exclude', 'same', 'pad'}, mfilename, "IncompleteBlocks");
            obj.IncompleteBlocks = str;
            
            obj.ReadSize = parser.Results.ReadSize;
            
            obj.validateCategoricalEquivalence();
                                                            
            % BlockLocationSet specified
            if ~contains('BlockLocationSet', parser.UsingDefaults)
                if ~(contains('Masks', parser.UsingDefaults) ...
                        && contains('InclusionThreshold', parser.UsingDefaults)...
                        && contains('BlockOffsets', parser.UsingDefaults)...
                        && contains('Levels', parser.UsingDefaults)...
                        && contains('BlockSize', parser.UsingDefaults))
                    error(message('images:bigimage:IncompatibleWithBLS'))
                end
                obj.BlockLocationSet = parser.Results.BlockLocationSet;             
                obj.IsReady = true;
                % Validate each block, and trim them if required
                % (IncompleteBlocks=="exclude")
                obj.validateAndTrimBlockLocationSet()
                
                obj.Levels = parser.Results.BlockLocationSet.Levels;
                obj.BlockSize = parser.Results.BlockLocationSet.BlockSize;
                obj.BlockOffsets = parser.Results.BlockLocationSet.BlockSize;
            else
                obj.IsReady = true;
                obj.buildBlockSet()
            end
                        
            obj.triggerReadAhead();
            
            obj.reset()
        end
        
        function tf = hasdata(obj)
            %hasdata Returns true if more data is available.
            %     TF = hasdata(bimds) returns a logical scalar TF
            %     indicating availability of data. This method should be
            %     called before calling read. hasdata is used in
            %     conjunction with read to read all the data within the
            %     bigimageDatastore.
            %
            %     Example
            %     -------
            %     bim = bigimage('tumor_091R.tif');
            %     bimds = bigimageDatastore(bim,1);
            %     while hasdata(bimds)
            %         [data, info] = read(bimds);
            %     end
            %
            % See also bigimageDatastore, read, reset
            
            tf = obj.NextReadIndex<=size(obj.BlockLocationSet.BlockOrigin,1);
        end
        
        function pbimds = partition(obj, numP, idx)
            % partition Return a partitioned part of the bigimageDatastore.
            %     SUBBIMDS = partition(BIMDS,N,INDEX) partitions DS into N
            %     parts and returns the partitioned Datastore, SUBDS,
            %     corresponding to INDEX. An estimate for a reasonable
            %     value for N can be obtained by using the NUMPARTITIONS
            %     function.
            %
            %     Example
            %     -------
            %     bim = bigimage('tumor_091R.tif');
            %     bimds = bigimageDatastore(bim,2);
            %
            %     bimdsp1 = partition(bimds, 2, 1);
            %     disp('Partition 1');
            %     while hasdata(bimdsp1)
            %         [data, info] = read(bimdsp1);
            %         disp(info);
            %     end
            %
            %     bimdsp2 = partition(bimds, 2, 2);
            %     disp('Partition 2');
            %     while hasdata(bimdsp2)
            %         [data, info] = read(bimdsp2);
            %         disp(info);
            %     end
            %
            % See also bigimageDatastore, numpartitions, maxpartitions
            
            validateattributes(numP, "numeric", {"scalar", "nonempty", "positive", "integer"}, ...
                "partition", "N");
            validateattributes(idx, "numeric", {"scalar", "nonempty", "positive", "integer", "<=", numP}, ...
                "partition", "INDEX");
            pbimds = copy(obj);
                                                            
            sizeInEachPartition = ceil(obj.Length/numP);
            
            startInd = (idx-1)*sizeInEachPartition+1;
            endInd = min(startInd+sizeInEachPartition-1, obj.Length);
            
            
            partionedBlockOrigin = obj.BlockLocationSet.BlockOrigin(startInd:endInd,:);
            partionedImageNumber = obj.BlockLocationSet.ImageNumber(startInd:endInd,:);
            
            pbimds.BlockLocationSet = blockLocationSet(partionedImageNumber,partionedBlockOrigin,...
                obj.BlockLocationSet.BlockSize, obj.BlockLocationSet.Levels);
            pbimds.reset()
        end
        
        function oneblock = preview(obj)
            %  preview   Reads the first block
            %     b = preview(bimds) Returns the first block from the start
            %     of the datastore.
            %
            %     See also bigimageDatastore, read, hasdata, reset, readall,
            %     progress.                        
            if obj.Length == 0
                oneblock = [];
            else
                oneblock = obj.readOneBlock(obj.BlockLocationSet.BlockOrigin(1,:), obj.BlockLocationSet.ImageNumber(1), obj.BlockLocationSet.Levels(1), true);
            end
        end
        
        function amount = progress(obj)
            %  progress  Amount of datastore read.
            %     R = progress(BIMDS) gives the ratio of the datastore
            %     BIMDS that has been read.
                        
            amount = (obj.NextReadIndex - 1) / obj.Length;
        end
        
        function [multiReadData, infoStruct, blockLocationsIntrinsic] = read(obj)
            % read Read data and information about the extracted data.
            %     BCELL = read(BIMDS) Returns the data extracted from the
            %     bigimageDatastore, BIMDS. BCELL is a cell array of block
            %     data of length ReadSize.
            %
            %     [B, INFO] = read(BIMDS) also returns information about
            %     where the data was extracted from the bigimageDatastore.
            %     INFO is a scalar struct with the following fields. These
            %     fields are arrays if ReadSize>1.
            %
            %       Level           - The level from which this data was
            %                         read.
            %       ImageNumber     - An index into the bimds.Images
            %                         array corresponding to the bigimage
            %                         from which this block was read.
            %       BlockStartWorld - The center world coordinates of the
            %                         top left pixel of the block,
            %                         excluding any padding.
            %       BlockEndWorld   - The center world coordinates of the
            %                         bottom right pixel of the block,
            %                         excluding any padding.
            %       DataStartWorld  - The center world coordinates of the
            %                         top left pixel of the block,
            %                         including padding pixels.
            %       DataEndWorld    - The center world coordinates of the
            %                         bottom right pixel of the block,
            %                         including padding pixels.
            %
            % Note: When a bigimageDatastore is created with a Mask, the
            % read method includes computation time needed to identify a
            % valid image block which satisfies the Mask at the specified
            % InclusionThreshold. This will result in varying run times
            % which depend on the Mask size and sparsity.
            %
            %     Example
            %     -------
            %     bim = bigimage('tumor_091R.tif');
            %     bimds = bigimageDatastore(bim,1);
            %     while hasdata(bimds)
            %         [data, info] = read(bimds);
            %         disp(info);
            %     end
            %
            %  See also bigimageDatastore, readsize
            doCatConversion = true;
            [multiReadData, infoStruct, blockLocationsIntrinsic] = obj.readCore(doCatConversion);            
        end
        
        function data = readall(obj) %#ok<MANU,STOUT>
            error(message('images:bigimage:readallNotSupported'))
        end
        
        function [data, info] = readRelative(obj, infoStruct, blockOffsets)
            % readRelative Read neighboring block using relative position
            %     b = readRelative(bimds, sinfo, boffset) reads a
            %     neighboring block. sinfo is a struct (as returned by read
            %     or readRelative) that specifies the source block. boffset
            %     is a 1-by-2 integer valued vector specifying the offset
            %     from the source block. Offset is specified in units of
            %     blocks. b is [] when boffset puts the neighboring block
            %     out of bounds of the corresponding image.
            %
            %     [b, rinfo] = readRelative(bimds, sinfo, boffset) also
            %     returns the info struct of the block that was read.
            %
            %     Input info structs need to have the following fields:
            %       Level           - The level from which this data was
            %                         read.
            %       ImageNumber     - An index into the input BIGIMAGES
            %                         array corresponding to the bigimage
            %                         from which this block was read.
            %       BlockStartWorld - The coordinates of the extreme top
            %                         left of the block.
            %
            %     Returned info structs have the same format as those
            %     returned by the read() function.
            %
            %     NOTE: Masks are not used; the requested blocks are always
            %     read. The IncompleteBlocks behavior is respected. If the
            %     requested block is incomplete and IncompleteBlocks has a
            %     value of 'exclude', an empty block will be returned.
            %     PadMethod and BorderSize are also honored.
            %
            %     Example
            %     -------
            %     % Read the 4-connected neighbor blocks
            %     bim = bigimage('cameraman.tif');
            %     bimds = bigimageDatastore(bim,1, 'BlockSize', [64 64]);
            %     % Read the first block
            %     [b, sinfo] = read(bimds);
            %     b = b{1};
            %     % Read its four neighbors:
            %     bLeft   = readRelative(bimds, sinfo, [0 -1]);
            %     bTop    = readRelative(bimds, sinfo, [-1 0]);
            %     bRight  = readRelative(bimds, sinfo, [0 1]);
            %     bBottom = readRelative(bimds, sinfo, [1 0]);
            %     % Assemble as a montage to view relative locations
            %     montage({[], bTop, [], bLeft, b, bRight, [], bBottom, []}, ...
            %       'Size', [3 3], 'BorderSize', 5, 'BackgroundColor', 'b')
            %
            %  See also bigimageDatastore, read
            
            validateattributes(infoStruct, "struct", {"scalar", "nonempty"}, "readRelative", "infoStruct") %#ok<*CLARRSTR>
            validateattributes(blockOffsets, "numeric", {"integer", "numel", 2}, "readRelative", "blockOffsets")
            if ~isfield(infoStruct, 'Level') || ~isfield(infoStruct, 'ImageNumber') || ...
                    ~isfield(infoStruct, 'BlockStartWorld')
                error(message('images:bigimage:missingInfoFields'))
            end
            
            % Validate the info struct
            validateattributes(infoStruct.ImageNumber, "numeric",...
                {"positive", "scalar", "<=", numel(obj.Images)}, ...
                "readRelative", "sinfo.ImageNumber");
            validateattributes(infoStruct.Level, "numeric",...
                {"positive","integer", "scalar", "<=", numel(obj.Images(infoStruct.ImageNumber).SpatialReferencing)},...
                "readRelative", "sinfo.Level");
            validateattributes(infoStruct.BlockStartWorld, "numeric",...
                {"numel", 2}, "readRelative", "sinfo.BlockStartWorld");
            
            % Additional validation for level, it has to correspond to the
            % one the data store was created with
            if ~isequal(infoStruct.Level, obj.Levels(infoStruct.ImageNumber))
                error(message('images:bigimage:readRelativeLevelDoestMatch',num2str(infoStruct.Level), num2str(obj.Levels(infoStruct.ImageNumber))));
            end
            
            % Find intrinsic location of the block to read.
            theImage = obj.Images(infoStruct.ImageNumber);
            ref = theImage.SpatialReferencing(infoStruct.Level);
            bsize = theImage.getBlockSize(infoStruct.Level);
            yxWorld = infoStruct.BlockStartWorld;
            [xInt, yInt] = ref.worldToIntrinsic(yxWorld(1), yxWorld(2));
            yxIntrinsic = round([yInt xInt]);            
            
            % Compute the start point for output block
            startIntrinsic = yxIntrinsic + obj.BlockOffsets .* blockOffsets(:)';
            
            % Is that out of bounds?
            if any(startIntrinsic > ref.ImageSize) || any((startIntrinsic + bsize - 1) < 1)
                info = struct.empty();
                data = [];
                return
            end
            
            % Or incomplete?
            if strcmp(obj.IncompleteBlocks, 'exclude')
                expectedEndOfblock = startIntrinsic + obj.BlockSize - 1;
                if any(expectedEndOfblock > ref.ImageSize)
                    info = struct.empty();
                    data = [];
                    return
                end
            end
            
            % Read the neighbor block
            [data, info] = obj.readOneBlock(startIntrinsic, infoStruct.ImageNumber, infoStruct.Level, true);
        end
        
        function reset(obj)
            % reset  Set next read to begin at start.
            %     reset(bimds) Resets the bigimageDatastore to the state
            %     where no data has been read from it.
            %
            %     Example
            %     -------
            %     bim = bigimage('tumor_091R.tif');
            %     bimds = bigimageDatastore(bim,2);
            %     while hasdata(bimds)
            %         [data, info] = read(bimds);
            %         disp(info);
            %     end
            %
            %     % Reset to read the blocks again
            %     disp('After reset');
            %     reset(bimds);
            %     while hasdata(bimds)
            %         [data, info] = read(bimds);
            %         disp(info);
            %     end
            %
            %     See also bigimageDatastore, read, hasdata, progress
            
            obj.NextReadIndex = 1;
        end
        
        function newds = shuffle(obj)
            % shuffle  Permute order blocks will be read.
            %     NEWDS = shuffle(BIMDS) randomly reorders the read order
            %     of the blocks in BIMDS and returns a new
            %     bigimageDatastore NEWDS. The original datastore is
            %     unchanged.
            %
            %     Example
            %     -------
            %     bim = bigimage('tumor_091R.tif');
            %     bimds = bigimageDatastore(bim,2);
            %     while hasdata(bimds)
            %         [data, info] = read(bimds);
            %         disp(info);
            %     end
            %
            %     sbimds = shuffle(bimds);
            %     disp('Shuffled Order');
            %     while hasdata(sbimds)
            %         [data, info] = read(sbimds);
            %         disp(info);
            %     end
            %
            %     See also bigimageDatastore, partition
            newds = copy(obj);
                        
            randPermInd = randperm(obj.Length);
            shuffledBlockOrigin = obj.BlockLocationSet.BlockOrigin(randPermInd,:);
            shuffledImageNumber = obj.BlockLocationSet.ImageNumber(randPermInd,:);
            
            newds.BlockLocationSet = blockLocationSet(shuffledImageNumber,shuffledBlockOrigin,...
                obj.BlockLocationSet.BlockSize, obj.BlockLocationSet.Levels);
            
            obj.triggerReadAhead();
            
            newds.reset()
        end
        
        %------------------------------------------------------------------
        function tbl = countEachLabel(obj,varargin)
            %countEachLabel Counts the number of pixel labels for each class.
            %
            % tbl = countEachLabel(bimds) counts the occurrence of each
            % pixel label for all blocks represented by bimds. Only blocks
            % that are output by read are used for counting. The output tbl
            % is a table with the following variables names:
            %
            %   Name            - The pixel label class name.
            %
            %   PixelCount      - The number of pixels of a given class in 
            %                     all blocks.
            %
            %   BlockPixelCount - The total number of pixels in blocks that
            %                     had an instance of the given class.
            %
            %
            %   [___] = countEachLabel(___, Name, Value) specifies additional
            %   parameters. Supported parameters include:
            %
            %   'UseParallel'         A logical scalar specifying if a new
            %                         or existing parallel pool should be
            %                         used. If no parallel pool is active,
            %                         a new pool is opened based on the
            %                         default parallel settings. This
            %                         syntax requires Parallel Computing
            %                         Toolbox. Default value is false.
            %
            % Class Balancing
            % ---------------
            % The output of countEachLabel, tbl can be used to calculate
            % class weights for class balancing, for example:
            %
            %   * Uniform class balancing weights each class such that each
            %     has a uniform prior probability:
            %
            %        numClasses = height(tbl)
            %        prior = 1/numClasses;
            %        classWeights = prior ./ tbl.PixelCount
            %
            %   * Inverse frequency balancing weights each class such that
            %     underrepresented classes are given higher weight:
            %
            %        totalNumberOfPixels = sum(tbl.PixelCount)
            %        frequency = tbl.PixelCount / totalNumberOfPixels;
            %        classWeights = 1./frequency
            %
            %   * Median frequency balancing weights each class using the
            %     median frequency. The weight for each class c is defined
            %     as median(imageFreq)/imageBlockFreq(c) where
            %     imageBlockFreq(c) is the number of pixels of a given
            %     class divided by the total number of pixels in image
            %     blocks that had an instance of the given class c.
            %
            %        imageBlockFreq = tbl.PixelCount ./ tbl.BlockPixelCount
            %        classWeights = median(imageBlockFreq) ./ imageBlockFreq
            %
            % The calculated class weights can be passed to the
            % pixelClassificationLayer. See example below.
            %
            % Example
            % --------
            %   % Counts pixel labels in a labeled image and calculate
            %   % class weights for class balancing
            %
            %   % Load labeled data
            %   load('buildingPixelLabeled.mat');
            %   
            %   pixelLabelID = [1 2 3 4];
            %   classNames = ["sky" "grass" "building" "sidewalk"];
            %
            %   % Count pixel labels occurrences in the labeled images
            %   bigLabeledImage = bigimage(uint8(label), 'Classes', classNames, 'PixelLabelIDs', pixelLabelID);
            %
            %   % Set the resolution level and block size of the images
            %   bigimageLevel = 1;
            %   blockSize = [200 150];
            %
            %   % Create a bigimageDatastore from the image dataset
            %   blabelds = bigimageDatastore(bigLabeledImage, bigimageLevel, 'BlockSize', blockSize);
            %
            %   % Look at the pixel label occurrences of each class.
            %   tbl = countEachLabel(blabelds);
            %
            %   % Class balancing using uniform prior weighting.
            %   prior = 1/numel(classNames);
            %   uniformClassWeights = prior ./ tbl.PixelCount
            %
            %   % Class balancing using inverse frequency weighting.
            %   totalNumberOfPixels = sum(tbl.PixelCount);
            %   frequency = tbl.PixelCount / totalNumberOfPixels;
            %   invFreqClassWeights = 1./frequency
            %
            %   % Class balancing using median frequency weighting.
            %   freq = tbl.PixelCount ./ tbl.BlockPixelCount
            %   medFreqClassWeights = median(freq) ./ freq
            %
            %   % Pass the class weights to the pixel classification layer.
            %   layer = pixelClassificationLayer('ClassNames', tbl.Name, ...
            %       'ClassWeights', medFreqClassWeights)
            %
            % See also pixelClassificationLayer, bigimage,
            %          balancePixelLabels
        
            narginchk(0,3);
            
            useParallelFlag = parseNameValuePairs(varargin{:});
            
            % Make a copy so we do not dirty the state.
            newds = copy(obj);
            newds.reset();
            
            if any(arrayfun(@(x)~(x.IsCategorical),obj.Images))
                error(message('images:bigimageDatastore:allImagesMustBeCategorical'));
            end
            
            % classes can have repeated values 
            % Note: unique with 'stable' doesn't sort the data
            classes = unique(obj.Images(1).Classes,'stable');
            numClasses = numel(classes);
            
            % Make sure all images in the datastore have the same classes
            if any(arrayfun(@(x)~isequal(sort(unique(x.Classes,'stable')),sort(classes)),obj.Images))
                error(message('images:bigimageDatastore:allImagesMustHaveSameCategories'));
            end
            
            % Sort classes and corresponding pixelLabelIDs so that counts
            % are binned correctly across images in a datastore. Each image
            % in the datastore could order the classes and pixelLabelIDs
            % differently.
            [imageClassNames, imagePixelLabelIDs] = cellfun(@(x,y)sortClassesAndPixelLabelIDs(x,y),{obj.Images.PixelLabelIDs},{obj.Images.Classes},'UniformOutput',false);
            
            if useParallelFlag
                % Set up parallel pool.
                p = gcp;
                if isempty(p)
                    error(message('images:bigimageDatastore:couldNotOpenPool'))
                end
                numPartitions = p.NumWorkers;
                
                counts          = zeros(numClasses, numPartitions);
                blockPixelCount = zeros(numClasses, numPartitions);
                
                parfor pIdx = 1:numPartitions
                    subds = partition(newds,numPartitions,pIdx);
                    
                    % Use imagePixelLabelIDs to bin pixels in each image.
                    % Classes with same PixelLabelIDs are then using
                    % classes. 
                    [countsSlice, blockPixelCountSlice] = calculateCountsAndPixelCounts(subds, classes, numClasses, imageClassNames, imagePixelLabelIDs);
                    
                    counts(:, pIdx) = countsSlice
                    blockPixelCount(:,pIdx) = blockPixelCountSlice;
                end
                
                % Aggregate the results of classes in each block from all partitions
                blockPixelCount = sum(blockPixelCount,2);
                counts = sum(counts,2);
                
            else
                [counts, blockPixelCount] = calculateCountsAndPixelCounts(newds, classes, numClasses, imageClassNames, imagePixelLabelIDs);
            end
            
            tbl = table();
            tbl.Name            = classes;
            tbl.PixelCount      = counts;
            tbl.BlockPixelCount = blockPixelCount;
        end
    end
    
    % Property mutators and accessors
    methods
        function set.BorderSize(obj, newValue)
            validateattributes(newValue, {'numeric'}, {'numel', 2, 'vector', 'nrows', 1, 'real', 'nonnegative', 'integer'}, 'bigimageDatastore', 'BorderSize')
            obj.BorderSize = double(newValue);
        end
        
        function set.ReadSize(obj, newValue)
            validateattributes(newValue, {'numeric'}, {'scalar', 'real', 'positive', 'integer'}, 'bigimageDatastore', 'ReadSize')
            obj.ReadSize = double(newValue);
        end
        
        function set.PadMethod(obj, newValue)
            if ~isempty(obj.Images)%#ok<MCSUP>
                % Not loadobj
                [~, newValue] = validatePadMethod(newValue, obj.Images); %#ok<MCSUP>
            end
            obj.PadMethod = newValue;           
        end
        
        function set.InclusionThreshold(obj, newValue)
            [~, newValue] = validateInclusionThreshold(newValue, numel(obj.Images)); %#ok<MCSUP>
            obj.InclusionThreshold = newValue;
            if ~isempty(obj.Masks)%#ok<MCSUP>
                % Recompute location set (will use cached mask stats)
                obj.buildBlockSet();
            end
        end
        
        function L = get.Length(obj)
            L = numel(obj.BlockLocationSet.ImageNumber);
        end
    end
    
    methods (Access = protected)
        function num = maxpartitions(obj)
            num = obj.Length;
        end
    end
    
    methods (Access = private)
        function validateCategoricalEquivalence(obj)
            firstClassNames = obj.Images(1).Classes;
            tf = arrayfun(@(bim)isequal(bim.Classes, firstClassNames), obj.Images);
            if ~all(tf)
                error(message('images:bigimageDatastore:allImagesMustHaveSameCategories'));
            end
        end
        
        function validateAndTrimBlockLocationSet(obj)
            % Scalar blocklocationSet object
            validateattributes(obj.BlockLocationSet,...
                "blockLocationSet","scalar",mfilename,"BlockLocationSet");
            
            imageNumbers = unique(obj.BlockLocationSet.ImageNumber);
            
            % All ImageNumbers should be valid indices.
            % ImageNumbers are already validated to be positive integers.
            maxImageNum = max(imageNumbers);
            if maxImageNum > numel(obj.Images)
                error(message('images:bigimage:badImageNumber', numel(obj.Images)))
            end
            
            % All specified levels must exist.
            if numel(obj.BlockLocationSet.Levels) ~= numel(obj.Images)
                error(message('images:bigimage:incorrectNumLevels', numel(obj.Images)));
            end
            for ind = 1:numel(obj.BlockLocationSet.Levels) % obtained from bls
                bim = obj.Images(ind);
                numLevels = size(bim.LevelSizes,1);
                if obj.BlockLocationSet.Levels(ind) > numLevels
                    error(message('images:bigimage:badLevel', ind, numLevels));
                end
            end
            
            %All origins should be in-bounds.
            for imageInd = imageNumbers'
                inds = obj.BlockLocationSet.ImageNumber==imageInd;
                blockOrigins = obj.BlockLocationSet.BlockOrigin(inds,:);
                ref = obj.Images(imageInd).SpatialReferencing(obj.Levels(imageInd));
                if any(blockOrigins(:,1)>ref.ImageSize(2)) || any(blockOrigins(:,2)>ref.ImageSize(1))
                    error(message('images:bigimage:outOfBounds', imageInd))
                end
            end
            
            if obj.IncompleteBlocks=="exclude"
                % filter out incomplete blocks.
                tf = false(size(obj.BlockLocationSet.ImageNumber));
                for ind = 1:numel(tf)
                    imageNumber = obj.BlockLocationSet.ImageNumber(ind);
                    lvl = obj.BlockLocationSet.Levels(imageNumber);
                    imageSize = obj.Images(imageNumber).SpatialReferencing(lvl).ImageSize;                    
                    fullBlockEdge = imageSize - obj.BlockLocationSet.BlockSize + 1;
                    tf(ind) = obj.BlockLocationSet.BlockOrigin(ind,1)<=fullBlockEdge(2) ...
                        & obj.BlockLocationSet.BlockOrigin(ind,2)<=fullBlockEdge(1);
                end
                inboundBlockOrigin = obj.BlockLocationSet.BlockOrigin(tf,:);
                inboundImageNumber = obj.BlockLocationSet.ImageNumber(tf);                
                obj.BlockLocationSet = blockLocationSet(inboundImageNumber,inboundBlockOrigin, obj.BlockLocationSet.BlockSize, obj.Levels);
            end
        end
        
        function buildBlockSet(obj)                        
            if isempty(obj.Images) || ~obj.IsReady
                % loadobj || called by set methods of props during
                % construction.
                return
            end
                                    
            excludeIncompleteBlocks = obj.IncompleteBlocks=="exclude";
            if isempty(obj.Masks)
                bls = selectBlockLocations(obj.Images,...
                    'Levels', obj.Levels,...
                    'BlockOffset', obj.BlockOffsets,...
                    'BlockSize', obj.BlockSize,...
                    'ExcludeIncompleteBlocks', excludeIncompleteBlocks);        
            else                
                bls = selectBlockLocations(obj.Images, ...
                    'Levels', obj.Levels,...
                    'Masks', obj.Masks, ...
                    'BlockOffset', obj.BlockOffsets,...
                    'BlockSize', obj.BlockSize,...
                    'InclusionThreshold', obj.InclusionThreshold,...
                    'ExcludeIncompleteBlocks', excludeIncompleteBlocks);                    
            end
            obj.BlockLocationSet = bls;
        end
        
        function [multiReadData, infoStruct, blockLocationsIntrinsic] = readCore(obj, doCatConversion)
            
            multiReadData = cell(obj.ReadSize, 1);
            multiReadInfo = {};
            blockLocationsIntrinsic = cell(1, obj.ReadSize);
            for idx = 1:obj.ReadSize
                if ~obj.hasdata()
                    if idx==1 % Nothing could be read
                        error(message('images:bigimage:noMoreData'));
                    end
                    multiReadData(idx:end) = [];
                    break
                end
                
                blockLoc = obj.BlockLocationSet.BlockOrigin(obj.NextReadIndex,:);
                imageNumber = obj.BlockLocationSet.ImageNumber(obj.NextReadIndex);
                % Convert to row/col
                regionStartIntrinsic = [blockLoc(2), blockLoc(1)];
                level = obj.Levels(imageNumber);
                [data, info] = obj.readOneBlock(regionStartIntrinsic, imageNumber, level, doCatConversion);
                
                blockLocationsIntrinsic{idx} = {level, regionStartIntrinsic(1), regionStartIntrinsic(2)};
                
                obj.NextReadIndex = obj.NextReadIndex+1;
                
                multiReadData{idx} = data;
                multiReadInfo{idx} = info; %#ok<AGROW>
            end
            
            % Flip the info struct inside out to make it easier to use
            structArray = [multiReadInfo{:}];
            infoStruct.Level = [structArray.Level];
            infoStruct.ImageNumber = [structArray.ImageNumber];
            infoStruct.BlockStartWorld = reshape([structArray.BlockStartWorld],[], numel(multiReadInfo))';
            infoStruct.BlockEndWorld = reshape([structArray.BlockEndWorld],[], numel(multiReadInfo))';
            infoStruct.DataStartWorld = reshape([structArray.DataStartWorld],[], numel(multiReadInfo))';
            infoStruct.DataEndWorld = reshape([structArray.DataEndWorld],[], numel(multiReadInfo))';            
        end
                
        function [data, info] = readOneBlock(obj, regionStartIntrinsic, imageNumber, level, doCatConversion)
            info.Level = level;
            info.ImageNumber = imageNumber;
            
            theImage = obj.Images(imageNumber);
            ref = theImage.SpatialReferencing(level);
            imageSize = ref.ImageSize;
            
            if any(regionStartIntrinsic<1)
                % Out of bounds
                data = []; info = [];
                return
            end
            
            [x,y] = ref.intrinsicToWorld(regionStartIntrinsic(2), regionStartIntrinsic(1));
            info.BlockStartWorld = [y, x];
            
            regionEndIntrinsic = regionStartIntrinsic + obj.BlockSize - 1;
            [x,y] = ref.intrinsicToWorld(regionEndIntrinsic(2), regionEndIntrinsic(1));
            % Clamp to middle of last pixel
            x = min(x, ref.XWorldLimits(2) - ref.PixelExtentInWorldX/2);
            y = min(y, ref.YWorldLimits(2) - ref.PixelExtentInWorldY/2);
            info.BlockEndWorld = [y, x];
            
            % Border size
            regionStartIntrinsic = regionStartIntrinsic - obj.BorderSize;
            regionEndIntrinsic = regionEndIntrinsic + obj.BorderSize;
            
            % Start has potentially changed due to bordersize
            [x,y] = ref.intrinsicToWorld(regionStartIntrinsic(2), regionStartIntrinsic(1));
            info.DataStartWorld = [y, x];
            
            % Padding
            paddingNorthAndWest = max(-regionStartIntrinsic + 1, 0);
            paddingSouthAndEast = max(regionEndIntrinsic - imageSize, 0);
            if strcmp(obj.IncompleteBlocks, 'same')
                paddingNorthAndWest = min(paddingNorthAndWest, obj.BorderSize);
                paddingSouthAndEast = min(paddingSouthAndEast, obj.BorderSize);
            end
            
            % Clamp and read
            regionStartIntrinsic = max(regionStartIntrinsic, [1 1]);
            regionEndIntrinsic = min(regionEndIntrinsic, imageSize);
            
            if strcmp(obj.PadMethod,'symmetric') && any(paddingSouthAndEast)
                % Need to reach out to the left to get more data.
                reqPadStart = regionStartIntrinsic-max(paddingSouthAndEast-1,0);
                reqPadStart = max(reqPadStart,1);
                data = theImage.getRegionIntrinsic(level, ...
                    reqPadStart, regionEndIntrinsic, doCatConversion);
                % Pad
                data = padData(data, paddingNorthAndWest, paddingSouthAndEast, obj.PadMethod, theImage);
                % Discard the extra data read (which was only used to do
                % the padding SE).
                start = regionStartIntrinsic-reqPadStart+1;
                data = data(start(1):end, start(2):end,:);
            else
                data = theImage.getRegionIntrinsic(level, ...
                    regionStartIntrinsic, regionEndIntrinsic,doCatConversion);
                % Pad, if needed, these methods do not need extra data to
                % be read from the image
                if any(paddingNorthAndWest | paddingSouthAndEast)
                    data = padData(data, paddingNorthAndWest, paddingSouthAndEast, obj.PadMethod, theImage);
                end
            end
            
            % Expand data end to account for padding on lower right
            if any(paddingSouthAndEast)
                regionEndIntrinsic = regionEndIntrinsic + paddingSouthAndEast;
            end
            
            % End could have changed to account for border/padding
            [x,y] = ref.intrinsicToWorld(regionEndIntrinsic(2), regionEndIntrinsic(1));
            info.DataEndWorld = [y, x];
            
            % Convert to x,y format
            info.BlockStartWorld = [info.BlockStartWorld(2), info.BlockStartWorld(1)];
            info.BlockEndWorld = [info.BlockEndWorld(2), info.BlockEndWorld(1)];
            info.DataStartWorld = [info.DataStartWorld(2), info.DataStartWorld(1)];
            info.DataEndWorld = [info.DataEndWorld(2), info.DataEndWorld(1)];
        end
        
        
        function triggerReadAhead(obj)
            % Inform the adapter of the order in which user blocks are
            % going to be read (adapter starts an asyc read ahead of this
            % data)
            for imageInd = 1:numel(obj.Images)
                if obj.Images(imageInd).Adapter.SupportsReadAhead
                    thisImageBlocks = obj.BlockLocationSet.ImageNumber == imageInd;
                    blockOriginsXY = obj.BlockLocationSet.BlockOrigin(thisImageBlocks,:);
                    obj.Images(imageInd).Adapter.readAhead(blockOriginsXY, obj.Levels(imageInd), obj.BlockSize, obj.ReadSize);
                end
            end
        end

    end
    
    % The Subsettable interface is an architectural element that allows
    % CombinedDatastores to be partitionable. It is not currently
    % documented.
    methods (Hidden)
       
        function subds = subset(obj, indices)
            % subset  Returns a new datastore with the specified
            % block indices
            %
            %  SUBDS = subset(BIMDS, INDICES) creates a deep copy of the
            %  input datastore DS containing blocks corresponding to
            %  INDICES. INDICES must be a vector of positive and unique
            %  integer numeric values. INDICES can be a 0-by-1 empty array
            %  and does not need to be provided in any sorted order when
            %  nonempty. The output datastore SUBDS, contains the blocks
            %  corresponding to INDICES and in the same order as INDICES.
            %  INDICES can also be specified as a N-by-1 vector of logical
            %  values, where N is the total number of blocks in the
            %  datastore obtained by the numobservations() method.
            %
            % See also bigimageDatastore, partition, shuffle
            
            import matlab.io.datastore.internal.validators.validateSubsetIndices;
            indices = validateSubsetIndices(indices, obj.Length, mfilename);
            
            subds = copy(obj);
            
            subBLSBImageNumber = obj.BlockLocationSet.ImageNumber(indices);
            subBLSBlockOrigin = obj.BlockLocationSet.BlockOrigin(indices,:);
            subds.BlockLocationSet = blockLocationSet(subBLSBImageNumber,...
                subBLSBlockOrigin, obj.BlockLocationSet.BlockSize, ...
                obj.BlockLocationSet.Levels);
            
            subds.reset();
        end
        
        function n = numobservations(ds)
            %numobservations Returns the number of blocks in this datastore
            %
            %   N = NUMOBSERVATIONS(BIMDS) returns the number of blocks in the
            %   datastore.
            %
            %   See also bigimageDatastore, subset
            n = ds.Length;
        end
        
    end
    
    methods (Static)
        function obj = loadobj(obj)
            if isstruct(obj)
                % Auto load failed, just construct the object from scratch
                % again
                obj = bigimageDatastore(obj.Images, obj.Levels, ...
                    'BlockSize', obj.BlockSize,...
                    'BlockOffsets', obj.BlockOffsets,...
                    'BorderSize', obj.BorderSize,...
                    'Masks', obj.Masks,...
                    'InclusionThreshold', obj.InclusionThreshold,...
                    'IncompleteBlocks', obj.IncompleteBlocks,...
                    'PadMethod', obj.PadMethod,...
                    'ReadSize', obj.ReadSize);            
            end
        end
    end
end


function [tf, padMethod] = validatePadMethod(padMethod, bigImages)
if isstring(padMethod) || ischar(padMethod)
    allowedStrings = {'replicate', 'symmetric'};
    if bigImages(1).IsCategorical
        % Check for exact match with Classes first.
        isClassName = any(strcmp(padMethod, bigImages(1).Classes));
        if isClassName
            % Encode as a string
            padMethod = string(padMethod);
        else
            try
                padMethod = validatestring(padMethod, allowedStrings, mfilename);
                % Encode as a char vector
                padMethod = char(padMethod);
            catch
                error(message('images:bigimage:invalidPadString'));
            end
        end
    else
        padMethod = validatestring(padMethod, allowedStrings, mfilename);
    end
elseif bigImages(1).IsCategorical
    % Categorical only supports string (earlier condition) or missing.
    validateattributes(padMethod, "missing", {'scalar', 'real', 'nonsparse'}, mfilename);
else
    % Numeric pad method and datatype is NOT categorical
    validateattributes(padMethod, ["numeric", "logical"], {'scalar', 'real', 'nonsparse'}, mfilename);
end

tf = true;

end


function [tf, icth] = validateInclusionThreshold(icth, numImages)
tf = true;

if numImages==0
    % numImages == 0 on loadobj
    return
end
if isscalar(icth)
    icth = repmat(icth, [1, numImages]);
end
validateattributes(icth, "numeric", {'real', '<=', 1, '>=', 0, 'numel', numImages}, mfilename, "InclusionThreshold")
end


function data = padData(data, paddingNorthAndWest, paddingSouthAndEast, padMethod, theImage)

if theImage.IsCategorical && ~iscategorical(data) &&...
        (isstring(padMethod) || all(ismissing(padMethod)))
    % Numeric read of categorical data, convert padMethod from ClassName to
    % PixelLabelIDs. Note: padMethod is a string only if its a ClassName
    % (and not one of symmetric/replicate). categorical2numeric also
    % handles missing correctly.
    padMethod = theImage.categorical2numeric(padMethod);    
end

if any(paddingNorthAndWest)
    data = padarray(data, paddingNorthAndWest, padMethod, 'pre');
end
if any(paddingSouthAndEast)
    data = padarray(data, paddingSouthAndEast, padMethod, 'post');
end
end


function useParallelFlag = parseNameValuePairs(varargin)

% Convert string inputs to character vectors.
args = matlab.images.internal.stringToChar(varargin);

% Parse remainder of input arguments.
parser = inputParser();
parser.FunctionName = mfilename;
parser.CaseSensitive = false;
parser.PartialMatching = true;
parser.KeepUnmatched = false;
parser.addParameter('UseParallel', false, @validateUseParallel)
parser.parse(args{:});

useParallelFlag = parser.Results.UseParallel;
end

function tf = validateUseParallel(useParallel)

isLogicalScalar(useParallel);
if useParallel && ~matlab.internal.parallel.isPCTInstalled()
    error(message('images:bigimageDatastore:couldNotOpenPool'))
else
    tf = true;
end
end

function tf = isLogicalScalar(input)

validateattributes(input, {'numeric', 'logical'}, {'scalar','finite'})
tf = true;

end

function [classes, pixelLabelIDs] = sortClassesAndPixelLabelIDs(pixelLabelIDs, classes)
% Outputs sorted classes and pixeLabelIDs based on sorted classes

[classes, idx] = sort(classes,'ascend');

% pixelLabelIDs can be a Mx3 vector for RGB inputs
pixelLabelIDs = pixelLabelIDs(idx,:);
end

function [counts, blockPixelCount] = calculateCountsAndPixelCounts(ds, classes, numClasses, imageClassNames, imagePixelLabelIDs)
% calculateCountsAndPixelCounts Calculate the counts and blockPixelCounts
% for all classes in the datastore, ds. The data in the datastore, ds is
% read numerically using the internal method, readCore(). The counts for
% pixels in the block are binned using the corresponding pixelLabelIDs of
% the image from which the block originated. The binned counts that
% correspond to the same class names in imageClassNames are merged based on
% the unique class names in classes.

counts          = zeros(numClasses,1);
blockPixelCount = zeros(numClasses,1);

while hasdata(ds)
    % read categorical data as numeric
    [C, info] = readCore(ds, false);
    for blockIdx = 1:numel(C)
        imgIdx = info.ImageNumber(blockIdx);
        
        blockSize = size(C{blockIdx});
        if numel(blockSize) == 3
            % RGB
            % Indicate presence of pixelLabelIDs in RGB input blocks, one
            % plane at a time
            presenceMatrixR = arrayfun(@(x)(C{blockIdx}(:,:,1) == x), imagePixelLabelIDs{imgIdx}(:,1),'UniformOutput',false);
            presenceMatrixG = arrayfun(@(x)(C{blockIdx}(:,:,2) == x), imagePixelLabelIDs{imgIdx}(:,2),'UniformOutput',false);
            presenceMatrixB = arrayfun(@(x)(C{blockIdx}(:,:,3) == x), imagePixelLabelIDs{imgIdx}(:,3),'UniformOutput',false);
            
            % Aggregate the presence matrix across planes to get actual
            % count. Only if a true value is present in all planes, does it
            % add to the count.
            countsForOneBlock = cellfun(@(x,y,z) nnz(x & y & z), presenceMatrixR, presenceMatrixG, presenceMatrixB);
        else
            countsForOneBlock = arrayfun(@(x) nnz(C{blockIdx} == x), imagePixelLabelIDs{imgIdx});
        end
        
        % Merge counts that correspond to the same class
        countsForOneBlockUniqueClasses = arrayfun(@(x)sum(countsForOneBlock(imageClassNames{imgIdx} == classes(x))),(1:numClasses)');
        
        counts = counts + countsForOneBlockUniqueClasses;
        
        classIdx = (countsForOneBlockUniqueClasses > 0);
        blockPixelCount(classIdx) = blockPixelCount(classIdx) + prod(blockSize(1:2));
    end
end
end
    
