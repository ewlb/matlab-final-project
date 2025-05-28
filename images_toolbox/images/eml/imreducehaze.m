function [finalDehazedOutput, T, atmLight] = imreducehaze(im, varargin) %#codegen
%IMREDUCEHAZE  Reduce atmospheric haze.

% Copyright 2021-2022 The MathWorks, Inc.

% Syntax
% ------
%
% D = imreducehaze(I)
% [D, T, L] = imreducehaze(I)
% [___] = imreducehaze(I, Amount)
% [___] = imreducehaze(__, Name, Value)
%
% Input Specs
% ------------
%
% I:
%   real
%   grayscale or RGB Image
%   uint8, uint16,single or double
%
%   Amount: in the range of [0,1]
%   numeric
%   real,scalar, non-negative
%
% Name-Value Pairs:
%   'Method': 'simpledcp' or 'approxdcp'
%   char or string
%   Default: 'simpledcp'
%
% 'AtmosphericLight':
%   real, non-negative, vector
%   double
%   A scalar (for grayscale) or a 3-element vector
%   (for RGB images) in the range [0,1]
%   Default Value: depends on Method
%
% 'ContrastEnhancement': Contrast enhancement technique
%   'global' (default) | 'boost' | 'none'
%
% 'BoostAmount': Amount of per-pixel gain
%   0.1 (default) | number in the range [0, 1]
%
% Output Specs
% ------------
% D:
% same size and class as of I
%
% T:
% double, 2D array, same size as of I
%
% L:
% double array of size 1-by-3

narginchk(1, 10);

[Ain, amount, method, atmLightIn, contrastMethod, boostAmount, ...
    isRGB] = parseInputs(im, varargin{:});

originalClass = coder.const(class(Ain));

if isfloat(Ain)
    % The algorithm assumes the input image is in [0,1]
    A = min(1, max(0, Ain));
else
    % convert to single if image is not float type
    A = im2single(Ain);
end

amount = cast(amount,'like', A);

if (amount == 0)
    finalDehazedOutput = Ain;
    T = [];
    atmLight = [];
else
    % Choose method to dehaze the image
    switch method
        case SIMPLEDCP
            [deHazed, T, atmLight] = deHazeSimpleDCP(A, amount, atmLightIn, isRGB);
        case APPROXDCP
            [deHazed, T, atmLight] = deHazeApproxDCP(A, amount, atmLightIn, isRGB);
        otherwise
            assert(false);
    end

    % Select method of contrast enhancement (Post-processing)
    switch contrastMethod
        case GLOBAL
            finalDehazedOutputIn = globalStretching(deHazed);
        case BOOST
            finalDehazedOutputIn = boosting(deHazed, amount, boostAmount, 1-T);
        case NONE
            finalDehazedOutputIn = deHazed;
        otherwise
            assert(false);
    end

    % Convert dehazed image and transmission map back to input image class
    finalDehazedOutput = convertToOriginalClass(finalDehazedOutputIn, originalClass);
end


%--------------------------------------------------------------------------
function [B, T, atmLightOut] = deHazeSimpleDCP(A, amount, atmLight, isRGB)
% SimpleDCP
% This function computes dark-channel prior, and refines it using guided
% filter, only across channel elements are considered for dark channel
% estimation

coder.inline('always');
coder.internal.prefer_const(A, amount, atmLight, isRGB);

% 1. Estimate atmospheric light
if isempty(atmLight)
    atmLightUsingQuadTree = computeatmLightUsingQuadTree(A);
    if isRGB
        atmLightIn = reshape(atmLightUsingQuadTree, [1 1 3]);
    else
        atmLightIn = atmLightUsingQuadTree;
    end
else
    if isRGB
        atmLightIn = reshape(atmLight, [1 1 3]);
    else
        atmLightIn = atmLight;
    end
end

% 2. Estimate transmission t(x)
normI = min(A, [] , 3);
transmissionMap = 1 - normI;

% 3. Use guided filtering to refine the transmission map
epsilon = 0.01; % default value
transmissionMap = images.internal.coder.algimguidedfilter(transmissionMap,...
    transmissionMap, [5 5], epsilon);
transmissionMap = min(1, max(0, transmissionMap));
omega = 0.9;

% Thickness of haze in input image is second output of imreducehaze.
% Thickness Map does not depends on amount value.
T = cast(1 - transmissionMap,'double');

% Omega value is set to 0.9, to leave some of haze in restored image for
% natural appearance of dehazed scene
transmissionMap = 1 - omega * (1 - transmissionMap);

% This lower bound preserves a small amount of haze in dense haze regions
t0 = cast(0.1,'like',A);

% Recover scene radiance
radianceMap = atmLightIn + (A - atmLightIn) ./ max(transmissionMap, t0);
radianceMap = min(1, max(0, radianceMap));

% New transmission map based on amount of haze to be removed
newTransmissionMap = min(1, transmissionMap + amount);

% Dehazed output image based on Amount, if Amount == 1,
% then B = radianceMap
B = radianceMap .* newTransmissionMap + ...
    atmLightIn .* (1-newTransmissionMap);

% Reshape atmLight to 1 x 3 vector if input image is RGB
if(isRGB)
    atmLightOut = double(reshape(atmLightIn, [1 3]));
else
    atmLightOut = double(atmLightIn);
end

%--------------------------------------------------------------------------
function [B, T, atmLightOut] = deHazeApproxDCP(A, amount, atmLight,isRGB)
% DCP
% This function computes dark-channel prior, and refines it using guided
% filter, spatial and across channel elements are considered

coder.inline('always');
coder.internal.prefer_const(A, amount, atmLight, isRGB);

% 1. Calculate dark channel image prior
patchSize = ceil(min(size(A,1), size(A,2)) / 400 * 15);
minFiltStrel = strel('square', patchSize);

darkChannel = min(A,[],3);
darkChannel = imerode(darkChannel, minFiltStrel);

% 2. Estimate atmospheric light
if isempty(atmLight)
    if isRGB
        I = rgb2gray(A);
    else
        I = A;
    end
    atmLightIn = estimateAtmosphericLight(A, I, darkChannel);
else
    if isRGB
        atmLightIn = reshape(atmLight, [1 1 3]);
    else
        atmLightIn = atmLight;
    end
end

% 3. Estimate transmission t(x)
normI = A ./ atmLightIn;
normI = min(normI, [] , 3);
transmissionMap = 1 - imopen(normI, minFiltStrel);

% 4. Use guided filtering to refine the transmission map
% Neighborhood size and degree of smoothing chosen
% empirically to approximate soft matting as best as possible.
epsilon = 1e-4;
filterRadius = ceil(min(size(A,1), size(A,2)) / 50);
nhoodSize = 2 * filterRadius + 1;
% Make sure that subsampleFactor is not too large
subsampleFactor = 4;
subsampleFactor = min(subsampleFactor, filterRadius);
transmissionMap = images.internal.coder.algimguidedfilter( ...
    transmissionMap, A, [nhoodSize nhoodSize], epsilon, subsampleFactor);
transmissionMap = min(1, max(0, transmissionMap));
omega = 0.95;

% Thickness of haze in input image is second output of
% imreducehaze.Thickness Map does not depends on amount value.
T = cast(1 - transmissionMap, 'double');

% Omega value is set to 0.9, to leave some of haze in restored image for
% natural appearance of dehazed scene
transmissionMap = 1 - omega * (1 - transmissionMap);

% This lower bound preserves a small amount of haze in dense haze regions
t0 = cast(0.1,'like',A);

% Recover scene radiance
radianceMap = atmLightIn + (A - atmLightIn) ./ max(transmissionMap, t0);
radianceMap = min(1, max(0, radianceMap));

% New transmission map based on amount of haze to be removed
newTransmissionMap = min(1, transmissionMap + amount);

% Dehazed output image based on Amount, if Amount == 1,
% then B = radianceMap
B = radianceMap .* newTransmissionMap + ...
    atmLightIn .* (1-newTransmissionMap);

% Reshape atmLight to 1 x 3 vector if input image is RGB

if(isRGB)
    atmLightOut = double(reshape(atmLightIn, [1 3]));
else
    atmLightOut = double(atmLightIn);
end

%--------------------------------------------------------------------------
function atmosphericLight = estimateAtmosphericLight(A, I, darkChannel)
% Atmospheric light estimation using 0.1% brightest pixels in darkchannel

% First, find the 0.1% brightest pixels in the dark channel.
% This ensures that we are selecting bright pixels in hazy regions.
p = 0.001; % 0.1 percent
[histDC, binCent] = imhist(darkChannel);
binWidth = mean(diff(binCent));
normCumulHist = cumsum(histDC)/(size(A,1)*size(A,2));
binIdx = find(normCumulHist >= 1-p);
darkChannelCutoff = binCent(binIdx(1)) - binWidth/2;

% Second, find the pixel with highest intensity in the
% region made of the 0.1% brightest dark channel pixels.
mask = darkChannel >= darkChannelCutoff;
grayVals = I(mask);
[y, x] = find(mask);
[~, maxIdx] = max(grayVals);

atmosphericLight = A(y(maxIdx(1)), x(maxIdx(1)), :);
atmosphericLight(atmosphericLight == 0) = eps(class(A));


%--------------------------------------------------------------------------
function atmLight = computeatmLightUsingQuadTree(A)
% Quad-tree decomposition of dark channel is used for estimation
% of atmospheric light
coder.inline('always');
coder.internal.prefer_const(A);

[dm, dn, ~] = size(A);
Q = [1, 1, dm, dn];

if (dm>=64 && dn>=64)
    % default values
    numLevels = 5; % Decomposition levels
    % Window size for finding spatial minimum value for dark channel
    winSize = ceil(min(size(A,1),size(A,2)) / 400 * 15);
    minFiltStrel = strel('square', winSize);
    darkChannel = min(A, [], 3);
    darkChannel = imerode(darkChannel, minFiltStrel);
    mu = coder.nullcopy(zeros(1,4));
    quadrantIndex=coder.nullcopy(zeros(4,4));
    for ii=coder.unroll(1:numLevels)
        % Quadrants indices matrix
        quadrantIndex(:,:) = ([Q(1), Q(2), (Q(1)+Q(3))/2, (Q(2)+Q(4))/2;
            Q(1),((Q(2)+Q(4))/2)+1, (Q(1)+Q(3))/2, Q(4);
            ((Q(1)+Q(3))/2)+1, Q(2), Q(3), ((Q(2)+Q(4))/2);
            ((Q(3)+Q(1))/2)+1, ((Q(4)+Q(2))/2)+1, Q(3), Q(4)]);
        quadrantIndex = round(quadrantIndex);

        % Decomposition of dark channel into four quadrants
        firstQuadrant = darkChannel(quadrantIndex(1,1):quadrantIndex(1,3),...
            quadrantIndex(1,2):quadrantIndex(1,4));
        secondQuadrant = darkChannel(quadrantIndex(2,1):quadrantIndex(2,3),...
            quadrantIndex(2,2):quadrantIndex(2,4));
        thirdQuadrant = darkChannel(quadrantIndex(3,1):quadrantIndex(3,3),...
            quadrantIndex(3,2):quadrantIndex(3,4));
        fourthQuadrant = darkChannel(quadrantIndex(4,1):quadrantIndex(4,3),...
            quadrantIndex(4,2):quadrantIndex(4,4));

        % Computation of mean for each quadrant
        mu(1) = mean(firstQuadrant(:));
        mu(2) = mean(secondQuadrant(:));
        mu(3) = mean(thirdQuadrant(:));
        mu(4) = mean(fourthQuadrant(:));

        % Selecting maximum average intensity quadrant
        [~, ind] = max(mu);
        Q = quadrantIndex(ind, :);
    end

    % Selecting bright image pixels based on final decomposed quadrant
    img = A(Q(1):Q(3), Q(2):Q(4), :);
    [mm, nn, pp] = size(img);
    brightIm = ones(mm, nn, pp);

    % Minimum Equilidean distance based bright pixel estimation (= atmLight)
    equiDist = sqrt((abs(brightIm - img)).^2);
    equiDistImage = sum(equiDist, 3);
    equiDistVector = equiDistImage(:);
    imageVector = reshape(img, mm*nn, pp);
    [~, index] = min(equiDistVector);
    atmLight = imageVector(index, :);
else
    % Selecting bright image pixels based on final decomposed quadrant
    img = A(Q(1):Q(3), Q(2):Q(4), :);
    [mm, nn, pp] = size(img);
    brightIm = ones(mm, nn, pp);

    % Minimum Equilidean distance based bright pixel estimation (= atmLight)
    equiDist = sqrt((abs(brightIm-img)).^2);
    equiDistImage = sum(equiDist, 3);
    equiDistVector = equiDistImage(:);
    imageVector = reshape(img, mm*nn, pp);
    [~, index] = min(equiDistVector);
    atmLight = imageVector(index, :);
end

%--------------------------------------------------------------------------
function enhanced = globalStretching(A)
coder.inline('always');
coder.internal.prefer_const(A)

% Global Stretching
chkCast = class(A);

% Gamma correction
gamma = 0.75;
A = A.^gamma;

% Normalization to contrast stretch to [0,1]
A = mat2gray(A);

% Find limits to stretch the image
clipLimit = stretchlim(A,[0.001, 0.999]);

% Adjust the cliplimits
alpha = 0.8;
clipLimit = clipLimit + alpha*(max(clipLimit, mean(clipLimit, 2)) - clipLimit);

% Adjust the image intensity values to new cliplimits
enhanced = imadjust(A, clipLimit);
enhanced = cast(enhanced, chkCast);


%--------------------------------------------------------------------------
function B = boosting(img, amount, boostAmount, transmissionMap)
coder.inline('always');
coder.internal.prefer_const(img, amount, boostAmount, transmissionMap);

% Boost as contrast enhancement technique
boostAmount = boostAmount * (1 - transmissionMap);
B = img .* (1 + (amount * boostAmount));

%--------------------------------------------------------------------------
function J = convertToOriginalClass(I, OriginalClass)
coder.inline('always');
coder.internal.prefer_const(I,OriginalClass);

if strcmp(OriginalClass,'uint8')
    J = im2uint8(I);
elseif strcmp(OriginalClass,'uint16')
    J = im2uint16(I);
elseif strcmp(OriginalClass,'single')
    J = im2single(I);
    J = min(1, max(0, J));
else
    %  double
    J = min(1, max(0, I));
end


%--------------------------------------------------------------------------
function [im, amount, method, atmLight, contrastMethod, ...
    boostAmount, isRGB] = parseInputs(im, varargin)

coder.inline('always');
coder.internal.prefer_const(im, varargin);

coder.internal.errorIf(coder.const(numel(size(im)) == 3) && ...
    ~(size(im,3)==3 || size(im,3)==1), 'images:validate:invalidImageFormat');

isRGB = ndims(im) == 3;

% validate im
validImageTypes = {'single', 'double', 'uint8', 'uint16'};
validateattributes(im, validImageTypes, {'real', 'nonsparse', 'nonempty'}, ...
    mfilename,'im', 1);

% im must be MxN grayscale or MxNx3 RGB
coder.internal.errorIf(~(ismatrix(im) || isRGB), 'images:validate:invalidImageFormat', 'im');

if nargin == 1 || (nargin > 1 && (ischar(varargin{1}) || isstring(varargin{1})))
    amount = 1;
    beginNVIdx = 1;
else
    % validate amount
    validateattributes(varargin{1}, {'numeric'}, ...
        {'scalar', 'real', 'nonnegative', '<=', 1, 'nonsparse', 'nonempty'}, ...
        mfilename, 'Amount');
    amount = varargin{1};
    beginNVIdx = 2;
end

[method, atmLight, contrastMethod, ...
    boostAmount] = parseNameValuePairs(isRGB, varargin{beginNVIdx:end});


%--------------------------------------------------------------------------
% Parse the Name-Value pairs which are optional arguments
function [method, atmLight, contrastMethod, ...
    boostAmount, isAtmLightSpecified] = parseNameValuePairs(isRGB, varargin)
coder.inline('always');
coder.internal.prefer_const(isRGB, varargin);

% Define parser mapping struct
params = struct(...
    'Method', uint32(0),...
    'AtmosphericLight', uint32(0), ...
    'ContrastEnhancement', uint32(0), ...
    'BoostAmount', uint32(0));

% Specify parser options
options = struct(...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

% Parse name-value pairs
pstruct = coder.internal.parseParameterInputs(params, options, varargin{:});

methodString =  coder.internal.getParameterValue(pstruct.Method, ...
    'simpledcp', varargin{:});
atmLight =  coder.internal.getParameterValue(pstruct.AtmosphericLight, ...
    [], varargin{:});
contrastMethodString =  coder.internal.getParameterValue(pstruct.ContrastEnhancement, ...
    'global' , varargin{:});
boostAmount =  coder.internal.getParameterValue(pstruct.BoostAmount, ...
    0.1, varargin{:});

% Check whether atmLight & boostAmount are specified
if coder.const(pstruct.AtmosphericLight == zeros('uint32'))
    isAtmLightSpecified = false;
else
    isAtmLightSpecified = true;
end

if coder.const(pstruct.BoostAmount == zeros('uint32'))
    isBoostAmountSpecified = false;
else
    isBoostAmountSpecified = true;
end

% Validate Parse Options
validateMethod(methodString);
validateAtmosphericLight(atmLight, isRGB, isAtmLightSpecified);
validateContrastEnhancement(contrastMethodString);
validateBoostAmount(boostAmount)

% Convert the strings to corresponding enumerations
method = stringToMethod(methodString);
contrastMethod = stringToContrastEnhancement(contrastMethodString);

coder.internal.errorIf(isBoostAmountSpecified && ~coder.const(contrastMethod == BOOST), ...
    'images:imreducehaze:boostamountShouldNotBeSpecified');

%--------------------------------------------------------------------------
% Validate Method String
function validateMethod(methodString)
coder.inline('always');
validateattributes(methodString, {'char', 'string'}, ...
    {'scalartext'}, mfilename, 'Method');
validatestring(methodString, {'simpledcp', 'approxdcp'}, ...
    mfilename, 'Method');

%--------------------------------------------------------------------------
% Validate Atmospheric Light
function validateAtmosphericLight(atmLight, isRGB, isAtmLightSpecified)
coder.inline('always');
coder.internal.prefer_const(atmLight, isRGB, isAtmLightSpecified);
if isAtmLightSpecified && ~isempty(atmLight)
    if isRGB
        validateattributes(atmLight, {'double'}, {'real', 'vector', 'finite', ...
            'nonnegative', '<=', 1}, mfilename, 'AtmosphericLight');
        coder.internal.errorIf(numel(atmLight) ~= 3, 'images:imreducehaze:invalidAtmLightVector');

    else % gray
        validateattributes(atmLight, {'double'}, {'real', 'scalar', 'finite', ...
            'nonnegative', '<=', 1}, mfilename, 'AtmosphericLight');
    end
end

%--------------------------------------------------------------------------
% Validate ContrastEnhancement String
function validateContrastEnhancement(methodString)
coder.inline('always');
validateattributes(methodString, {'char', 'string'}, ...
    {'scalartext'}, mfilename, 'ContrastEnhancement');
validatestring(methodString,...
    {'global', 'boost', 'none'}, mfilename, 'ContrastEnhancement');

%--------------------------------------------------------------------------
% Validate Boost Amount
function validateBoostAmount(value)
coder.inline('always');
validateattributes(value, {'double'}, {'real', 'scalar', ...
    'nonnan', '>=', 0 , 'finite', '<=', 1, 'nonsparse'}, mfilename, 'BoostAmount');

%--------------------------------------------------------------------------
function method = stringToMethod(mStr)
% Convert Method string to its corresponding enumeration
% Use strncmpi to allow case-insensitive, partial matches
if strncmpi(mStr,'simpledcp',numel(mStr))
    method = SIMPLEDCP;
else % if strncmpi(mStr,'approxdcp',numel(mStr))
    method = APPROXDCP;
end

%--------------------------------------------------------------------------
function contrastEnhancement = stringToContrastEnhancement(cStr)
% Convert ContrastEnhancement string to its corresponding enumeration
% Use strncmpi to allow case-insensitive, partial matches
if strncmpi(cStr,'global',numel(cStr))
    contrastEnhancement = GLOBAL;
elseif strncmpi(cStr,'boost',numel(cStr))
    contrastEnhancement = BOOST;
else % if strncmpi(cStr,'full',numel(cStr))
    contrastEnhancement = NONE;
end

%--------------------------------------------------------------------------
function methodFlag = SIMPLEDCP()
coder.inline('always');
methodFlag = int8(1);

%--------------------------------------------------------------------------
function methodFlag = APPROXDCP()
coder.inline('always');
methodFlag = int8(2);

%--------------------------------------------------------------------------
function contrastEnhancementFlag = GLOBAL()
coder.inline('always');
contrastEnhancementFlag = int8(3);

%--------------------------------------------------------------------------
function contrastEnhancementFlag = BOOST()
coder.inline('always');
contrastEnhancementFlag = int8(4);

%--------------------------------------------------------------------------
function contrastEnhancementFlag = NONE()
coder.inline('always');
contrastEnhancementFlag = int8(5);
