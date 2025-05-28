classdef blockedImage < handle ...
        & matlab.mixin.CustomDisplay...
        & matlab.mixin.Copyable        
        
    properties
        UserData (1,1) struct
    end
    
    properties(Dependent)
        BlockSize (:,:) {mustBeInteger, mustBePositive, mustBeNonempty}
        
        Mode (1,1) char {mustBeMember(Mode, {'r','w','a'})}
        % Note - 'a' is undocumented.
        
        WorldStart (:,:) {mustBeReal, mustBeFinite, mustBeNonempty, mustBeNumeric}
        
        WorldEnd (:,:) {mustBeReal, mustBeFinite, mustBeNonempty, mustBeNumeric}
        
        AlternateFileSystemRoots (:,2) string
    end
    
    properties (Dependent, SetAccess=private)
        SizeInBlocks
        
        InitialValue (1,1)
    end
    
    properties (Access = private)
        % The core properties for dependent properties
        BlockSize_ double
        Mode_ (1,1) char = 'r'
        WorldStart_ (:,:) {mustBeReal, mustBeFinite}
        WorldEnd_ (:,:) {mustBeReal, mustBeFinite}
        InitialValue_ = 0
        SizeInBlocks_
        AlternateFileSystemRoots_  (:, 2) string
        
        % Variables to cache Adapter capabilities.
        IsGetFullImageSupported logical
        IsGetRegionSupported logical
    end
    
    properties (Hidden)
        % Cache object - caches blocks.
        % Marked Hidden since blockedImageDatastore needs access to this.
        BlockCache (1,1) images.blocked.internal.BlockCache
    end
    
    properties (GetAccess = public, SetAccess = private)
        Size (:,:) double {mustBeInteger, mustBePositive}
        
        NumLevels (1,:) {mustBeInteger, mustBePositive} = 1
        
        NumDimensions (:,:) {mustBeInteger, mustBePositive}
        
        IOBlockSize (:,:) double {mustBeInteger, mustBePositive}
        
        ClassUnderlying (:,1) string
        
        Source
    end
    
    properties (GetAccess = public, SetAccess = private)        
        Adapter = []
    end
    
    properties (Access = private)
        % LUT to convert IO levels to sorted levels exposed by this object
        Level2IOLevelLUT (:,1) double = []
        
        
        % A cell array, each element holds one block of initial values for
        % that corresponding level. This is cached for reuse, useful when
        % reading from a image which does not have valid image data
        % everywhere (e.g reading the result of a masked apply).
        BlocksFullOfInitialValue cell
        
        % The original state of the adapter as provided to the constructor.
        % This is saved for reuse during loadobj, or while reopening the
        % source after a crop operation.
        OriginalAdapter
        
        % The source string as given at construction time (before path
        % resolution happens)
        OriginalSource
        
        
        % Flag indicating if current image is the result of a previous crop
        % operation. (Note: crops operations can chain).
        IsCropped (1,1) logical = false
        % For a cropped image, stores the offset from the origin of the
        % original to the start of the crop window.
        CroppedOffsetSub(:,:) double {mustBeInteger}
        
        % For Mode=='w', holds the current level being written to. Useful
        % for multi-resolution image (since when level changes, openToWrite
        % must be called). Initialized to an invalid level.
        CurrentWriteLevel (1,1) double {mustBeInteger} = 0
        
        % Pixel extents in world units. This is updated each time
        % WorldStart/End change and is used in coordinate conversion
        % routines.
        PixelSizeInWorld (:,:) {mustBeReal, mustBeFinite}
    end
    
    properties (Access = private, NonCopyable, Transient)
        % Holds the result of a parfeval call, these are 'future' objects
        % representing the work spawned off to the workers.
        Futures
        % A data queue used to signal progress from the workers (in the
        % parallel context)
        ProgressDataQueue

        % All wait bar related variables are stored in this struct.
        WaitBarVars = struct('Aborted', false);
    end
    
    methods
        function obj = blockedImage(sources, imageSize, blockSize, initialValue, params)
            arguments
                sources = []
                imageSize (:,:) {mustBeInteger, mustBePositive} = []
                blockSize (:,:) {mustBeInteger, mustBePositive} = []
                initialValue = []
                params.Adapter (1,1) images.blocked.Adapter {mustBeValid}
                params.BlockSize (:,:) {mustBeInteger, mustBePositive, mustBeNonempty}
                params.WorldStart (:,:) {mustBeReal, mustBeFinite, mustBeNonempty, mustBeNumeric}
                params.WorldEnd (:,:) {mustBeReal, mustBeFinite, mustBeNonempty, mustBeNumeric}
                params.UserData (1,1) struct
                params.Mode (1,1) char {mustBeMember(params.Mode, {'r','w','a'})} = 'r'
                params.AlternateFileSystemRoots (:,2) string
            end
            
            if nargin == 0
                % Needed for creating arrays of objects
                return
            end            
           
            if isa(sources, 'matlab.io.datastore.FileSet')
                stringArrayOrNumericCell = sources.FileInfo.Filename; 
            elseif iscellstr(sources) || ischar(sources) %#ok<ISCLSTR>
                stringArrayOrNumericCell = string(sources);
            elseif isnumeric(sources)||islogical(sources) ||...
                    isstruct(sources) || iscategorical(sources)
                stringArrayOrNumericCell = {sources};
            elseif isempty(sources)
                % Explicitly use double([])
                stringArrayOrNumericCell = {[]};
            elseif iscell(sources) && all(cellfun(@(x)isnumeric(x)||islogical(x)||iscategorical(x), sources),'all')
                % Multilevel in-memory representation. Group it as one unit
                stringArrayOrNumericCell = {sources};
            else
                % Let adapter validate
                stringArrayOrNumericCell = sources;
            end
                        
            
            % Allow creation of an array of objects from a array/cell of
            % sources.
            obj(numel(stringArrayOrNumericCell)) = blockedImage();
            
            
            % If input sources is a fileset, pick AFS from it.
            if isa(sources, 'matlab.io.datastore.FileSet')
                [obj.AlternateFileSystemRoots] = deal(sources.AlternateFileSystemRoots);
            end
            
            % Loop through each source
            for sInd = 1:numel(stringArrayOrNumericCell)
                
                % Setup the cache
                obj(sInd).BlockCache = images.blocked.internal.BlockCache;
                               
                if params.Mode == "w" || params.Mode == "a"
                    if numel(stringArrayOrNumericCell)~=1
                        error(message('images:blockedImage:onlyScalarWrite'));
                    end
                    
                    % NV takes priority
                    if isfield(params,'BlockSize')
                        blockSize = params.BlockSize;
                    end
                    
                    if iscell(stringArrayOrNumericCell)
                        destination = stringArrayOrNumericCell{sInd};
                    else
                        destination = stringArrayOrNumericCell(sInd);
                    end
                    obj.OriginalSource = destination;
                    obj.writeModeConstructor(destination, blockSize, ...
                        imageSize, initialValue, params);
                    
                else
                    % read mode, error if any write mode optional inputs
                    % were given
                    if ~isempty(imageSize) || ~ isempty(initialValue)
                        error(message('images:blockedImage:invalidWriteModeArgs'));
                    end
                    if iscell(stringArrayOrNumericCell)
                        % Source is guaranteed numeric/struct/categorical
                        source = stringArrayOrNumericCell{sInd};
                    else % Its a string array
                        source = stringArrayOrNumericCell(sInd);
                    end
                    obj(sInd).OriginalSource = source;
                    obj(sInd).readModeConstructor(source, params);
                end
                
                % Common read-write props
                if isfield(params, 'AlternateFileSystemRoots')
                    obj(sInd).AlternateFileSystemRoots = params.AlternateFileSystemRoots;
                end
                
                % Overwrite default world extents if given as PVs
                if isfield(params,'WorldStart')
                    % Validate start<end against existing WorldEnd only if
                    % WorldEnd is not given explicitly. Else, set WorldStart
                    % without validating against WorldEnd (the WorldEnd setter
                    % will do the validation)
                    validateAgainstExistingEnd = ~isfield(params,'WorldEnd');
                    mustMatchSize(obj(sInd), params.WorldStart, "WorldStart")
                    obj(sInd).setWorldStart(params.WorldStart, validateAgainstExistingEnd);
                end
                if isfield(params,'WorldEnd')
                    obj(sInd).WorldEnd = params.WorldEnd;
                end
                obj(sInd).computePixelWorldExtents();
                
                if isfield(params, 'UserData')
                    obj(sInd).UserData = params.UserData;
                end
            end
            
            % Set mode after setting blocksize (since blocksize cant be set
            % in 'w' mode, this has to be set at the end)
            [obj.Mode_] = deal(params.Mode);            
        end
        
        function delete(obj)            
            if isempty(obj.Adapter)
                % If Adapter was ever set, close it
                close(obj.Adapter);
            end
        end
        
        function varargout = apply(obj, usrFcn, params)
            
            %            
            
            % Internal use PV
            % 'Parent'      - A uifigure. A uiprogressdlg will be parented
            %                 to this. Default is empty.
            % 'Cancellable' - Scalar logical. Controls if the cancel button
            %                 is shown or not on the waitbar. Default is
            %                 true.
            
            arguments                
                obj(1,:) blockedImage
                usrFcn (1,1) function_handle
                params.BatchSize (1,1) double {mustBeInteger} = 1
                % Default value covers full image in non-overlapping blocks
                params.BlockLocationSet (1,1) blockLocationSet {validateBLS(obj, params.BlockLocationSet)}
                % Defaults to BlockSize property
                params.BlockSize (1,:) double {mustBeInteger, mustBePositive, mustBeNonempty}
                % Defaults to 0
                params.BorderSize (1,:) double {mustBeInteger}
                params.DisplayWaitbar (1,1) logical = true
                params.ExtraImages (1,:) blockedImage = blockedImage.empty()
                params.ExtraLevels (1,:) double {mustBeInteger, mustBePositive}
                params.Level (1,1) double {mustBeInteger, mustBePositive, mustBeLessThanNumLevels(obj, params.Level)} = 1
                % Default determined by output type and OutputLocation
                params.Adapter
                params.OutputLocation (1,1) string {mustBeTextScalar, mustBeNonzeroLengthText}
                params.Resume (1,1) logical = false
                params.PadMethod = "replicate"
                params.PadPartialBlocks (1,1) logical = false
                params.UseParallel (1,1) logical = false
                
                params.Parent (1,1) {mustBeA(params.Parent, 'matlab.ui.Figure')}
                params.Cancellable(1,1) logical = true
            end            
            
            if any(arrayfun(@(b)isempty(b.Adapter),obj))
                error(message('images:blockedImage:emptyInput'))
            end
            
            if params.BatchSize>1 && ~params.PadPartialBlocks        
                % BatchSize>1 requires that blocks be padded
                error(message('images:blockedImage:setPadPartial'));
            end
            
            if isfield(params, 'BlockSize') && isfield(params, 'BlockLocationSet')
                % If BlockSize is specified, BlockLocationSet should NOT be
                % specified
                error(message('images:blockedImage:blockSizeAndBlockLocationSet'));
            end
                        
            % Extract string sources and check for duplicates
            stringInds = arrayfun(@(b)isstring(b.Source), obj);            
            if ~isequal(numel(unique([obj(stringInds).Source])), sum(stringInds))
                error(message('images:blockedImage:duplicateSources'))
            end            

            % Swap the parallel loop (if enabled) from over blocks to over
            % images if there are more images than workers to ensure
            % workers are optimally utilized.
            IsParallelOverImages = false;
            if params.UseParallel
                if ~isfield(params, 'OutputLocation')
                    error(message('images:blockedImage:parallelNeedsOutputLocation'));
                end                
                curPool = gcp();
                if isempty(curPool)
                    error(message('images:bigimage:couldNotOpenPool'))
                end                
                IsParallelOverImages = numel(obj)>curPool.NumWorkers;
            end
            
            % Parse Adapter PV. Its either a scalar adapter, or one per
            % output in a cell array.
            if isfield(params,'Adapter')
                if isscalar(params.Adapter)
                    if iscell(params.Adapter)
                        params.Adapter = params.Adapter{1};
                    end
                    % Use the same for all outputs
                    params.Adapter = repmat({params.Adapter}, [1, nargout]);
                else
                    % Else, has to be cell array of same size as number of
                    % outputs.
                    validateattributes(params.Adapter, {'cell'},...
                        {'nonempty', 'numel', nargout}, mfilename, 'Adapters');
                end
                
                for imageInd = 1:numel(params.Adapter)
                    anAdapter = params.Adapter{imageInd};
                    validateattributes(anAdapter, {'images.blocked.Adapter'},...
                        {'scalar'}, mfilename, 'Adapter');
                    if params.UseParallel && ~IsParallelOverImages
                        % The adapter needs to support parallel write ONLY
                        % if we are processing blocks in parallel.
                        acap = blockedImage.introspectAdapter(anAdapter);
                        if ~acap.parallelWriteSupported
                            error(message('images:blockedImage:noParallelSupport'));
                        end
                    end
                end
            else
                % Pick defaults depending on output later (after the first
                % block is processed, so output types can be inferred). 
                params.Adapter = {};
            end            
            
            % Parse output location
            if isfield(params, 'OutputLocation')
                if ~params.Resume
                    mustNotExist(params.OutputLocation);
                end
            else
                params.OutputLocation = string.empty();
            end            
                        
            % Augment params to indicate array size (used to compute
            % outputlocation and waitbar length)
            params.ArrayLength = numel(obj);
            % Note: Only the first in the array holds the waitbar
            cleanUpFcn = onCleanup(@()obj(1).deleteWaitBar());
            
            varargout = cell(1, nargout);
            if IsParallelOverImages
                % Many images. Parallel image-wise, serial block-wise
                % Disable blockwise paralleism explicitly
                params.UseParallel = false;
                [varargout{:}] = obj.applyInParallelOverImages(usrFcn, params);

            elseif numel(obj)>1
                % Loop over images serially, blocks in parallel depending
                % on UseParallel. Waitbar is over number of images
                [varargout{:}] = obj.applyInSerialOverImages(usrFcn, params);

            else
                % One image. parallel block-wise if UseParallel is set.
                varargout = cell(1, nargout);
                oneCallOutputs = cell(1, nargout);
                % For each image in array:
                params.Index = 1;
                % This will process blocks in parallel if required
                [oneCallOutputs{:}] = obj.applyCore(usrFcn, params);
                for oInd = 1:nargout
                    varargout{oInd}(end+1) = oneCallOutputs{oInd};
                end
            end
        end
        
        function cobj = crop(obj, cstart, cend)
            arguments
                obj(1,:) blockedImage
                cstart(1,:) double {mustBePositive, mustBeInteger, mustBeNonempty}
                cend(1,:) double {mustBePositive, mustBeInteger, mustBeNonempty}
            end
            
            if isempty(obj.Adapter)
                % blockedImage().. nop.
                error(message('images:blockedImage:emptyInput'))                
            end
            
            
            obj.mustBeInReadMode();
                                   
            if numel(cstart)>obj.NumDimensions 
                error(message('images:blockedImage:invalidNumCols', 'CSTART'))
            end
            if numel(cend)>obj.NumDimensions 
                error(message('images:blockedImage:invalidNumCols', 'CEND'))
            end
            
            % Extend cstart/cend for other dimensions
            cstart(numel(cstart)+1:obj.NumDimensions) = 1;
            cend(numel(cend)+1:obj.NumDimensions) = obj.Size(1, (numel(cend)+1:obj.NumDimensions));
            
            if any(cend>obj.Size(1,:)) || any(cend<cstart)
                error(message('images:blockedImage:invalidCropEnd'))
            end
            
            cobj = copy(obj);
                       
            % Keep track of cropped status. Useful later in some interfaces
            % to simplify computation for non-cropped images.
            cobj.IsCropped = true;                        
            
            % Convert crop window to world coordinates (use finest level)
            cstartWorld = obj.sub2world(cstart, "Level", 1);
            cendWorld = obj.sub2world(cend, "Level", 1);
            % Expand on either side to include pixel edges
            halfPixel = (obj.WorldEnd_(1,:) - obj.WorldStart_(1,:))...
                ./obj.Size(1,:)...
                ./2;
            cstartWorld = cstartWorld-halfPixel;
            % Half open range ([))
            cendWorld = cendWorld+halfPixel-eps(cendWorld);
                        
            for lInd = 1:obj.NumLevels
                
                lvlPixelSubStart = obj.world2sub(cstartWorld, "level", lInd);
                lvlPixelSubEnd = obj.world2sub(cendWorld, "Level", lInd);
                
                % Update the world extents based on the actual pixels used
                % (Note this will most likely be different than cstartWorld/end for
                % sublevels)
                halfPixel = (obj.WorldEnd_(lInd,:) - obj.WorldStart_(lInd,:))...
                    ./obj.Size(lInd,:)...
                    ./2;
                cobj.WorldStart_(lInd,:) = obj.sub2world(lvlPixelSubStart, "level", lInd) - halfPixel;
                % Dont subtract eps here since WorldEnd is not half open
                % (we clamp the edge of the image to belong to the last
                % pixel)
                cobj.WorldEnd_(lInd,:) = obj.sub2world(lvlPixelSubEnd, "level", lInd) + halfPixel;
                                
                cobj.Size(lInd,:) = lvlPixelSubEnd-lvlPixelSubStart+1;
                cobj.SizeInBlocks_(lInd,:) = ceil(cobj.Size(lInd,:)./cobj.BlockSize_(lInd,:));
                
                if obj.IsCropped
                    % Cropping a previously cropped image, include the
                    % offset.
                    cobj.CroppedOffsetSub(lInd,:) = lvlPixelSubStart-1 ...
                        + obj.CroppedOffsetSub(lInd,:);
                else
                    cobj.CroppedOffsetSub(lInd,:) = lvlPixelSubStart-1;
                end
            end
        end
    
        function mobj = makeMultiLevel2D(obj, params)
            arguments
                obj (1,1) blockedImage
                params.Scales (1,:) double {mustBeNumericOrLogical mustBeFinite mustBePositive}
                params.BlockSize (1,:) {mustBeInteger, mustBePositive, mustBeVector, mustBeNonempty}
                params.Interpolation (1,1) string 
                params.OutputLocation (1,1) string {mustBeTextScalar, mustBeNonzeroLengthText}
                params.Adapter (1,1) images.blocked.Adapter
                params.UseParallel (1,1) logical = false
                params.DisplayWaitbar (1,1) logical = true
                % Internal API for apps
                params.Parent (1,1) {mustBeA(params.Parent, 'matlab.ui.Figure')}
            end

            %

            params = validateAndSetInterpolation(obj, params, "makeMultiLevel2D");

            % Default adapter to Tiff unless input is in memory and an
            % outputlocation is NOT specified.
            if ~isfield(params, "Adapter")
                if ~isfield(params, "OutputLocation") ...
                        && isa(obj.Adapter,'images.blocked.InMemory')
                    params.Adapter = images.blocked.InMemory;
                else
                    params.Adapter = images.blocked.TIFF;
                end
            end

            % Default value for Scales halves till all dims are <2048.
            isScaleUserSpecified = isfield(params,'Scales');
            if ~isScaleUserSpecified
                imageSize = obj.Size(1,:);
                params.Scales = 1;
                while any(imageSize*params.Scales(end) > 2048)
                    params.Scales(end+1) = params.Scales(end)/2;
                end
            end

            % Pick default block size from the finest level of the input.
            % Nudge to x16 if TIFF to meet file format constraint.
            inputLevel = 1;
            if ~isfield(params, "BlockSize")
                params.BlockSize = obj.BlockSize(inputLevel,:);
                if isa(params.Adapter, 'images.blocked.TIFF')
                    % TIFF required blocks to be x16. Both BlockSize and
                    % Scales impact the output block size. Floor BlockSize
                    % to nearest x256 to help reduce the size of 'nudge'
                    % required on the scales. (Floor to ensure that we dont
                    % end with single partial blocks if we round up)
                    params.BlockSize = max(floor(params.BlockSize(1:2)/256)*256,256);
                end
            end

            if isa(params.Adapter, 'images.blocked.TIFF')
                % Nudge scales to ensure resized blocks are x16
                newScales = max(round(params.Scales*16)/16, 1/16);
                newScales = sort((newScales),'descend');
                % If nudged scales are off by more than 1% of the smallest
                % input scale, issue a warning.
                givenScales = sort(params.Scales,'descend');                
                if max(imabsdiff(givenScales, newScales))>.01*min(params.Scales)...
                        && isScaleUserSpecified
                    warning(message('images:blockedImage:scalesChangedForTiff', num2str(newScales)));                    
                end
                params.Scales = newScales;
            end

            % imresize uses 'bilinear'
            if params.Interpolation=="linear"
                params.Interpolation = "bilinear";
            end

            resizer = @(block,scale)imresize(block,scale, params.Interpolation);
            mobj = makeMultiLevelN(obj, resizer, params);
        end

        function mobj = makeMultiLevel3D(obj, params)
            arguments
                obj (1,1) blockedImage
                params.Scales (1,:) double {mustBeNumericOrLogical mustBeFinite mustBePositive}
                params.BlockSize (1,:) {mustBeInteger, mustBePositive, mustBeVector, mustBeNonempty}
                params.Interpolation (1,1) string 
                params.OutputLocation (1,1) string {mustBeTextScalar, mustBeNonzeroLengthText}
                params.Adapter (1,1) images.blocked.Adapter
                params.UseParallel (1,1) logical = false
                params.DisplayWaitbar (1,1) logical = true
                % Internal API for apps
                params.Parent (1,1) {mustBeA(params.Parent, 'matlab.ui.Figure')}
            end

            if obj.NumDimensions<3
                error(message('images:blockedImage:invalid3DDimensions'));
            end

            params = validateAndSetInterpolation(obj, params, "makeMultiLevel3D");

            % Default blocksize is from the finest level of the input
            inputLevel = 1;
            isBlockSizeDefault = ~isfield(params, "BlockSize");
            if isBlockSizeDefault
                params.BlockSize = obj.BlockSize(inputLevel,:);
            end

            % Default Scales - halve till all dims < 256
            if ~isfield(params,'Scales')
                imageSize = obj.Size(1,:);
                params.Scales = 1;
                while any(imageSize*params.Scales(end) > 256)
                    params.Scales(end+1) = params.Scales(end)/2;
                end
            end

            if isBlockSizeDefault
                % Ensure we dont end up with a MxNx1 intermediate block
                % while scaling down. The minimum size in the third
                % dimension is 1/minscale (which results in the last level
                % having a MxNx1 dimension). 
                minRequired3rdDim = ceil(1/min(params.Scales));
                params.BlockSize(3) = max(params.BlockSize(3), minRequired3rdDim);
            end

            % Default Adapter is H5Blocks, unless input is in memory.
            if ~isfield(params, "Adapter")
                if isa(obj.Adapter,'images.blocked.InMemory')
                    params.Adapter = images.blocked.InMemory;
                else
                    params.Adapter = images.blocked.H5Blocks;
                end
            end

            resizer = @(block, scale)resizer3D(block, scale, params.Interpolation);
            mobj = makeMultiLevelN(obj, resizer, params);
        end

        function mobj = concatenateLevels(obj)
            arguments (Repeating)
                obj (1,:) blockedImage
            end
            %

            % Create copies to ensure changing properties of the original
            % does not impact the output
            bimArray = cellfun(@(b)copy(b), obj);

            adapter = images.blocked.LevelConcatenator(bimArray);
            mobj = blockedImage([], 'Adapter',adapter);
            % Explicitly set the source. Setting the source in the
            % constructor will result in code taking the array output
            % creation code path.
            mobj.Source = bimArray;
        end

    end
    
    %% Get
    methods
        function imgRegion = getRegion(obj, pixelStartSub, pixelEndSub, params)
            arguments
                obj (1,1) blockedImage
                pixelStartSub (1,:) {mustBeInteger, mustBePositive, mustBeLessThanOrEqualNumDimensions(obj,pixelStartSub)}
                pixelEndSub (1,:) {mustBeInteger, mustBePositive, mustBeLessThanOrEqualNumDimensions(obj,pixelEndSub)}
                params.Level (1,1) {mustBeInteger, mustBePositive, mustBeLessThanNumLevels(obj, params.Level)} = 1
                % Internal use only
                params.BlockCache = []
            end
            
            obj.mustBeInReadMode();
            
            if isempty(obj.Adapter)
                % blockedImage().. nop.
                imgRegion = [];
                return
            end
            
            level = params.Level;

            % Pad out any missing dimensions with full extent.
            pixelStartSub(:, end+1:obj.NumDimensions) = 1;
            pixelEndSub(:, end+1:obj.NumDimensions) = obj.Size(level,size(pixelEndSub,2)+1:obj.NumDimensions);
            

            if any(pixelEndSub>obj.Size(level,:)) || any(pixelEndSub<pixelStartSub)
                error(message('images:blockedImage:invalidPixelSub'))
            end            
            
            imgRegion = obj.getRegionInternal(pixelStartSub, pixelEndSub,...
                params.Level, params.BlockCache);
        end
        
        function [block, blockInfo] = getBlock(obj, blockSub, params)
            arguments
                obj (1,1) blockedImage
                blockSub (1,:) {mustBeInteger, mustBePositive, mustMatchNumDimensions(obj, blockSub)}
                params.Level (1,1) {mustBeInteger, mustBePositive, mustBeLessThanNumLevels(obj, params.Level)} = 1
            end
            
            obj.mustBeInReadMode();
            
            if isempty(obj.Adapter)
                % blockedImage().. nop.
                block = []; blockInfo = struct([]);
                return
            end
            
            
            if any(blockSub>obj.SizeInBlocks_(params.Level,:))
                error(message('images:blockedImage:invalidBlockSub', ...
                    num2str(obj.SizeInBlocks_(params.Level,:))))
            end
            
            level = params.Level;
            
            blockedStartInPixelSub = (blockSub-1).*obj.BlockSize_(level,:) + 1;
            blockedEndInPixelSub = blockedStartInPixelSub + obj.BlockSize_(level,:) - 1;
            
            imageSize = obj.Size(level,:);
            
            % Clamp
            blockedEndInPixelSub = min(blockedEndInPixelSub, imageSize);
            
            block = obj.getRegion(blockedStartInPixelSub, blockedEndInPixelSub,...
                'Level', level);
            
            if nargout == 2
                blockInfo.Start = blockedStartInPixelSub;
                blockInfo.End = blockedEndInPixelSub;
                blockInfo.Level = level;
            end
        end
        
        function fullImage = gather(obj, params)
            arguments
                obj (1,1) blockedImage
                params.Level (1,1) {mustBeInteger, mustBePositive, mustBeLessThanNumLevels(obj, params.Level)} = obj.NumLevels
            end
            
            obj.mustBeInReadMode();
            
            if isempty(obj.Source)
                fullImage = [];
                return
            end
            
            if isempty(obj.IsGetFullImageSupported)
                % Flag which indicates is the current adapter supports
                % getFullImage API (which is more efficient than getRegion)
                acap = blockedImage.introspectAdapter(obj.OriginalAdapter);
                obj.IsGetFullImageSupported = acap.getFullImageSupported;
            end
            
            level = params.Level;
            
            if obj.IsGetFullImageSupported && ~obj.IsCropped
                ioLevel = obj.Level2IOLevelLUT(level);
                fullImage = obj.Adapter.getFullImage(ioLevel);
            else
                startSubs = ones(1,obj.NumDimensions);
                endSubs = obj.Size(level,:);
                fullImage = obj.getRegion(startSubs, endSubs,...
                    'Level', level);
            end
        end
    end
    
    %% Set, Write
    methods
        function setBlock(obj, blockSub, data, params)           
            arguments
                obj (1,1) blockedImage
                blockSub (1,:) {mustBeInteger, mustBePositive, mustMatchNumDimensions(obj, blockSub)}
                data {mustBeNonempty}
                params.Level (1,1) {mustBeInteger, mustBePositive, mustBeLessThanNumLevels(obj, params.Level)} = 1
            end
            
            if isempty(obj.Adapter)
                % blockedImage().. nop.
                return
            end
            
            if obj.Mode_~='w' && obj.Mode_~='a'
                error(message('images:blockedImage:notInWriteMode'))
            end
            
            if any(blockSub>obj.SizeInBlocks_(params.Level,:))
                error(message('images:blockedImage:invalidBlockSub',...
                    num2str(obj.SizeInBlocks_(params.Level,:))))
            end
            
            level = params.Level;
            
            validateattributes(data, obj.ClassUnderlying(level),...
                {'nonempty'}, mfilename, 'BLOCKDATA');
            if isstruct(data) && ~isequal(sort(fieldnames(data)), sort(fieldnames(obj.InitialValue_)))
                % Field names dont match
                error(message('images:blockedImage:fieldNamesMismatch'));
            elseif iscategorical(data) && ~isequal(sort(categories(data)), sort(categories(obj.InitialValue_)))
                % Categories dont match
                error(message('images:blockedImage:categoriesMismatch'));
            end
            
            ioLevel = obj.Level2IOLevelLUT(level);
            
            %Note: CurrentWriteLevel is opened to 1 in the write
            %constructor by default.
            if ~isequal(obj.CurrentWriteLevel, ioLevel)
                % Open adapter to writing at requested level
                % (Or, if already opened and writing to a multiresolution
                % image, switch to writing to the requested level)
                info.Size = obj.Size;
                info.IOBlockSize = obj.BlockSize_;
                info.Datatype = obj.ClassUnderlying;
                info.InitialValue = obj.InitialValue_;
                info.UserData = obj.UserData;
                info.WorldStart = obj.WorldStart_;
                info.WorldEnd = obj.WorldEnd_;
                obj.Adapter.openToWrite(obj.Source,info, ioLevel);
                obj.CurrentWriteLevel = ioLevel;
            end
            
            if any(blockSub == obj.SizeInBlocks_(params.Level,:))
                % Edge block, check if data needs to be trimmed to fit
                sizeIfNotTrimmed = (blockSub-1).*obj.BlockSize_(level,:) + size(data, 1:obj.NumDimensions);
                trimAmount = max(0, sizeIfNotTrimmed - obj.Size(level,:));
                if any(trimAmount)
                    % Trim
                    indStruct.type = '()';
                    indStruct.subs = cell(1,obj.NumDimensions);
                    for dInd = 1:obj.NumDimensions
                        indStruct.subs{dInd} = 1:(size(data,dInd)-trimAmount(dInd));
                    end
                    data = subsref(data, indStruct);
                end
            else
                expBlockSize = obj.BlockSize_(level,:);
                if ndims(data)>numel(expBlockSize) || ~isequal(size(data, 1:numel(expBlockSize)), expBlockSize)
                    error(message('images:blockedImage:incorrectBlockSize', ...
                        num2str(blockSub), num2str(size(data)), num2str(expBlockSize)));
                end
            end
            
            obj.Adapter.setIOBlock(blockSub, ioLevel, data);
        end
        
        function write(obj, destination, params)            
            arguments
                obj (1,1) blockedImage
                destination (1,1) string {mustBeNonzeroLengthText}
                params.BlockSize (1,:) double {mustBeNumeric, mustBeInteger, mustBePositive, mustBeNonempty}
                params.DisplayWaitbar (1,1) logical = true
                params.LevelImages (1,:) blockedImage = blockedImage.empty()
                params.Levels (1,:) {mustBeInteger, mustBePositive, mustBeLessThanNumLevels(obj, params.Levels)} = 1:obj.NumLevels
                params.Adapter (1,1) images.blocked.Adapter {mustBeValid} = pickWriteAdapter(destination, obj.InitialValue)
                % Internal API for apps
                params.Parent (1,1) {mustBeA(params.Parent, 'matlab.ui.Figure')}
            end
            
            mustNotExist(destination);
            
            if isfield(params, 'BlockSize')
                % Extend BlockSize if needed
                if numel(params.BlockSize)<obj.NumDimensions
                    params.BlockSize(end+1:obj.NumDimensions) = ...
                        obj.Size(1, numel(params.BlockSize)+1: end);
                end
                validateattributes(params.BlockSize, {'double'},...
                    {'size', [1 obj.NumDimensions]}, ...
                    mfilename, 'BlockSize');
            end
            
            % LevelImages should be single level and match NumDimensions
            % Datatype can change (some formats store logical masks as a
            % level)
            if ~isempty(params.LevelImages)
                if ~all([params.LevelImages.NumDimensions]==obj.NumDimensions)
                    error(message('images:blockedImage:levelImagesShouldHaveSameDims'))
                end
                if ~all([params.LevelImages.NumLevels]==1)
                    error(message('images:blockedImage:levelImagesMustbeSingleLevel'))
                end
            end
            
            if isa(params.Adapter, 'images.blocked.InMemory')
                error(message('images:blockedImage:cantWriteToInMem'))
            end
            
            writeAdapter = copy(params.Adapter);
            
            % Create a single array of all writable images
            bimArray = [obj, params.LevelImages];
            % Collect all their levels.
            allLevels = arrayfun(@(x){1:x.NumLevels}, bimArray);
            
            % Replace the first (obj)'s level with whatever was explicitly
            % specified.
            allLevels{1} = params.Levels;
            totalNumLevels = numel([allLevels{:}]);
            
            % Initialize output meta data
            nDims = obj.NumDimensions;
            imageSizes = ones(totalNumLevels, nDims);
            ioBlockSizes = ones(totalNumLevels, nDims);
            pixelTypes = repmat("", [1 , totalNumLevels]);
            worldStart = zeros(totalNumLevels, nDims);
            worldEnd = zeros(totalNumLevels, nDims);
            
            %Create a copy, set required blocksize and count total number
            %of blocks. Collect required meta data.
            outLvlInd = 1;
            numBlocks = 0;
            for objInd = 1:numel(bimArray)
                % Create a copy so we can change the blockSize
                bimArray(objInd) = copy(bimArray(objInd));
                
                bim = bimArray(objInd);
                for lvlInd = 1:numel(allLevels{objInd})
                    % Collect meta data for each level
                    lvl = allLevels{objInd}(lvlInd);
                    imageSizes(outLvlInd,:) = bim.Size(lvl,:);
                    if isfield(params,'BlockSize')
                        ioBlockSizes(outLvlInd,:) = params.BlockSize;
                    else
                        ioBlockSizes(outLvlInd,:) = bim.BlockSize(lvl,:);
                    end
                    bim.BlockSize(lvl,:) = ioBlockSizes(outLvlInd,:);
                    pixelTypes(outLvlInd) = bim.ClassUnderlying(lvl);
                    
                    sizeInBlocks = bim.SizeInBlocks(lvl,:);
                    numBlocks = numBlocks + prod(sizeInBlocks);
                    
                    worldStart(outLvlInd,:) = bim.WorldStart_(lvl, :);
                    worldEnd(outLvlInd,:) = bim.WorldEnd_(lvl,:);
                    
                    outLvlInd = outLvlInd+1;
                end
            end
            
            % Prepare the common 'info' struct to pass to the adapter
            info.UserData = obj.UserData;
            info.Size = imageSizes;
            info.IOBlockSize = ioBlockSizes;
            info.Datatype = pixelTypes;
            info.WorldStart = worldStart;
            info.WorldEnd = worldEnd;
            
            % Setup waitbar
            wparams.DisplayWaitbar = params.DisplayWaitbar;
            wparams.BatchSize = 1;
            wparams.Cancellable = false;
            if isfield(params, 'Parent')
                wparams.Parent = params.Parent;
            end
            cleanUpFcn = onCleanup(@()obj.deleteWaitBar());
            titleText = getString(message('images:blockedImage:processingBlocks'));
            [obj.WaitBarVars, updateWaitBarFcn] = ...
                obj.initializeWaitBarVars(wparams, numBlocks, titleText);
            
            
            outLvlInd = 1;
            blockSubCell = cell(1,nDims);
            try
                for objInd = 1:numel(bimArray)
                    bim = bimArray(objInd);
                    info.InitialValue = bim.InitialValue;
                    % For each level of that bim
                    for lvlInd = 1:numel(allLevels{objInd})
                        lvl = allLevels{objInd}(lvlInd);
                        writeAdapter.openToWrite(destination,info, outLvlInd);
                        
                        % For each block in that level
                        sizeInBlocks = bim.SizeInBlocks(lvl,:);
                        totalNumBlocks = prod(sizeInBlocks);
                        for blockInd = 1:totalNumBlocks
                            [blockSubCell{:}] = ind2sub(sizeInBlocks, blockInd);
                            data = bim.getBlock([blockSubCell{:}],"Level", lvl);
                            writeAdapter.setIOBlock([blockSubCell{:}], outLvlInd, data);
                            updateWaitBarFcn();
                        end
                        
                        outLvlInd = outLvlInd + 1;
                    end
                end
                
                writeAdapter.close();
                
            catch ALL
                try
                    writeAdapter.close();
                catch
                    % ignore any failures.
                end
                % Clean up partial data
                if isfolder(destination)
                    rmdir(destination, 's')
                elseif isfile(destination)
                    delete(destination)
                end
                rethrow(ALL);
            end
        end
    end
    
    %% Coordinate conversion routines
    methods
        function world = sub2world(obj, pixelSubs, params)
            arguments
                obj (1,1) blockedImage
                pixelSubs (:,:) double {mustBeInteger, mustBeLessThanOrEqualNumDimensions(obj, pixelSubs)}
                params.Level (1,1) double {mustBeInteger, mustBePositive, mustBeLessThanNumLevels(obj, params.Level)} = 1
            end
            nInputDims = size(pixelSubs,2);
            pixelSizeInWorld = obj.PixelSizeInWorld(params.Level,1:nInputDims);
                        
            % This points to the right edge of the pixel
            world = obj.WorldStart_(params.Level,1:nInputDims) + pixelSizeInWorld.*pixelSubs;
            
            % Pixel subscripts are pixel centers, so move back half a pixel
            % width
            world = world-pixelSizeInWorld/2;
        end
        
        function pixelSubs = world2sub(obj, pixelWorld, params)            
            arguments
                obj (1,1) blockedImage
                pixelWorld (:,:) double {mustBeFinite, mustBeReal, mustBeLessThanOrEqualNumDimensions(obj, pixelWorld)}
                params.Level (1,1) double {mustBeInteger, mustBePositive, mustBeLessThanNumLevels(obj, params.Level)} = 1
                
                % Internal API for use when working with getRegionpadded,
                % where this is turned off.
                params.Clamp (1,1) logical = true
            end
            nInputDims = size(pixelWorld,2);
            pixelSizeInWorld = obj.PixelSizeInWorld(params.Level,1:nInputDims);
            
            % Bring first pixel edge to 0 by:
            %   - obj.WorldStart_(params.Level,:)
            % Then move to world coordinates of pixel centers by:
            %   + pixelSizeInWorld/2
            % Then convert world coordinates to subscripts by:
            %   ./pixelSizeInWorld
            % Do this in one line for performance (pixelWorld can contain
            % multiple pixel locations!)
            pixelSubs = (pixelWorld - obj.WorldStart_(params.Level,1:nInputDims) + pixelSizeInWorld/2)./pixelSizeInWorld;
            
            % Lock down to half open interval - [)
            % Note: When Clamp is false, pixelSubs can be negative (to
            % account for border size etc), so use FIX.
            pixelSubs(pixelSubs>0) = round(pixelSubs(pixelSubs>0));
            pixelSubs(pixelSubs<0) = fix(pixelSubs(pixelSubs<0));
            
            if params.Clamp
                % Make valid subscripts by default
                pixelSubs = max(min(obj.Size(params.Level,1:nInputDims), pixelSubs), 1);
            end
        end
        
        function blockSub = sub2blocksub(obj, pixelSubs, params)
            arguments
                obj (1,1) blockedImage
                pixelSubs (:,:) {mustBeInteger, mustBePositive, mustMatchNumDimensions(obj, pixelSubs)}
                params.Level (1,1) double {mustBeInteger, mustBePositive, mustBeLessThanNumLevels(obj, params.Level)} = 1
            end
            if any(pixelSubs>obj.Size(params.Level,:),'all')
                error(message('images:blockedImage:pixelSubsTooLarge'))
            end
            blockSize = obj.BlockSize_(params.Level,:);
            blockSub = ceil(pixelSubs./blockSize);
        end
        
        function [pixelStartSub, pixelEndSub] = blocksub2sub(obj, blockSub, params)
            arguments
                obj (1,1) blockedImage
                blockSub (:,:) {mustBeInteger, mustMatchNumDimensions(obj, blockSub)}
                params.Level (1,1) double {mustBeInteger, mustBePositive, mustBeLessThanNumLevels(obj, params.Level)} = 1
            end
            level = params.Level;
            
            if any(blockSub>obj.SizeInBlocks_(level,:),'all')
                error(message('images:blockedImage:exceedsSizeInBlock'));
            end
            
            pixelStartSub = (blockSub-1).*obj.BlockSize_(level,:) + 1;
            pixelEndSub = pixelStartSub + obj.BlockSize_(level,:) - 1;
            % Clamp the end to account for potential partial blocks
            pixelEndSub = min(pixelEndSub, obj.Size(level,:));
        end
    end
    
    %% Property methods
    methods
        function m = get.Mode(obj)
            m = obj.Mode_;
        end
        
        function set.Mode(obj, m)
            arguments
                obj(1,1) blockedImage
                m (1,1) char
            end
            
            m = validatestring(m, {'r','w'});
            if m~='r'
                error(message('images:blockedImage:onlyRModeAllowed'))
            end
            
            if obj.Mode_ == 'w' && m=='r'
                obj.reopenInReadMode();
            end
            
            obj.Mode_ = m;
        end
        
        function sb = get.SizeInBlocks(obj)
            sb = obj.SizeInBlocks_;
        end
        
        function bs = get.BlockSize(obj)
            bs = obj.BlockSize_;
        end
        function set.BlockSize(obj, bs)
            arguments
                obj (1,1) blockedImage
                bs (:,:) double {mustBeInteger mustMatchSize(obj, bs, "BlockSize")}
            end
            
            if obj.Mode_~='r'
                error(message('images:blockedImage:cantSetBlockSizeInWriteMode'))
            end
            
            if isempty(obj.Adapter)
                % blockedImage().. nop.
                return
            end
            
            if size(bs,1)==1
                bs = repmat(bs,[obj.NumLevels, 1]);
            end
            if size(bs,2)<obj.NumDimensions
                bs(:, end+1:obj.NumDimensions) = obj.Size(:, size(bs,2)+1:end);
            end
            
            obj.BlockSize_ = bs;
            
            % Update SizeInBlocks prop
            obj.SizeInBlocks_ = ceil(obj.Size./obj.BlockSize_);
            
            % Compute the IO blocks needed per level
            numIOBlocksInOneBlock = ceil(obj.BlockSize_./obj.IOBlockSize);
            % Cache at least 4 (see tech note)
            numIOBlocksInOneBlock = max(4, max(prod(numIOBlocksInOneBlock,2)));
            
            % Reset cache and update size
            obj.BlockCache.reset();
            obj.BlockCache.CacheSize = numIOBlocksInOneBlock;
        end
        
        function set.InitialValue(obj, uv)
            obj.InitialValue_ = uv; 
            obj.BlocksFullOfInitialValue = {};
        end
        function uv = get.InitialValue(obj)
            uv = obj.InitialValue_;
        end
        
        function set.WorldStart(obj, ws)
            arguments
                obj (1,1) blockedImage
                ws (:,:) double {mustMatchSize(obj, ws, "WorldStart")}
            end
            
            if isempty(obj.Adapter)
                % blockedImage().. nop.
                return
            end
            
            validateAgainstEnd = true;
            obj.setWorldStart(ws, validateAgainstEnd);
            obj.computePixelWorldExtents();
        end
        function ws = get.WorldStart(obj)
            ws = obj.WorldStart_;
        end
        
        function set.WorldEnd(obj, we)
            arguments
                obj (1,1) blockedImage
                we (:,:) double {mustMatchSize(obj, we, "WorldEnd")}
            end
            
            if isempty(obj.Adapter)
                % blockedImage().. nop.
                return
            end
            
            if size(we,1)==1
                % repmat for levels
                we = repmat(we,[obj.NumLevels, 1]);
            end
            
            if size(we,2)<obj.NumDimensions
                % Expand for dimensions
                we(:, end+1:obj.NumDimensions) = ...
                    obj.Size(:, size(we,2)+1:obj.NumDimensions)+0.5;
            end
            
            if any(obj.WorldStart_>we,'all')
                error(message('images:blockedImage:endMustBeGreaterThanStart'))
            end
            
            obj.WorldEnd_ = we;
            obj.computePixelWorldExtents();
        end
        function we = get.WorldEnd(obj)
            we = obj.WorldEnd_;
        end
        
        function set.AlternateFileSystemRoots(obj, afs)
            obj.AlternateFileSystemRoots_ = afs;
        end
        function afs = get.AlternateFileSystemRoots(obj)
            afs = obj.AlternateFileSystemRoots_;
        end
    end
    
    methods (Access = protected)
        % Custom display
        function groups = getPropertyGroups(obj)
            groups = [matlab.mixin.util.PropertyGroup(),...
                matlab.mixin.util.PropertyGroup()];
            groups(1).Title = getString(message('images:blockedImage:readOnlyProps'));
            groups(2).Title = getString(message('images:blockedImage:settableProps'));
            
            if isscalar(obj)
                if iscell(obj.Source)
                    sourceStr = formattedDisplayText(obj.Source,...
                        "LineSpacing", "compact", "SuppressMarkup", true);
                else
                    sourceStr = obj.Source;
                end

                groups(1).PropertyList = struct(...
                    'Source', sourceStr,...
                    'Adapter', obj.Adapter,...
                    'Size', obj.Size,...
                    'SizeInBlocks', obj.SizeInBlocks,...
                    'ClassUnderlying', obj.ClassUnderlying);
                
                rwStruct = struct();
                if obj.Mode == 'r'
                    rwStruct.BlockSize = obj.BlockSize_;
                else
                    groups(1).PropertyList.BlockSize = obj.BlockSize_;
                end
                
                if ~isempty(obj.ClassUnderlying) ...
                        && (obj.ClassUnderlying(1)=="struct" ||obj.ClassUnderlying(1)=="categorical")
                    % InitialValue is more useful for these two types
                    rwStruct.InitialValue = obj.InitialValue;
                end
                
                if ~isequal(obj.UserData, struct())
                    rwStruct.UserData = obj.UserData;
                end
                
                % Custom coordinates?
                inDefaultCoordinate = ~isempty(obj.Size) &&...
                    all(obj.WorldStart_==0.5,'all') && ...
                    all(obj.Size(1,:)+0.5 == obj.WorldEnd_,'all');
                if ~inDefaultCoordinate
                    rwStruct.WorldStart = obj.WorldStart_;
                    rwStruct.WorldEnd = obj.WorldEnd_;
                end
                groups(2).PropertyList = rwStruct;
            elseif numel(obj)>1 % vector
                % Vector of blockedImages
                variousString = getString(message('images:blockedImage:various'));
                dispStruct.Source = variousString;
                dispStruct.Adapter = variousString;
                dispStruct.ClassUnderlying = variousString;
                
                try
                    % To check if all elements have the same class or
                    % adapter.
                    allSameAdapters = arrayfun(@(bim)isa(bim.Adapter, class(obj(1).Adapter)), obj);
                    if all(allSameAdapters,'all')
                        dispStruct.Adapter = obj(1).Adapter;
                    end
                    allSameClass = arrayfun(@(bim)bim.ClassUnderlying(1)==obj(1).ClassUnderlying(1), obj);
                    if all(allSameClass,'all')
                        dispStruct.ClassUnderlying = obj(1).ClassUnderlying;
                    end
                catch ALL %#ok<NASGU>
                    % This could fail if any array element is empty.
                    % In which case, leave it as 'various'
                end
                
                groups(1).PropertyList = dispStruct;
            end
        end
        
        % Custom copy
        function cpObj = copyElement(obj)
            obj.mustBeInReadMode();
            
            % Make a shallow copy of all properties
            cpObj = copyElement@matlab.mixin.Copyable(obj);
            
            % Create a new instance of the adapter in read mode.
            cpObj.Adapter = copy(cpObj.OriginalAdapter);
            cpObj.Adapter.openToRead(cpObj.Source);
            % Call this to ensure adapters updates internal state if
            % required.
            cpObj.Adapter.getInfo();
        end
    end
    
    %% API helpers for supporting functions
    methods (Hidden)
        
        function mobj = makeMultiLevelN(obj, resizer, params)
            inputLevel = 1;
            bim = copy(obj);
            bim.BlockSize = params.BlockSize;

            isOutputInMemory = isa(params.Adapter, "images.blocked.InMemory");
            if isOutputInMemory
                params.OutputLocation = [];
            end

            if ~isfield(params, 'OutputLocation') && ~isOutputInMemory
                % Attempt to find parent folder
                if isstring(bim.Source) && (isfile(bim.Source) || isfolder(bim.Source))
                    % Default is "<source name>_multiLevel"
                    [params.OutputLocation, sourceName] = fileparts(bim.Source);
                    if ~isfolder(params.OutputLocation)
                        error(message('images:blockedImage:couldNotSetOutputLocation'));
                    end
                    params.OutputLocation = string(params.OutputLocation) ...
                        + filesep ...
                        + string(sourceName)+"_multiLevel";
                    if isprop(params.Adapter, 'Extension')
                        params.OutputLocation = params.OutputLocation +"."+ params.Adapter.Extension;
                    end
                else
                    error(message('images:blockedImage:couldNotSetOutputLocation'));
                end
            end

            % Inspect the adapter capability
            acap = blockedImage.introspectAdapter(params.Adapter);
            if params.UseParallel && ~acap.parallelWriteSupported
                params.UseParallel = false;
                warning(message('images:blockedImage:switchingToSerial'))
            end

            if ~(isnumeric(obj.InitialValue) || islogical(obj.InitialValue) || iscategorical(obj.InitialValue))
                error(message('images:blockedImage:unsupportedClassForResize'))
            end

            % Sort the scale from highest to lowest. Rescales are 'feed
            % forward'
            params.Scales = sort(params.Scales,'descend');
            numOutLevels = numel(params.Scales);

            lastBlockSub = bim.SizeInBlocks_(inputLevel,:);

            % Setup waitbar
            wparams.DisplayWaitbar = params.DisplayWaitbar;
            wparams.BatchSize = 1;
            wparams.Cancellable = false;
            if isfield(params, 'Parent')
                wparams.Parent = params.Parent;
            end
            cleanUpFcn = onCleanup(@()bim.deleteWaitBar());
            titleText = getString(message('images:blockedImage:resizeTitle'));
            [bim.WaitBarVars, updateWaitBarFcn] = ...
                bim.initializeWaitBarVars(wparams, prod(lastBlockSub), titleText);

            % Process 1-st block
            firstBlockSub = ones([1, bim.NumDimensions]);
            blockFirst = bim.getBlock(firstBlockSub, "Level",inputLevel);
            scaledBlocksFirst = scaleBlocks(blockFirst, resizer, params.Scales);
            fullOutputBlockSizes = cellfun(@(x)size(x, 1:bim.NumDimensions), scaledBlocksFirst,'UniformOutput',false);
            fullOutputBlockSizes = vertcat(fullOutputBlockSizes{:});
            updateWaitBarFcn();

            % Process last block, if one exists. This is required to deduce
            % the final full output size for each level. This last block
            % captures how potentially partial blocks are handled along the
            % edge.
            hasLastBlock = ~all(lastBlockSub==1);
            if hasLastBlock % i.e there are more than one blocks                
                blockLast = bim.getBlock(lastBlockSub, "Level",inputLevel);
                scaledBlocksEnd = scaleBlocks(blockLast, resizer, params.Scales);

                numFullBlocks = lastBlockSub-1;
                lastBlockSize = cellfun(@(x)size(x, 1:bim.NumDimensions), scaledBlocksEnd,'UniformOutput',false);
                lastBlockSize = vertcat(lastBlockSize{:});

                outputImageSizes = fullOutputBlockSizes.*numFullBlocks+lastBlockSize;
                updateWaitBarFcn();
            else
                outputImageSizes = fullOutputBlockSizes;
            end

            % Create output
            mobj = blockedImage(params.OutputLocation,...
                outputImageSizes, fullOutputBlockSizes, bim.InitialValue,...
                'Adapter', params.Adapter,...
                'Mode', 'w',...
                'WorldStart', bim.WorldStart_(inputLevel,:),...
                'WorldEnd',  bim.WorldEnd_(inputLevel,:),...
                "UserData", bim.UserData,...
                'AlternateFileSystemRoots', bim.AlternateFileSystemRoots);

            % Write already processed blocks
            for ind = 1:numOutLevels
                mobj.setBlock(firstBlockSub, scaledBlocksFirst{ind}, "Level",ind);
            end

            if hasLastBlock
                % Write processed last (partial) blocks
                for ind = 1:numOutLevels
                    mobj.setBlock(lastBlockSub, scaledBlocksEnd{ind}, "Level",ind);
                end

                % Create the datastore for the input to help iterate over
                % rest of the blocks.
                bls = selectBlockLocations(bim,"Levels",inputLevel, ...
                    "BlockSize",bim.BlockSize_(inputLevel,:));
                bimds = blockedImageDatastore(bim,"BlockLocationSet",bls);

                % Remove first and last, since they are already processsed.
                bimds = subset(bimds,2:bimds.TotalNumBlocks-1);

                if params.UseParallel
                    progressDataQueue = parallel.pool.DataQueue;
                    afterEach(progressDataQueue, @(~)updateWaitBarFcn());
                    numParts = numpartitions(bimds, gcp);
                    scales = params.Scales;
                    parfor parInd = 1:numParts
                        wbimds = partition(bimds, numParts, parInd);
                        while hasdata(wbimds)
                            [block, info] = read(wbimds);
                            scaledBlocks = scaleBlocks(block{1}, resizer, scales);
                            for ind = 1:numOutLevels
                                mobj.setBlock(info.BlockSub, ...
                                    scaledBlocks{ind}, "Level", ind); %#ok<PFBNS>
                            end
                            send(progressDataQueue,1); 
                        end
                    end

                else                    
                    while hasdata(bimds)
                        [block, info] = read(bimds);
                        scaledBlocks = scaleBlocks(block{1}, resizer, params.Scales);
                        for ind = 1:numOutLevels
                            mobj.setBlock(info.BlockSub,...
                                scaledBlocks{ind}, "Level", ind);
                        end
                        updateWaitBarFcn();
                    end
                end
            
            end


            % Flip to read mode before returning
            mobj.Mode = 'r';
            % Set the blocksize explicitly, so the same value is set for
            % all levels
            mobj.BlockSize = params.BlockSize;
        end

        function imgRegion = getRegionInternal(obj, pixelStartSub, pixelEndSub, level, blockCache)
            if isempty(obj.IsGetRegionSupported)
                % Flag which indicates if the current adapter supports
                % getRegion API (which is more efficient than getBlock)
                acap = blockedImage.introspectAdapter(obj.OriginalAdapter);
                obj.IsGetRegionSupported = acap.getRegionSupported;
            end

            if obj.IsGetRegionSupported && ~obj.IsCropped
                ioLevel = obj.Level2IOLevelLUT(level);
                imgRegion = obj.Adapter.getRegion(pixelStartSub, pixelEndSub, ioLevel);
            else
                imgRegion = obj.assembleIOBlocksToFormRegion(pixelStartSub, pixelEndSub, level, blockCache);
            end
        end
    
        function img = getRegionPadded(obj, pixelStartSub, pixelEndSub, level, padMethod, blockCache)
            % Calls getRegion, then pads as required.
            
            % For use in blockedImageDatastore.
            % And for fetching extra blocks in apply()
            arguments
                obj (1,1) blockedImage
                pixelStartSub (1,:) 
                pixelEndSub (1,:) 
                level (1,1) 
                padMethod 
                blockCache 
            end
            imageSize = obj.Size(level, :);
            
            % Optimizing in-bounds reads
            noPaddingRequired = all(pixelStartSub>=1) && all(pixelEndSub<=imageSize);
            
            if noPaddingRequired || isequal(padMethod, "none")
                img = obj.getRegionInternal(pixelStartSub, pixelEndSub,...
                    level, blockCache);
                
            else % replicate or numeric value
                clampedStart = min(max(pixelStartSub,1),imageSize);
                clampedEnd = min(max(pixelEndSub,1), imageSize);
                
                % Note -handle the case when region is fully outside the
                % image.
                prePad = max(0, clampedStart - pixelStartSub + min(0, pixelEndSub-1));
                pstPad = max(0,pixelEndSub - clampedEnd - max(0,pixelStartSub-imageSize));
                
                
                % region is entirely out of bounds for constant padding
                if ~(isequal(padMethod, 'replicate')||isequal(padMethod, 'symmetric')) && ...
                        (any(pixelEndSub<1) || any(pixelStartSub>imageSize))
                    img = repmat(padMethod, (clampedEnd-clampedStart)+1);
                else
                    img = obj.getRegionInternal(clampedStart, clampedEnd, ...
                        level, blockCache);
                end
                
                if any(prePad)
                    img = blockedImage.padarrayWraper(img, prePad, padMethod, 'pre');
                end
                if any(pstPad)
                    img = blockedImage.padarrayWraper(img, pstPad, padMethod, 'post');
                end
            end
            
        end
        
        function serializeUserData(obj)
            %serializeUserData - attempt to write UserData to Source
            % For use with volume segmenter app.
            if ~isa(obj.Adapter,'images.blocked.InMemory')
                desc = images.blocked.internal.loadDescription(obj.Source);
                desc.Info.UserData = obj.UserData;
                images.blocked.internal.saveDescription(obj.Source, desc);
            end
        end
    end
    
    %% Constructor helpers
    methods (Access = private)
        
        function writeModeConstructor(obj, destination, blockSize, imageSize, initialValue, params)
            if isempty(blockSize) || isempty(imageSize) || isempty(initialValue)
                error(message('images:blockedImage:writeConstructorIncomplete'));
            end
            
            % Only these 'types' are currently supported
            validateattributes(initialValue, {'struct', 'numeric', 'logical','categorical'},...
                {'scalar'}, mfilename, 'InitialValue');
            
            % Adapter
            if isfield(params, 'Adapter')
                % Copy for use
                obj.Adapter = copy(params.Adapter);
            else
                obj.Adapter = pickWriteAdapter(destination, initialValue);
            end
            % Keep the original copy for use later
            obj.OriginalAdapter = copy(obj.Adapter);
            
            if isa(obj.Adapter, 'images.blocked.InMemory') && ~isempty(destination)
                error(message('images:blockedImage:destinationMustBeEmpty'))
            end
            if isempty(destination) && ~isa(obj.Adapter, 'images.blocked.InMemory')
                error(message('images:blockedImage:adapterMustBeInMemory'))
            end
            
            if params.Mode == "w"
                mustNotExist(destination);
            else
                % Append or create mode. If destination exists, check its
                % contents are consistent with this write attempt.
                params.Adapter = obj.Adapter;
                validateAppendFor(destination, blockSize, imageSize, initialValue, params);
            end
            
            % Extend blockSize to multi levels if needed
            if ~isequal(size(blockSize), size(imageSize))
                blockSize = repmat(blockSize, [size(imageSize,1),1]);
            end
            
            % Prepare the info struct
            info.UserData = obj.UserData;
            info.Size = imageSize;
            info.IOBlockSize = blockSize;
            info.Datatype = repmat(string(class(initialValue)),[1, size(imageSize,1)]);
            info.InitialValue = initialValue;
            if isfield(params, 'WorldStart')
                info.WorldStart = params.WorldStart;
            else
                info.WorldStart = repmat(0.5, size(imageSize));
            end
            if isfield(params, 'WorldEnd')
                info.WorldEnd = params.WorldEnd;
            else
                % Default world end is the same for all levels (same as
                % finest)
                we = double(imageSize)+0.5;
                info.WorldEnd = repmat(we, [size(imageSize,1),1]);
            end
            
            firstLevel = 1;
            obj.Adapter.openToWrite(destination, info, firstLevel);
            obj.CurrentWriteLevel = firstLevel;
            obj.initializeProps(destination, info, true);
            
            % Had to be set after rest of the props are initialized (to
            % ensure .Size is set to compute sizeinblocks)
            obj.BlockSize = info.IOBlockSize;
        end
        
        function readModeConstructor(obj, source, params)
            source = resolveToAbsolute(source);
            % Adapter
            if isfield(params, 'Adapter')
                % Copy for use
                obj.Adapter = copy(params.Adapter);
            else
                obj.Adapter = pickReadAdapter(source);
            end
            % Keep the original copy for use later
            obj.OriginalAdapter = copy(obj.Adapter);
            
            
            obj.Adapter.openToRead(source);
            info = obj.Adapter.getInfo();
            validateAdapterOpenOutputs(info, obj.Adapter);
            obj.initializeProps(source, info, true);
            
            % BlockSize
            if isfield(params, 'BlockSize')
                if size(params.BlockSize, 1) == 1
                    params.BlockSize = repmat(params.BlockSize, [obj.NumLevels, 1]);
                else
                    mustMatchSize(obj, params.BlockSize, 'BlockSize')
                end
                
                % Extend the blocksize with size from first level
                % if needed. Make sure to do this independently for
                % each image.
                ndim = obj.NumDimensions;
                bs = params.BlockSize;
                bs(:,size(params.BlockSize,2)+1:ndim) = obj.Size(1, size(params.BlockSize,2)+1:ndim);
                % By-pass validation
                obj.BlockSize_ = bs;
            else                
                % By-pass validation
                obj.BlockSize_ = pickOptimalBlockSize(...
                    obj.IOBlockSize, obj.Size);
            end
            
            % Compute the mapping from blockedImage's level to the Adapters
            % levels, this enables blockedImage's levels to always go
            % from 1 (finest) to N (coarsest) monotonically
            % irrespective of actual level order in the source.
            numPixels = prod(obj.Size,2);
            [~, obj.Level2IOLevelLUT] = sort(numPixels,'descend');
            
            % Reorder based on sorted Levels. Do size first since blocksize
            % depends on Size being set first.
            obj.Size = obj.Size(obj.Level2IOLevelLUT,:);
            % This time, use the set method (needed to compute sizeInBlocks
            % and to set the cache to the right size)
            obj.BlockSize = obj.BlockSize_(obj.Level2IOLevelLUT,:);
            obj.IOBlockSize = obj.IOBlockSize(obj.Level2IOLevelLUT,:);
            % Sorty the data types accordingly
            obj.ClassUnderlying = obj.ClassUnderlying(obj.Level2IOLevelLUT);
        end
        
        function reopenInReadMode(obj)
            %reopenInReadMode reopen image in read mode
            %  REOPENINREADMODE(WBIM) reopens a blockedImage in read mode.
            %  This method should be used to convert a writable
            %  blockedImage to a readable blockedImage before data can be
            %  read from that instance.
            
            % Do this first in case adapter needs to pad out partial data
            % (e.g in Matrix adapter)
            obj.Adapter.close();
            
            if isa(obj.Adapter,'images.blocked.InMemory')
                source = obj.Adapter.Data;
            else
                source = obj.Source;
            end
            
            obj.Adapter = copy(obj.OriginalAdapter);
            obj.Adapter.openToRead(source);
            info = obj.Adapter.getInfo();
            
            % Retain potentially user set props which were made after the
            % construction (so did not make it to the data via the adapter)
            initAll = false;
            obj.initializeProps(source, info, initAll);                        
            
            obj.Mode_ = 'r';
            
            % Trim trailing dimensions off of blockSize in case apply
            % output caused a dimension reduction. (This is a guess, user
            % can always update these props).
            obj.BlockSize = obj.BlockSize(:, 1:size(info.Size,2));
            obj.WorldStart_ = obj.WorldStart(:, 1:size(info.Size,2));
            obj.WorldEnd_ = obj.WorldEnd(:, 1:size(info.Size,2));
            obj.computePixelWorldExtents();
        end
        
        function initializeProps(obj, source, infoFromAdapter, initAll)
            obj.Source = source;
            
            % properties from info
            obj.Size = infoFromAdapter.Size;
            obj.IOBlockSize = infoFromAdapter.IOBlockSize;
            obj.ClassUnderlying = infoFromAdapter.Datatype;
            
            % properties derived from info
            obj.NumLevels = size(obj.Size,1);
            obj.NumDimensions = size(obj.Size, 2);
            
            if initAll
                % Pick optional data from adapter only when initializing
                % all props. (Skip this part when reserializing in PCT mode
                % or reopening after write mode since user may have
                % overwritten these props)
                if isfield(infoFromAdapter, 'UserData') && ~isempty(infoFromAdapter.UserData)
                    obj.UserData = infoFromAdapter.UserData;
                end
                if isfield(infoFromAdapter, 'WorldStart')
                    obj.WorldStart_ = infoFromAdapter.WorldStart;
                    if size(obj.WorldStart_,1)~=obj.NumLevels
                        % Replicate for all levels
                        obj.WorldStart_ = repmat(obj.WorldStart_(1,:), [obj.NumLevels,1]);
                    end
                else
                    obj.WorldStart_ = 0.5*ones(obj.NumLevels, obj.NumDimensions);
                end
                if isfield(infoFromAdapter, 'WorldEnd')
                    obj.WorldEnd_ = infoFromAdapter.WorldEnd;
                    if size(obj.WorldEnd_,1)~=obj.NumLevels
                        % Replicate for all levels
                        obj.WorldEnd_ = repmat(obj.WorldEnd_(1,:), [obj.NumLevels,1]);
                    end

                else
                    % Set the WorldEnd of all levels to match the finest
                    % level be default.
                    obj.WorldEnd_ = repmat(obj.Size(1,:)+0.5, [obj.NumLevels, 1]);
                end
            end
            
            % Bypass setter, since even for InMemory, we want to set this
            % initially.
            obj.InitialValue_ = infoFromAdapter.InitialValue;
            
            % Default (will get overwritten later if in read mode)
            obj.Level2IOLevelLUT = 1:obj.NumLevels;
        end
    end
    
    %% Waitbar helpers
    methods (Access = private)
        function [waitBarVars, updateWaitBarFcn] = initializeWaitBarVars(obj, params, totalNumBlocks, wbTitle)
            waitBarVars.Aborted = false;
            if params.DisplayWaitbar
                waitBarVars.waitBar = []; % handle to the hg waitbar object
                waitBarVars.Aborted = false;
                waitBarVars.NumCompleted = 0;
                waitBarVars.Total = totalNumBlocks;
                % Update wait bar for first few blocks and then per percentage increment
                waitBarVars.updateIncrements = unique([1:20 round((0.01:0.01:1) .*(waitBarVars.Total+1))]);
                waitBarVars.updateCounter = 1;
                waitBarVars.startTic = tic;
                waitBarVars.BatchSize = params.BatchSize;
                waitBarVars.Parent = [];
                waitBarVars.Cancellable = params.Cancellable;
                waitBarVars.Title = wbTitle;
                waitBarVars.ThresholdTime = 15; %estimated remaining seconds before showing up waitbar
                
                if isfield(params,'Parent')
                    waitBarVars.Parent = params.Parent;
                end
                
                % Callback for when each blocked is done processing
                updateWaitBarFcn = @()obj.updateWaitbar();
            else
                updateWaitBarFcn = [];
            end
        end
        
        function updateWaitbar(obj)
            % Gets called after each blocked is processed, updates a waitbar
            % at a slower rate
            
            
            if ~isempty(obj.WaitBarVars.waitBar) && obj.WaitBarVars.waitBar.isCancelled()
                % User clicked on 'Cancel'
                obj.WaitBarVars.Aborted = true;
                if ~isempty(obj.Futures)
                    % UseParallel == true mode.
                    delete(obj.ProgressDataQueue);
                    cancel(obj.Futures);
                end
                return
            end
            
            % Increment the cached count of completed blocks
            obj.WaitBarVars.NumCompleted = obj.WaitBarVars.NumCompleted + obj.WaitBarVars.BatchSize;
            % Last batch may not be 'full'
            obj.WaitBarVars.NumCompleted = min(obj.WaitBarVars.NumCompleted, obj.WaitBarVars.Total);
            
            % Updates are expensive, do so intermittently
            if obj.WaitBarVars.NumCompleted >= obj.WaitBarVars.updateIncrements(obj.WaitBarVars.updateCounter)
                obj.WaitBarVars.updateCounter = obj.WaitBarVars.updateCounter + 1;
                
                if isempty(obj.WaitBarVars.waitBar)
                    % Wait bar not yet shown
                    elapsedTime = toc(obj.WaitBarVars.startTic);
                    % Decide if we need a wait bar or not,
                    remainingTime = elapsedTime / obj.WaitBarVars.NumCompleted * (obj.WaitBarVars.Total - obj.WaitBarVars.NumCompleted);
                    if remainingTime > obj.WaitBarVars.ThresholdTime % seconds
                        obj.createWaitbar();
                    end
                else
                    % Show progress on existing wait bar
                    obj.WaitBarVars.waitBar.update(obj.WaitBarVars.NumCompleted);
                    drawnow;
                end
            end
        end
        
        function createWaitbar(obj)
            if images.internal.isFigureAvailable()
                if isempty(obj.WaitBarVars.Parent)
                    obj.WaitBarVars.waitBar = iptui.cancellableWaitbar(getString(message('images:bigimage:waitbarTitleGUI')),...
                        obj.WaitBarVars.Title,obj.WaitBarVars.Total,obj.WaitBarVars.NumCompleted,...
                        'Cancellable', obj.WaitBarVars.Cancellable);
                else
                    obj.WaitBarVars.waitBar = iptui.cancellableWaitbar(getString(message('images:bigimage:waitbarTitleGUI')),...
                        obj.WaitBarVars.Title,obj.WaitBarVars.Total,obj.WaitBarVars.NumCompleted,...
                        'Cancellable', obj.WaitBarVars.Cancellable, 'Parent', obj.WaitBarVars.Parent);
                end
            else
                obj.WaitBarVars.waitBar = iptui.textWaitUpdater(obj.WaitBarVars.Title,...
                    getString(message('images:bigimage:waitbarCompletedTxt')),obj.WaitBarVars.Total,obj.WaitBarVars.NumCompleted);
            end
        end
        
        function deleteWaitBar(obj)            
            if isfield(obj.WaitBarVars, 'waitBar') && ~isempty(obj.WaitBarVars.waitBar)
                % Delete wait bar if one was created
                destroy(obj.WaitBarVars.waitBar)
            end
        end
    end
    
    %% Helpers
    methods (Access = private)
        function blocked = getBlockOfInitialValues(obj, level)
            if numel(obj.BlocksFullOfInitialValue)<level || isempty(obj.BlocksFullOfInitialValue{level})
                if isnumeric(obj.InitialValue_)||islogical(obj.InitialValue_)
                    unloadedValue = cast(obj.InitialValue_, obj.ClassUnderlying(level));
                else
                    unloadedValue = obj.InitialValue_;
                end
                obj.BlocksFullOfInitialValue{level} = repmat(unloadedValue, obj.BlockSize_(level,:));
            end
            blocked = obj.BlocksFullOfInitialValue{level};
        end
        
        function mustBeInReadMode(obj)
            if obj.Mode_~='r'
                error(message('images:blockedImage:notInReadMode'))
            end
        end
        
        function setWorldStart(obj, ws, validateAgainstEnd)
            if size(ws,1)==1
                % repmat for levels
                ws = repmat(ws,[obj.NumLevels, 1]);
            end
            
            if size(ws,2)<obj.NumDimensions
                % Expand for dimensions
                ws(:, end+1:obj.NumDimensions) = 0.5;
            end
            
            % Only validate if prop is being set (we skip this in the
            % constructor to prevent validating both start and end against
            % the existing values)
            if validateAgainstEnd && any(ws>obj.WorldEnd_,'all')
                error(message('images:blockedImage:endMustBeGreaterThanStart'))
            end
            
            obj.WorldStart_ = ws;
        end
        
        function imgRegion = assembleIOBlocksToFormRegion(obj, pixelStartSub, pixelEndSub, level, blockCache)
            if obj.IsCropped
                pixelStartSub = pixelStartSub + obj.CroppedOffsetSub(level,:);
                pixelEndSub = pixelEndSub + obj.CroppedOffsetSub(level,:);
            end            
            
            % Note: obj.Levels are sorted based on pixel count, use the LUT
            % to map to the underlying data source's level.
            ioLevel = obj.Level2IOLevelLUT(level);
            
            % Note: IOBlockSize of blockedImage is sorted
            ioBlockSize = obj.IOBlockSize(level,:);
            
            % IO Block subscripts for blocks which contain the starting and
            % end pixel locations.
            ioBlockStartSub = floor((pixelStartSub-1)./ioBlockSize) + 1;
            ioBlockEndSub = floor((pixelEndSub-1)./ioBlockSize) + 1;
            
            % Total number of full IO blocks required
            numFullIOBlocks = prod(ioBlockEndSub - ioBlockStartSub + 1);
            
            % Read all the required IO blocks into a cell array
            dataIOBlocks = cell(1,numFullIOBlocks);
            
            numDims = obj.NumDimensions;
            
            curIOBlockSub = ioBlockStartSub;
            ioBlockSubStarts = cell(1,numFullIOBlocks);
            for blockedInd = 1:numFullIOBlocks
                
                if isempty(blockCache)
                    % Use this instance's cache
                    block = obj.BlockCache.getIOBlockViaCache(obj.Adapter, ioLevel, curIOBlockSub);
                else
                    % Use the cache given
                    block = blockCache.getIOBlockViaCache(obj.Adapter, ioLevel, curIOBlockSub);
                end
                
                % Ensure block is smaller than IO block size
                if ~all(size(block)<=ioBlockSize(1:ndims(block)))
                    %Note: partial blocks can be smaller.
                    error(message('images:blockedImage:invalidGetIOBlockSize', ...
                        class(obj.Adapter), num2str(ioLevel), num2str(curIOBlockSub)));
                end
                
                if isempty(block)
                    % Replace with Initial values (fill value)
                    dataIOBlocks{blockedInd} = obj.getBlockOfInitialValues(level);
                else
                    dataIOBlocks{blockedInd} = block;
                end
                
                % Cache for later use
                ioBlockSubStarts{blockedInd} = curIOBlockSub;
                
                % Increment the blocked subscripts to point to next IO block
                for dInd=1:numDims
                    if curIOBlockSub(dInd)+1 <= ioBlockEndSub(dInd)
                        curIOBlockSub(dInd) = curIOBlockSub(dInd) + 1;
                        break;
                    else
                        % Reset the rest
                        curIOBlockSub(dInd) = ioBlockStartSub(dInd);
                    end
                end
            end
            
            % Initialize output
            if isnumeric(dataIOBlocks{1}) || islogical(dataIOBlocks{1})
                imgRegion = zeros(pixelEndSub - pixelStartSub + 1, obj.ClassUnderlying(level));
            else
                % Essentially do img(end,end..) = scalar to initialize
                % img (usually faster than repmat)
                lastSub = pixelEndSub - pixelStartSub + 1;
                indStruct.type = '()';
                indStruct.subs = cell(1,numel(lastSub));
                for dInd = 1:numel(lastSub)
                    indStruct.subs{dInd} = lastSub(dInd);
                end
                imgRegion = dataIOBlocks{1}(1);
                imgRegion = subsasgn(imgRegion, indStruct, dataIOBlocks{1}(1));
            end
            
            %--------------Assembling a block from ioblocks----------------
            for blockedInd = 1:numFullIOBlocks
                oneIOBlockData = dataIOBlocks{blockedInd};
                ioBlockSubStart = ioBlockSubStarts{blockedInd};
                
                blockSize = size(oneIOBlockData, 1:numDims);
                
                ioBlockStartInPixelSubs = (ioBlockSubStart-1).*ioBlockSize + 1;
                % Note - block can be partial on edges
                ioBlockEndInPixelSubs = ioBlockStartInPixelSubs + blockSize - 1;
                
                % Clip top left if required, compute the start offset in
                % this block in local blocked subscripts.
                topLeftDiff = pixelStartSub - ioBlockStartInPixelSubs;
                srcRegionStart = ones(1,numDims) + max(topLeftDiff,0);
                
                % Compute destination offset in img where this needs to be
                % copied _to_.
                dstRegionStart = ones(1,numDims) + max(-topLeftDiff,0);
                
                % Size of the chunk of pixels to be copied over.
                % Note: pixelEndSub is clamped to imageSize.
                botRightDiff = ioBlockEndInPixelSubs - pixelEndSub;
                srcEndInIOBlock = blockSize - max(botRightDiff, 0);
                % numPixel - 1
                numPixelsM1 = srcEndInIOBlock - srcRegionStart;
                                
                if numDims == 2
                    imgRegion(...
                        dstRegionStart(1):(dstRegionStart(1)+numPixelsM1(1)),...
                        dstRegionStart(2):(dstRegionStart(2)+numPixelsM1(2))) = ...
                        oneIOBlockData(...
                        srcRegionStart(1):(srcRegionStart(1)+numPixelsM1(1)),...
                        srcRegionStart(2):(srcRegionStart(2)+numPixelsM1(2)));
                elseif numDims == 3
                    imgRegion(...
                        dstRegionStart(1):(dstRegionStart(1)+numPixelsM1(1)),...
                        dstRegionStart(2):(dstRegionStart(2)+numPixelsM1(2)),...
                        dstRegionStart(3):(dstRegionStart(3)+numPixelsM1(3))) = ...
                        oneIOBlockData(...
                        srcRegionStart(1):(srcRegionStart(1)+numPixelsM1(1)),...
                        srcRegionStart(2):(srcRegionStart(2)+numPixelsM1(2)),...
                        srcRegionStart(3):(srcRegionStart(3)+numPixelsM1(3)));
                else
                    dstInd = cell(1,numDims);
                    srcInd = cell(1,numDims);
                    
                    for dInd = 1:numDims
                        dstInd{dInd} = ...
                            dstRegionStart(dInd):(dstRegionStart(dInd)+numPixelsM1(dInd));
                        srcInd{dInd} = ...
                            srcRegionStart(dInd):(srcRegionStart(dInd)+numPixelsM1(dInd));
                    end
                    imgRegion(dstInd{:}) = oneIOBlockData(srcInd{:});
                end
            end
            %--------------------------------------------------------------
        end
        
        function computePixelWorldExtents(obj)
            % Recompute PixelWorldExtents each time WorldStart/End changes
            
            % Note: WorldStart and End mark pixel _edges_
            imageWorldExtents = obj.WorldEnd_ - obj.WorldStart_;
            obj.PixelSizeInWorld = imageWorldExtents./obj.Size;                         
        end
    end
    
    %% Apply helpers
    methods (Access = private)
        function varargout = applyInSerialOverImages(obj, usrFcn, params)
            numImages = numel(obj);
            
            % First element holds the waitbar
            titleText = getString(message('images:blockedImage:processingImages'));

            wbParams = params;
            % While counting updates, discount batchsize since we are
            % looping over images and not blocks.
            wbParams.BatchSize = 1; 
            [obj(1).WaitBarVars, updateWaitBarFcn] = ...
                obj(1).initializeWaitBarVars(wbParams, numImages, titleText);
            if params.DisplayWaitbar
                % Show wait bar right away, since the first image might
                % take a long time to process
                obj(1).createWaitbar();
            end            
            % Disable the blockwise waitbar logic in applyCore, control
            % it externally here
            params.DisplayWaitbar = false;            
            
            % Initialize
            varargout = cell(1, nargout);
            oneCallOutputs = cell(1, nargout);
            
            for imageInd = 1:numImages
                params.Index = imageInd;
                [oneCallOutputs{:}] = obj(imageInd).applyCore(usrFcn, params);
                for oInd = 1:nargout
                    varargout{oInd}(imageInd) = oneCallOutputs{oInd};
                end
                updateWaitBarFcn();
                if obj(1).WaitBarVars.Aborted
                    break;
                end
            end
        end
        
        function varargout = applyInParallelOverImages(obj, usrFcn, params)    
            % Process images in parallel, blocks serially.
            numImages = numel(obj);            
            
            % First element holds the waitbar
            titleText = getString(message('images:blockedImage:processingImages'));

            wbParams = params;
            % While counting updates, discount batchsize since we are
            % looping over images and not blocks.
            wbParams.BatchSize = 1;            
            [obj(1).WaitBarVars, updateWaitBarFcn] = ...
                obj(1).initializeWaitBarVars(wbParams, numImages, titleText);            
            % Disable the blockwise waitbar
            params.DisplayWaitbar = false;
            
            % A data queue for the workers to signal completion of one
            % image, used to trigger an update to the waitbar
            obj(1).ProgressDataQueue = parallel.pool.DataQueue;
            afterEach(obj(1).ProgressDataQueue, @(~)updateWaitBarFcn());
                        
            % Spawn off parallel tasks
            obj(1).Futures = parallel.FevalFuture.empty();
            for idx = numImages:-1:1 % Reverse order to initialize Futures
                curImage = obj(idx);
                obj(1).Futures(idx) = parfeval(gcp, @curImage.applyOnEachImage, nargout, ...
                    nargout, idx, usrFcn, params, obj(1).ProgressDataQueue);
            end
                        
            argOuts = cell(1, numImages);
            % Fetch data and merge the output values.
            for idx = 1:numImages
                try
                    % To fetch completed results one by one
                    oneCallOutputs = cell(1, nargout);
                    [doneIdx, oneCallOutputs{:}] = fetchNext(obj(1).Futures);
                    argOuts{doneIdx} = oneCallOutputs;
                catch ERR
                    if ~isempty(ERR.cause) && strcmp(ERR.cause{1}.identifier, 'parallel:fevalqueue:ExecutionCancelled')
                        % Did the user cancel? if so, return
                        % partial results
                        break;
                    else
                        % Unexpected error, clean up and inform user
                        cancel(obj(1).Futures);
                        % Wait till all running ones are completed
                        % (else they may bring up a wait bar which wont
                        % get deleted)
                        wait(obj(1).Futures);
                        delete(obj(1).ProgressDataQueue);
                        rethrow(ERR)
                    end
                end
            end
            
            % Turn the cell array inside out, convert a cell array
            % where each element is a cellarray of outputs for one
            % image. Into a cell array of num outputs, each element
            % being an array of blocked images.
            varargout = cell(1, nargout);
            for oInd = 1:nargout
                for ind=numImages:-1:1
                    if ~isempty(argOuts{ind})
                        ithOutputArray(ind) = argOuts{ind}{oInd};
                    end
                end
                varargout{oInd} = ithOutputArray;
            end
        end
        
        function varargout = applyOnEachImage(obj, numOutputs, ind, usrFcn, params, progressDataQueue)
            varargout = cell(1,numOutputs);
            params.Index = ind;
            [varargout{:}] = obj.applyCore(usrFcn, params);
            send(progressDataQueue,1); % To update the wait bar
        end        
        
        function varargout = applyCore(obj, usrFcn, params)
            % Note: This is called on a scalar obj.            
            
            % BlockSize 
            if isfield(params,'BlockSize')
                if numel(params.BlockSize) > obj.NumDimensions
                    error(message('images:blockedImage:invalidNumCols', 'BlockSize'))
                end
                % Extend blocksize using image size if required
                params.BlockSize(numel(params.BlockSize)+1:obj.NumDimensions) = ...
                    obj.Size(params.Level, numel(params.BlockSize)+1: obj.NumDimensions);
            else
                params.BlockSize = obj.BlockSize_(params.Level,:);
            end
            
            %BlockLocationSet
            if isfield(params, 'BlockLocationSet')
                % Already ensured that BlockSize is NOT provided, so pick
                % from the BLS.
                params.BlockSize = params.BlockLocationSet.BlockSize;
                
                % Extract block origins for this image.
                thisImageInds = params.BlockLocationSet.ImageNumber == params.Index;
                if any(thisImageInds)
                    thisImageLevel = params.BlockLocationSet.Levels(params.Index);                    
                    blockOriginsForThisImage = params.BlockLocationSet.BlockOrigin(thisImageInds, :);
                    if size(blockOriginsForThisImage,2)~=obj.NumDimensions
                        error(message('images:blockedImage:invalidNumDims', "BlockLocationSet"))
                    end
                    % Validate block origins are within bounds
                    xySize = obj.Size(thisImageLevel,:);
                    xySize(1:2) = xySize(2:-1:1);
                    if any(blockOriginsForThisImage>xySize,'all')
                        error(message('images:blockedImage:outOfBoundBlocks'))
                    end
                    numBlocks = size(blockOriginsForThisImage,1);
                    % Create a new BLS for blocks just from this image.
                    params.BlockLocationSet = blockLocationSet(ones(numBlocks,1), blockOriginsForThisImage,...
                        params.BlockLocationSet.BlockSize, thisImageLevel);

                    if ~isequal(params.Level, params.BlockLocationSet.Levels)
                        error(message('images:blockedImage:LevelMismatch',...
                            num2str(params.BlockLocationSet.Levels), num2str(params.Level)))
                    end
                else
                    % No blocks from this image, nothing to process
                    varargout = repmat({blockedImage()}, [1 nargout]);
                    return;
                end
            else
                % Default bls covers the full image
                params.BlockLocationSet = selectBlockLocations(obj, ...
                    'Levels', params.Level,...
                    'BlockSize', params.BlockSize, ...
                    'ExcludeIncompleteBlocks', false);
            end
            
            % Validate BorderSize
            if isfield(params, 'BorderSize')
                if numel(params.BorderSize) > obj.NumDimensions
                    error(message('images:blockedImage:invalidNumCols', 'BorderSize'))
                end
                % 0 extend if needed
                params.BorderSize(numel(params.BorderSize)+1:obj.NumDimensions) = 0;
            else
                params.BorderSize = zeros(1, obj.NumDimensions);
            end
            
            if isempty(params.OutputLocation) && ...
                    ~isempty(params.Adapter) &&...
                    any(cellfun(@(a)~isa(a,'images.blocked.InMemory'), params.Adapter))
                % Empty OutputLocation, but not all adapters are 'InMemory'
                error(message('images:blockedImage:outputLocationRequired'))
            end                        
                        
            % Extra Images and Levels
            if ~isfield(params, 'ExtraLevels')
                params.ExtraLevels = [];
            end
            if ~isempty(params.ExtraImages)
                if ~isempty(params.ExtraLevels)
                    validateattributes(params.ExtraLevels, {'numeric'},...
                        {'positive', 'integer','numel', numel(params.ExtraImages)},...
                        mfilename, 'ExtraLevels');
                    if any(params.ExtraLevels>[params.ExtraImages.NumLevels])
                        error(message('images:blockedImage:invalidExtraLevel'));
                    end
                else
                    % Defaults
                    params.ExtraLevels = [params.ExtraImages.NumLevels];
                end
            end
            % Information required for handling extra images
            extraImageInfo.images = params.ExtraImages;
            extraImageInfo.levels = params.ExtraLevels;
            extraImageInfo.padMethod = params.PadMethod;            
            
            updateWaitBarFcn = [];            
            if params.DisplayWaitbar
                titleText = getString(message('images:blockedImage:processingBlocks'));
                [obj.WaitBarVars, updateWaitBarFcn] = ...
                    obj.initializeWaitBarVars(params, params.BlockLocationSet.TotalNumBlocks, titleText);
            end            
            
            
            % Create a datastore to represent the input blocks, ignore
            % batch size since we only want to process one block at this
            % time.
            bimds = blockedImageDatastore(obj, ...
                'BlockLocationSet', params.BlockLocationSet,...
                'BorderSize', params.BorderSize,...
                'ReadSize', 1,...
                'PadPartialBlocks', params.PadPartialBlocks,...
                'PadMethod', params.PadMethod);
                        
            % Process first block
            % This has to be done even if Resume==true, since we dont
            % have the output details, and we should validate that the two
            % runs are equivalent (in terms of output blocksize and
            % datatype).
            [results, firstBlockInfo, inputBlockSizeWithBorder] = callUsrFcn(bimds, extraImageInfo, ...
                usrFcn, nargout, params.Index);
            updateWaitBarFcn();
            
            % Ensure that the first block was NOT partial (if it was, we
            % cant accurately determine output size. Order of blocks can be
            % controlled by the user via BLS. Note - size(Data) does not
            % 1-extend so explicitly ask Size to return size for blocksize
            % elements.
            if any(size(firstBlockInfo.Data, 1:numel(firstBlockInfo.BlockSize))<firstBlockInfo.BlockSize)
                % This is a partial block
                error(message('images:blockedImage:firstBlockShouldBeFull'))
            end            
            
            % results is already trimmed if outsize == insize within
            % callUsrFcn. So remove border from input too.
            inBlockSize = inputBlockSizeWithBorder - 2*firstBlockInfo.BorderSize;
            
            % Check if each output is going to be the same size as the
            % input, if not, we have to process the last block to determine
            % the final output image size.
            processLastBlock = false;
            for rInd = 1:numel(results)
                % Skip check for struct outputs since its always scalar.
                result = results{rInd};
                if isstruct(result)
                    continue
                end
                sizeOfResult = size(result);
                if numel(sizeOfResult)<numel(inBlockSize)
                    % If MxN is the output for MxNXP, we can still infer
                    % that the outputsize == inputsize(1:ndims) in
                    % createOutput later.
                    outNDims = numel(sizeOfResult);
                    processLastBlock = processLastBlock ...
                        | ~isequal(inBlockSize(1:outNDims), sizeOfResult);
                else                   
                    % numdims are same but block sizes are different. Or
                    % output numdims> input numdims.
                    processLastBlock = processLastBlock ...
                        | ~isequal(inBlockSize, sizeOfResult(1:numel(inBlockSize)));
                end
            end
            
            % Compute total number of input blocks (like SizeInBlocks but
            % for the BlockSize specified in apply())
            inSize = obj.Size(params.Level,:);
            bsExtended = ones(1,numel(inSize));
            bsExtended(1:numel(params.BlockSize)) = params.BlockSize;
            inSizeInBlocks = ceil(inSize./bsExtended);       
            
            if prod(inSizeInBlocks)==1
                % If there is only one block, then there is no 'last'
                % block.
                processLastBlock = false;
            end
            
            % Process  the last single block, if required
            lastResults = {};
            if processLastBlock
                % Partition to get the a datastore with only the last block
                % in it.
                lbimds = partition(bimds, bimds.TotalNumBlocks, bimds.TotalNumBlocks);
                [lastResults, lastBlockInfo] = callUsrFcn(lbimds, extraImageInfo, ...
                    usrFcn, nargout, params.Index);
                updateWaitBarFcn();
            end
            
            % Initialize output using result of first/last blocks
            outputs = cell(1, numel(results));
            for rInd = 1:numel(results)                                
                outputs{rInd} = obj.createOutput(params,...
                    inSize, inSizeInBlocks,...
                    processLastBlock, results, lastResults,...
                    numel(results), rInd);
                
                outNDims = outputs{rInd}.NumDimensions;
                
                % Write the first block                
                blockSub = trimOr1Extend(firstBlockInfo.BlockSub, outNDims);
                outputs{rInd}.setBlock(blockSub, results{rInd});
                
                % Write the last block, if processed
                if processLastBlock
                    blockSub = trimOr1Extend(lastBlockInfo.BlockSub, outNDims);
                    outputs{rInd}.setBlock(blockSub, lastResults{rInd});
                end
            end
                        
            % Create a datastore with the rest (remove the first/last block),
            % honor batch size this time.
            lastOffset = 0;
            if processLastBlock
                lastOffset = 1;
            end
            bls = bimds.BlockLocationSet;
            bls = blockLocationSet(bls.ImageNumber(2:(end-lastOffset)), ...
                bls.BlockOrigin(2:(end-lastOffset),:), bls.BlockSize, bls.Levels);            
            
            % Trim out previously processed blocks in case Resume is true
            if params.Resume && numel(outputs)>0
                bls = obj.trimCompletedBlock(bls, outputs, params);
            end
            
            bimds = blockedImageDatastore(obj, ...
                'BlockLocationSet', bls,...
                'BorderSize', params.BorderSize,...
                'ReadSize', params.BatchSize,...
                'PadPartialBlocks', params.PadPartialBlocks,...
                'PadMethod', params.PadMethod);
            
            if params.UseParallel
                obj.applyInParallelOverBlocks(bimds, usrFcn, outputs, updateWaitBarFcn,...
                    extraImageInfo, params.Index);
            else
                obj.WaitBarVars.Aborted  = false;
                checkForAbortFcn = @()obj.WaitBarVars.Aborted;
                applyInSerialOverBlocks(bimds, usrFcn, outputs, updateWaitBarFcn,...
                    checkForAbortFcn, extraImageInfo, params.Index);
            end
            
            % Close the results
            for rInd = 1:nargout
                outputs{rInd}.reopenInReadMode();
            end
            
            varargout = outputs;
        end
                        
        function applyInParallelOverBlocks(obj, bimds, usrFcn, outputs,...
                updateWaitBar, extraImageInfo, imageNumber)            
            
            % A data queue for the workers to single completion of one
            % blocked, used to trigger an update to the waitbar
            obj.ProgressDataQueue = parallel.pool.DataQueue;
            afterEach(obj.ProgressDataQueue, @(~)updateWaitBar());
                                  
            % Spawn parallel tasks
            p = gcp();
            numWorkers = p.NumWorkers;
            obj.Futures = parallel.FevalFuture.empty();
            for idx = numWorkers:-1:1
                % Compute the subset of the datastore that should be sent
                % to this worker
                dsPart = bimds.partition(numWorkers, idx);                
                obj.Futures(idx) = parfeval(p, @applyWorker, 0, ...
                    dsPart, usrFcn, outputs,...
                    obj.ProgressDataQueue, extraImageInfo, imageNumber);
            end
            
            % Fetch data and merge the output values.
            for idx = 1:numWorkers
                try
                    % To fetch completed results one by one
                    % This is done purely to check for errors (output is
                    % already written to disk by the workers)
                    fetchNext(obj.Futures);
                catch ERR                    
                    if ~isempty(ERR.cause) && strcmp(ERR.cause{1}.identifier, 'parallel:fevalqueue:ExecutionCancelled')
                        % Did the user cancel? if so, return
                        % partial results
                        break;
                    else
                        % Unexpected error, clean up and inform user
                        cancel(obj.Futures);
                        % Wait till all running ones are completed
                        % (else they may bring up a wait bar which wont
                        % get deleted)
                        wait(obj.Futures);
                        delete(obj.ProgressDataQueue);
                        rethrow(ERR)
                    end
                end
            end
        end                
        
        function bo = createOutput(obj, params, inSize, inSizeInBlocks, processLastBlock, firstResults, lastResults, numResults, rInd)
            firstBlockOutput = firstResults{rInd};
            % First block is always non-partial. Pick this as the
            % output blocksize. This can have a different number of
            % dimensions than the input. This variable fully determines
            % the output dimensions.
            firstBlockSize = size(firstBlockOutput);
            outNDims = ndims(firstBlockOutput);
            
            inNDims = obj.NumDimensions;

            if outNDims<inNDims ...
                    && any(inSizeInBlocks(outNDims+1:end)~=1)
                % e.g Input is MxNxP, blockSize is b1xb2x1, output
                % blocksize is ob1xob2. Final output size is still 3D! So
                % 1 extend the output blocksize to ob1xob2x1.
                firstBlockSize(outNDims+1:inNDims) = 1;
                outNDims = inNDims;
            elseif outNDims>inNDims
                inSizeInBlocks(end+1:outNDims) = 1;
            end

            
            % Determine output size
            lastBlockSize = [];
            if processLastBlock
                % Compute final size assuming all full interior blocks
                % return the same size output as the first block, and
                % then add the last block's output size. Note - the
                % last block might have singleton dimensions.
                lastBlockSize = size(lastResults{rInd}, 1:outNDims);
                % "full' interior blocks
                outSize = (inSizeInBlocks(1:outNDims)-1).*firstBlockSize;
                % potentially partial last block.
                outSize = outSize + lastBlockSize;
            else
                % Only first block processed.
                if isstruct(firstBlockOutput)
                    % Struct outputs are always scalar. So one output
                    % per one input block.
                    outSize = inSizeInBlocks;
                    firstBlockSize(end:numel(outSize)) = 1;
                    outNDims = numel(outSize);
                else
                    if prod(inSizeInBlocks)==1
                        % Only one block, so output size is the same as
                        % this block size
                        outSize = firstBlockSize;
                    else
                        if outNDims>inNDims
                            % Output dimensions are greater than input,
                            % Pad out with the size of the result for the
                            % additional dimensions.
                            outSize = [inSize, firstBlockSize(inNDims+1:end)];
                        else
                            % Output size is same as input, barring
                            % dimensions that got reduced away. Compute
                            % outputsize assuming full blocks, and trim
                            % each dimension down to max of input (to
                            % account for partial blocks at the edges.
                            outSize = inSizeInBlocks(1:outNDims).*firstBlockSize;
                            outSize = min(outSize, inSize(1:outNDims));
                        end
                    end
                end
            end
            
            % Figure out the write adapter to use
            if isempty(params.Adapter)
                % No adapter specified, pick based on output and if
                % OutputLocation was specified.                
                if isempty(params.OutputLocation)
                    outAdapter = images.blocked.InMemory;
                else
                    % Disk output
                    if isnumeric(firstBlockOutput) || islogical(firstBlockOutput)
                        outAdapter = images.blocked.BINBlocks;
                    else
                        outAdapter = images.blocked.MATBlocks;
                    end
                end
            else
                outAdapter = params.Adapter{rInd};
            end
                        
            if params.Resume
                % Check if resume is supported by the adapter
                acap = blockedImage.introspectAdapter(outAdapter);
                if ~acap.resumeSupported
                    error(message('images:blockedImage:resumeNotSupported'))
                end
            end
                        
            
            if isa(outAdapter, 'images.blocked.InMemory')
                destination = string.empty();
            else
                % Augment params.OutputLocation (create subfolders for n'th
                % result if nargout>1, form output name based on input
                % Source, tag on extensions if needed based on output
                % adapter).
                destination = getOutputLocation(obj.Source, params.OutputLocation, ...
                    params.ArrayLength, params.Index, numResults, rInd,...
                    outAdapter, params.Resume);
            end
            
            % Create output blockedImage in write mode, ensure to
            % propagate coordinates and set AlternateFileSystemRoots.
            if obj.NumDimensions<outNDims
                % Rely on set() behavior which extends by defaults.
                ws = obj.WorldStart_(params.Level, :);
                we = obj.WorldEnd_(params.Level, :);
            else
                % Trim, if needed
                ws = obj.WorldStart_(params.Level, 1:outNDims);
                we = obj.WorldEnd_(params.Level, 1:outNDims);
            end
            
            % Are partial input blocks being returned as full output
            % blocks? If so, WorldEnd needs to be expanded to treat the
            % last output as a full block. Note: This is true when output
            % is of type struct since the output is always scalar struct
            % irrespective of input block size.
            partialInputProcessedAsFull = isequal(firstBlockSize, lastBlockSize);
            if isstruct(firstBlockOutput) || partialInputProcessedAsFull
                inPixelSizeInWorld = obj.PixelSizeInWorld(params.Level,:);
                inSizeFullBlocks = ceil(inSize./params.BlockSize).*params.BlockSize;
                worldExtent = inPixelSizeInWorld.*inSizeFullBlocks;
                we = ws + worldExtent(1:numel(ws));
            end
            
            if params.Resume
                mode = 'a';
            else
                mode = 'w';
            end
            
            bo = blockedImage(destination,...
                outSize, firstBlockSize, getInitialValue(firstBlockOutput),...
                'Adapter', outAdapter,...
                'Mode', mode,...
                'WorldStart', ws,...
                'WorldEnd',  we,...
                'AlternateFileSystemRoots', obj.AlternateFileSystemRoots);
        end
        
        function bls = trimCompletedBlock(obj, bls, outputs, params)
            % Check the first output adapter to see how many were already
            % processed.
            existingBlocks = outputs{1}.Adapter.alreadyWritten(params.Level);
            numBlocks = size(existingBlocks,1);
            
            % We need to process 1st and last anyway, were more blocks
            % processed in previous run?
            if ~isempty(existingBlocks) && numBlocks>2
                % List of all blocks. Flip XY to Row/Col
                blockOrigins = bls.BlockOrigin;
                blockOrigins(:, [2 1]) = blockOrigins(:, [1 2]);
                allBlockSubs = ceil(blockOrigins./bls.BlockSize);
                
                % Filter existing blocks out from the list to be
                % processed this time.
                toProcessBlockSubs = setdiff(allBlockSubs, existingBlocks,'rows','stable');
                toProcessBlockOrigin = (toProcessBlockSubs-1).*bls.BlockSize + 1;
                
                % Go back to XY
                toProcessBlockOrigin(:,[2 1]) = toProcessBlockOrigin(:,[1 2]);
                bls = blockLocationSet(ones(1,size(toProcessBlockOrigin,1)), ...
                    toProcessBlockOrigin, bls.BlockSize, bls.Levels);
                
                if params.DisplayWaitbar
                    % Update waitbar to show actual number of blocks to
                    % process
                    obj.WaitBarVars.NumCompleted = size(existingBlocks,1);
                end
            end
        end
    end
       
    %% Static
    methods(Static, Hidden)
        function obj = loadobj(s)                           
            
            if isstruct(s) || isempty(s.Adapter)
                % Something else failed to load, call constructor
                % explicitly with a 'pristine' Adapter.
                obj = blockedImage(s.OriginalSource,...
                    'BlockSize', s.BlockSize_,...
                    'WorldEnd', s.WorldEnd_,'WorldStart', s.WorldStart_,...
                    'Adapter', s.OriginalAdapter);
                return
            end
            
            obj = s;
            
            % Re-resolve the original path again at load time.
            if isstring(obj.OriginalSource)
                obj.Source = resolveToAbsolute(obj.OriginalSource);
            end
            
            % Apply AlternateFileSystemRoots
            obj.Source = resolveAFS(obj.Source, obj.AlternateFileSystemRoots);
            
            % Start with a fresh copy of the saved Adapter (so things like
            % cached info is retained)
            obj.Adapter = copy(obj.Adapter);
            
            if obj.Mode_=='r'
                % Gets called on a client when loading from a MAT file or
                % when de-serializing the inputs of bigimage/apply with
                % UseParallel==true.
                obj.Adapter.openToRead(obj.Source);
            else
                if runningOnPCTWorker()
                    % Gets called when an 'output' of apply is
                    % de-serialized (instantiated) on a PCT worker as part
                    % of blockedImage/apply with UseParallel==true.
                    obj.Adapter.openInParallelToAppend(obj.Source)
                else
                    % Gets called on a client when loading from a MAT file
                    warning("images:blockedImage:openingInReadOnly",...
                        "Opening in read-only mode");
                    obj.Mode_ = 'r';
                    obj.Adapter.openToRead(obj.Source)                    
                end
            end
        end
        
        function padded = padarrayWraper(a, padSize, methodOrVal, direction)
            % paddarray does not support structs, but padarray_algo does.
            % Also we can bypass a lot of unwanted validation by going
            % directly to the algo implementation.
            method = methodOrVal;
            if isstring(method)
                method = char(method);
            end
            if ~ischar(method)
                method = 'constant';
            end
            padded = images.internal.padarray_algo(a, padSize, method, methodOrVal, direction);
        end
        
        function acap = introspectAdapter(adapter)
            % Introspect the adapter to query its capabilities.
            % Cache to improve performance.
            persistent ACapMap
            
            if isempty(ACapMap)
                ACapMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            
            adaptClass = class(adapter);
            if isKey(ACapMap, adaptClass)
                acap = ACapMap(adaptClass);
            else
                acap = struct();
                meta = metaclass(adapter);
                acap.getRegionSupported = ~isempty(meta.MethodList.findobj('Name','getRegion'));
                acap.getFullImageSupported = ~isempty(meta.MethodList.findobj('Name','getFullImage'));
                
                % Check if openInParallelToAppend comes from the base class (which implies
                % that parallel write is not supported).
                methodDetail = meta.MethodList.findobj('Name','openInParallelToAppend');
                acap.parallelWriteSupported = ~isequal(methodDetail.DefiningClass.Name, 'images.blocked.Adapter');
                
                methodDetail = meta.MethodList.findobj('Name','alreadyWritten');
                acap.resumeSupported = ~isequal(methodDetail.DefiningClass.Name, 'images.blocked.Adapter');
                
                ACapMap(adaptClass) = acap;
            end
        end
    end
end

%% makeMulti helpers
function scaledBlocks = scaleBlocks(block, resizer, scales)
% Scale blocks in a 'feed forward' fashion
scaledBlocks = cell(1, numel(scales));

if abs(scales(1)-1) <100*eps(1)
    % Assume its '1'
    scaledBlocks{1} = block;
else
    scaledBlocks{1} = resizer(block, scales(1));
end
for ind = 2:numel(scales)
    scaledBlocks{ind} = resizer(scaledBlocks{ind-1}, scales(ind)/scales(ind-1));
end
end

function rblock = resizer3D(block, scale, interp)
if ndims(block)<=3
    rblock = imresize3(block,scale, "Method", interp);
else
    % imresize3 does NOT support ND.
    % Reshape the rest of the dims into a single trailing dim,loop over
    % it, and then reshape the final result back. Only first three dims
    % are resized.
    originalSize = size(block);
    block = reshape(block, originalSize(1), originalSize(2), originalSize(3), []);
    for cInd = size(block,4):-1:1
        rblock(:,:,:,cInd) = imresize3(block(:,:,:,cInd), scale, "Method", interp);
    end
    rSize = size(rblock);
    rSize(4:numel(originalSize)) = originalSize(4:end);
    rblock = reshape(rblock, rSize);
end
end


%% Apply helpers
function applyWorker(bimdsLocal, usrFcn, outputs, progressDataQueue, extraImageInfo, imageNumber)
% Process blocks from an image on a worker
if ~hasdata(bimdsLocal)
    return
end

% Function handle to update the client waitbar by 1 unit when a block is
% done.
updateWaitBarFcn = @()send(progressDataQueue,1);
% Abort is handled in the client
checkForAbortFcn = @()false;

% Use the normal serial mode inside the parallel worker
applyInSerialOverBlocks(bimdsLocal, usrFcn, outputs, updateWaitBarFcn, ...
    checkForAbortFcn, extraImageInfo, imageNumber)
end

function applyInSerialOverBlocks(bimds, usrFcn, outputs, updateWaitBarFcn, ...
    checkForAbortFcn, extraImageInfo, imageNumber)
% Process blocks from an image in a serial fashion

while hasdata(bimds) && ~checkForAbortFcn()
    [results, blockInfo] = callUsrFcn(bimds, extraImageInfo, ...
        usrFcn, numel(outputs), imageNumber);
    
    for rInd = 1:numel(outputs)
        result = results{rInd};
        
        %Output number of dimensions need not be the same as the input.
        outNDims = outputs{rInd}.NumDimensions;
        
        batchSize = size(blockInfo.BlockSub,1);
        if batchSize == 1 % avoid weight of subsref for common case.
            blockSub = trimOr1Extend(blockInfo.BlockSub, outNDims);
            outputs{rInd}.setBlock(blockSub, result);
        else
            % Handle batch size
            indStruct.type = '()';
            indStruct.subs = repmat({':'}, 1,ndims(result));
            if size(result, numel(size(result))) ~= batchSize
                % Didnt get 'batchsize' worth of output data
                error(message('images:blockedImage:invalidOutputBatchSize', num2str(size(result)),num2str(batchSize)));
            end
            for bInd = 1:batchSize
                indStruct.subs{end} = bInd;
                blockResult = subsref(result, indStruct);
                blockSub = trimOr1Extend(blockInfo.BlockSub(bInd,:), outNDims);
                outputs{rInd}.setBlock(blockSub, blockResult);
            end
        end
    end
    
    updateWaitBarFcn();
end
end

function [results, blockInfo, inBlockSizeWithBorder] = callUsrFcn(bimds, ...
    extraImageInfo, usrFcn, numOutArgs, imageNumber)
% 1. Read a block from the datastore
% 2. Read spatially corresponding blocks from Extra Images
% 3. Call user function handle
% 4. TrimBorder automatically from the output

% Read one block
[block, blockInfo] = bimds.read();

% Augment DS info 
blockInfo.ImageNumber = imageNumber;
% Use the specific batch size for this particular call (can be less than
% user specified BatchSize parameter!)
blockInfo.BatchSize = numel(block);
if numel(block)>1
    catDim = bimds.Images(1).NumDimensions + 1;
    blockInfo.Data = cat(catDim, block{:});
else
    blockInfo.Data = block{1};
end

% This info is only required while processing the first block to help
% initial logic to deduce the output size.
inBlockSizeWithBorder = size(block{1},1:bimds.Images(1).NumDimensions);

results = cell(1, numOutArgs);
if isempty(extraImageInfo.images)
    % Core call to the user processing function
    [results{:}] = usrFcn(blockInfo);
else
    % Fetch blocks from ExtraImages and then call user function
    extraBlocks = getExtraBlocks(bimds.Images, extraImageInfo, blockInfo);
    [results{:}] = usrFcn(blockInfo, extraBlocks{:});
end

if any(cellfun(@(x)isempty(x), results))
    error(message('images:blockedImage:emptyResult'))
end

results = cellfun(@(r)trimBorder(r, blockInfo),...
    results, 'UniformOutput', false);
end

function extraBlocks = getExtraBlocks(bim, extraImageInfo, blockInfo)
% Given an input blockinfo, find the spatially corresponding blocks from
% ExtraImages. 

% Partial batch is possible at the end, so dont rely on blockInfo.BatchSize
batchSize = size(blockInfo.BlockSub,1);

% These are coordinates to pixel centers
worldStart = bim.sub2world(blockInfo.Start, 'Level', blockInfo.Level(1));
worldEnd = bim.sub2world(blockInfo.End, 'Level', blockInfo.Level(1));

% Compute half pixel extent
imageExtents = bim.WorldEnd_(blockInfo.Level,:) - bim.WorldStart_(blockInfo.Level,:);
halfPixelSize = imageExtents./bim.Size(blockInfo.Level,:)/2;

% Expand to pixel edges. Ensure to use a [) interval
worldStart = worldStart - halfPixelSize;
worldEnd = worldEnd + halfPixelSize - eps(worldEnd);

extraBlocks = cell(1, numel(extraImageInfo.images));
for ind = 1:numel(extraImageInfo.images)
    exBim = extraImageInfo.images(ind);
    exLevel = extraImageInfo.levels(ind);
    % Does this extra image have exactly the same coordinate mapping?
    hasSameCoordinates = isequal(bim.WorldStart_(blockInfo.Level,:), exBim.WorldStart_(exLevel,:)) ...
        && isequal(bim.WorldEnd_(blockInfo.Level,:), exBim.WorldEnd_(exLevel,:))...
        && isequal(bim.Size(blockInfo.Level,:), exBim.Size(exLevel,:));
    batchBlocks = cell(1, batchSize);
    
    % For use to extend coordinates if
    % exBim.NumDimensions>bim.NumDimensions
    exBimWorldStart = exBim.sub2world(ones(1, exBim.NumDimensions), 'Level',exLevel);
    exBimWorldEnd = exBim.sub2world(exBim.Size(exLevel,:), 'Level', exLevel);
    
    % Set extra image's block size based on the first block to ensure we
    % can cat the image.
    exBlockSizeM1 = []; % exBlockSize-1
    for bInd = 1:batchSize
        if hasSameCoordinates
            exBlockStartSub = blockInfo(bInd).Start;
            exBlockEndSub = blockInfo(bInd).End;
        else
            % Get corresponding region from exBim via coordinate
            % transformation to the common world coordinates.

            % exBim.NumDimensions need not match bim.NumDimensions.
            % First trim if needed.
            exBlockStartWorld = worldStart(bInd,1:min(exBim.NumDimensions, numel(worldStart)));
            % Then extend if needed in other dimensions to include all data
            exBlockStartWorld(bim.NumDimensions+1:exBim.NumDimensions) = ...
                exBimWorldStart(bim.NumDimensions+1:exBim.NumDimensions);

            % Find subscripts that exist within this region (dont clamp,
            % padding happens for out-of-bounds locations in getRegionPadded).
            exBlockStartSub = exBim.world2sub(exBlockStartWorld, 'Clamp', false, 'Level', exLevel);

            if isempty(exBlockSizeM1)
                exBlockEndWorld = worldEnd(bInd,1:min(exBim.NumDimensions, numel(worldEnd)));
                exBlockEndWorld(bim.NumDimensions+1:exBim.NumDimensions) = ...
                    exBimWorldEnd(bim.NumDimensions+1:exBim.NumDimensions);
                exBlockEndSub = exBim.world2sub(exBlockEndWorld, 'Clamp', false, 'Level', exLevel);
                exBlockSizeM1 = exBlockEndSub-exBlockStartSub;
            end
            exBlockEndSub = exBlockStartSub+exBlockSizeM1;
        end
        % Read this region with padding for out-of-bounds locations (same
        % padmethod as specified in apply PV)
        batchBlocks{bInd} = exBim.getRegionPadded(exBlockStartSub, exBlockEndSub, ...
            exLevel, extraImageInfo.padMethod, []);
    end
    
    catDim = exBim.NumDimensions + 1;
    extraBlocks{ind} = cat(catDim, batchBlocks{:});
end
end

function result = trimBorder(result, blockInfo)
% Remove added BorderSize pixels from output ONLY if
%      outputsize = inputsize(1:numel(outputSize))

if ~any(blockInfo.BorderSize)
    % Nothing to trim
    return
end

% These sizes include any potential borders.
inputSize = size(blockInfo.Data);
resultSize = size(result);

if numel(resultSize)<numel(inputSize)
    % Do Trim if output is, say, MxN for MxNxP input.
    doTrim = isequal(resultSize, inputSize(1:numel(resultSize)));
else
    doTrim = isequal(resultSize, inputSize);
end

if ~doTrim
    % Output size is different from input size, trim amount is not well
    % defined. Dont trim.
    return
end

% Create index struct to trim into core region trimming out the border
trimInds = cell(1,ndims(result));
for dInd = 1:min(numel(resultSize), numel(blockInfo.BorderSize))
    border = blockInfo.BorderSize(dInd);
    trimInds{dInd} = (border+1):(size(result,dInd)-border);
end
% Pass through the batchSize dim, if one exists
for dInd = (dInd+1):ndims(result)
    trimInds{dInd} = ':';
end
result = result(trimInds{:});

end

function initialValue = getInitialValue(result)
% Default initial value is either 0 or the first output value
% for struct with empty fields, and an appropriate undefined
% for categorical.
if isnumeric(result)||islogical(result)
    initialValue = cast(0,'like', result);
else
    if isstruct(result)
        if numel(result)~=1
            error(message('images:blockedImage:scalarStructOnly'))
        end
        % Initial value is a scalar stuct with the same
        % field names, but empty values.
        firstStructOut = result(1);
        fields = fieldnames(firstStructOut);
        structParams = cell(1,2*numel(fields));
        structParams(1:2:end) = fields;
        initialValue = struct(structParams{:});
    elseif iscategorical(result)
        % has to be categorical
        % pick <undefined> with the same categories
        classNames = categories(result(1));
        initialValue = categorical(nan, 1:numel(classNames), classNames);
    else
        error(message('images:blockedImage:unsupportedOutput'))
    end
end
end

function outputLoc = getOutputLocation(source, outputLoc, numBims, index, numRes, rInd, outAdapter, isResuming)
% Pick an output location based on index in the input array, index in the
% output result and the location of the corresponding input.

if isempty(outputLoc)
    return
end

% First, create a subfolder for the N'th result if there are more than
% one.
if numRes>1
    outputLoc = outputLoc + filesep + "output" + num2str(rInd);
end

% Then create another level if an array is being processed.
if numBims>1
    % Base output name is derived from the input
    if isstring(source)
        [~, base] = fileparts(source);
        outputLoc = fullfile(outputLoc,base);
    else
        % in-memory input, use zero padded index
        numZeros = floor(log10(numBims))+1;
        outputLoc = fullfile(outputLoc, sprintf(['%0', num2str(numZeros),'d'], index));
    end
end

% Tag on extension, if adapter supplies one and specified output locations
% does NOT have one.
singleFileWithExtension = numBims==1 && contains(outputLoc, '.');
if isprop(outAdapter, 'Extension') && ~isempty(outAdapter.Extension) && ~singleFileWithExtension
    outputLoc = outputLoc + "." + outAdapter.Extension;
end

% Check for dupes, append a number to create new loc if required.
% Do this ONLY if we are not resuming (since if we are, there might be
% folders from previous runs)
checkLoc = outputLoc;
ind = 1;
while ~isResuming && exist(checkLoc, 'file') % check for both files and folders
    [path, base, ext] = fileparts(checkLoc);
    if path==""
        path = ".";
    end
    base = base + num2str(ind);
    checkLoc = path + filesep + base + ext;
    ind = ind+1;
end
outputLoc = checkLoc;

end

%% Helpers
function adapter = pickReadAdapter(source)


isCellOfInMemoryData = iscell(source) && ...
    all(cellfun(@(x)isnumeric(x)||islogical(x)||iscategorical(x)||isstruct(x), source));
if isnumeric(source) || islogical(source) || isempty(source)...
        ||iscategorical(source) || isstruct(source)...
        ||isCellOfInMemoryData
    adapter = images.blocked.InMemory();
    
elseif ~(isstring(source)||ischar(source))
    % Not a string/char. No known shipping adapter exists.
    error(message('images:blockedImage:unableToFindReadAdapter', 'sources'))
        
elseif  isfolder(source) && isfile(fullfile(source, 'description.mat'))
    % One of our 'folder of blocks, one per file' format
    desc = images.blocked.internal.loadDescription(source);
    if ~isfield(desc,'Adapter') || ~isa(desc.Adapter,'images.blocked.Adapter')
        error(message('images:blockedImage:invalidDescription', source))
    end
    adapter = desc.Adapter;

else
    % Assume file
    if ~isfile(source)
        % Check if its on path
        fileOnPath = which(source);
        if ~isempty(fileOnPath)
            source = fileOnPath;
        end
    end
    if ~isfile(source)
        if isfolder(source)
            error(message('images:blockedImage:unableToFindReadAdapter', source))
        else
            error(message('images:blockedImage:couldNotFindFile', source))
        end
    end
    
    if isTIFF(source)
        % Struct array with info from all IFD's
        tiffInfo = matlab.io.internal.imagesci.imtifinfo(source);
        % ImageJ files have only one IFD, so need to look at other tags:
        isImageJ = images.internal.tiff.isImageJTiff(tiffInfo);
        % Heuristic to check if all slices have the same dims, if so,
        % likely 3D.
        is3D = all(tiffInfo(1).Height==[tiffInfo.Height]) && ...
            all(tiffInfo(1).Width==[tiffInfo.Width]) && ...
            numel(tiffInfo)>1;
        if is3D || isImageJ
            adapter = images.blocked.TIFF3D();
            adapter.TiffInfo = tiffInfo;
        else
            adapter = images.blocked.TIFF();
        end

    elseif isJP2(source)
        adapter = images.blocked.JPEG2000();
    
    elseif endsWith(source,'.h5') || endsWith(source, '.hdf5')        
        adapter = images.blocked.H5();    
    
    else
        % Assume its a generic image, let imfinfo fail if its not.
        adapter = images.blocked.GenericImage();
    end
end
end

function adapter = pickWriteAdapter(destination, initialValue)

if (isnumeric(destination)||islogical(destination)||iscategorical(destination) ||isstruct(destination))...
        && isempty(destination)
    adapter = images.blocked.InMemory;
    
elseif isnumeric(initialValue) || islogical(initialValue)
    validateattributes(destination, {'string'}, {'scalartext'}, mfilename, "DESTINATION")
    [~, ~, ext] = fileparts(destination);
    if isequal(ext, "")
        % No extension, assume folder
        adapter = images.blocked.BINBlocks;
    else
        switch ext
            case {'.tif', '.tiff'}
                adapter = images.blocked.TIFF;
            case {'.h5', '.hdf5'}
                adapter = images.blocked.H5;
            otherwise
                % Check with imformats if IMWRITE could write to this
                support = imformats(strrep(ext,'.',''));
                if ~isempty(support) && ~isempty(support.write)
                    adapter = images.blocked.GenericImage;
                else
                    error(message('images:blockedImage:unableToFindWriteAdapter'))
                end
        end
    end
    
elseif iscategorical(initialValue) || isstruct(initialValue) || ismissing(initialValue)
    adapter = images.blocked.MATBlocks;
    
else
    error(message('images:blockedImage:unableToFindWriteAdapter'))
end
end

function tf = isTIFF(source)
persistent istif;
if isempty(istif)
    % Cache the istiff private function
    fmts = imformats('tif');
    istif = fmts.isa;
end
tf = istif(source);
end

function tf = isJP2(source)
persistent isjp2;
if isempty(isjp2)
    % Cache the private function
    fmts = imformats('jp2');
    isjp2 = fmts.isa;
end
tf = isjp2(source);
end



function tf = runningOnPCTWorker()
tf = ~isempty(which('getCurrentTask')) && ~isempty(getCurrentTask());
end

function blockSize = pickOptimalBlockSize(ioBlockSize, imageSize)

% Check if 2D or 3D with 2/3 channels (RGB)
if size(ioBlockSize,2)<3 || (size(ioBlockSize,2)==3 && ioBlockSize(1,3)==3)
    % Arbitrary choice. Balance between
    % too large (memory pressure if pipeline requires copies) or too small
    % (block book keeping overhead)
    % Note: Faster way to initialize
    optBlockSize = ioBlockSize./ioBlockSize*1024; 
    if size(ioBlockSize,2)==3
        optBlockSize(:,3) = ioBlockSize(:,3);
    end
    factor = floor(optBlockSize./ioBlockSize);
    factor(factor<1)=1;
    blockSize = ceil(ioBlockSize.*factor);
else
    % For larger dimensions, just stick to IO block size
    blockSize = ioBlockSize;
end
blockSize = min(blockSize, imageSize);
end

%% Validators
function mustMatchNumDimensions(bim, vec)
% Source validator enforces if its a vec or matrix.
if bim.NumDimensions ~= size(vec,2)
    error(message('images:blockedImage:mustHaveNumDimsElements'));
end
end

function mustBeLessThanOrEqualNumDimensions(bim, vec)
% Source validator enforces if its a vec or matrix.
if bim.NumDimensions < size(vec,2)
    error(message('images:blockedImage:mustHaveLessThanOrEqualNumDimsElements'));
end
end

function mustBeLessThanNumLevels(bim, level)
mustBeLessThanOrEqual(level, min([bim.NumLevels]));
end

function mustMatchSize(blkImage, bs, propName)
if size(bs,2) > blkImage.NumDimensions
    error(message('images:blockedImage:invalidNumCols', propName))
end
if size(bs,1)>1 && size(bs,1)~= blkImage.NumLevels
    error(message('images:blockedImage:notAllLevels', propName));
end
end

function validateAdapterOpenOutputs(info, adapter)

if ~isstruct(info) || ~isscalar(info)
    error(message('images:blockedImage:incorrectInfo', class(adapter)))
end

if ~all(isfield(info,{'Size', 'IOBlockSize', 'Datatype', 'InitialValue'}))
    fn = fieldnames(info);
    fn = sprintf(' %s', fn{:});
    error(message('images:blockedImage:missingInfoFields',class(adapter), fn))
end

if ~isequal(size(info.Size), size(info.IOBlockSize))
    error(message('images:blockedImage:sizesNotConsistent', class(adapter)));
end

numLevels = size(info.Size,1);
if ~isstring(info.Datatype) || numel(info.Datatype)~=numLevels
    error(message('images:blockedImage:invalidDatatype', class(adapter)))
end

if isfield(info,'UserData') ...
        && ~isempty(info.UserData) ...
        && ~(isstruct(info.UserData) && isscalar(info.UserData))
    error(message('images:blockedImage:invalidUserData', class(adapter)))
end

end

function validateBLS(bims, bls)
% Scalar BLS
validateattributes(bls, {'blockLocationSet'},...
    {'scalar'}, mfilename, 'BlockLocationSet');

%BLS.ImageNumber should be valid index into BIMS
maxImageNum = max(bls.ImageNumber);
if isempty(maxImageNum)
    return; % nothing to validate, empty bls
end
if maxImageNum~=1 && maxImageNum>numel(bims)
    error(message('images:blockedImage:invalidImageNumberInBLS'))
end

% No duplicate blocks
blocks = [bls.ImageNumber, bls.BlockOrigin];
if ~isequal(blocks, unique(blocks, 'rows', 'stable'))
    error(message('images:blockedImage:uniqueBlocksRequired'))
end

% All blocks should be on a regular grid of BlockSize
bs = bls.BlockSize;
bs(1:2) = bs(2:-1:1); % Go to x-y to match origin order in BLS
if ~all(rem(bls.BlockOrigin-1, bs)==0, 'all')
    error(message('images:blockedImage:nonRegularGridBlocks'))
end

end

function location = resolveToAbsolute(location)
if ~isstring(location)
    % location is an in-mem matrix
    return
end

if isfolder(location) || isfile(location)
    % Resolve to absolute path
    [~,msgStruct] = fileattrib(location);
    location = string(msgStruct.Name);
elseif ~isempty(which(location))
    % Its on path, get absolute path
    fid = fopen(location,'r');
    if fid==-1
        % Let adapter error
        return
    end
    % FOPEN on an FID returns the absolute path.
    location = string(fopen(fid));
    fclose(fid);
else
    % leave it be, let adapter handle it
end
end

function location = resolveAFS(location, afs)
if ~isstring(location)|| isfolder(location) || isfile(location)
    % Nothing to resolve
    return
end
for ind = 1:size(afs,1)
    % Search for a match in any row with either entry
    if startsWith(location, afs(ind,1))
        location = updateWithAFS(location,afs(ind,1),afs(ind,2));
    elseif startsWith(location, afs(ind,2))
        location = updateWithAFS(location,afs(ind,2),afs(ind,1));
    end
end
end

function location = updateWithAFS(location, old, new)
% Replace old with new, taking care to ensure there is a filesep in
% between.
if (endsWith(old,'/')||endsWith(old,'\')) ...
        && ~(endsWith(new,'/')||endsWith(new,'\'))
    % Old ends with filesep, but new does not, so update.
    new = new + filesep;    
end

location = strrep(location, old, new);

% Update rest of the path to be valid on current system.
if ispc
    location = strrep(location, '/','\');
else
    location = strrep(location, '\','/');
end
end

function blockSub = trimOr1Extend(blockSub, numDims)
if numel(blockSub)<numDims
    % 1 extend
    blockSub(end+1:numDims) = 1;
else
    % Trim, if needed.
    blockSub = blockSub(1:numDims);
end
end

function mustNotExist(destination)
if isempty(destination)
    % in-memory
    return
end
if (isfile(destination) || (isfolder(destination)))
    error(message('images:blockedImage:cannotOverwrite', destination))
end
end

function validateAppendFor(destination, blockSize, imageSize, initialValue, params)
if ~isa(params.Adapter, 'images.blocked.internal.DirOfBlockFiles')...
        &&~isa(params.Adapter, 'images.blocked.GenericImage')
    % Allow generic images to pass through (they only have one block, so if
    % the destination exists, one can still 'append' one block by
    % overwriting that one block).
    error(message('images:blockedImage:cannotAppendToDestination'))
end

% Return if no content exists in destination
if ~(isfolder(destination) && numel(dir(destination))~=2)
    return
end

try
    existingAdapter = pickReadAdapter(destination);
catch ALL
    error(message('images:blockedImage:incompatibleAppend', 'Adapter'));
end

% params.Adapter is always populated
if ~isequal(class(params.Adapter), class(existingAdapter))
    % Output exists, but the given adapter does not match existing contents
    % (either different adapter, or no valid blockedImage was found)
    error(message('images:blockedImage:incompatibleAppend', 'ADAPTER'));
end

adapter = copy(params.Adapter);
adapter.openToRead(destination);
info = adapter.getInfo();

if ~isequal(info.Size, imageSize)
    error(message('images:blockedImage:incompatibleAppend', 'SIZE'));
end
if ~isequal(info.IOBlockSize, blockSize)
    error(message('images:blockedImage:incompatibleAppend', 'BLOCKSIZE'));
end
if ~isequal(info.InitialValue, initialValue)
    error(message('images:blockedImage:incompatibleAppend', 'INITIALVALUE'));
end
end

function mustBeValid(object)
if isa(object, 'handle') && ~isvalid(object)
    error(message('images:blockedImage:invalidAdapterHandle'))
end
end

function params = validateAndSetInterpolation(bim, params, funcName)
if isfield(params,"Interpolation")
    params.Interpolation = validatestring(params.Interpolation, ["nearest", "linear", "cubic"],...
        funcName,"Interpolation");
    if iscategorical(bim.InitialValue) && params.Interpolation~="nearest"
        error(message("images:blockedImage:invalidInterpolationForCategorical"))
    end
else
    if iscategorical(bim.InitialValue)
        params.Interpolation = "nearest";
    else
        params.Interpolation = "linear";
    end
end
end

% Copyright 2019-2024 The MathWorks, Inc.
