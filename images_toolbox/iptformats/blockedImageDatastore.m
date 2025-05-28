classdef blockedImageDatastore <  matlab.io.Datastore & ...
        matlab.mixin.Copyable & ...
        matlab.io.datastore.Partitionable & ...
        matlab.io.datastore.Shuffleable   & ...
        matlab.io.datastore.mixin.Subsettable
       
    properties (Dependent)
        BorderSize (1,:) double {mustBeInteger}
        
        PadMethod
    end
    properties (Access = private)
        BorderSize_
        PadMethod_
    end
    
    properties
        ReadSize (1,1) double {mustBeInteger} = 1
        
        PadPartialBlocks(1,1) logical = true
    end
    
    properties (SetAccess = private)
        Images (:,1) blockedImage
        
        BlockLocationSet blockLocationSet
        
        BlockSize (1,:) double {mustBeInteger}
    end
    
    properties (SetAccess = private, Dependent)
        TotalNumBlocks(1,1) double {mustBeInteger}
    end
    
    properties (Access = private)
        NextReadIndex(1,1) double = 1
        
        % A common block cache for all blockedImages in the datastore
        BlockCache (1,1) images.blocked.internal.BlockCache
    end    

    methods
        function obj = blockedImageDatastore(bims, params)
            arguments
                bims (:,1)
                params.BlockSize (1,:) {mustBeInteger, mustBePositive, mustBeNonempty}
                params.BlockLocationSet (1,1) blockLocationSet
                params.BorderSize (1,:) double {mustBeInteger}
                params.ReadSize (1,1) double {mustBeInteger, mustBePositive} = 1
                params.PadMethod 
                params.PadPartialBlocks (1,1) logical = true
            end
            
            if ~isa(bims, 'blockedImage')
                % Should be convertible to one                
                bims = blockedImage(bims);
            end

            if any(arrayfun(@(b)isempty(b.Adapter),bims),'all')
                % This indicates that one of the elements is a
                % 'blockedImage()' which is not allowed.
                error(message('images:blockedImage:emptyElement'));
            end
            
            if isfield(params, 'BorderSize')
                mustMatchDims(params.BorderSize, bims, "BorderSize")
            else
                params.BorderSize = zeros(1, bims(1).NumDimensions);
            end
            
            if isfield(params, 'PadMethod')
                validatePadMethod(params.PadMethod, bims)
            else
                params.PadMethod = bims(1).InitialValue;
            end
            
            % All bims should have same NumDimensions
            if ~all([bims.NumDimensions]==bims(1).NumDimensions)
                error(message('images:blockedImage:inconsistentNumDims'))
            end
            
            obj.Images = bims;
            
            if isfield(params,'BlockLocationSet')
                blockSize = params.BlockLocationSet.BlockSize;
                if isfield(params, 'BlockSize')
                    % Cant specify both.
                    error(message('images:blockedImage:blockSizeAndBlockLocationSet'))
                end
                if size(params.BlockLocationSet.BlockOrigin,2)>bims(1).NumDimensions
                    error(message('images:blockedImage:invalidNumDims', "BlockLocationSet"))
                elseif size(params.BlockLocationSet.BlockOrigin,2)<bims(1).NumDimensions
                    % If image is a higher dimension than block location
                    % set, then extend blocksize by actual image size.
                    % (allows use of 2D BLS from say BW masks, on 3D images
                    % (RGB)).
                    firstBimInd = params.BlockLocationSet.ImageNumber(1);
                    firstLevelInd = params.BlockLocationSet.Levels(1);
                    firstImageSize = bims(firstBimInd).Size(firstLevelInd,:);
                    firstNumDims = bims(firstBimInd).NumDimensions;
                    blockSize(end+1:firstNumDims) = firstImageSize(numel(blockSize)+1:end);
                end
                if max(params.BlockLocationSet.ImageNumber)>numel(bims)
                    error(message('images:blockedImage:incorrectArraylength',max(params.BlockLocationSet.ImageNumber)))
                end
                obj.BlockLocationSet = params.BlockLocationSet;
                                
                
            elseif isfield(params, 'BlockSize')
                if numel(params.BlockSize)<bims(1).NumDimensions
                    % See if we can extend unambiguously
                    exDims = numel(params.BlockSize)+1: bims(1).NumDimensions;
                    if all(arrayfun(@(bim)isequal(bim.Size(1,exDims),bims(1).Size(1,exDims)), bims))
                        % All images have the same size in the missing
                        % dimensions
                        params.BlockSize(exDims) = bims(1).Size(1,exDims);
                    end
                end
                mustMatchDims(params.BlockSize, bims, "BlockSize");
                obj.BlockLocationSet = selectBlockLocations(obj.Images,...
                    'BlockSize', params.BlockSize);
                blockSize = obj.BlockLocationSet.BlockSize;
            
            else
                % Default if none is given
                obj.BlockLocationSet = selectBlockLocations(obj.Images);
                blockSize = obj.BlockLocationSet.BlockSize;
            end
            
            % All bims should have same type
            expType = obj.Images(1).ClassUnderlying(obj.BlockLocationSet.Levels(1));
            for imageInd = unique(obj.BlockLocationSet.ImageNumber)'
                if ~isequal(expType, obj.Images(imageInd).ClassUnderlying(obj.BlockLocationSet.Levels(imageInd)))
                    error(message('images:blockedImage:inconsistentTypes', num2str(imageInd), expType))
                end
            end
            
            obj.BorderSize = params.BorderSize;
            obj.ReadSize = params.ReadSize;
            obj.PadMethod = params.PadMethod;
            obj.PadPartialBlocks = params.PadPartialBlocks;
            
            obj.BlockSize = blockSize;
            
            if numel(bims) == 1
                % Single image, so reuse its internal cache
                obj.BlockCache = bims.BlockCache;
            else
                % Multiple images, by-pass individual cache and use a
                % common one. Else, when numel(bims) is large, the total
                % cache size would blow up.
                obj.BlockCache = images.blocked.internal.BlockCache();
            end
        end
        
        function tf = hasdata(obj)
            tf = obj.NextReadIndex <= obj.TotalNumBlocks;
        end
        
        function reset(obj)
            obj.NextReadIndex = 1;
        end
        
        function newds = shuffle(obj)
            newds = copy(obj);
            
            randPermInd = randperm(obj.TotalNumBlocks);
            shuffledBlockOrigin = obj.BlockLocationSet.BlockOrigin(randPermInd,:);
            shuffledImageNumber = obj.BlockLocationSet.ImageNumber(randPermInd,:);
            
            newds.BlockLocationSet = blockLocationSet(shuffledImageNumber,shuffledBlockOrigin,...
                obj.BlockLocationSet.BlockSize, obj.BlockLocationSet.Levels);
            newds.reset()
        end
        
        function [blocks, blockInfo] = read(obj)           
            blocks = cell(obj.ReadSize, 1);
            multiReadInfo = {};
            for idx = 1:obj.ReadSize
                if ~obj.hasdata()
                    if idx==1 % Nothing could be read
                        error(message('images:blockedImage:noMoreData'));
                    end
                    blocks(idx:end) = [];
                    break
                end
                
                blockLoc = obj.BlockLocationSet.BlockOrigin(obj.NextReadIndex,:);
                imageNumber = obj.BlockLocationSet.ImageNumber(obj.NextReadIndex);
                
                % Convert to row/col
                regionStartSubs = blockLoc;
                regionStartSubs(1:2) = [regionStartSubs(2), regionStartSubs(1)];
                
                level = obj.BlockLocationSet.Levels(imageNumber);
                [data, info] = obj.readOneBlock(regionStartSubs, imageNumber, level);
                obj.NextReadIndex = obj.NextReadIndex+1;
                
                blocks{idx} = data;
                multiReadInfo{idx} = info; %#ok<AGROW>
            end
                        
            structArray = [multiReadInfo{:}];
            
            if isscalar(structArray)
                blockInfo = structArray;                
            else
                % Flip the info struct inside out to make it easier to use
                blockInfo.Level = reshape([structArray.Level],[], numel(multiReadInfo))';
                blockInfo.ImageNumber = reshape([structArray.ImageNumber],[], numel(multiReadInfo))';
                blockInfo.BlockSub = reshape([structArray.BlockSub],[], numel(multiReadInfo))';
                blockInfo.Start = reshape([structArray.Start],[], numel(multiReadInfo))';
                blockInfo.End = reshape([structArray.End],[], numel(multiReadInfo))';                            
            end
            
            blockInfo.BorderSize = structArray(1).BorderSize;
            blockInfo.BlockSize = obj.BlockSize;
            
        end
        
        function pbimds = partition(obj, numP, idx)
            arguments
                obj (1,1) blockedImageDatastore
                numP (1,1) double {mustBeInteger}
                idx (1,1) double {mustBeInteger}
            end
            pbimds = copy(obj);            
            
            pIndices = matlab.io.datastore.internal.util.pigeonHole(...
                numP, obj.TotalNumBlocks,idx);
            
            partionedBlockOrigin = obj.BlockLocationSet.BlockOrigin(pIndices,:);
            partionedImageNumber = obj.BlockLocationSet.ImageNumber(pIndices,:);
            
            pbimds.BlockLocationSet = blockLocationSet(partionedImageNumber,partionedBlockOrigin,...
                obj.BlockLocationSet.BlockSize, obj.BlockLocationSet.Levels);
            
            pbimds.reset()
        end
        
        function oneblock = preview(obj)
            if obj.TotalNumBlocks == 0
                oneblock = [];
            else
                % pick first block
                blockSub = obj.BlockLocationSet.BlockOrigin(1,:);
                imageNumber = obj.BlockLocationSet.ImageNumber(1);
                level = obj.BlockLocationSet.Levels(imageNumber);
                oneblock = obj.readOneBlock(blockSub, imageNumber, level);
            end
        end
        
        function amount = progress(obj)
            amount = (obj.NextReadIndex - 1) / obj.TotalNumBlocks;
        end
        
        function totalNumBlocks = get.TotalNumBlocks(obj)
            totalNumBlocks = obj.BlockLocationSet.TotalNumBlocks;
        end
        
        function tbl = countEachLabel(obj,params)
            arguments
                obj (1,1) blockedImageDatastore
                params.UseParallel (1,1) logical = false
                params.Classes (:,1) string
                params.PixelLabelIDs (:,1) double {mustBeNumericOrLogical}
            end
            %
            
            % Empty BLS
            tbl = table();
            if isempty(obj.BlockLocationSet) || isempty(obj.BlockLocationSet.ImageNumber)
                return
            end
            
            
            % Type of the first block
            imageInd = obj.BlockLocationSet.ImageNumber(1);
            imType = obj.Images(imageInd).ClassUnderlying(obj.BlockLocationSet.Levels(imageInd));
            
            if imType == "categorical"
                if isfield(params,'Classes') || isfield(params,'PixelLabelIDs')
                    error(message('images:blockedImage:classesWasProvided'))
                end
                params.Classes = sort(categories(obj.Images(imageInd).InitialValue));
                params.HasCats = true;
                
                for ind = 1:numel(obj.Images)
                    thisCats = sort(categories(obj.Images(ind).InitialValue));
                    if ~isequal(params.Classes, thisCats)
                        expCats = ['{', sprintf('%s ', params.Classes{:})];
                        actCats = ['{', sprintf('%s ', thisCats{:})];
                        expCats(end) = '}';actCats(end) = '}';
                        error(message('images:blockedImage:inconsistentCategories', expCats, num2str(ind), actCats))
                    end
                end
                
            elseif any(strcmp(imType, images.internal.iptlogicalnumerictypes))
                % logical or numeric
                if ~(isfield(params,'Classes') && isfield(params,'PixelLabelIDs'))
                    error(message('images:blockedImage:classesNotProvided'))
                end
                params.HasCats = false;
                
                % 1xN
                validateattributes(params.PixelLabelIDs, {'numeric'},...
                    {'vector', 'numel', numel(params.Classes)}, mfilename, 'PixelLabelIDs');
                params.PixelLabelIDs = params.PixelLabelIDs(:);
                
            else
                % unsupported type (struct)
                error(message('images:blockedImage:unsupportedType', imType))
            end
            
            % Make a copy so we do not dirty the state.
            newds = copy(obj);
            newds.reset();
            
            numClasses = numel(params.Classes);
            if params.UseParallel
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
                    [countsSlice, blockPixelCountSlice] = calculateCountsAndPixelCounts(subds, params);
                    counts(:, pIdx) = countsSlice
                    blockPixelCount(:,pIdx) = blockPixelCountSlice;
                end
                
                % Aggregate the results of classes in each block from all partitions
                blockPixelCount = sum(blockPixelCount,2);
                counts = sum(counts,2);
                
            else
                [counts, blockPixelCount] = calculateCountsAndPixelCounts(newds, params);
            end
            
            % Combine duplicate classes if any (the counts are computed in
            % the same stable order)
            uniqueClasses = unique(params.Classes, 'stable');
            tbl = table();
            tbl.Name            = string(uniqueClasses);
            tbl.PixelCount      = counts;
            tbl.BlockPixelCount = blockPixelCount;
        end
        
        function writeall(obj, outputLocation, params)
            arguments
                obj (1,1) blockedImageDatastore
                outputLocation (1,1) string {mustBeNonzeroLengthText}
                params.OutputFormat (1,1) string = "png"
                params.Quality (1,1) double {mustBeInteger, mustBeInRange(params.Quality,0,100)} = 75
                params.FilenamePrefix (1,1) string = ""
                params.FilenameSuffix (1,1) string = ""
                params.UseParallel (1,1) logical = false
                params.WriteFcn (1,1) function_handle
            end
            %

            % Create a copy, reset it and ensure 1 block/read
            ds = obj.copy();
            ds.reset();
            ds.ReadSize = 1;
           
            % Ensure OutputLocation ends with a filesep
            params.OutputLocation = outputLocation;
            if ~endsWith(params.OutputLocation, filesep)
                params.OutputLocation = params.OutputLocation + filesep;
            end
            % Create output folder if needed
            images.blocked.internal.createFolder(params.OutputLocation)

            if ~isfield(params, 'WriteFcn')
                % If no custom write function is given, ensure supported
                % extensions are specified 
                supportedFormats = {'jpg','jpeg','png','mat'};
                if ~ismember(params.OutputFormat, supportedFormats)
                    error(message('images:blockedImage:unsupportedWriteAllFormat', strjoin(supportedFormats,',')))
                end
                % before using the default
                params.WriteFcn = @defaultWriteFcn;
            end

            % Number of digits required to represent all image numbers
            % (used for leading zero padding in file name)
            numDigitsInImageNumber = ceil(log10(numel(ds.Images)))+1;
            % e.g. %02d to format Image numbers like so: 01, 02 ...
            params.Leading0FormatStr = ['%0' num2str(numDigitsInImageNumber), 'd'];
                        
            % Sort order of blocks. In case shuffle has been called, this
            % improves cache use while reading
            bls = ds.BlockLocationSet;
            sorted = sortrows([ds.BlockLocationSet.ImageNumber ds.BlockLocationSet.BlockOrigin]);
            ds.BlockLocationSet = blockLocationSet(sorted(:,1),...
                sorted(:,2:end), bls.BlockSize,bls.Levels);
            
            if params.UseParallel                
                ppool = gcp;
                if isempty(ppool)
                    error(message('images:bigimageDatastore:couldNotOpenPool'))
                end
                numParts = numpartitions(ds, ppool);
                parfor pind = 1:numParts
                    pds = partition(ds, numParts, pind);
                    pds.writeAllInSerial(params)                    
                end

            else 
                ds.writeAllInSerial(params)
            end
        end

    end
    
    % Set props
    methods
        function set.BorderSize(obj, bs)
            mustMatchDims(bs, obj.Images, "BorderSize"); 
            obj.BorderSize_ = bs;
        end
        function bs = get.BorderSize(obj)
            bs = obj.BorderSize_;
        end
        function set.PadMethod(obj, pm)
            validatePadMethod(pm, obj.Images); 
            obj.PadMethod_ = pm;
        end
        function pm = get.PadMethod(obj)
            pm = obj.PadMethod_;
        end
    end
    
    methods (Access = protected)
        function num = maxpartitions(obj)
            num = obj.TotalNumBlocks;
        end

        function dscopy = copyElement(obj)
            dscopy = copyElement@matlab.mixin.Copyable(obj);
            % blockedImages in Images property are handle objects, ensure
            % to copy them too. 
            dscopy.Images = copy(obj.Images);
        end
    end
    
    methods (Hidden)
        function subds = subset(obj, indices)            
            import matlab.io.datastore.internal.validators.validateSubsetIndices;
            indices = validateSubsetIndices(indices, obj.TotalNumBlocks, mfilename);
            
            subds = copy(obj);
            
            subBLSBImageNumber = obj.BlockLocationSet.ImageNumber(indices);
            subBLSBlockOrigin = obj.BlockLocationSet.BlockOrigin(indices,:);
            subds.BlockLocationSet = blockLocationSet(subBLSBImageNumber,...
                subBLSBlockOrigin, obj.BlockLocationSet.BlockSize, ...
                obj.BlockLocationSet.Levels);
            subds.reset();
        end
        
        function n = numobservations(obj)
            n = obj.TotalNumBlocks;
        end
    end
    
    methods (Access = private)

        function writeAllInSerial(obj, params)            
            while hasdata(obj)
                [block, blockInfo] = obj.read();
                blockFile = makeBlockFileName(params, blockInfo);
                % Invoke the write fcn.
                writeInfo.ReadInfo = blockInfo;
                writeInfo.SuggestedOutputName = blockFile;
                writeInfo.Location = params.OutputLocation;
                writeInfo.Quality = params.Quality;
                params.WriteFcn(block{1}, writeInfo, params.OutputFormat);
            end
        end
 
        function [block, blockInfo] = readOneBlock(obj, blockStart, imageNumber, level)
            bim = obj.Images(imageNumber);
            imageSize = bim.Size(level,:);            
            blockSize = obj.BlockSize;
            
            % If image is a higher dimension than block location set, then
            % extend block start in those dimensions by 1
            blockStart(end+1:bim.NumDimensions) = 1;            

            startLoc = blockStart - obj.BorderSize_;
            
            blockEnd = blockStart + blockSize - 1;
            if ~obj.PadPartialBlocks
                blockEnd = min(blockEnd, imageSize);
            end
            endLoc = blockEnd + obj.BorderSize_;
            
            obj.BlockCache.CurrentImageNumber = imageNumber;
            block = bim.getRegionPadded(startLoc, endLoc,...
                level, obj.PadMethod_, obj.BlockCache);
            
            blockInfo.BlockSub = ceil(blockStart./blockSize);
            blockInfo.Start = startLoc; % these two can be out
            blockInfo.End = endLoc;     % of bounds!
            blockInfo.Level = level;
            blockInfo.ImageNumber = imageNumber;
            blockInfo.BorderSize = obj.BorderSize_;
        end
    end
end

%% Helpers

function defaultWriteFcn(block, writeInfo, format)
blockFileWithParentDir = writeInfo.Location ...
    + writeInfo.SuggestedOutputName;
% Make sure it does not already exist
if isfile(blockFileWithParentDir)
    error(message('images:blockedImage:cannotOverwrite',...
        blockFileWithParentDir))
end

switch format
    case {'jpg', 'jpeg'}
            imwrite(block, blockFileWithParentDir,...
                "Quality", writeInfo.Quality);
    case {'png'}
            imwrite(block, blockFileWithParentDir);

    case 'mat'
        % No thread support for SAVE
        save(blockFileWithParentDir, 'block');

    otherwise
        % Not user facing. Earlier validation will have
        % caught this.
        assert(false, "Unknown format");
end
end

function blockFileName = makeBlockFileName(params, blockInfo)
% Create block file name of the format
% 'Image_<N>_Level_<L>_Block_<block origin>.<ext>'.
blockFileName = params.FilenamePrefix ...
    + "Image_" ...
    + num2str(blockInfo.ImageNumber, params.Leading0FormatStr)...
    + "_Level_" + num2str(blockInfo.Level)...
    + "_Block_" + regexprep(num2str(blockInfo.Start),'\s+','_')...
    + params.FilenameSuffix...
    + "." + params.OutputFormat;
end

function validatePadMethod(val, bims)
if ischar(val) || isstring(val)
    validatestring(val, {'replicate', 'symmetric'},mfilename,'PadMethod');
else
    validateattributes(val, {'numeric', 'logical', 'struct','categorical'},...
        {'scalar'}, mfilename, 'PadMethod');
    expClass = class(bims(1).InitialValue);
    isNumericExpected = any(strcmp(expClass, images.internal.iptlogicalnumerictypes));
    isNumericInput = any(strcmp(class(val), images.internal.iptlogicalnumerictypes));
    if isNumericExpected && isNumericInput
        if isequal(val, cast(val, expClass))
            % e.g. convert double(0) to uint8(0)
            val = cast(val, expClass);
        end
    end
    
    if ~isa(val, class(bims(1).InitialValue))
        error(message('images:blockedImage:invalidPadValueClass', expClass))
    end
    
    % Additional validation for struct and categorical
    if isstruct(val) && ~isequal(sort(fieldnames(val)), sort(fieldnames(bims(1).InitialValue)))
        error(message('images:blockedImage:invalidPadValueStruct'))
    end
    if iscategorical(val) && ~isequal(sort(categories(val)), sort(categories(bims(1).InitialValue)))
        error(message('images:blockedImage:invalidPadValueCat'))
    end
end
end

function mustMatchDims(prop, bims, propName)
dims = bims(1).NumDimensions;
if numel(prop)~=dims
    error(message('images:blockedImage:invalidNumDims', propName))
end
end

function [counts, blockPixelCount] = calculateCountsAndPixelCounts(ds, params)
% calculateCountsAndPixelCounts Calculate the counts and blockPixelCounts
% for all classes in the datastore, ds.

uniqueClasses = unique(params.Classes, 'stable');

numClasses = numel(uniqueClasses);

counts = zeros(numClasses,1);
blockPixelCount = zeros(numClasses,1);

while hasdata(ds)
    data = read(ds);
    for blockIdx = 1:numel(data)
        numObs = numel(data{blockIdx});
        
        if params.HasCats
            % Each image might have a different order that categories are
            % listed in, so sort to ensure they are all the same.
            countsForOneBlock = countcats(data{blockIdx}(:));
            [~,sInds] = sort(categories(data{blockIdx}));
            countsForOneBlock = countsForOneBlock(sInds);
        else % numeric
            countsForOneBlock = zeros(numClasses, 1);
            for cInd = 1:numClasses
                % Collapse duplicate classes
                pixelIdsForThisClass = ...
                    params.PixelLabelIDs(params.Classes == uniqueClasses(cInd));
                for pInd = 1:numel(pixelIdsForThisClass)
                    countsForOneBlock(cInd) = countsForOneBlock(cInd) + ...
                        nnz(data{blockIdx}==pixelIdsForThisClass(pInd));
                end
            end
        end
        
        counts = counts + countsForOneBlock;
        
        classIdx = countsForOneBlock > 0;
        blockPixelCount(classIdx) = blockPixelCount(classIdx) + numObs;
    end
end
end

%   Copyright 2020-2023 The MathWorks, Inc.
