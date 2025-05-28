function [masks, scores] = imsegsam(im, options)
% masks = imsegsam(I, Name=Value) segments all the objects in an
% image I using the Segment Anything Model. I here is a H-by-W-by-3 RGB
% image, or a H-by-W-by-1 grayscale image. The segmented masks are returned
% as a connected component object, holding the foreground pixel indices for
% each object.
%
% [ __ , scores]  = imsegsam(I, Name=Value), returns the
% prediction confidence scores for each of the segmented object as a
% numObjects-by-1 numeric vector.
%
% The the visual prompts for interactive segmentation can be specified using
% the following Name-value pairs:
%
% 'PointGridSize'          The number of points to be sampled along the
%                          X and the Y direction, expressed as a
%                          [sizeX, sizeY] vector. The SAM model uses
%                          these grid points as prompts for segmenting
%                          objects at these locations. When multiple
%                          crop levels are used, the PointGridSize is
%                          down-scaled by the factor specified by
%                          GridDownscaleFactor N-V pair.
%                          Use a higher PointGridSize value for images
%                          with smaller and close together objects.
%
%                          Default: [32, 32]
%
% 'PointGridMask'          The ROI within the image to segment objects
%                          from specified as a logical mask of the same
%                          spatial size as the input image. Any points
%                          in the points grid lying outside the foreground
%                          region will be discarded and not used as
%                          prompts to segment the objects.
%
%                          Default: true(size(I,1), size(I,2))
%
% 'NumCropLevels'          The number of levels to take image crops
%                          from.  At each level the image is divided
%                          into 2^(level-1)-by-2^(level-1) number of
%                          crops. The object segmentation is run again
%                          for each of the crops resized up to the model
%                          input size. Use this option if you have
%                          small objects in your image which are not
%                          captured by a single level grid. Note that
%                          using more levels comes at a cost of
%                          significantly slow down of the processing of
%                          the image.
%
%                          Default: 1
%
% 'PointGridDownscaleFactor' The PointGridSize scale down factor at each crop
%                          level. The PointGridSize is scaled down by a
%                          factor of pow(PointGridDownscaleFactor, n-1) at the
%                          nth crop level.
%
%                          Default: 2
%
% 'PointBatchSize'         The number of point pronpts that are batched
%                          and processed together while running SAM's
%                          mask decoder. A higher batch size can speed-
%                          up the processing, but comes with a penalty
%                          of higher memory usage. If running out of
%                          memory, try using a lower PointBatchSize.
%
%                          Default: 64
%
% 'ScoreThreshold'         A scalar between 0 and 1. Detections
%                          with scores less than the threshold
%                          value are removed. Increase this value
%                          to reduce false positives.
% 
%                          Default: 0.8
%
% 'SelectStrongestThreshold' The IoU threshold used by the non maximum
%                          supression algorithm to remove duplicate
%                          object segmentations. Any two objects with
%                          IoU above this value will be trated as
%                          duplicate and only the one with higher score
%                          will be retained.
%
%                          Default: 0.7
%
% 'MinObjectArea'          The smallest size of a valid object. Any
%                          object with an area smaller than the
%                          MinObjectArea will be discarded. Also, any
%                          hole smaller than the MinObjectArea will be
%                          filled.
% 
%                          Default: 0
%
% 'MaxObjectArea'         The largest size of a valid object. Any
%                         object with an area larger than the
%                         MaxObjectArea will be discarded.
% 
%                         Default: 0.95*size(I,1)*size(I,2)
%
% 'ExecutionEnvironment' Hardware resource on which to run the model,
%                        specified as one of these values -
%                        {"cpu", "gpu", "auto"}.
%                        "auto" uses the GPU if available, otherwise
%                        runs the inference on CPU.
%     
%                        Default: "auto"
%
% 'Verbose'              Set true to display progress information.
%  
%                        Default: true

%   Copyright 2023-2024 The MathWorks, Inc.

arguments
    im {validateImageInput}
    options.PointGridSize (1,2) {mustBeNumeric, mustBeVector, mustBePositive, mustBeFinite, mustBeReal, mustBeInteger} = [32, 32]
    options.PointGridMask {validateROIMask(options.PointGridMask,im)} = true(size(im,1), size(im,2))
    options.NumCropLevels (1,1) {mustBeNumeric, mustBePositive, mustBeFinite, mustBeScalarOrEmpty, mustBeReal, mustBeInteger} = 1 
    options.PointGridDownscaleFactor (1,1) {mustBeNumeric, mustBePositive, mustBeFinite, mustBeScalarOrEmpty, mustBeReal, mustBeInteger} = 2 
    options.PointBatchSize (1,1) {mustBeNumeric, mustBePositive, mustBeFinite, mustBeScalarOrEmpty, mustBeReal, mustBeInteger} = 64
    options.ScoreThreshold (1,1){mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(options.ScoreThreshold, 1), mustBeReal} = 0.88
    options.SelectStrongestThreshold (1,1){mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(options.SelectStrongestThreshold, 1), mustBeReal} = 0.7
    options.MinObjectArea (1,1) {mustBeNumeric, mustBeFinite, mustBeReal, validateObjectArea(options.MinObjectArea, im)} = 0
    options.MaxObjectArea (1,1) {mustBeNumeric, mustBePositive, mustBeFinite, mustBeReal, validateObjectArea(options.MaxObjectArea, im)} = 0.95*size(im,1)*size(im,2)
    options.ExecutionEnvironment {mustBeMember(options.ExecutionEnvironment,{'gpu','cpu','auto'})} = 'auto'
    options.Verbose (1,1) {validateLogicalFlag}= true
end


% Verify If maxObjectArea is greater than minObjectArea
if(options.MinObjectArea > options.MaxObjectArea)
    error(message('images:autoSAM:invalidMinMaxObjectArea'));
end

% Verify that the image size is greater than the pointGridSize
if(any(size(im, [2 1]) < options.PointGridSize))
    error(message('images:autoSAM:invalidImageSize', options.PointGridSize(1), options.PointGridSize(2)));
end

% Load SAM
persistent sam
if(isempty(sam))
    if(options.Verbose)
        disp(getString(message('images:autoSAM:loadSAM')));
    end

    sam = segmentAnythingModel();

    if(options.Verbose)
        disp(getString(message('images:autoSAM:loadSAMComplete')));
    end
end

% Invoke automatic segmentation using SAM
[masks, scores] = segmentObjects(sam, im, options);

end

%--------------------------------------------------------------------------
function tf = validateImageInput(in)
    
tf = (isnumeric(in)||islogical(in))&&...
         ndims(in)<=3 && ~isscalar(in) && ~isvector(in) &&... && numdims should be less than 3 
         (size(in,3)==3||size(in,3)==1); % gray scale or RGB image
if(~tf)
    error(message('images:autoSAM:invalidImageInput'));
end

end

%--------------------------------------------------------------------------
function tf = validateROIMask(in, im)
    
tf = islogical(in)&&...
         ndims(in)==2 && ... && numdims should be 2 
         size(in,1)==size(im,1) && ...
         size(in,2)==size(im,2);
if(~tf)
    error(message('images:autoSAM:invalidPointGridMask'));
end

end

%--------------------------------------------------------------------------
function tf = validateObjectArea(objArea, im)
% Object Area must be between 0 and image area.
tf = (objArea >= 0) && (objArea <= (size(im,1)*size(im,2)));

if(~tf)
    error(message('images:autoSAM:invalidObjectArea'));
end
end

%--------------------------------------------------------------------------
function validateLogicalFlag(in)
    validateattributes(in,{'logical'}, {'scalar','finite', 'real'});
end