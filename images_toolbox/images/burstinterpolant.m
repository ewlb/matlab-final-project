function superResolvedImage = burstinterpolant(imds, tforms, scale)

narginchk(3,3);

[lChannelImages, refImage, tforms] = parseInputs(imds, tforms, scale);
originalClass = class(refImage); % Get the class of the image.

% Inverse Distance Weighting based interpolation.
upscaledImage = imgInterpolation(lChannelImages, tforms, scale);

% Get the size of upscaled image.
[m, n, ~] = size(upscaledImage);

if size(refImage,3) == 3
    refImage = rgb2lab(refImage);
    resizedImage = imresize(refImage(:,:,2:3),[m n],'bicubic');
    % Adding the a and b channels back to the upscaledImage
    upscaledImage(:,:,2:3) = resizedImage;
    upscaledImage = lab2rgb(upscaledImage);
end

% Convert back to original class
superResolvedImage = convertToOriginalClass(upscaledImage, originalClass);

end

function hrImg = imgInterpolation(lowResImgs, tforms, scale)

% Size of image
imSize = size(lowResImgs(:,:,1));
imCenter = (imSize+1)/2;

% Total number of images
numImgs = size(lowResImgs, 3);
% Find the rotation and translation between the reference image and moving
% image
estTheta = zeros(numImgs, 1);
estDelta = zeros(numImgs, 2);

for ii = 2: numImgs
    estTForm = tforms(ii-1).T;
    estTheta(ii,1) = (atan2d(estTForm(2,1) ,estTForm(1,1)));
    estDelta(ii,:) = [estTForm(3,1) estTForm(3,2)];

end

% High resolution to Low resolution transformation (Inverse transformation)
transformations = zeros(3,3, numImgs);
for i = 1: numImgs

    % Transformation matrix
    tCenter = [1 0 0;0 1 0;-imCenter(1) -imCenter(2) 1];
    tRotation = [cosd(estTheta(i)) sind(estTheta(i))  0; ...
        -sind(estTheta(i)) cosd(estTheta(i)) 0; 0 0 1];
    tTranslationBackToOrigin = [1 0 0;0 1 0; imCenter(1) imCenter(2) 1];
    initialtform = tCenter*tRotation*tTranslationBackToOrigin;

    % incorporate scale
    tformCenteredRotation = initialtform * (1/cast(scale,'double').*eye(3));
    tformCenteredRotation(3,3)= 1;

    % incorporate delta
    tform = tformCenteredRotation;
    tform(3,1:2) = tform(3,1:2)+estDelta(i,:);
    transformations(:,:,i) = tform;
end

%  Inverse Distance Weighting based interpolation
hrImg = images.internal.builtins.interpolation_halide(lowResImgs,transformations, scale);

end


function [Images, refImage, tforms] = parseInputs(im, tforms, scale)

% Validate attributes for first argument
if iscell(im)
    matlab.images.internal.errorIfgpuArray(im{:}, tforms, scale);
    validateattributes(im, {'cell'}, ...
        {'nonempty','vector'}, mfilename, 'images');

elseif isa(im,'matlab.io.datastore.ImageDatastore')
    validateattributes(im, {'matlab.io.datastore.ImageDatastore', ...
        'matlab.io.datastore.TransformedDatastore'}, ...
        {'nonempty','vector'}, mfilename, 'images');

    validateattributes(im.Files, {'cell'}, ...
        {'nonempty'}, mfilename, 'images');
elseif isa(im, 'matlab.io.datastore.TransformedDatastore')
     validateattributes(im, {'matlab.io.datastore.TransformedDatastore'}, ...
        {'nonempty','vector'}, mfilename, 'images');
    validateattributes(im.UnderlyingDatastore.Files, {'cell'}, ...
        {'nonempty'}, mfilename, 'images');
else
   error(message('images:burstinterpolant:invalidInput'));
end

% Validate attributes for second argument
if ~(isobject(tforms))
    error(message('images:burstinterpolant:invalidTformType'));
end

% validate attributes for third argument
validateattributes(scale,{'numeric'},...
    {'nonsparse', 'nonempty','real', 'scalar', 'nonnan',...
    'finite', 'positive', '>=', 1}, mfilename, 'Scale');

% Verify the first input argument
if iscell(im)
    nframes = numel(im);
    refImage = im{1};
elseif isa(im,'matlab.io.datastore.ImageDatastore')
    nframes = numel(im.Files);
    refImage = readimage(im, 1);
elseif isa(im,'matlab.io.datastore.TransformedDatastore')
    nframes = numel(im.UnderlyingDatastore.Files);
    refImage = read(im);
end

% Validate the number of images
% Require more than 1 image for interpolation
if nframes <=1
    error(message('images:burstinterpolant:insufficientInputImages'));
end

% Validate the reference image
validateattributes(refImage, {'single', 'double', 'uint8', 'uint16'},...
    {'nonsparse', 'real', 'finite', 'nonnegative','nonnan'}, mfilename, 'Image', 1);

% Check if, number of tforms in affine2d object are one less than total
% number of images.
ntrames = numel(tforms);
if ntrames ~= nframes-1
    error(message('images:burstinterpolant:incorrectNumberoftforms'));
end

% Check image is rgb or gray scale
isRGB = size(refImage, 3);

% Check image size
chkSize = size(refImage);

% Decide the image class
chkClass = class(refImage);

% Store all the images into array
Images = zeros([chkSize(1) chkSize(2) nframes]);

if iscell(im)
    for imgCount = 1:nframes
        validateattributes(im{imgCount},...
            {'single', 'double', 'uint8', 'uint16'},...
            {'real', 'nonsparse', 'finite','nonnegative', 'nonempty', 'nonnan',...
            'size', chkSize}, mfilename, 'Image', imgCount);

        if ~(strcmp(chkClass,class(im{imgCount})))
            error(message('images:burstinterpolant:invalidImageClass'));
        end

        if isRGB == 3
            Images(:,:,imgCount) = rgb2lightness(im{imgCount});
        elseif isRGB == 1
            % If image is not double or single, default its converted into
            % double.
            if ~(isa(chkClass, 'double') || isa(chkClass, 'single'))
                Images(:,:,imgCount) = im2double(im{imgCount});
            end
        else
            % Images expected to be grayscale or RGB.
            error(message('images:burstinterpolant:invalidFormat'));
        end
    end

else

    im = im.copy();
    im.reset();
    i = 1;

    while(im.hasdata)
        readImg = read(im);
        validateattributes(readImg,...
            {'single', 'double', 'uint8', 'uint16'},...
            {'real', 'nonsparse', 'finite', 'nonnegative', 'nonempty', 'nonnan',...
            'size', chkSize}, mfilename, 'Image', i);

        if ~(strcmp(chkClass,class(readImg)))
            error(message('images:burstinterpolant:invalidImageClass'));
        end

        % Convert the RGB images to lightness
        if isRGB == 3
            Images(:,:,i) = rgb2lightness(readImg);
        elseif isRGB == 1
            Images(:,:,i) = im2double(readImg);
        else
            % Images expected to be grayscale or RGB.
            error(message('images:burstinterpolant:invalidFormat'));
        end
        i = i+1;
    end
end

end

function B = convertToOriginalClass(B, OriginalClass)
% Convert back to original datatype
if strcmp(OriginalClass, 'uint8')
    B = im2uint8(B);
elseif strcmp(OriginalClass, 'uint16')
    B = im2uint16(B);
elseif strcmp(OriginalClass, 'single')
    B = im2single(B);
else
    %  double
    B = im2double(B);
end
end

% Copyright 2018-2022 The MathWorks, Inc.
