function hdr = makehdr(filenames, varargin)
%MAKEHDR Create high dynamic range image.
%   HDR = MAKEHDR(FILES) creates a single-precision high dynamic range
%   image HDR from a set of spatially registered low dynamic range (LDR) 
%   images listed in FILES. FILES is an array of strings, or a cell array 
%   of character vectors.  These files must contain EXIF exposure metadata.
%   The "middle" exposure value between the brightest and darkest images is
%   used as the base exposure for the high dynamic range calculations.
%   (This value does not need to appear in any particular file.)
%
%   HDR = MAKEHDR(IMDS) creates a single-precision high dynamic range
%   image HDR from the set of spatially registered low dynamic range images
%   in imageDatastore IMDS.
%
%   HDR = MAKEHDR(___, NAME, VALUE, ...) creates a high dynamic range image
%   from the low dynamic range images, specifying parameters and
%   corresponding values that control various aspects of the image
%   creation. Parameter names can be abbreviated, and case does not matter.
%
%   HDR = MAKEHDR(IMAGES, 'RelativeExposure', RE) creates a   
%   single-precision HDR image from a set of LDR images contained in 
%   IMAGES. Use the parameter 'RelativeExposure' to specify the relative
%   exposure values for the input images. IMAGES is a cell array of 
%   matrices of size MxN or MxNx3. The input LDR images must have the same 
%   dimensions. 
%
%   HDR = MAKEHDR(IMAGES, 'ExposureValues', EV) creates a
%   single-precision HDR image from a set of LDR images contained in 
%   IMAGES. Use the parameter 'ExposureValues' to specify the exposure
%   values for the input images. IMAGES is a cell array of matrices of size 
%   MxN or MxNx3. The input LDR images must have the same dimensions.
%
%   Parameters include:
%
%   'BaseFile'                 Character array or string containing the 
%                              name of the file to use as the base
%                              exposure.
%
%   'ExposureValues'           A vector of exposure values, with one
%                              element for each low dynamic range image in
%                              FILES. An increase of one exposure value
%                              (EV) corresponds to a doubling of exposure,
%                              while a decrease in one EV corresponds to a
%                              halving of exposure. Any positive value is
%                              allowed.  This parameter overrides EXIF
%                              exposure metadata.
%
%   'RelativeExposure'         A vector of relative exposure values, with
%                              one element for each low dynamic range image
%                              in FILES.  An image with a relative exposure
%                              (RE) of 0.5 has half as much exposure as an
%                              image with an RE of 1.  An RE value of 3 has
%                              three times the exposure of an image with an
%                              RE of 1. This parameter overrides EXIF
%                              exposure metadata.
%
%   'MinimumLimit'             A numeric scalar value that specifies the
%                              minimum "correctly exposed" value. For each
%                              low dynamic range image, pixels with smaller
%                              values are considered underexposed and will
%                              not contribute to the final high dynamic
%                              range image. Default value is assumed to be
%                              2% of the maximum intensity allowed by the
%                              data type of the images.
%
%   'MaximumLimit'             A numeric scalar value that specifies the
%                              maximum "correctly exposed" value. For each
%                              low dynamic range image, pixels with larger
%                              values are considered overexposed and will
%                              not contribute to the final high dynamic
%                              range image. Default value is assumed to be
%                              98% of the maximum intensity allowed by the
%                              data type of the images.
%
%   'CameraResponse'           An array that specifies mapping of the scene
%                              radiance to the image pixel intensity. It
%                              must be N-by-3 for color images and N-by-1
%                              for grayscale images, where N is 256 for
%                              uint8 images or 65536 for uint16 images.
%
%   Class Support 
%   ------------- 
%   The input images can be color or grayscale. They can have any bit
%   depth. Preferred bit depth for low dynamic range image is 8 or 16.
%   Input LDR images must have the same bit depth and class. The output
%   image HDR is of single-precision.
%
%   Notes
%   -----
%   [1] When input is FILES, specify only one of these parameters:
%       'BaseFile', 'ExposureValues', or 'RelativeExposure'.
%   [2] When input is IMAGES, specify either of the parameters
%       'RelativeExposure' or 'ExposureValues' for exposure information.
%       'BaseFile' cannot be used in this case.
%   [3] 'MaximumLimit' and 'MinimumLimit' values are ignored when 
%       'CameraResponse' is specified.
%
%   References
%   ----------
%   [1] Reinhard, et al. "High Dynamic Range Imaging." 2006. Ch. 4.
%   [2] Paul E. Debevec and Jitendra Malik. "Recovering high dynamic range
%   radiance maps from photographs." ACM SIGGRAPH 2008 classes. ACM, 2008.
%
%   Example 1:
%   ----------
%   %  Make a high dynamic range image from a series of six low dynamic
%   %  range images that share the same F-Stop number and have different
%   %  exposure times. Use TONEMAP to visualize the HDR image.
%
%      files = ["office_1.jpg", "office_2.jpg", "office_3.jpg", ...
%               "office_4.jpg", "office_5.jpg", "office_6.jpg"];
%      expTimes = [0.0333, 0.1000, 0.3333, 0.6250, 1.3000, 4.0000];
%
%      hdr = makehdr(files, 'RelativeExposure', expTimes ./ expTimes(1));
%      rgb = tonemap(hdr);
%      figure; imshow(rgb)
%
%   Example 2:
%   ----------
%   %  Make a high dynamic range image using crf curve from a series of six
%   %  low dynamic range images specified by their location. These files
%   %  contain EXIF exposure metadata. Use TONEMAP to visualize the HDR
%   %  image.
%
%     setDir = fullfile(toolboxdir('images'), 'imdata','office_*');
%     imds = imageDatastore(setDir);
%     % Estimate crf using CAMRESPONSE
%     crf = camresponse(imds);
%     hdr = makehdr(imds, 'CameraResponse', crf);
%     rgb = tonemap(hdr);
%     figure; imshow(rgb)
%
%   Example 3:
%   ----------
%   %  Make a high dynamic range image from a series of six low dynamic
%   %  range images that have different exposure times. Use TONEMAP to
%   %  visualize the HDR image.
%
%      im1 = imread('office_1.jpg'); im2 = imread('office_2.jpg'); 
%      im3 = imread('office_3.jpg'); im4 = imread('office_4.jpg');
%      im5 = imread('office_5.jpg'); im6 = imread('office_6.jpg');
%      images = {im1, im2, im3, im4, im5, im6};
%      expTimes = [0.0333, 0.1000, 0.3333, 0.6250, 1.3000, 4.0000];
%
%      hdr = makehdr(images, 'RelativeExposure', expTimes ./ expTimes(1));
%      rgb = tonemap(hdr);
%      figure; imshow(rgb)
%
%   See also HDRREAD, HDRWRITE, LOCALTONEMAP, TONEMAP, TONEMAPFARBMAN,
%   CAMRESPONSE.

%   Copyright 2007-2019 The MathWorks, Inc.

% Parse and check inputs.
narginchk(1,9)

% Retrofit code to accept array of strings. Convert cellstr to allow rest
% of code to continue to work as designed with cellstr input.
validateattributes(filenames,{'cell','string','matlab.io.datastore.ImageDatastore'},...
    {'nonempty'},mfilename,'files',1);
if isa(filenames,'matlab.io.datastore.ImageDatastore')
    validateattributes(filenames.Files, {'cell'}, ...
        {'nonempty'}, mfilename, 'files',1);
end
if iscell(filenames)
    fnameInit = filenames{1};
elseif isstring(filenames)
    filenames = cellstr(filenames);
    fnameInit = filenames{1};
elseif isa(filenames,'matlab.io.datastore.ImageDatastore')
    filenames = filenames.copy();
    filenames.reset();
    fnameInit = filenames.Files{1};
end

usingMatrices = validateImages(filenames, fnameInit);

% Get the metadata from the first image file
meta = getMetaData(fnameInit, usingMatrices);

numImage = numel(filenames);
if isa(filenames,'matlab.io.datastore.ImageDatastore')
    numImage = numel(filenames.Files);
end

% Get the number of channels
numPlanes = 1;
if strcmp(meta.ColorType, 'truecolor')
    numPlanes = 3;
end

varargin = matlab.images.internal.stringToChar(varargin);
options = parseArgs(meta, varargin{:});
validateOptions(options, numImage, usingMatrices, filenames, meta, numPlanes);


if isempty(options.CameraResponse)
    % HDR image estimation
    hdr = gethdrWithoutCrf(filenames,options,meta,fnameInit,numImage,numPlanes, usingMatrices);
else % HDR image estimation using CRF
    hdr = gethdrWithCrf(filenames,options,meta,fnameInit,numImage,numPlanes, usingMatrices);
end


%--------------------------------------------------------------------------
function usingMatrices = validateImages(filenames, fnameInit)
    usingMatrices = false;
    % Check if the input is a cell array of matrices
    if (isa(fnameInit, 'uint8') || isa(fnameInit, 'uint16') || ...
        isa(fnameInit, 'uint32') || isa(fnameInit, 'uint64'))
        usingMatrices = true;
        % Check if non-empty images with 1 or 3 channels are the inputs
        for numImage = 1:numel(filenames)
            if ((size(filenames{numImage},3) ~= 1) && (size(filenames{numImage},3) ~= 3)) || ...
                (isequal(size(filenames{numImage}),[0,0])) || (~isreal(filenames{numImage}))
                error(message('images:makehdr:incorrectInputImages'));
            end
            % Ensure rest of the inputs are of supported type too
            validateattributes(filenames{numImage}, ...
                {'uint8', 'uint16', 'uint32','uint64'}, {'nonsparse'},...
                mfilename, 'IMAGES');
        end
    elseif issparse(fnameInit)
        error(message('images:makehdr:incorrectInputImages'));
    elseif isnumeric(fnameInit) || islogical(fnameInit)
        error(message('images:makehdr:incorrectDataType'));
    end


%--------------------------------------------------------------------------
function hdr = gethdrWithoutCrf(filenames,options,meta,fnameInit,numImage,numPlanes, usingMatrices)
% Create output variables for an accumulator and the number of LDR images
% that contributed to each pixel.
[hdr, properlyExposedCount] = makeContainers(meta,fnameInit,numPlanes);
% Construct the HDR image by iterating over the LDR images.
% Get the minimum exposure image from the user or make a first pass through
% the images to find the lowest exposure image.

if ~isempty(options.BaseFile)
    [baseTime, baseFStop] = getExposure(options.BaseFile, usingMatrices);
elseif (isempty(options.RelativeExposure) && isempty(options.ExposureValues))
    [baseTime, baseFStop] = getAverageExposure(filenames, usingMatrices);
end

someUnderExposed = false(size(hdr));
someOverExposed = false(size(hdr));
someProperlyExposed = false(size(hdr));
% Read the LDR image
if (usingMatrices)
    images = filenames;
else
    images = loadImage(filenames, meta, numImage, numPlanes, usingMatrices);
end
for p = 1:numImage
    if isa(filenames,'matlab.io.datastore.ImageDatastore')
       fname = filenames.Files{p}; 
    else
        fname = filenames{p};
    end
    if ~isempty(options.ExposureValues)
        % Convert log2 EV equivalents to decimal values.
        relExposure = 2 .^ options.ExposureValues(p);
    elseif ~isempty(options.RelativeExposure)
        relExposure = options.RelativeExposure(p);
    else
        [this_ExposureTime, this_FNumber] = getExposure(fname, usingMatrices);
        relExposure = computeRelativeExposure(baseFStop, ...
            baseTime, ...
            this_FNumber, ...
            this_ExposureTime);
    end
    
    % Read the LDR image
    ldr = images{p};
    
    underExposed = ldr < options.MinimumLimit;
    someUnderExposed = someUnderExposed | underExposed;
    
    overExposed = ldr > options.MaximumLimit;
    someOverExposed = someOverExposed | overExposed;
    
    properlyExposed = ~(underExposed | overExposed);
    someProperlyExposed = someProperlyExposed | properlyExposed;
    
    properlyExposedCount(properlyExposed) = properlyExposedCount(properlyExposed) + 1;
    
    % Remove over- and under-exposed values.
    ldr(~properlyExposed) = 0;
    
    % Bring the intensity of the LDR image into a common HDR domain by
    % "normalizing" using the relative exposure, and then add it to the
    % accumulator.
    hdr = hdr + single(ldr) ./ relExposure;
end
% Average the values in the accumulator by the number of LDR images
% that contributed to each pixel to produce the HDR radiance map.
hdr = hdr ./ max(properlyExposedCount, 1);

% For pixels that were completely over-exposed, assign the maximum
% value computed for the properly exposed pixels.
maxVal = max(hdr(someProperlyExposed));
if ~isempty(maxVal)
    % If maxVal is empty, then none of the pixels are correctly exposed.
    % Don't bother with the rest; hdr will be all zeros.
    hdr(someOverExposed & ~someUnderExposed & ~someProperlyExposed) = maxVal;
end

% For pixels that were completely under-exposed, assign the
% minimum value computed for the properly exposed pixels.
minVal = min(hdr(someProperlyExposed));
if ~isempty(minVal)
    % If minVal is empty, then none of the pixels are correctly exposed.
    % Don't bother with the rest; hdr will be all zeros.
    hdr(someUnderExposed & ~someOverExposed & ~someProperlyExposed) = minVal;
end

% For pixels that were sometimes underexposed, sometimes
% overexposed, and never properly exposed, use regionfill.
fillMask = someUnderExposed & someOverExposed & ~someProperlyExposed;
if any(fillMask(:))
    hdr(:,:,1) = regionfill(hdr(:,:,1), fillMask(:,:,1));
    if ~ismatrix(hdr)
        hdr(:,:,2) = regionfill(hdr(:,:,2), fillMask(:,:,2));
        hdr(:,:,3) = regionfill(hdr(:,:,3), fillMask(:,:,3));
    end
end


%--------------------------------------------------------------------------
function hdr = gethdrWithCrf(filenames,options,meta,fnameInit,numImage,numPlanes, usingMatrices)
% Create output variables for an accumulator and the number of LDR images
% that contributed to each pixel.

[hdr, ~] = makeContainers(meta,fnameInit,numPlanes);
% Construct the HDR image by iterating over the LDR images.
% With using crf curve.

validateCRF(options, meta, numPlanes)

if ~isempty(options.ExposureValues)
    exposure = options.ExposureValues;
elseif ~isempty(options.RelativeExposure)
    exposure = options.RelativeExposure./mean(options.RelativeExposure);
else
    exposure = zeros(1,numImage);
    for p = 1:numImage
        if isa(filenames,'matlab.io.datastore.ImageDatastore')
            fname = filenames.Files{p};            
        else
            fname = filenames{p};
        end
        exposure(p) = getExposure(fname, usingMatrices);
    end
end

% Loading logarithm exposures
% do scaling to avoid negative values (as log is undefined)
if min(exposure)<0
    exposure = (exposure - min(exposure) + 1)./abs(min(exposure));
end
logExpo = log(exposure);

% Weighting Function
bitsPerSample = meta.BitDepth / numPlanes;
maxVal = 2^bitsPerSample-1;
weight = 0:maxVal;
weight(ceil(maxVal/2)+1:maxVal+1) = maxVal - weight(ceil(maxVal/2)+1:maxVal+1);

% camera response curve
CRF = options.CameraResponse;
% Read all LDR images
if (usingMatrices)
    images = filenames;
else
    images = loadImage(filenames, meta, numImage, numPlanes, usingMatrices);
end
% HDR estimation
for itr = 1:numPlanes
    nrSum = 0;
    drSum = 0;
    lnCRF = CRF(:,itr);
    % HDR estimation using all images
    for n = 1:numImage
        ldr = images{n};
        w = weight(single(ldr(:,:,itr))+1);
        nrSum = nrSum + (w.*((lnCRF(ldr(:,:,itr)+1))-(logExpo(n))));
        drSum = drSum + w;
    end
    hdr(:,:,itr) = single(exp(nrSum./(drSum+eps)));
end


%--------------------------------------------------------------------------
function [baseTime, baseFStop] = getExposure(filename, usingMatrices)
% Extract the exposure values from a file containing EXIF metadata.

exif = getExposureDataFromFile(filename, usingMatrices);
baseFStop = exif.FNumber;
baseTime = exif.ExposureTime;


%--------------------------------------------------------------------------
function [baseTime, baseFStop] = getAverageExposure(filenames, usingMatrices)
% Extract the average exposure (assuming constant illumination) from a set
% of files containing EXIF metadata.  The average exposure may not actually
% correspond to the exposure of any particular image.

minTime = 0;
minFStop = 0;
maxTime = 0;
maxFStop = 0;

% Look through all of the files and keep track of the least and greatest
% exposure.
numImage = numel(filenames);
if isa(filenames,'matlab.io.datastore.ImageDatastore')
    numImage = numel(filenames.Files);
end
for p = 1:numImage
    if iscell(filenames)
        fname = filenames{p};
    elseif isa(filenames,'matlab.io.datastore.ImageDatastore')
        fname = filenames.Files{p};
    end
    exif = getExposureDataFromFile(fname, usingMatrices);
    if (p == 1)
        % First file.
        minFStop = exif.FNumber;
        minTime = exif.ExposureTime;
        maxFStop = exif.FNumber;
        maxTime = exif.ExposureTime;
    else
        % Nth file.
        if (computeRelativeExposure(minFStop, ...
                minTime, ...
                exif.FNumber, ...
                exif.ExposureTime) < 1)
            
            % Image has least exposure so far.
            minFStop = exif.FNumber;
            minTime = exif.ExposureTime;
            
        elseif (computeRelativeExposure(maxFStop, ...
                maxTime, ...
                exif.FNumber, ...
                exif.ExposureTime) > 1)
            
            % Image has most exposure so far.
            maxFStop = exif.FNumber;
            maxTime = exif.ExposureTime;
        end
    end
end

% Determine the "middle" exposure value.  It's easier to manipulate
% exposure time rather than f/stop.
re = computeRelativeExposure(minFStop, minTime, ...
    maxFStop, maxTime);
baseFStop = minFStop;
baseTime  = minTime * log2(re);


%--------------------------------------------------------------------------
function exif = getExposureDataFromFile(filename, usingMatrices)
% Extract exposure metadata from a file containing EXIF.

meta = getMetaData(filename, usingMatrices);
if isfield(meta, 'DigitalCamera')
    exif = meta.DigitalCamera;
else
    error(message('images:makehdr:exifFormat', filename));
end

if (isempty(exif) || ...
        ~isstruct(exif) || ...
        ~isfield(exif, 'FNumber') || ...
        ~isfield(exif, 'ExposureTime'))
    
    error(message('images:makehdr:noExposureMetadata', filename));
end


%--------------------------------------------------------------------------
function meta = getMetaData(filename, usingMatrices)

if (usingMatrices)
    % Estimate the Metadata 
    % Metadata requires Height, Width, BitDepth, Channels & ColorType
    % FNumber & ExposureTimes are omitted 
    [Height, Width, Channels] = size(filename);
    BitDepth = Channels*str2double(regexp(class(filename),'\d+','match'));
    if Channels == 3
        ColorType = 'truecolor';
    else
        ColorType = 'grayscale';
    end
    
    meta = struct('Height', Height, 'Width', Width, 'BitDepth', BitDepth, ...
        'NumberOfChannels', Channels, 'ColorType', ColorType);
else 
    try
    meta = imfinfo(filename);
    catch ME
        if (isequal(ME.identifier, 'MATLAB:imagesci:imfinfo:fileOpen'))
            error(message('images:makehdr:fileNotFound', filename));
        else
            % Unexpected error
            rethrow(ME)
        end
    end

    % If there are several images in the file,
    % use the meta data of the first one
    if ~isscalar(meta)
        meta = meta(1);
    end
end


%--------------------------------------------------------------------------
function relExposure = computeRelativeExposure(f1, t1, f2, t2)

% Exposure varies directly with the exposure time and inversely with the
% square of the F-stop number.
relExposure = (f1 / f2)^2 * (t2 / t1);


%--------------------------------------------------------------------------
function options = parseArgs(meta, varargin)
% Parse the parameter-value pairs, getting default values.

parser = inputParser();
parser.FunctionName = mfilename;

% NameValue 'BaseFile'
defaultBaseFile = '';
validateBaseFile = @(x) validateattributes(x, ...
    {'char'}, ...
    {'vector'}, ...
    mfilename,'BaseFile');
parser.addParameter('BaseFile', ...
    defaultBaseFile, ...
    validateBaseFile);

% NameValue 'ExposureValues'
defaultExposureValues = [];
validateExposureValues = @(x) validateattributes(x, ...
    {'single','double'}, ...
    {'vector', 'real', 'finite', 'nonnan'}, ...
    mfilename,'ExposureValues');
parser.addParameter('ExposureValues', ...
    defaultExposureValues, ...
    validateExposureValues);

% NameValue 'RelativeExposure'
defaultRelativeExposure = [];
validateRelativeExposure = @(x) validateattributes(x, ...
    {'single','double'}, ...
    {'vector', 'real', 'finite', 'positive', 'nonzero'}, ...
    mfilename,'RelativeExposure');
parser.addParameter('RelativeExposure', ...
    defaultRelativeExposure, ...
    validateRelativeExposure);

% NameValue 'MinimumLimit'
defaultMinimumLimit = [];
validateMinimumLimit = @(x) validateattributes(x, ...
    {'single','double'}, ...
    {'scalar', 'real','integer', 'nonnan', 'positive','nonsparse'}, ...
    mfilename,'MinimumLimit');
parser.addParameter('MinimumLimit', ...
    defaultMinimumLimit, ...
    validateMinimumLimit);

% NameValue 'MaximumLimit'
defaultMaximumLimit = [];
validateMaximumLimit = @(x) validateattributes(x, ...
    {'single','double'}, ...
    {'scalar', 'real','integer', 'nonnan', 'positive','nonsparse'}, ...
    mfilename,'MaximumLimit');
parser.addParameter('MaximumLimit', ...
    defaultMaximumLimit, ...
    validateMaximumLimit);

% NameValue 'CameraResponse'
defaultCRF = [];
validateCRF = @(x) validateattributes(x, ...
    {'single','double'}, ...
    {'2d', 'real', 'finite','nonempty'}, ...
    mfilename,'CameraResponse');
parser.addParameter('CameraResponse', ...
    defaultCRF, ...
    validateCRF);

parser.parse(varargin{:});
options = parser.Results;

% Determine the range of the first image
numSamples = 1;
if strcmp(meta.ColorType, 'truecolor')
    numSamples = 3;
end
bitsPerSample = meta.BitDepth / numSamples;
maxVal = 2^bitsPerSample-1;

if isempty(options.MinimumLimit)
    % Default is 2% of range
    options.MinimumLimit = round(0.02 * maxVal);
end

if isempty(options.MaximumLimit)
    % Default is 98% of range
    options.MaximumLimit = round((1-0.02) * maxVal);
end


%--------------------------------------------------------------------------
function validateOptions(options, numImage, usingMatrices, files, meta, numPlanes)

fieldCount = 0;

if (usingMatrices)
    if (isempty(options.ExposureValues) && isempty(options.RelativeExposure))
        error(message('images:makehdr:incorrectNumberOfParameters'));
    elseif (~isempty(options.ExposureValues) && ~isempty(options.RelativeExposure))
        error(message('images:makehdr:incorrectNumberOfParameters'));
    end     
    if (usingMatrices)
        images = files;
    else
        images = loadImage(files, meta, numImage, numPlanes, usingMatrices);
    end
    for imgCount=2:numImage
        if (~strcmp(class(images{1}), class(images{imgCount})))
            error(message('images:makehdr:matricesNotSameClass'));
        end
        if ~isequal(size(images{imgCount},1),meta.Height) ...
                || ~isequal(size(images{imgCount},2),meta.Width) ...
                || ~isequal(size(images{imgCount},3),numPlanes)
            error(message('images:makehdr:matrixDimensions'));
        end
    end
else
    % Make sure that mutually exclusive options aren't provided.
    if ~isempty(options.BaseFile)
        fieldCount = fieldCount + 1;
    end
    if ~isempty(options.ExposureValues)
        fieldCount = fieldCount + 1;
    end
    if ~isempty(options.RelativeExposure)
        fieldCount = fieldCount + 1;
    end
    if (fieldCount > 1)
        error(message('images:makehdr:tooManyExposureParameters'))
    end
end

% Make sure that the correct number of exposure-related values are given.
if (~isempty(options.ExposureValues) ...
        && (numel(options.ExposureValues) ~= numImage))
    error(message('images:makehdr:wrongExposureValuesCount'))
elseif (~isempty(options.RelativeExposure) ...
        && (numel(options.RelativeExposure) ~= numImage))
    error(message('images:makehdr:wrongRelativeExposureCount')) 
end


%--------------------------------------------------------------------------
function validateCRF(options, meta, numPlanes)
% Make sure that size of the camera response curve array is '2^N-by-(1 or 3)'.
% where, N is the bit depth

bitsPerSample = meta.BitDepth / numPlanes;
if ~isequal(size(options.CameraResponse,2), numPlanes)...
        || ~isequal(size(options.CameraResponse,1), 2^bitsPerSample)
    error(message('images:makehdr:invalidCRFSize',2^bitsPerSample,numPlanes))
    % Size of 'CameraResponse' should be {0}-by-{1}
end


%--------------------------------------------------------------------------
function [hdr, counts] = makeContainers(meta,filename,numPlanes)
% Create a floating point accumulator for the final HDR image
% and a counter for the number of contributing images.

if ~(strcmp(meta.ColorType, 'truecolor') ...
        || strcmp(meta.ColorType, 'grayscale'))
    error(message('images:validate:invalidImageFormat',filename))
end

hdr = zeros(meta.Height, meta.Width, numPlanes, 'single');
counts = zeros(meta.Height, meta.Width, numPlanes, 'single');


%--------------------------------------------------------------------------
function images = loadImage(files, meta, numImage, numPlanes, usingMatrices)
% Read all LDR images
images = cell(1,numImage);

% Load all images
if isa(files,'matlab.io.datastore.ImageDatastore')
    for imgCount = 1:numImage
        images{imgCount} = readimage(files,imgCount);
    end
else
    for imgCount = 1:numImage
        images{imgCount} = imread(files{imgCount});
    end
end

if isa(files,'matlab.io.datastore.ImageDatastore')
    files = files.Files'; % To validate dimensions and bitdepth
end

% Make sure all images have same dimensions
for imgCount = 1:numImage
    if ~isequal(size(images{imgCount},1),meta.Height) ...
        || ~isequal(size(images{imgCount},2),meta.Width) ...
            || ~isequal(size(images{imgCount},3),numPlanes)
        error(message('images:makehdr:imageDimensions', files{imgCount}));
    end
end

% Make sure all images have same bitdepth
for imgCount = 1:numImage
    metatemp = getMetaData(files{imgCount}, usingMatrices);
    if ~isequal(metatemp.BitDepth,meta.BitDepth)
        error(message('images:makehdr:imageBitDepth', files{imgCount}));
    end
end