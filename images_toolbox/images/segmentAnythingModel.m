classdef segmentAnythingModel < handle
% sam = segmentAnythingModel() loads a pretrained segment
% anything model trained on the SA-1B dataset. This model can be used to
% interactively segment objects in an image using visual prompts like - points,
% boxes and masks. This pretrained model uses a ViT-B architecture.
%
% Methods
% extractEmbeddings()     - Run the encoder on the input image and cache the embeddings.
% segmentObjectsFromEmbeddings() - Predict object mask from image embeddings.

%   Copyright 2023-2024 The MathWorks, Inc.

    properties (Access=private)
        %SAM VIT Encoder dlnetwork
        vitEncoder
        
        % SAM decoder weights and params
        decoderParams
        
        % SAM network Input Size
        InputSize = [1024, 1024]
        
        % Dataset mean
        DatasetMean = [123.675, 116.28, 103.53]
        
        % Dataset standard deviation
        DatasetStd = [58.395, 57.12, 57.375]

        % Prompt labels
        ForegroundLabel = 1
        BackgroundLabel = 0
        BoxTopLeftLabel = 2
        BoxBottomRightLabel = 3

        % Mask Threshold
        MaskThreshold = 0;

    end

    properties(Access=private)
        % Handle Verbose output
        Printer = []
        % Printer Message Cache
        PrinterMsg = []
        % Total Number of crops to be processed
        NumCrops = 1
        % Current crop
        CurrentCropIdx = 1
        % Handle canceling of autoSAM
        IsCanceled = false
    end

    events
        % Event for point batch processing completion
        PointBatchProcessed
    end


    methods
        function obj = segmentAnythingModel()
        % sam = segmentAnythingModel() loads a pretrained segment
        % anything model trained on the SA-1B dataset. This model can be used to
        % interactively segment objects in an image using visual prompts like - points,
        % boxes and masks. This pretrained model uses a ViT-B architecture.
        %
        % Methods
        % extractEmbeddings()     - Run the encoder on the input image and cache the embeddings.
        % segmentObjectsFromEmbeddings() - Predict object mask from  image embeddings.

        data = images.internal.sam.configureAndLoadSAM(); 
        
        obj.decoderParams = data.params_decoder;
        obj.vitEncoder = data.vitEncoder;

        end

        function embeddings = extractEmbeddings(obj, I)
        % embeddings = extractEmbeddings(sam, I) returns the image embeddings computed
        % by running a forward pass on the encoder of the segment anything model.
        % Here, image I can be a H-by-W-by-3 RGB image or a H-by-W-by-3-by-B batch
        % of RGB images. The embeddings is correspondingly either a 64-by-64-by-256
        % array, or  a 64-by-64-by-256-by-B array.
        
            arguments
                obj
                I {validateImage, mustBeFinite, mustBeReal}
            end
            
            % Preprocess input
            I = preprocess(obj,I);
            
            embeddings = predictEncoder(obj, I);
            embeddings = extractdata(embeddings);
            
        end

        function [masks, scores, maskLogits] = segmentObjectsFromEmbeddings(obj, embeddings, imSize, options)
        % masks = segmentObjectsFromEmbeddings(sam, embeddings, imageSize, Name=Value) segments the object of
        % interest using the image embeddings specified by embeddings and the visual
        % prompts specified through the Name=Value pairs. embeddings are a
        % 64-by-64-by-256 array returned by the extractEmbeddings() method.
        % imSize is the size of the input image used to generate the
        % embeddings. This is a 1-by-2 or a 1-by-3 vector.
        % The masks is a H-by-W logical mask of the object.
        % At the minimum one visual prompt needs to be specified to segment 
        % the object, including Foreground Points or Bounding box.
        % The the visual prompts for interactive segmentation can be specified using
        % the following Name-value pairs:
        %
        % 'ForegroundPoints'       A set of foreground points specified as [x,y]
        %                          pairs, which belong to the object to be
        %                          segmented. This is specified as P-by-2 array,
        %                          with the first column holding the x-coordinate
        %                          of the point and the second column holding the
        %                          y-coordinate.
        %
        %                          Default: []
        %
        % 'BackgroundPoints'       A set of background points specified as [x,y]
        %                          pairs, which do-not belong to the object to be
        %                          segmented and should be excluded from the
        %                          segmentation. This is specified as P-by-2 array,
        %                          with the first column holding the x-coordinate
        %                          of the point and the second column holding the
        %                          y-coordinate.
        %
        %                          Default: []
        %
        % 'BoundingBox'            A rectangular bounding box specified as a 1x4
        %                          vector, containing the bounds of
        %                          the object to be segmented. The boundingBox has
        %                          a [x, y, width, height] format.
        %
        %                          Default: []
        %
        % 'MaskLogits'             The un-thresholded 256-by-256-by-1 mask logits
        %                          returned from the previous call to segment().
        %                          Use this input to refine the previous object
        %                          mask using other prompts like points and boxes.
        %
        %                          Default: []
        %
        % 'ReturnMultiMask'        A logical scalar when set to true returns three
        %                          segmentation masks for the objects. In this case
        %                          the masks are H-by-W-by-3 array. Use this flag
        %                          in cases of ambiguous prompts, like single
        %                          points.
        %  
        %                          Default: false
        %
        % [masks, scores] = segmentObjectsFromEmbeddings(__) returns the scores corresponding
        % to each mask. scores is a numeric scalar when MultiMask is set to
        % false, else scores is a 1x3 numeric vector.
        %
        % [masks, scores, maskLogits] = segmentObjectsFromEmbeddings(__) returns the
        % un-thresholded mask logits before thresholding. The maskLogits can be a
        % 256-by-256 numeric array, or a 256-by-256-by-3 numeric array dependent
        % on the value of the MultiMask option. These MaskLogits can be directly
        % passed into the MaskLogits visual prompt name-value pair in the subsequent
        % calls to segmentObjectsFromEmbeddings(), along with point prompts to refine the object
        % mask further.
        
    
            arguments 
                obj
                embeddings (64, 64, 256) {validateEmbeddings, mustBeFinite, mustBeReal}
                imSize {validateImageSize, mustBeFinite, mustBeReal}
                options.ForegroundPoints {validatePoints, mustBeFinite, mustBeReal, mustBePositive} = []
                options.BackgroundPoints {validatePoints, mustBeFinite, mustBeReal, mustBePositive} = []
                options.BoundingBox {validateBox,mustBeFinite, mustBeReal, mustBePositive} = []
                options.MaskLogits {validateMaskLogits} = [];
                options.ReturnMultiMask (1,1) logical = false
            end

            if(isgpuarray(embeddings) && ~canUseGPU)
                error(message('images:sam:noGPUDetected'));
            end
            
            fgPoints = []; bgPoints = []; bbox = [];

            % Filter out any invalid or out of bound point prompts
            if(~isempty(options.ForegroundPoints))
                fgPoints = filterInvalidPoints(options.ForegroundPoints, imSize);
            end
            if(~isempty(options.BackgroundPoints))
                bgPoints = filterInvalidPoints(options.BackgroundPoints, imSize);
            end
            
            if(~isempty(options.BoundingBox))
                % Convert box prompts to XYXY format 
                bbox = XYWH2XYXY(options.BoundingBox);
                % Filter out any invalid box and clip the box to image bounds
                bbox = filterInvalidBbox(bbox, imSize);
            end

            % At least one of valid foreground point prompt or bounding box
            % prompt needs to be provided
            if(isempty(fgPoints)&&...
               isempty(bbox))
                error(message('images:sam:insufficientPrompts'));
            end

            [masks, scores, maskLogits] = predictDecoderBatch(obj,embeddings, imSize, fgPoints,...
                                                            bgPoints, bbox,...
                                                            options.MaskLogits, 1);
            
            
            masks = postprocessResize(obj, masks, imSize, [1, 1, imSize(2)-1, imSize(1)-1], imSize);

            % Convert to logical
            masks = masks>0;

            % Multi masks handling
            % The masks returned by the decoder are of size = 4. The first
            % token corresponds to a single mask mode. idxs 2,3,4
            % correspond to the 3 multi-mask mode outputs.
            if(~options.ReturnMultiMask)
                idx = 1;
            else
                idx = [2, 3, 4];
            end
            masks = masks(:,:,idx);
            scores = scores(idx);
            maskLogits = maskLogits(:,:,idx);

            masks = gather(masks);
            scores = gather(scores);
            maskLogits = gather(maskLogits);

        end
    end

    methods(Hidden)

        function [masksCC, scores] = segmentObjects(obj, im, options)
            % Segment all objects in the image using SAM model along with
            % point grids. 
            % im is a RGB or, a grayscale numeric image.
            % options is the paramters struct passed in from imsegsam
            % function with the following fields:
            % options.PointGridSize
            % options.PointGridMask
            % options.NumCropLevels
            % options.PointGridDownscaleFactor
            % options.PointBatchSize
            % options.ScoreThreshold
            % options.SelectStrongestThreshold
            % options.MinObjectArea
            % options.MaxObjectArea
            % options.ExecutionEnvironment
            % options.Verbose
            
            % Handle canceling of operation
            obj.IsCanceled = false;
            
            % Reset printer
            obj.Printer = [];
           
            if(string(options.ExecutionEnvironment) == "auto")
                if(canUseGPU)
                    execEnvironment = "gpu";
                else
                    execEnvironment = "cpu";
                end
            else
                execEnvironment = string(options.ExecutionEnvironment);
            end

            if((execEnvironment == "gpu") && ~canUseGPU)
                error(message('images:sam:noGPUDetected'));
            end

            % Cast the image to appropriate device
            if(execEnvironment == "gpu")
                im = gpuArray(im);
            else
                im = gather(im);
            end

            % Process image and image crops and merge the segmentation results.
            % Generate crop boxes based on numcroplevels
            [cropBoxes, cropLvl] = generateImageCropBoxes(size(im), options.NumCropLevels);

            numCropBoxes = size(cropBoxes,1);
            obj.NumCrops = numCropBoxes;
            
            % Variables to consolidate results across croplevels
            allMasksPxIdx = [];
            allScores = [];
            allBoxes = [];

            for cropIdx = 1:numCropBoxes
                
                % Cache crop idx for verbose print
                obj.CurrentCropIdx = cropIdx;
                
                cropIm = imcrop(im,cropBoxes(cropIdx,:));

                % Extract embeddings by running the encoder
                embeddings = extractEmbeddings(obj, cropIm);
                
                % Calculate the gridSize for the crop level
                gridSize = ceil(options.PointGridSize ./ (options.PointGridDownscaleFactor^(cropLvl(cropIdx)-1)));

                % Segment all objects in the the current image crop
                [masksPxIdx, scores, boxes] = segmentAllObjectsFromEmbeddings(obj, embeddings, size(cropIm), cropBoxes(cropIdx,:),...
                                                                            gridSize, options.PointGridMask, options.ScoreThreshold,...
                                                                            options.SelectStrongestThreshold, options.PointBatchSize,...
                                                                            size(im), options.Verbose);
                allMasksPxIdx = cat(2, allMasksPxIdx, masksPxIdx);
                allScores = cat(1, allScores, scores);
                allBoxes = cat(1, allBoxes, boxes);


            end
            
            % Perform NMS across crop levels
            if(~isempty(masksPxIdx))
                [~,~,keepIdx] = selectStrongestBbox(allBoxes, allScores, "OverlapThreshold",options.SelectStrongestThreshold);
                allScores = allScores(keepIdx);
                allMasksPxIdx = allMasksPxIdx(keepIdx);
            end

            if(obj.IsCanceled)
                allMasksPxIdx = [];
                allScores = [];
                allBoxes = [];
            end
            
            % Create a connected component struct 
            masksCC = constructCCStruct(allMasksPxIdx, size(im));


            % Remove all objects lesser than minArea pixels and fill all holes <
            % N pixels. Remove objects > MaxObjectArea
            if(~isempty(allMasksPxIdx))
                [masksCC,scores] = images.internal.sam.filterObjectsBySize(masksCC,allScores,options.MinObjectArea, options.MaxObjectArea);
            end

            scores = gather(scores);
            
            % Clean up printer object for next run
            obj.Printer.linebreak();
            obj.PrinterMsg = [];
            obj.Printer = [];

        end

        function [allMaskPxIdx, allScores, allBoxes] = segmentAllObjectsFromEmbeddings(obj, embeddings, imSize, cropBox, gridSize, roiMask, scoreThreshold, nmsThreshold, pointBatchSize, fullImageSize, verbose)

            obj.IsCanceled = false;
            % Configure printer
            % Handle verbose display
            if(isempty(obj.Printer))
                obj.Printer = vision.internal.MessagePrinter.configure(verbose);

                obj.Printer.linebreak();
                iPrintHeader(obj.Printer);
            end
            
            % define parameters
            iouThreshold = scoreThreshold;
            maskThreshold = 0;
            stabilityScoreOffset = 1;
            stabilityScoreThreshold = 0.92;
            
            % Create a normalized grid of points
            gridPoints = buildPointsGrid(obj, gridSize);
            
            % Scale the grid to image Size
            gridPoints(:,1) = round(gridPoints(:,1)*imSize(2));
            gridPoints(:,2) = round(gridPoints(:,2)*imSize(1));
            
            % Filter out grid points lying out of the mask
            gridPoints = filterGridPoints(gridPoints, roiMask);
            
            totalPoints = size(gridPoints,1);

            % Perform batched inference on the points
            pointsDS = arrayDatastore(gridPoints);
            batchSize = pointBatchSize;
            pointsDS.ReadSize = batchSize;

            allMaskPxIdx = [];
            allScores = [];
            allBoxes = [];
            
            pointsProcessed = 0;

            while(hasdata(pointsDS)&&~obj.IsCanceled)

                fgPoints = read(pointsDS);
                fgPoints = cat(3, fgPoints{:});
                    
                % update num processed points for verbose display
                pointsProcessed = pointsProcessed + size(fgPoints,3);
                
                % Run the decoder
                [masks, scores] = predictDecoderBatch(obj, embeddings, imSize,...
                                                        fgPoints, [], [], [],batchSize);

                % Print progress
                obj.PrinterMsg = iPrintProgress(obj.Printer, obj.PrinterMsg, obj.CurrentCropIdx, obj.NumCrops, pointsProcessed, totalPoints);
                
                % Extract masks and scores corresponding to multi-mask mode
                masks = masks(:,:,2:4,:);
                scores = scores(2:4, :);

                masks = reshape(masks,size(masks,1), size(masks,2),[]);
                scores = scores(:);
                
                % Filter based on pred IOU Threshold
                keepIdx = scores > iouThreshold;
                
                scores = scores(keepIdx);
                masks = masks(:,:,keepIdx);

                % If empty after filtering skip remaining post processing
                % steps and continue
                if(isempty(masks))
                    continue;
                end

                % Calculate stability scores
                stabilityScores = calculateStabilityScores(masks, maskThreshold,...
                                                            stabilityScoreOffset);

                % Filter based on stabilityScores
                keepIdx = stabilityScores >= stabilityScoreThreshold;
                scores = scores(keepIdx);
                masks = masks(:,:,keepIdx);

                % If empty after filtering skip remaining post processing
                % steps and continue
                if(isempty(masks))
                    continue;
                end

                % Resize the masks to full imagesize
                masks = postprocessResize(obj, masks, imSize, cropBox, fullImageSize);

                % Threshold the masks
                masks = masks > obj.MaskThreshold;

                % Convert Masks to a sparse representation - pixelIdxList
                masksPixelIdxList = images.internal.sam.masks2PixelIdxList(masks);

                clear masks;

                % Remove all empty masks
                numMaskElements = cellfun(@(x)numel(x),masksPixelIdxList);
                validMaskIdx = ~(numMaskElements==0);
                masksPixelIdxList = masksPixelIdxList(validMaskIdx);
                scores = scores(validMaskIdx);

                % Calculate mask Boxes for NMS
                maskBoxes = masksPixelIdxList2bbox(masksPixelIdxList, fullImageSize(1:2));

                % Perform NMS
                [~,~,keepIdx] = selectStrongestBbox(maskBoxes, scores, "OverlapThreshold",nmsThreshold);
                scores = scores(keepIdx);
                masksPixelIdxList = masksPixelIdxList(keepIdx);
                maskBoxes = maskBoxes(keepIdx,:);

                %Remove any mask close to the crop edge
                [maskBoxes, keepIdx] = filterBoxesNearCropEdge(maskBoxes, cropBox, fullImageSize);
                masksPixelIdxList = masksPixelIdxList(keepIdx);
                scores = scores(keepIdx);

                %If empty after filtering skip remaining post processing
                %steps and continue
                if(isempty(maskBoxes))
                    continue;
                end


                allMaskPxIdx = cat(2, allMaskPxIdx, masksPixelIdxList);
                allScores = cat(1, allScores, (scores));
                allBoxes = cat(1, allBoxes, (maskBoxes));
                
                % Notify completion of a single point batch processing
                evtData = images.internal.sam.SAMPointBatchEventData(obj.CurrentCropIdx,obj.NumCrops,pointsProcessed,totalPoints);
                notify(obj,'PointBatchProcessed',evtData);
               
            end
            
            if(obj.IsCanceled)
                allMaskPxIdx = [];
                allScores = [];
                allBoxes = [];
                return;
            end
            % Perform NMS across point batches
            if(~isempty(allBoxes))
                [allBoxes,~,keepIdx] = selectStrongestBbox(allBoxes, allScores, "OverlapThreshold",nmsThreshold);
                allScores = allScores(keepIdx);
                allMaskPxIdx = allMaskPxIdx(keepIdx);
            end
            
        end

        function stop(obj)
            obj.IsCanceled = true;
        end
    end

    methods(Access=private)

        function gridPoints = buildPointsGrid(obj, pointsPerSide)

            offset = 1./(2.*pointsPerSide);
            % Generate grid points
            [X, Y] = meshgrid(offset(1):1/pointsPerSide(1):1-offset(1),...
                              offset(2):1/pointsPerSide(2):1-offset(2));
            gridPoints = [X(:), Y(:)];

        end


        function [masks, scores, maskLogits] = predictDecoderBatch(obj,embeddings, imSize, fgPoints, bgPoints,...
                                                                    bboxes, maskLogits, batchSize)
            
            % Run batched inference on the decoder
            pointPrompts = [];
            pointPromptLabels = [];

            % Foreground points
            if(~isempty(fgPoints))
                % The imported ONNX decoder expects points as 1xnumPointsx2
                fgPoints = single(fgPoints);
                numPoints = size(fgPoints, 1);
                fgPoints = permute(fgPoints, [3 1 2]);
                fgLabels = repmat(obj.ForegroundLabel, [1, numPoints]);

                pointPrompts = cat(2, pointPrompts, fgPoints);
                pointPromptLabels = cat(2, pointPromptLabels, fgLabels);
            end
            
            % Background points
            if(~isempty(bgPoints))
                % The imported ONNX decoder expects points as 1xnumPointsx2
                bgPoints = single(bgPoints);
                numPoints = size(bgPoints, 1);
                bgPoints = permute(bgPoints, [3 1 2]);
                bgLabels = repmat(obj.BackgroundLabel, [1, numPoints]);

                pointPrompts = cat(2, pointPrompts, bgPoints);
                pointPromptLabels = cat(2, pointPromptLabels, bgLabels);
            end

            % Bounding box prompts
            if(~isempty(bboxes))
                bboxes = single(bboxes);
                [boxPointPrompts, boxPointLabels] = boxPrompts2Points(obj,bboxes);
                pointPrompts = cat(2, pointPrompts, boxPointPrompts);
                pointPromptLabels = cat(2, pointPromptLabels, boxPointLabels);
            end
            
            % Scale the point prompts to resized image coordinates
            resizeScale = getImageResizeScale(obj,imSize);
            pointPrompts = scalePointPrompts(obj, pointPrompts, resizeScale);

            if(isempty(bboxes))
                batchSize = size(pointPrompts,1);
                emptyPoint = [0,0]; emptyPoint = permute(emptyPoint,[3, 1, 2]);
                emptyPoint = repmat(emptyPoint, [batchSize 1 1]);
                pointPrompts = cat(2, pointPrompts, emptyPoint);
                pointPromptLabels = cat(2, pointPromptLabels, -1);
                pointPromptLabels = repmat(pointPromptLabels,[batchSize 1]);
            end

            % Mask prompts            
            if(~isempty(maskLogits))
                hasMaskPrompt = single(1);
                maskPrompts = maskLogits;
            else
                hasMaskPrompt = single(0);
                maskPrompts = zeros(256,256,1, 'single');
            end
            
            imSize = single(imSize(1:2));
            if(isrow(imSize))
                imSize = imSize';
            end
            
            % Enable gpu processing based on the type of embeddings
            if(isgpuarray(embeddings))
                pointPrompts = gpuArray(pointPrompts);
                pointPromptLabels = gpuArray(pointPromptLabels);
                maskPrompts = gpuArray(maskPrompts);
                imSize = gpuArray(imSize);
                hasMaskPrompt = gpuArray(hasMaskPrompt);
            end
            
            % The SAMDecFcn performs post processing as well.
            [masks, scores, maskLogits] = images.internal.sam.SAMDecFcn(embeddings,pointPrompts,pointPromptLabels,...
                                                                maskPrompts, hasMaskPrompt, imSize, obj.decoderParams);
        end
            
        function [pointPrompts, pointLabels] = boxPrompts2Points(obj,bbox)
            % Convert[X1 Y1 X2 Y2] box into a point prompt- [X1 Y1 ; X2 Y2]
            bbox = [bbox(1,1:2);bbox(1,3:4)];
            pointPrompts = permute(bbox, [3 1 2]);
            pointLabels = [obj.BoxTopLeftLabel, obj.BoxBottomRightLabel];
        end

        function points = scalePointPrompts(~, points, scale)
        % Scale points from input image space to resized image space
        % Change the coordinate from MATLAB's spatial system (0.5 based)
        % to 0 based expected by SAM.
            points = (points - 0.5)*scale;

        end

        function scale = getImageResizeScale(obj, imageSize)
        % Query the image resize scale
            inputSize = obj.InputSize(1);
            if imageSize(1) > imageSize(2)
                scale = inputSize / imageSize(1);
            else
                scale = inputSize / imageSize(2);
            end
        end

        function embeddings = predictEncoder(obj, I)
           
            if(isgpuarray(I) && ~canUseGPU)
                error(message('images:sam:noGPUDetected'));
            end
            
            % Run forward on the encoder
            dlX = dlarray(I,'SSCB');
            embeddings = predict(obj.vitEncoder, dlX);

        end

        function [processedImg, scale] = preprocess(obj, I)

            input_size = obj.InputSize(1);
            image_size = size(I);
            
            % Resize
            % Resize Image to Inputsize maintaining the aspect ratio and
            % padding the end with zeroes
            if image_size(1) > image_size(2)
                Iresized = imresize(I,[input_size,nan], "bilinear");
                scale = input_size / size(I,1);
                Iresized = padarray(Iresized,[0,input_size-size(Iresized,2)],'post');
            else
                Iresized = imresize(I,[nan,input_size], "bilinear");
                scale = input_size / size(I,2);
                Iresized = padarray(Iresized,[input_size-size(Iresized,1),0],'post');
            end

            % Grayscale to color
            if(size(I,3)==1)
                Iresized = repmat(Iresized,[1 1 3]);
            end
            
            % Normalize
            Iresized = single(Iresized);
            pixel_mean = reshape(obj.DatasetMean, 1,1,3);
            pixel_std = reshape(obj.DatasetStd, 1,1,3);
            processedImg = (Iresized - pixel_mean) ./ pixel_std;
        end

        function postProcessedImg = postprocessResize(obj, im, cropSize, cropBox, originalImSize)

            
            % Resize the low resolution masks to full image size
            if(cropSize(1) > cropSize(2))
                % Vertical image
                im = imresize(im, [cropSize(1), nan], "bilinear");
            else
                im = imresize(im, [nan, cropSize(2)], "bilinear");
            end

            postProcessedCrop = im(1:cropSize(1), 1:cropSize(2),:);

            postProcessedImg = zeros(originalImSize(1), originalImSize(2), size(im,3), 'like', im);
            postProcessedImg(cropBox(1,2):cropBox(1,2)+cropBox(1,4),...
                             cropBox(1,1):cropBox(1,1)+cropBox(1,3), :) = ...
                              postProcessedCrop;
        end

    end

    methods(Static,Hidden)
        function info = samSpkgInfo()
            info = images.internal.sam.configureAndLoadSAM(true);
        end
    end
end


%--------------------------------------------------------------------------
function validateImage(in)
    tf = (isnumeric(in)||islogical(in))&&...
         ndims(in)<=4 && ... && numdims should be less than 3 
         (size(in,3)==3||size(in,3)==1); % gray scale or RGB image
    if(~tf)
        error(message('images:sam:invalidImageInput'));
    end
end

%--------------------------------------------------------------------------
function validateEmbeddings(in)
    tf = isnumeric(in)&&...
         ndims(in) == 3 &&...
         (size(in,1)==64 && size(in,2)==64 && size(in,3)==256); % Should be a 64x64x256 input
    if(~tf)
        error(message('images:sam:invalidEmbeddings'));
    end
end

%--------------------------------------------------------------------------
function validateImageSize(in)
    tf = isnumeric(in)&&...
         (numel(in)==2||numel(in)==3);
    if(~tf)
        error(message('images:sam:invalidImageSize'));
    end
end
%--------------------------------------------------------------------------
function tf = validatePoints(in)
    tf = isempty(in)||...
         (isnumeric(in)&&...
         ndims(in)==2 && ... && numdims should be 2
         size(in,2)==2); %#ok<ISMAT> % Second dim should be of size 2 (Px2)
    if(~tf)
        error(message('images:sam:invalidPoints'));
    end
end

%--------------------------------------------------------------------------
function tf = validateBox(in)
    tf = isempty(in)||...
         (isnumeric(in)&&...
         ndims(in)==2 && ... && numdims should be 2
         size(in,1)==1&&...
         size(in,2)==4); %#ok<ISMAT> % Second dim should be of size 4 (1x4)
    if(~tf)
        error(message('images:sam:invalidBox'));
    end
end
%--------------------------------------------------------------------------
function tf = validateMaskLogits(in)
    tf = isempty(in)||...
         (isnumeric(in)&&...
         ndims(in) == 2 &&...
         (size(in,1)==256 && size(in,2)==256)); %#ok<ISMAT> % Should be a 256x256x1x1 input
    if(~tf)
        error(message('images:sam:invalidMaskLogits'));
    end
end

%--------------------------------------------------------------------------
function points = filterInvalidPoints(points, imSize)

    H = imSize(1);
    W = imSize(2);

    validIdx = ((points(:,1) >= 0.5) & (points(:,1) <= W + 0.5)) &...
                    ((points(:,2) >= 0.5) & (points(:,2) <= H + 0.5));

    points = points(validIdx, :);

end

function bbox = masksPixelIdxList2bbox(masksPixelIdxList, maskSize)
   % Compute mask bbox from pixelIdxList
    for idx = 1:length(masksPixelIdxList)
        [r,c]  = ind2sub(maskSize, masksPixelIdxList{idx});
    
        minR = min(r);
        maxR = max(r);
        minC = min(c);
        maxC = max(c);
   
        bbox(idx,:) = [minC minR maxC-minC+1 maxR-minR+1];
    end
end

%--------------------------------------------------------------------------
function boxXYXY = XYWH2XYXY(boxXYWH)
    boxXYXY = [boxXYWH(:,1),...
               boxXYWH(:,2),...
               boxXYWH(:,1)+boxXYWH(:,3),...
               boxXYWH(:,2)+boxXYWH(:,4)];
end

%--------------------------------------------------------------------------
function boxXYWH = XYXY2XYWH(boxXYXY)
    boxXYWH = [boxXYXY(:,1),...
               boxXYXY(:,2),...
               boxXYXY(:,3)-boxXYXY(:,1),...
               boxXYXY(:,4)-boxXYXY(:,2)];
end

%--------------------------------------------------------------------------
function bbox = filterInvalidBbox(bbox, imSize)
    % Filter boxes outside the image bounds
    H = imSize(1);
    W = imSize(2);

    % Check if the boxes are completely out of bounds, or is second edge is
    % less than positive edge
    if( (bbox(1,3) < 1)||...
        (bbox(1,4) < 1)||...
        (bbox(1,1) > W)||...
        (bbox(1,2) > H))
        
        bbox = [];
        return;
    end
    % Clip boxes in image bounds
    bbox(1,1) = max(1, bbox(1,1));
    bbox(1,2) = max(1, bbox(1,2));
    bbox(1,3) = min(W, bbox(1,3));
    bbox(1,4) = min(H, bbox(1,4));

end

%--------------------------------------------------------------------------
function stabilityScores = calculateStabilityScores(masks, maskThreshold, thresholdOffset)
    % Compute stability scores for masks by addingand subtracting a offset
    % from masks and computing the IOU from thresholded masks in bith the
    % scenarios.
    intersection = sum ( masks > (maskThreshold+thresholdOffset), [1 2]);
    union = sum ( masks > (maskThreshold-thresholdOffset), [1 2]);
    stabilityScores = squeeze(intersection./union);
end

%--------------------------------------------------------------------------
function CC = constructCCStruct(pixelIdxList, imSize)
    % Create the connected component structure
    CC.Connectivity = 8;
    CC.ImageSize = [imSize(1), imSize(2)];
    CC.NumObjects = length(pixelIdxList);
    CC.PixelIdxList = pixelIdxList;
end

%--------------------------------------------------------------------------
function gridPoints = filterGridPoints(gridPoints, roiMask)
    % Filter out the grid points outside the foreground region of the mask
    linIdx = sub2ind(size(roiMask), gridPoints(:,2), gridPoints(:,1));
    inROI = roiMask(linIdx);

    gridPoints = gridPoints(inROI,:);

end

%--------------------------------------------------------------------------
function [cropBoxes, cropLevel] = generateImageCropBoxes(imSize, nCropLevels)
    % Generate all image crops based on NUmCropLevels
    % Original Image
    cropBoxes(1,:) = [1 1 imSize(2)-1 imSize(1)-1];
    cropLevel (1) = 1;

    if(nCropLevels==1)
        return;
    end
    cropOverlapRatio = 512/1500;
    shortSide = min(imSize(1), imSize(2));

    for lvlIdx = 2:nCropLevels

        cropPerSide = 2^(lvlIdx-1);
        overlap = floor(cropOverlapRatio * shortSide * (2/cropPerSide));

        cropWidth = ceil( (overlap * (cropPerSide-1) + imSize(2) ) / cropPerSide);
        cropHeight = ceil( (overlap * (cropPerSide-1) + imSize(1) ) / cropPerSide);

        cropX = floor( (cropWidth-overlap) .* (0:1:cropPerSide-1)) +1;
        cropY = floor( (cropHeight-overlap) .* (0:1:cropPerSide-1)) +1;

        for x = cropX
            for y = cropY

                cropBoxes(end+1, :) = [x, y , min(x+cropWidth, imSize(2)), min(y+cropHeight, imSize(1))];
                cropLevel(end+1) = lvlIdx;
            end
        end

    end

    cropBoxes = XYXY2XYWH(cropBoxes);
end

%--------------------------------------------------------------------------
function [maskBoxes, keepidx] = filterBoxesNearCropEdge(maskBoxes, cropBox, fullImageSize)
% Filter boxes near crop edges, while retaining the boxes close to image
% edge.

numBoxes = size(maskBoxes,1);
maskBoxesXYXY = XYWH2XYXY(maskBoxes);
cropBoxXYXY = XYWH2XYXY(cropBox);
imageBoxXYXY = [1, 1, fullImageSize(2), fullImageSize(1)];

absTol = 20;

isNearCropEdge = abs(maskBoxesXYXY-repmat(cropBoxXYXY,[numBoxes,1]))<=absTol;
isNearImageEdge = abs(maskBoxesXYXY-repmat(imageBoxXYXY,[numBoxes,1]))<=absTol;

isNearCropEdge = isNearCropEdge & ~isNearImageEdge;
keepidx = ~ any(isNearCropEdge,2);

maskBoxes = maskBoxes(keepidx, :);

end

%--------------------------------------------------------------------------
function iPrintHeader(printer)
    printer.printMessage('images:autoSAM:verboseHeader');
    printer.print('---------------------------------------------');
    printer.linebreak();
end

%--------------------------------------------------------------------------
function updateMessage(printer, prevMessage, nextMessage)
    backspace = sprintf(repmat('\b',1,numel(prevMessage))); % figure how much to delete
    printer.print([backspace nextMessage]);
end

%--------------------------------------------------------------------------
function nextMessage = iPrintProgress(printer, prevMessage, currCropIdx, numCrops, currPoints, totalPoints)
    nextMessage = getString(message('images:autoSAM:verboseProgressTxt',...
                                    currCropIdx, numCrops, currPoints, totalPoints));
    updateMessage(printer, prevMessage, nextMessage);
end

