%randomPatchExtractionDatastore Datastore for extracting 2-D or 3-D random patches from images or pixel label images
%
%   patchds = randomPatchExtractionDatastore(ds1, ds2, patchSize) creates a
%   datastore that extracts random patches of size, patchSize for training
%   workflows such as super-resolution, semantic segmentation in deep
%   learning. The inputs, ds1 and ds2 can be any image-based datastores
%   such as imageDatastore, pixelLabelDatastore or TransformedDatastore
%   with underlying image-based datastores. The input, ds1 represents the
%   training input to the network and ds2 represents the desired network
%   output. The patchSize can be a two element vector specifying the height
%   and width or a three element vector specifying the height, width and
%   depth of each patch.
%
%   [...] = randomPatchExtractionDatastore(..., Name, Value) specifies
%   additional name-value pair arguments described below:
%
%      'PatchesPerImage'       Number of random patches to be extracted per
%                              image.
%
%                              Default: 128
%
%      'DataAugmentation'      Specify image data augmentation using an
%                              imageDataAugmenter object or 'none'.
%                              Training data is augmented in real-time
%                              while training.
%
%                              Default: 'none'
%
%      'DispatchInBackground'  Accelerate patch extraction by
%                              asynchronously reading and queueing patches
%                              for use in training. Requires Parallel
%                              Computing Toolbox.
%
%                              Default: false
%
%   Notes
%   -----
%
%   1. The randomPatchExtractionDatastore can be used with image-based
%      datastores such as imageDatastore, pixelLabelDatastore or
%      TransformedDatastore with underlying image-based datastores. The
%      randomPatchExtractionDatastore datastore expects that the output
%      from the read operation on the input datastores return arrays of the
%      same size. It extracts patches at the same locations from the input
%      datastores.
%
%   2. If the input datastore is an imageDatastore, the values in its
%      Labels property are ignored by randomPatchExtractionDatastore.
%
%   3. The read method of the randomPatchExtractionDatastore outputs a table
%      containing two columns. Each column contains a cell array of patches
%      of size, M-by-N-by-C, where M-by-N is the patchsize, or
%      M-by-N-by-P-by-C, where M-by-N-by-P is the patchsize and C is the
%      channel size corresponding to each input image. The number of rows
%      in the table is equal to MiniBatchSize in the
%      randomPatchExtractionDatastore.
%
%   4. The 'DataAugmentation' Name-Value pair cannot be set to an
%      imageDataAugmenter object when patchSize is a 1-by-3 vector i.e. for
%      3-D patching. For augmenting 3-D patches, use transform method on
%      the output of randomPatchExtractionDatastore.
%
%   randomPatchExtractionDatastore Properties:
%
%      MiniBatchSize        - Number of patches returned in each read.
%      PatchesPerImage      - Number of random patches extracted per image.
%      DataAugmentation     - Selected data augmentations.
%      PatchSize            - Size of output patches.
%      DispatchInBackground - Whether background dispatch is used.
%      NumObservations      - Total number of patches in an epoch.
%
%   randomPatchExtractionDatastore Methods:
%
%      hasdata              - Returns true if there is more data in the datastore
%      partitionByIndex     - Partitions datastore given indices
%      preview              - Reads the first patch from the datastore
%      read                 - Reads data from the datastore
%      readall              - Reads all observations from the datastore
%      readByIndex          - Random access read from datastore given indices
%      reset                - Resets datastore to the start of the data
%      shuffle              - Shuffles the observations in the datastore
%      partition            - Returns a new datastore that represents a single
%                             partitioned portion of the original datastore
%      numpartitions        - Returns an estimate for a reasonable number of
%                             partitions to use with the partition function,
%                             according to the total data size
%      transform            - Create an altered form of the current datastore by
%                             specifying a function handle that will execute
%                             after read on the current datastore.
%      combine              - Create a new datastore that horizontally
%                             concatenates the result of read from two or more
%                             input datastores.
%
%   Example 1
%   ---------
%   % Generate random patches from images and their corresponding smoothened
%   % versions with augmentation.
%
%   imageDir = fullfile(toolboxdir('images'),'imdata');
%
%   % Create an imageDatastore holding the training images.
%   imds1 = imageDatastore(imageDir);
%
%   % Create an imageDatastore holding the same training images which will
%   % be smoothened using Gaussian Filtering.
%   imds2 =  imageDatastore(imageDir);
%
%   % Write a transform function to smoothen images.
%   imds2tform = transform(imds2, @(x)imgaussfilt(im2uint8(x),5));
%
%   % Create an imageDataAugmenter. For example, randomly rotate and mirror
%   % image data.
%   augmenter = imageDataAugmenter('RandRotation', @() 90*(randi([0,1],1)), 'RandXReflection', true);
%
%   % Create a datastore to extract random patches from the images and
%   % corresponding smoothened versions.
%   patchds = randomPatchExtractionDatastore(imds1,imds2tform,[50 50],...
%        'PatchesPerImage',512, 'DataAugmentation',augmenter);
%
%   % View an example of an augmented input image and the associated
%   % smoothened image.
%   patchds.MiniBatchSize = 5;
%   data = read(patchds);
%   cellData = data{1:5,1:2}';
%   montage(cellData, 'Size',[5 2])
%
%   Example 2
%   ---------
%   % Train a semantic segmentation network using images and corresponding
%   % pixel label images
%
%   dataSetDir = fullfile(toolboxdir('vision'),'visiondata','triangleImages');
%   imageDir = fullfile(dataSetDir, 'trainingImages');
%   labelDir = fullfile(dataSetDir, 'trainingLabels');
%
%   % Create an imageDatastore holding the training images.
%   imds = imageDatastore(imageDir);
%
%   % Define the class names and their associated label IDs.
%   classNames = ["triangle", "background"];
%   labelIDs   = [255 0];
%
%   % Create a pixelLabelDatastore holding the ground truth pixel labels for
%   % the training images.
%   pxds = pixelLabelDatastore(labelDir, classNames, labelIDs);
%
%   % Create network for semantic segmentation.
%   layers = [
%       imageInputLayer([32 32 1])
%       convolution2dLayer(3, 64, 'Padding', 1)
%       reluLayer()
%       maxPooling2dLayer(2, 'Stride', 2)
%       convolution2dLayer(3, 64, 'Padding', 1)
%       reluLayer()
%       transposedConv2dLayer(4, 64, 'Stride', 2, 'Cropping', 1);
%       convolution2dLayer(1, 2);
%       softmaxLayer()
%       pixelClassificationLayer()
%       ]
%
%   % Setup training options. Note MaxEpochs is set to 5 to reduce example
%   % run-time.
%   options = trainingOptions('sgdm', 'InitialLearnRate', 1e-3, ...
%       'MaxEpochs', 5, 'VerboseFrequency', 10);
%
%   % Create a datastore to extract random patches from the images and
%   % pixel labels.
%   patchds = randomPatchExtractionDatastore(imds,pxds,[32 32],...
%        'PatchesPerImage',512);
%
%   % Train network.
%   net = trainNetwork(patchds, layers, options)
%
%   Example 3
%   ---------
%   % Generate random patches from 3-D volumetric images and their
%   % corresponding labels
%
%   % Location of 3-D volume and pixel label data.
%   dataDir = fullfile(toolboxdir('images'), 'imdata');
%   imDir = fullfile(dataDir,'BrainMRILabeled','images');
%   pxDir = fullfile(dataDir,'BrainMRILabeled','labels');
%
%   % Specify a custom read function to read data from MAT files.
%   matReader = @examplePixelLabelDatastoreMatReader;
%
%   % Create an imageDatastore holding the training volumes.
%   imds = imageDatastore(imDir,'FileExtensions','.mat','ReadFcn',matReader);
%
%   % Create a pixelLabelDatastore holding the pixels labels for the
%   % training volumes.
%   classNames = ["edema", "nonEnhancingTumor", "enhancingTumour" ];
%   pixelLabelID = [1 2 3];
%   pxds = pixelLabelDatastore(pxDir, classNames, ...
%     pixelLabelID,'FileExtensions','.mat', 'ReadFcn',matReader);
%
%   % Create a datastore to extract random patches from the volumes and
%   % corresponding pixel labels.
%   patchds = randomPatchExtractionDatastore(imds,pxds,[70 70 50],...
%     'PatchesPerImage',512);
%
%   % View an example of an input volume and its associated pixel label data.
%   patchds.MiniBatchSize = 5;
%   data = read(patchds);
%   labelvolshow(data.ResponsePixelLabelImage{1},data.InputImage{1});
%
% See also trainNetwork, imageDataAugmenter, pixelLabelDatastore,
%          imageDatastore, matlab.io.datastore.TransformedDatastore.

% Copyright 2018-2021 The MathWorks, Inc.

classdef randomPatchExtractionDatastore < ...
        matlab.io.Datastore &...
        matlab.io.datastore.MiniBatchable &...
        matlab.io.datastore.Shuffleable &...
        matlab.io.datastore.BackgroundDispatchable &...
        matlab.io.datastore.PartitionableByIndex &...
        matlab.io.datastore.internal.RandomizedReadable
    
    properties(SetAccess = private)
        % PatchesPerImage
        %
        %   Integer scalar specifying the number of random patches extracted per
        %   image.
        PatchesPerImage
        
        % PatchSize
        %
        %   A two element vector or three element vector specifying the
        %   number of rows and columns in the output or rows, columns and
        %   planes in the output produced by the datastore.
        PatchSize
        
        % DataAugmentation
        %
        %   Specify image data augmentation using an imageDataAugmenter
        %   object or 'none' ("none"). Training data is augmented in
        %   real-time while training.
        DataAugmentation
    end
    
    properties (Dependent)
        %MiniBatchSize - MiniBatch Size
        %
        %   The number of observations returned as rows in the table
        %   returned by the read method.
        MiniBatchSize
    end
    
    properties(Dependent,SetAccess=protected)
        %NumObservations - Number of observations
        %
        %   The number of observations in the datastore.
        NumObservations
    end
    
    properties(Access = private)
        % Images returned by read() on DatastoreInternal
        Images
        
        % Image indices corresponding to each patch
        ImageIndicesPerPatch
        
        % Image info struct returned by read() on DatastoreInternal
        ImagesInfo
        
        % Current unread patch index of the datastore (i.e. index of patch
        % returned by read())
        CurrentPatchIndex
        
        % MiniBatch Size
        MiniBatchSizeInternal
        
        % Constructed Internal datastore to use the 2 input datastores
        DatastoreInternal
        
        % Datastore passed in as the 1st argument
        dsFirstInternal
        
        % Datastore passed in as the 2nd argument
        dsSecondInternal
        
        % List of patch indices which decides the order of patches returned
        % by read() (length is equal to number of patches in the datastore)
        OrderedIndices
        
        % Cache variables used by *ByIndex methods
        CachedImageIndicesPerPatch_
        CachedImages_
        CachedImagesInfo_
        
        % Cache variables used for storing image indices per patch, images,
        % info struct and number of cached patches returned by read()
        CachedImageIndicesPerPatch
        CachedImages
        CachedImagesInfo
        CachedNumPatches
        
        % Number of dimensions of the pixel-label images (for pixelLabelDatastores only)
        NumPixelLabelsDims
        
    end
    
    methods
        
        function this = randomPatchExtractionDatastore(ds1,ds2,patchSize,varargin)
            narginchk(3,inf);
            images.internal.requiresNeuralNetworkToolbox(mfilename);
            
            validateFirstDatastore(ds1,inputname(1));
            this.dsFirstInternal = copy(ds1);
            
            validateSecondDatastore(ds2,inputname(2));
            this.dsSecondInternal = copy(ds2);
            
            this.PatchSize = validatePatchSize(patchSize);
            
            if isa(ds1,'matlab.io.datastore.ImageDatastore') && isa(ds2,'matlab.io.datastore.PixelLabelDatastore')
                % Set ReadSize of underlying datastores to 1
                this.dsFirstInternal.ReadSize = 1;
                this.dsSecondInternal.ReadSize = 1;
                
                this.DatastoreInternal = vision.internal.PixelLabelImageDatastore(this.dsFirstInternal, this.dsSecondInternal);
                this.NumPixelLabelsDims = ndims(preview(this.dsSecondInternal));
            elseif isa(ds1,'matlab.io.datastore.ImageDatastore') && isa(ds2,'matlab.io.datastore.ImageDatastore')
                % Set ReadSize of underlying datastores to 1
                this.dsFirstInternal.ReadSize = 1;
                this.dsSecondInternal.ReadSize = 1;
                
                this.DatastoreInternal = images.internal.datastore.associatedImageDatastore(this.dsFirstInternal, this.dsSecondInternal);
                this.NumPixelLabelsDims = [];
            else % any other combination including TransformedDatastore
                this.DatastoreInternal = combine(this.dsFirstInternal, this.dsSecondInternal);
                this.NumPixelLabelsDims = [];
                
                dataFromOneRead = read(this.DatastoreInternal);
                reset(this.DatastoreInternal);
                % Expect read() from internal datastore to have 2 columns: input and response
                if size(dataFromOneRead,2) ~= 2
                    error(message('images:randomPatchExtractionDatastore:unexpectedReadFromInputDatastores'));
                end               
            end
            %%
            
            this.MiniBatchSize = 128;
            
            params = parseInputs(varargin{:});
            
            this.PatchesPerImage = params.PatchesPerImage;
            
            % Number of observations and ordered patch indices are set only
            % for associated and pixel label image datastores
            if isInternalInputAssociatedImageDatastore(this.DatastoreInternal) || ...
                    isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                numObservations = numpartitions(this.dsFirstInternal) * this.PatchesPerImage;
                this.OrderedIndices = 1:numObservations;
            end
            
            this.DataAugmentation = params.DataAugmentation;
            this.DispatchInBackground = params.DispatchInBackground;
            
            % DataAugmentation doesn't work with CombinedDatastore or 3-D
            % patch extraction.
            if ~is2DPatchExtraction(this) && isDataAugmentationEnabled(this)
                error(message('images:randomPatchExtractionDatastore:noDataAugmentationIn3D'));
            end
                        
            reset(this);
        end
        
        function batchSize = get.MiniBatchSize(this)
            batchSize = this.MiniBatchSizeInternal;
        end
        
        function set.MiniBatchSize(this,batchSize)
            this.MiniBatchSizeInternal = batchSize;
        end
        
        function numObservations = get.NumObservations(this)
            % Number of observations cannot be calculated for input
            % combined datastores
            if isInternalInputCombinedDatastore(this.DatastoreInternal)
                numObservations = Inf;
            else
                numObservations = numel(this.OrderedIndices);
            end
        end
        
        function s = saveobj(this)
            
            s.DatastoreFirst = this.dsFirstInternal;
            s.DatastoreSecond = this.dsSecondInternal;
            s.PatchSize = this.PatchSize;
            s.PatchesPerImage = this.PatchesPerImage;
            s.DataAugmentation = this.DataAugmentation;
            s.DispatchInBackground = this.DispatchInBackground;
            s.MiniBatchSize = this.MiniBatchSize;
        end
        
    end
    
    methods
        function [data,info] = readByIndex(this,indices)
            % Create datastore partition via a copy and index. This is
            % faster than constructing a new datastore with the new
            % files.
            
            if isInternalInputCombinedDatastore(this.DatastoreInternal)
                error(message('images:randomPatchExtractionDatastore:unsupportedMethod','readByIndex'));
            end
            
            if isempty(indices) || (islogical(indices) && all(~indices))
                data = cell2table(cell(0,2));
                info = struct([]);
                return;
            end
            
            validateIndicesWithinRange(indices,this.NumObservations)
            patchIndices = this.OrderedIndices(indices);
            imageIndices = mapPatchIndicesToImageIndices(this, patchIndices);
            
            % Read images corresponding to image indices and update the
            % cache to remove stale images and add newly read images
            readImagesByIndexAndUpdateCache(this, imageIndices);
            
            % Get random patches corresponding to unique image indices in
            % imageIndicesUnique
            numPatchIndices = numel(patchIndices);
            imageIndicesUnique = unique(imageIndices,'stable');
            [data, info] = getPatchesFromImages(this, numPatchIndices, imageIndicesUnique);
            
            dataVariableNames = getVariableNamesOfData(this);
            data = cell2table(data,'VariableNames',dataVariableNames);
            
        end
        
        function readImagesByIndexAndUpdateCache(this, imageIndices)
            % readImagesByIndexAndUpdateCache reads the images
            % corresponding to imageIndices from cache or the datastore. It
            % populates the properties
            %    Images
            %    ImagesInfo
            %    ImageIndicesPerPatch 
            % 
            % with the requested images corresponding to imageIndices. Read
            % images from cache if available. Read images that are not in
            % cache from the datastore. After read is complete, update the
            % cache properties in the object
            %    CachedImages_ 
            %    CachedImagesInfo_ 
            %    CachedImageIndicesPerPatch_ 
            
            % Initialize the image properties. 
            this.Images = [];
            this.ImagesInfo = [];
            this.ImageIndicesPerPatch = imageIndices;
            
            imageIndicesUnique = unique(imageIndices,'stable');
            
            % If image indices match the cached image indices don't read
            % again. Othwerwise, read only the indices that are not cached.
            cachedImageIndicesUnique = unique(this.CachedImageIndicesPerPatch_,'stable');
            if isequal(imageIndicesUnique,cachedImageIndicesUnique) || ...
                    all(ismember(imageIndicesUnique, cachedImageIndicesUnique))
                % All indices match cached indices.
                this.Images = this.CachedImages_;
                this.ImagesInfo = this.CachedImagesInfo_;
            else
                % Potential match. At least some image indices potentially
                % match the cached images.
                [indexFlag, indexLocations] = ismember(cachedImageIndicesUnique,imageIndicesUnique);
                if isempty(indexFlag) || ~any(indexFlag)
                    % No match. None of the image indices match the cached
                    % images.
                    [this.Images, this.ImagesInfo] = readUnderlyingDatastoreByIndex(this,imageIndicesUnique);
                else
                    % Partial match. Some of image indices match the cached
                    % images.
                    updatedImageIndicesUnique = imageIndicesUnique;
                    indexLocations = nonzeros(indexLocations);
                    updatedImageIndicesUnique(indexLocations) = [];
                    if ~isempty(updatedImageIndicesUnique)
                        % Read images that are not cached
                        [imagesUncached, imagesInfoUncached] = readUnderlyingDatastoreByIndex(this,updatedImageIndicesUnique);
                    else
                        % Nothing to read. Images are already cached.
                        [imagesUncached, imagesInfoUncached] = deal([]);
                    end
                    
                    % Insert both cached and uncached entries in the
                    % correct order to create the complete image-response
                    % table and info struct outputs
                    pIdx = 1;
                    for idx = imageIndicesUnique
                        if ismember(idx,cachedImageIndicesUnique)
                            % Add cached entries
                            this.Images = [this.Images;this.CachedImages_(cachedImageIndicesUnique==idx,:)];
                            this.ImagesInfo = [this.ImagesInfo; this.CachedImagesInfo_(cachedImageIndicesUnique==idx)];
                        else % Add uncached entries
                            this.Images = [this.Images;imagesUncached(pIdx,:)];
                            this.ImagesInfo = [this.ImagesInfo; imagesInfoUncached(pIdx)];
                            pIdx = pIdx + 1;
                        end
                    end
                end
                this.CachedImages_ = this.Images;
                this.CachedImagesInfo_ = this.ImagesInfo;
                % Note: this.ImageIndicesPerPatch could potentially have repeated
                % image indices as it has image indices corresponding to
                % each patch.
                this.CachedImageIndicesPerPatch_ = this.ImageIndicesPerPatch;
            end
        end
    
        function [data, info] = getPatchesFromImages(this, numPatchIndices, imageIndicesUnique)
            % getPatchesFromImages Return numPatchIndices number of patches
            % corresponding to image indices, imageIndicesUnique.
            
            % Initialize data and info
            data = cell(numPatchIndices,2);
            info = initializeInfo(this, numPatchIndices);
            
            [fImg1Name, fImg2Name] = getImageNameFunctionHandles(this);
            
            % Read numPatchIndices number of patches from random locations
            % in the corresponding image indices, imageIndicesUnique
            for idx = 1:numPatchIndices
                % Find the index of the image-pair in the Images property
                % which we want to use to get the current patch-pair
                imgIndex = (imageIndicesUnique==this.ImageIndicesPerPatch(idx));
                
                img = this.Images(imgIndex,:);
                if istable(img{1})
                    img = table2cell(img{:});
                end
                
                img1Size = size(img{1});
                img2Size = size(img{2});
                
                % Error checks
                validateImageSizes(this, img1Size, img2Size, fImg1Name(imgIndex), fImg2Name(imgIndex));
                validatePatchAndImageSize(this, img1Size, img2Size, fImg1Name(imgIndex), fImg2Name(imgIndex));
                
                [patchInput, patchResponse, patchLocation] = cropRandomPatchesFromImagePairs(this, img{1}, img{2});
                
                % Apply the same augmentation to random patch input and response pairs
                [patchInput, patchResponse] = applyDataAugmentationToPatches(this, imgIndex, patchInput, patchResponse);
                
                data{idx,1} = patchInput;
                data{idx,2} = patchResponse;
                
                info = populateOutputInfoStructForThisPatch(this, info, idx, imgIndex, patchLocation);                
            end
        end
        
        function info = populateOutputInfoStructForThisPatch(this, info, patchIdx, imgIndex, patchLocation)
            % populateOutputInfoStructForThisPatch Populate the info struct
            % for the current patch. The info struct has 4 fields
            %  ImageIndices
            %  RandomPatchRectangles
            %  InputImageFileName/Info (varies based on input datastores)
            %  ResponseImageFileName/Info (varies based on input datastores)
            % 
            % The index input, imgIndex is used to index into the correct
            % image-response file names or input-response info structs
            % from which the patch-pair was cropped.
            
            outputInfoVariableNames = getVariableNamesOfOutputInfo(this);                
            [fImg1Name, fImg2Name] = getImageNameFunctionHandles(this);
            
            info.ImageIndices(patchIdx,1) = this.ImageIndicesPerPatch(patchIdx);
            info.RandomPatchRectangles(patchIdx,:) = patchLocation;
                        
            if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal) || ...
                    isInternalInputAssociatedImageDatastore(this.DatastoreInternal)
                info.(outputInfoVariableNames{1}){patchIdx,1} = fImg1Name(imgIndex);
                info.(outputInfoVariableNames{2}){patchIdx,1} = fImg2Name(imgIndex);
                
            else % isInputCombinedDatastore(subds.DatastoreInternal)
                % For datastores with ReadSize > 1, (i.e. output of
                % read() has more than one row). The patches returned
                % do not have 1-to-1 correspondence with the input and
                % response info structs. The info structs are
                % returned as-is from the underlying datastores without
                % further processing to extract only the information
                % corresponding to the current patch.
                infoStruct = this.ImagesInfo;            
                info.(outputInfoVariableNames{1}){patchIdx,1} = infoStruct{imgIndex,1};
                info.(outputInfoVariableNames{2}){patchIdx,1} = infoStruct{imgIndex,2};
                
            end
        end
        
        function [patchInput, patchResponse] = applyDataAugmentationToPatches(this, imgIndex, patchInput, patchResponse)
            % applyDataAugmentationToPatches Apply the same augmentation to
            % random patch input and response pairs. The index input,
            % imgIndex, is the index corresponding to the image from which
            % the patch was croppped. It is used to index into the correct
            % info struct to get fill values to augment and label
            % information. It is used for pixel label images only.
            
            infoStruct = this.ImagesInfo;
            if isDataAugmentationEnabled(this)
                % Output is cropped to input image size by augment().
                if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                    fillval = infoStruct{imgIndex}.LabeledImageInfo.FillValue;
                    [patchInput,patchResponse] = this.DatastoreInternal.augment(this.DataAugmentation,patchInput,patchResponse,fillval);
                else
                    outCell = this.DataAugmentation.augment({patchInput,patchResponse});
                    [patchInput, patchResponse] = outCell{:};
                end
            end
            
            % Convert pixel label responses from numeric to categorical
            if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                patchResponse = label2categorical(this.DatastoreInternal.PixelLabelDatastore, patchResponse, infoStruct{imgIndex}.LabeledImageInfo);
            end
        end
        
        function [patchInput, patchResponse, patchLocation] = cropRandomPatchesFromImagePairs(this, img1, img2)
            % cropRandomPatchesFromImagePairs Extract 2-D or 3-D random
            % patches from input and response image pairs. Also, return the
            % location as [x y w h] for 2-D patches or [x y z w h d] for
            % 3-D patches
            
            if is2DPatchExtraction(this)
                % Extract input and response patch pairs from the same random location
                patchLocation = augmentedImageDatastore.randCropRect(img1,this.PatchSize);
                
                patchInput = augmentedImageDatastore.cropGivenDiscreteValuedRect(img1,patchLocation);
                patchResponse = augmentedImageDatastore.cropGivenDiscreteValuedRect(img2,patchLocation);
                
            else % 3-D Patch Extraction
                % Extract input and response patch pairs from the same random location
                patchLocation = augmentedImageDatastore.randCropCuboid(img1,this.PatchSize);
                
                patchInput = augmentedImageDatastore.cropGivenDiscreteValuedCuboid(img1,patchLocation);
                patchResponse = augmentedImageDatastore.cropGivenDiscreteValuedCuboid(img2,patchLocation);
            end
        end
        
        function dataVariableNames = getVariableNamesOfData(this)
            % getVariableNamesOfData Variable names of data table output
            % by calling read() on randomPatchExtractionDatastore.
            
            if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                dataVariableNames = {'InputImage','ResponsePixelLabelImage'};                            
            elseif isInternalInputAssociatedImageDatastore(this.DatastoreInternal)
                dataVariableNames = {'InputImage','ResponseImage'};          
            else % isInputCombinedDatastore(this.DatastoreInternal)
                dataVariableNames = {'InputImage','ResponseImage'};
            end
        end
        
        function inputInfoVariableNames = getVariableNamesOfInputInfo(this)
            % getVariableNamesOfInputInfo Variable names of input info
            % struct. The input info struct is the struct returned by
            % reading the input datastores.
            
            if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                inputInfoVariableNames = {'ImageFilename','LabeledImageInfo'};
            elseif isInternalInputAssociatedImageDatastore(this.DatastoreInternal)
                inputInfoVariableNames = {'ImageFilenameFirst','ImageFilenameSecond'};
            else % isInputCombinedDatastore(this.DatastoreInternal)
                inputInfoVariableNames = {''};
            end
        end
        
        function outputInfoVariableNames = getVariableNamesOfOutputInfo(this)
            % getVariableNamesOfOutputInfo Variable names of output info
            % struct by calling read() on randomPatchExtractionDatastore.
            % The fields in the info struct use the same prefix as the
            % corresponding variable names in the data table.
            
            dataVariableNames = getVariableNamesOfData(this);
            if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                outputInfoVariableNames = strcat(dataVariableNames,'Filename');       
            elseif isInternalInputAssociatedImageDatastore(this.DatastoreInternal)
                outputInfoVariableNames = strcat(dataVariableNames,'Filename');        
            else % isInputCombinedDatastore(this.DatastoreInternal)
                outputInfoVariableNames = strcat(dataVariableNames,'Info');
            end
        end
        
        function [fImg1Name, fImg2Name] = getImageNameFunctionHandles(this)
            % getImageNameFunctionHandles Return function handles
            % corresponding to image file names of the input and response.
            % If input is a CombinedDatastore, the function handles return
            % empty chars as they don't output file names (instead they
            % output the complete info struct).
            
            infoStruct = this.ImagesInfo;
            inputInfoVariableNames = getVariableNamesOfInputInfo(this);
            if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                fImg1Name = @(imgIndex)infoStruct{imgIndex}.(inputInfoVariableNames{1}){:};
                fImg2Name = @(imgIndex)infoStruct{imgIndex}.(inputInfoVariableNames{2}).Filename{:};
            elseif isInternalInputAssociatedImageDatastore(this.DatastoreInternal)
                fImg1Name = @(imgIndex)infoStruct{imgIndex}.(inputInfoVariableNames{1}){:};
                fImg2Name = @(imgIndex)infoStruct{imgIndex}.(inputInfoVariableNames{2}){:};
            else % isInputCombinedDatastore(this.DatastoreInternal)
                % Image names are set to empty because we don't infer
                % details of the info struct
                fImg1Name = @(imgIndex)'';
                fImg2Name = @(imgIndex)'';
            end
        end
        
        function info = initializeInfo(this, numIndices)
            % initializeInfo Initialize info struct with 4 fields 
            %   RandomPatchRectangles
            %   ImageIndices
            %   InputFileName/Info (varies based on input datastores)
            %   ResponseFileName/Info (varies based on input datastores)
            
            % Initialize info struct
            if is2DPatchExtraction(this)
                info.RandomPatchRectangles = zeros(numIndices,4);
            else
                info.RandomPatchRectangles = zeros(numIndices,6);
            end
            info.ImageIndices = zeros(numIndices,1);
            
            outputInfoVariableNames = getVariableNamesOfOutputInfo(this);
            if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                info.(outputInfoVariableNames{1}) = cell(numIndices,1);
                info.(outputInfoVariableNames{2}) = cell(numIndices,1);                
            elseif isInternalInputAssociatedImageDatastore(this.DatastoreInternal)
                info.(outputInfoVariableNames{1}) = cell(numIndices,1);
                info.(outputInfoVariableNames{2}) = cell(numIndices,1);                
            else
                info.(outputInfoVariableNames{1}) = cell(0,1);
                info.(outputInfoVariableNames{2}) = cell(0,1);
            end
        end
        
        function [data,info] = read(this)
            if ~hasdata(this)
                error(message('images:randomPatchExtractionDatastore:outOfData'));
            end
            
            % CurrentPatchIndex contains the current unread patch
            % index in the datastore
            if isInternalInputCombinedDatastore(this.DatastoreInternal)
                [data,info] = readPatches(this);
            else
                numPatches = min(this.MiniBatchSize,this.NumObservations-this.CurrentPatchIndex+1);
                patchIndices = this.CurrentPatchIndex:this.CurrentPatchIndex + numPatches - 1;
                [data,info] = readByIndex(this, patchIndices);
                this.CurrentPatchIndex = this.CurrentPatchIndex + numPatches;
            end
            
        end
        
        function reset(this)
            reset(this.DatastoreInternal);
            
            % Reset CurrentPatchIndex which contains the current unread
            % patch index in the datastore.
            resetCurrentPatchIndex(this);
            
            % Reset cache variables used by read() and *ByIndex methods
            resetDatastoreCache(this);
            
        end
        
        function newds = shuffle(this)
            
            newds = copy(this);
            % Reset the copied datastore because the original datastore's
            % state may have changed
            reset(newds);
            
            if isInternalInputCombinedDatastore(this.DatastoreInternal)
                newds.DatastoreInternal = shuffle(newds.DatastoreInternal);
            else
                % Assign the ordered patch indices from the original datastore
                % and re-order the patch indices randomly
                newds.OrderedIndices = this.OrderedIndices;
                imdsIndexList = randperm(this.dsFirstInternal.numpartitions);
                reorderIndexList(newds,imdsIndexList);
            end
        end
        
        function TF = hasdata(this)
            
            if isInternalInputCombinedDatastore(this.DatastoreInternal)
                outOfData = ~hasdata(this.DatastoreInternal) && ~hasCachedPatches(this);
            else
                outOfData = this.CurrentPatchIndex > this.NumObservations;
            end
            
            TF = ~outOfData;
            
        end
        
        function newds = partitionByIndex(this,indices)
            
            if isInternalInputCombinedDatastore(this.DatastoreInternal)
                error(message('images:randomPatchExtractionDatastore:unsupportedMethod','partitionByIndex'));
            end
            
            newds = copy(this);
            
            % Reset the copied datastore because the orginal datastore's
            % state may have changed
            reset(newds);
            
            newds.DatastoreInternal = copy(this.DatastoreInternal);
            newds.dsFirstInternal = copy(this.dsFirstInternal);
            newds.dsSecondInternal = copy(this.dsSecondInternal);
            
            newds.OrderedIndices = this.OrderedIndices(indices);
        end
        
        %------------------------------------------------------------------
        function subds = partition(this, varargin)
            %partition Returns a partitioned portion of the randomPatchExtractionDatastore.
            %   subds = partition(patchds, N, index) partitions patchds
            %   into N parts and returns the partitioned
            %   randomPatchExtractionDatastore, subds, corresponding to
            %   index. An estimate for a reasonable value for N can be
            %   obtained by using the NUMPARTITIONS function.
            %
            %   subds = partition(patchds,'Files',index) partitions patchds
            %   by files in the Files property and returns the partition
            %   corresponding to index.
            
            try
                narginchk(3,3);
                
                if ~isPartitionable(this)
                    error(message('images:randomPatchExtractionDatastore:unsupportedMethod', 'partition'));
                end
                
                newfirstds = partition(this.dsFirstInternal, varargin{:});
                newsecondds = partition(this.dsSecondInternal, varargin{:});
                
                subds = randomPatchExtractionDatastore(...
                    newfirstds, newsecondds, this.PatchSize, ...
                    'PatchesPerImage', this.PatchesPerImage, ...
                    'DataAugmentation', this.DataAugmentation, ...
                    'DispatchInBackground', this.DispatchInBackground);
                
                subds.MiniBatchSize = this.MiniBatchSize;
            catch ME
                throwAsCaller(ME)
            end
            
        end
        
    end
    
    methods (Hidden)
        function frac = progress(this)
            if isInternalInputCombinedDatastore(this.DatastoreInternal)
                % For TransformedDatastore inputs, NumObservations on
                % randomPatchExtractionDatastore is set to Inf. Therefore,
                % use the progress() method on internally constructed
                % CombinedDatastore to calculate progress.
                frac = progress(this.DatastoreInternal);
            else
                frac = (this.CurrentPatchIndex-1) / this.NumObservations;
            end
        end
        
        function TF = isShuffleable(this)
            
            TF = this.dsFirstInternal.isSubsettable && ...
                this.dsSecondInternal.isSubsettable;
        end
        
        function TF = isPartitionable(this)
            
            TF = this.dsFirstInternal.isSubsettable && ...
                this.dsSecondInternal.isSubsettable;
        end
    end
    
    methods(Hidden, Static)
        function this = loadobj(s)
            this = randomPatchExtractionDatastore(...
                s.DatastoreFirst, s.DatastoreSecond, s.PatchSize, ...
                'PatchesPerImage', s.PatchesPerImage, ...
                'DataAugmentation', s.DataAugmentation, ...
                'DispatchInBackground', s.DispatchInBackground);
            
            if isfield(s,'MiniBatchSize')
                this.MiniBatchSize = s.MiniBatchSize;
            else
                this.MiniBatchSize = 128;
            end
        end
        
    end
    
    methods(Access = public)
        function N = numpartitions(this, varargin)
            %NUMPARTITIONS Return an estimate for a reasonable number of
            %   partitions for the given information.
            %
            %   N = NUMPARTITIONS(DS) returns the default number of
            %   partitions for a given datastore, DS.
            %
            %   N = NUMPARTITIONS(DS, POOL) returns a reasonable number of
            %   partitions to parallelize DS over a parallel pool, POOL.
            %
            %   In the provided default implementation, the minimum of
            %   maxpartitions on the datastore, DS, and thrice the number
            %   of workers available, is returned as the number of partitions, N.
            %
            %   See also matlab.io.datastore.Partitionable, partition,
            %   maxpartitions.
            
            if numpartitions(this.dsFirstInternal) ~= numpartitions(this.dsSecondInternal)
                error(message('images:randomPatchExtractionDatastore:unequalNumPartitions'));
            end
            
            N = numpartitions(this.dsFirstInternal, varargin{:});
            
        end
    end
    
    methods(Access = private)
        function [data, info] = readUnderlyingDatastoreByIndex(this, indices)
            % readUnderlyingDatastoreByIndex Reads the internally
            % constructed datastore to return image data and info
            % corresponding to input image indices.
            %
            % When the interal datastore input is a
            % pixelLabelImageDatastore or associatedImageDatastore the
            % function uses the readByIndex() method to return data. Since,
            % readByIndex() supports random access, the value of indices is
            % used.
            
            numIndices = numel(indices);
            
            if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                % Use readNumericByIndex() because read() doesn't return
                % fillvalues required for data augmentation.
                data = cell(numIndices,1);
                info = cell(numIndices,1);
                
                for idx = 1:numIndices
                    [data{idx}, info{idx}] = readNumericByIndex(this.DatastoreInternal, indices(idx));
                end
            elseif isInternalInputAssociatedImageDatastore(this.DatastoreInternal)
                data = cell(numIndices,1);
                info = cell(numIndices,1);
                
                for idx = 1:numIndices
                    [data{idx}, info{idx}] = readByIndex(this.DatastoreInternal, indices(idx));
                end
            else
                error(message('images:randomPatchExtractionDatastore:invalidInputDatastore'));
            end
            
        end
        
        function [data,info] = readPatches(this)
            % readPatches Reads a MiniBatchSize amount of patches (or the
            % patches corresponding to the last remaining images in the
            % cache)
            
            % Read as many images as required to output at least one
            % minibatch amount of data. Update the cache with the newly
            % read images. We will remove the stale images from cache only
            % later.
            readImagesUntilMiniBatchSizeOfData(this);
            
            % Get random patches corresponding to unique image indices in
            % imageIndicesUnique
            numPatchIndices = min(this.MiniBatchSize,this.CachedNumPatches);
            imageIndicesUnique = unique(this.CachedImageIndicesPerPatch,'stable');
            [data, info] = getPatchesFromImages(this, numPatchIndices, imageIndicesUnique);
            
            dataVariableNames = getVariableNamesOfData(this);
            data = cell2table(data,'VariableNames',dataVariableNames);
            
            % Update patch index and image cache
            this.CurrentPatchIndex = this.CurrentPatchIndex + numPatchIndices;            
            updateCacheByNumPatchesOutput(this, numPatchIndices);
        end
              
        function updateCacheByNumPatchesOutput(this, numPatchIndices)
            % Reduce the number of cached patches by number of indices read
            this.CachedNumPatches = this.CachedNumPatches - numPatchIndices;
            
            % Update all cache variables
            if hasCachedPatches(this)
                % Update the cached images and info cache by removing
                % entries already used
                imageIndicesToRemove = (unique(this.CachedImageIndicesPerPatch(1:numPatchIndices),'stable') ~= this.CachedImageIndicesPerPatch(numPatchIndices+1));
                this.CachedImages(imageIndicesToRemove,:) = [];
                this.CachedImagesInfo(imageIndicesToRemove,:) = [];
            else 
                % Reset image and info cache if there are no more cached
                % patches
                this.CachedImages = [];
                this.CachedImagesInfo = [];
            end                
            this.CachedImageIndicesPerPatch(1:numPatchIndices) = [];
                        
        end
        
        function readImagesUntilMiniBatchSizeOfData(this)
            % readImagesUntilMiniBatchSizeOfData Reads the cached or
            % internally constructed datastore until it reads enough images
            % to output MiniBatchSize number of patches. It populates the
            % properties
            %    Images
            %    ImagesInfo
            %    ImageIndicesPerPatch 
            % 
            % with enough images to output at least one MiniBatchSize
            % amount of patches. Read images from cache if available. After
            % read is complete, append the cache properties in the object
            % with the newly read images. The stale entries will be removed
            % only later.
            %    CachedImages 
            %    CachedImagesInfo 
            %    CachedImageIndicesPerPatch 
            %
            % When the internal datastore input is a CombinedDatastore it
            % returns data by calling the read() method. The read()
            % function supports sequential access.
            
            this.Images = [];
            this.ImagesInfo = [];
            this.ImageIndicesPerPatch = [];
            
            if isInternalInputCombinedDatastore(this.DatastoreInternal)
                while this.CachedNumPatches < this.MiniBatchSize
                    if hasdata(this.DatastoreInternal)
                        [dataFromOneRead, infoFromOneRead] = read(this.DatastoreInternal);
                        % Note: read() doesn't always have to return the same
                        % number of rows
                        this.CachedImages = [this.CachedImages;dataFromOneRead];
                        numRowsRead = size(dataFromOneRead,1);
                        % Replicate info struct so that it has the same number
                        % of rows as data. Now, we can use identical indexing
                        % when accessing them.
                        this.CachedImagesInfo = [this.CachedImagesInfo;repmat(infoFromOneRead,[numRowsRead 1])];
                        this.CachedNumPatches = this.CachedNumPatches + (numRowsRead * this.PatchesPerImage);
                        
                        % Update input images indices variable with
                        % any extra image index values read because ReadSize of
                        % underlying datastore was greater than 1
                        if isempty(this.CachedImageIndicesPerPatch)
                            % For the first read or when patches from all
                            % cached images have been output already
                            lastCachedImageIndex = floor((this.CurrentPatchIndex-1)/this.PatchesPerImage);
                        else
                            lastCachedImageIndex = this.CachedImageIndicesPerPatch(end);
                        end
                        
                        indicesToAppend =  lastCachedImageIndex + repelem(1:numRowsRead,this.PatchesPerImage);
                        this.CachedImageIndicesPerPatch = [this.CachedImageIndicesPerPatch, indicesToAppend];
                        
                    else
                        if hasCachedPatches(this)
                            % Break out of the while loop to allow outputting
                            % any remaining patches
                            break;
                        else % this.CachedNumPatches <= 0                            
                            error(message('images:randomPatchExtractionDatastore:outOfData'));
                        end
                    end
                end
            else
                error(message('images:randomPatchExtractionDatastore:invalidInputDatastore'));
            end
            
            this.Images = this.CachedImages;
            this.ImagesInfo = this.CachedImagesInfo;
            this.ImageIndicesPerPatch = this.CachedImageIndicesPerPatch;
        end
        
        function imageIndices = mapPatchIndicesToImageIndices(this, patchIndices)
            imageIndices = 1 + floor((patchIndices - 1) / this.PatchesPerImage);
        end
        
        function TF = isDataAugmentationEnabled(this)
            TF = isa(this.DataAugmentation,'imageDataAugmenter');
        end
        
        function reorderIndexList(this,imdsIndexList)
            % Reorder OrderedIndices to be consistent with a new ordering
            % of the underlying imds. That is, when shuffle is called, we
            % only want to reorder imds, we don't want to end up with a
            % truly random shuffling of all of the observations (i.e
            % patches) because that will drastically degrade performance by
            % creating a situation where each image patch is from a
            % different source image.
            
            observationToImdsIndex = floor(( this.OrderedIndices - 1) / this.PatchesPerImage) + 1;
            newObservationMapping = zeros(size(observationToImdsIndex),'like',observationToImdsIndex);
            currentIdxPos = 1;
            for i = 1:length(imdsIndexList)
                idx = imdsIndexList(i);
                sortedIdx = find(observationToImdsIndex == idx);
                newObservationMapping(currentIdxPos:(currentIdxPos+length(sortedIdx)-1)) = this.OrderedIndices(sortedIdx);
                currentIdxPos = currentIdxPos+length(sortedIdx);
            end
            this.OrderedIndices = newObservationMapping;
        end
        
        function TF = is2DPatchExtraction(this)
            TF = (numel(this.PatchSize) == 2);
        end
        
        function TF = is3DPatchExtraction(this)
            TF = (numel(this.PatchSize) == 3);
        end
        
        function TF = is2DPixelLabelDatastore(this)
            TF = (this.NumPixelLabelsDims == 2);
        end
        
        function validateImageSizes(this, img1Size, img2Size, img1Name, img2Name)
            % Validate image sizes to make sure that their spatial
            % dimensions match. Channel dimensions can be different.
            if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                if is2DPixelLabelDatastore(this)
                    if ~isequal(img1Size(1:2),img2Size(1:2))
                        error(message('images:randomPatchExtractionDatastore:expectSameSizeImages', img1Name, img2Name));
                    end
                else
                    % 2-D images cannot be paired with 3-D labels
                    if numel(img1Size) < 3
                        error(message('images:randomPatchExtractionDatastore:expect3DImagesWith3DLabels', img1Name, img2Name));
                    end
                    
                    if ~isequal(img1Size(1:3),img2Size(1:3))
                        error(message('images:randomPatchExtractionDatastore:expectSameSizeImages', img1Name, img2Name));
                    end
                end
            else % isInputImageDatastore || isInputCombinedDatastore
                if is2DPatchExtraction(this)
                    if ~isequal(img1Size(1:2),img2Size(1:2))
                        error(message('images:randomPatchExtractionDatastore:expectSameSizeImages', img1Name, img2Name));
                    end
                else
                    % The images must have at least 3 dimensions
                    if numel(img1Size) < 3
                        error(message('images:randomPatchExtractionDatastore:expectMinimum3Dimensions', img1Name));
                    end
                    
                    if numel(img2Size) < 3
                        error(message('images:randomPatchExtractionDatastore:expectMinimum3Dimensions', img2Name));
                    end
                    
                    % The three spatial dimensions must match in size
                    if ~isequal(img1Size(1:3),img2Size(1:3))
                        error(message('images:randomPatchExtractionDatastore:expectSameSizeImages', img1Name, img2Name));
                    end
                end
            end
        end
        
        function validatePatchAndImageSize(this, img1Size, img2Size, img1Name, img2Name)
            % Validate image and patch sizes to make sure that number of
            % dimensions match and patch size is smaller than image size.
            if numel(this.PatchSize) > numel(img1Size)
                error(message('images:randomPatchExtractionDatastore:invalidPatchSizeDimsImageDims',img1Name, regexprep(num2str(img1Size),'\s+','x')));
            end
            
            if isInternalInputPixelLabelImageDatastore(this.DatastoreInternal)
                if numel(this.PatchSize) > numel(img2Size)
                    error(message('images:randomPatchExtractionDatastore:invalidPatchSizeDimsLabelDims', img2Name, regexprep(num2str(img2Size),'\s+','x')));
                end
            else % isInputImageDatastore || isInputCombinedDatastore
                if numel(this.PatchSize) > numel(img2Size)
                    error(message('images:randomPatchExtractionDatastore:invalidPatchSizeDimsImageDims',img2Name, regexprep(num2str(img2Size),'\s+','x')));
                end
            end
            
            if (is2DPatchExtraction(this) && any(this.PatchSize(1:2) > img1Size(1:2)) )   || ...
                    (is3DPatchExtraction(this) && any(this.PatchSize(1:3) > img1Size(1:3)))
                error(message('images:randomPatchExtractionDatastore:expectPatchSmallerThanImage', regexprep(num2str(this.PatchSize),'\s+','x'), regexprep(num2str(img1Size),'\s+','x'), img1Name));
            end
            
            if (is2DPatchExtraction(this) && any(this.PatchSize(1:2) > img2Size(1:2)) )   || ...
                    (is3DPatchExtraction(this) && any(this.PatchSize(1:3) > img2Size(1:3)))
                error(message('images:randomPatchExtractionDatastore:expectPatchSmallerThanImage', regexprep(num2str(this.PatchSize),'\s+','x'), regexprep(num2str(img2Size),'\s+','x'), img2Name));
            end
        end
        
        function resetCurrentPatchIndex(this)
            % Reset CurrentPatchIndex which contains the current unread
            % patch index in the datastore
            this.CurrentPatchIndex = 1;
        end
        
        function resetDatastoreCache(this)
            
            % Reset cache variables used by read()
            this.CachedImageIndicesPerPatch = [];
            this.CachedImages = [];
            this.CachedImagesInfo = [];
            this.CachedNumPatches = 0;
            
            % Reset cache variables used by *ByIndex methods
            this.CachedImageIndicesPerPatch_ = [];
            this.CachedImages_ = [];
            this.CachedImagesInfo_ = [];
        end
        
        function TF = hasCachedPatches(this)
            % Returns true if the datastore has cached patches.
            %
            % The CachedNumPatches property is set to zero at construction
            % time. It keeps track of the number of patches corresponding
            % to the cached images. If CachedNumPatches > 0, the datastore
            % can output patches even after it runs out of image data from
            % the internal underlying datastore. This is because the user
            % may have requested multiple patches per image and based on
            % the MiniBatchSize not all patches may have been read.
            
            TF = this.CachedNumPatches > 0;
        end
        
    end
    
    methods (Access = 'protected')
        
        function cpObj = copyElement(this)
            cpObj = copyElement@matlab.mixin.Copyable(this);
            
            % Deep copy the underlying datastores
            this.DatastoreInternal = copy(this.DatastoreInternal);
        end
    end
end

%--------------------------------------------------------------------------
function options = parseInputs(varargin)

parser = inputParser();
parser.PartialMatching = true;
parser.CaseSensitive = false;
parser.addParameter('PatchesPerImage',128,@validatePatchesPerImage);
parser.addParameter('DispatchInBackground',false,@validateDispatchInBackground);
parser.addParameter('DataAugmentation','none');

parser.parse(varargin{:});
options = parser.Results;

if ~isa(options.DataAugmentation, 'imageDataAugmenter')
    options.DataAugmentation = validatestring(options.DataAugmentation, {'none'}, mfilename, 'DataAugmentation');
end

end
%--------------------------------------------------------------------------
function B = validateDispatchInBackground(dispatchInBackground)

attributes = {'nonempty'};

validateattributes(dispatchInBackground,{'logical','scalar'}, attributes,...
    mfilename,'DispatchInBackground');

B = true;

end

%--------------------------------------------------------------------------
function B = validatePatchesPerImage(patchesPerImage)

attributes = {'nonempty','scalar', 'real', 'positive','integer','nonsparse'};

matlab.images.internal.errorIfgpuArray(patchesPerImage);
validateattributes(patchesPerImage,images.internal.iptnumerictypes, attributes,...
    mfilename,'PatchesPerImage');

B = true;

end

%--------------------------------------------------------------------------
function patchSize = validatePatchSize(patchSize)

attributes = {'real', 'positive','integer','nonempty'};

matlab.images.internal.errorIfgpuArray(patchSize);
validateattributes(patchSize,images.internal.iptnumerictypes, attributes,...
    mfilename,'patchSize');

if numel(patchSize) > 3
    error(message('images:randomPatchExtractionDatastore:invalidPatchSize'));
end

% Scalar patch sizes are expanded to 2-D only.
if isscalar(patchSize)
    patchSize = [patchSize patchSize];
end

end

%--------------------------------------------------------------------------
function B = validateFirstDatastore(ds,varName)

validateattributes(ds, {'matlab.io.datastore.ImageDatastore','matlab.io.datastore.PixelLabelDatastore','matlab.io.datastore.TransformedDatastore'}, ...
    {'nonempty','scalar'}, mfilename, upper(varName));

B = true;

end

%--------------------------------------------------------------------------
function B = validateSecondDatastore(ds,varName)

validateattributes(ds, {'matlab.io.datastore.ImageDatastore','matlab.io.datastore.PixelLabelDatastore','matlab.io.datastore.TransformedDatastore'}, ...
    {'nonempty','scalar'}, mfilename, upper(varName));

B = true;

end

%------------------------------------------------------------------
function TF = isInternalInputPixelLabelImageDatastore(ds)
TF = isa(ds,'vision.internal.PixelLabelImageDatastore');
end

%------------------------------------------------------------------
function TF = isInternalInputAssociatedImageDatastore(ds)
TF = isa(ds,'images.internal.datastore.associatedImageDatastore');
end

%------------------------------------------------------------------
function TF = isInternalInputCombinedDatastore(ds)
% Any input datastore pair that results in a combinedDatastore. 
% Note: combinedDatastore input to randomPatchExtractionDatastore function
% is not supported.
TF = isa(ds,'matlab.io.datastore.CombinedDatastore');
end

%------------------------------------------------------------------
function validateIndicesWithinRange(idx,numObservations)
if any((idx < 1) | (idx > numObservations)) && ~islogical(idx)
    error(message('images:randomPatchExtractionDatastore:invalidIndex'));
end
end


