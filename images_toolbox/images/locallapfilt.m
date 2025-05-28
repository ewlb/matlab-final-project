function output = locallapfilt(varargin)
inputs = parseInputs(varargin{:});

input = inputs.A;
sigma = inputs.sigma;
alpha = inputs.alpha;
beta  = inputs.beta;
processLuminance   = inputs.ProcessLuminance;
numIntensityLevels = inputs.NumIntensityLevels;

% Determine the maximum number of pyramid levels to which the input image
% must be decomposed to. This is chosen as the number of levels at which
% the shorter dimension reduces to one pixel in size.
numPyrLevels = floor( log2( min( size(input, [1 2]) ) ) ) + 1;

output = llf(input, sigma, alpha, beta, numIntensityLevels, ...
                processLuminance, numPyrLevels);
end

%--------------------------------------------------------------------------
function inputs = parseInputs(varargin)

narginchk(3,10);

% Convert string inputs to character vectors.
args = matlab.images.internal.stringToChar(varargin);

% Parse inputs with basic validation
parser = inputParser();
parser.FunctionName = mfilename;

% A
validateInput = @(x) validateattributes(x, ...
    {'single','uint8','uint16','int8','int16'}, ...
    {'real','nonsparse','nonempty'}, ...
    mfilename,'A',1);
parser.addRequired('A', validateInput);

% sigma is expected non-negative
validateSigma = @(x) validateattributes(x, ...
    {'numeric'}, ...
    {'scalar','real','nonnegative','finite','nonsparse','nonempty'}, ...
    mfilename,'sigma',2);
parser.addRequired('sigma', validateSigma);

% alpha is expected positive
validateAlpha = @(x) validateattributes(x, ...
    {'numeric'}, ...
    {'scalar','real','positive','finite','nonsparse','nonempty'}, ...
    mfilename,'alpha',3);
parser.addRequired('alpha', validateAlpha);

% Optional beta parameter
defaultBeta = 1;
% beta is expected non-negative
validateBeta = @(x) validateattributes(x, ...
    {'numeric'}, ...
    {'scalar','real','nonnegative','finite','nonsparse','nonempty'}, ...
    mfilename,'beta',4);
parser.addOptional('beta', ...
    defaultBeta, ...
    validateBeta);

% NameValue 'NumIntensityLevels'
defaultNumIntensityLevels = 'auto';
parser.addParameter('NumIntensityLevels', ...
    defaultNumIntensityLevels, ...
    @validateNumIntensityLevels);

% NameValue 'ColorMode'
defaultColorMode = 'luminance';
% expected string 'luminance' or 'separate'
validateColorMode = @(x) validateattributes(x, ...
    {'char'}, ...
    {}, ...
    mfilename,'ColorMode');
parser.addParameter('ColorMode', ...
    defaultColorMode, ...
    validateColorMode);

parser.parse(args{:});
inputs = parser.Results;

% Post-processing and additional validation

% A must be MxN grayscale or MxNx3 RGB
validColorImage = (ndims(inputs.A) == 3) && (size(inputs.A,3) == 3);
if ~(ismatrix(inputs.A) || validColorImage)
    error(message('images:validate:invalidImageFormat','A'));
end

inputs.sigma = single(inputs.sigma);
inputs.alpha = single(inputs.alpha);
inputs.beta  = single(inputs.beta);

% Deal with ('NumIntensityLevels','auto')
if ischar(inputs.NumIntensityLevels)
    validatestring(inputs.NumIntensityLevels, ...
        {'auto'}, mfilename, 'NumIntensityLevels');
    inputs.NumIntensityLevels = getAutoNumIntensityLevels(inputs.alpha);
end
inputs.NumIntensityLevels = int32(inputs.NumIntensityLevels);

inputs.ColorMode = validatestring( ...
    inputs.ColorMode, ...
    {'luminance','separate'}, ...
    mfilename, 'ColorMode');
inputs.ProcessLuminance = strcmp(inputs.ColorMode, 'luminance');
end

%--------------------------------------------------------------------------
function TF = validateNumIntensityLevels(x)

if ~ischar(x)
    validateattributes(x, ...
        {'numeric'}, ...
        {'scalar','real','positive','integer', ...
        'finite','nonsparse','nonempty'}, ...
        mfilename,'NumIntensityLevels');
end

TF = true;
end

%--------------------------------------------------------------------------
function numIntensityLevels = getAutoNumIntensityLevels(alpha)

if alpha < 0.1
    % for strong contrast increase, use many intensity levels
    % to increase the quality of the output image
    numIntensityLevels = 50;
elseif alpha < 0.9
    % Progressively increase the number of intensity levels
    % from 16 to 50 as we strengthen the amount of details increase
    numIntensityLevels = round(((50*0.9-16*0.1) - (50-16)*alpha)/(0.9-0.1));
else
    % for a small contrast increase or any kind of smoothing
    % a low number of intensity levels is enough
    numIntensityLevels = 16;
end
end


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
function output = llf(input, sigma, alpha, beta, numIntensityLevels, processLuminance, numPyramidLevels)
if (alpha == 1 && beta == 1) || (sigma == 0 && beta == 1)
    output = input;
    return
end

isRGB = size(input,3) == 3;
origClass = class(input);

% Scale to single in the 0-1 range.
if isa(input, 'int8')
    input = (single(input) + 128) / 255;
else
    input = im2single(input);
end

if isRGB && processLuminance
    [gray,ratios] = convertRGBToGrayFloat(input);
    filtered = llfCore(gray, sigma, alpha, beta, numIntensityLevels, numPyramidLevels);
    output = filtered.*ratios;
else
    for pInd = size(input,3):-1:1
        output(:,:,pInd) = llfCore(input(:,:,pInd), sigma, alpha, beta, numIntensityLevels, numPyramidLevels);
    end
end

% Scale back to input type
switch origClass
    case 'uint8'
        output = im2uint8(output);
    case 'int8'        
        output = int8(output*255-128);
    case 'uint16'
        output = im2uint16(output);
    case 'int16'
        output = im2int16(output);        
    otherwise
        % Has to be single, pass through.
end

end % 

%--------------------------------------------------------------------------
function [output,ratios] = convertRGBToGrayFloat(input)
kRCoeff = single(0.298936021293776);
kGCoeff = single(0.587043074451121);
kBCoeff = single(0.114020904255103);
output = kRCoeff * input(:,:,1) + kGCoeff * input(:,:,2) + kBCoeff * input(:,:,3);
ratios = input ./ (repmat(output, [1 1 3]) + eps('single'));
end

%--------------------------------------------------------------------------
function output = llfCore(input, sigma, alpha, beta, numIntensityLevels, numPyramidLevels)

minVal = min(input(:));
maxVal = max(input(:));

% Special case: 1 sample
if (numIntensityLevels == 1)
    refVal = (minVal+maxVal)/2;
    output = images.internal.builtins.llf.remap(input, refVal, sigma, alpha, beta);
    return
end

% Special case: flat image
if (minVal == maxVal)
    output = input;
    return
end

% Gaussian pyramid of the input
inGPyramid = cell(numPyramidLevels,1);
inGPyramid{1} = input;
for i = 2:numPyramidLevels
    inGPyramid{i} = images.internal.builtins.llf.pyrdownsample(inGPyramid{i-1});
end

% Allocate space for the output Laplacian pyramid and initialize to zero
outLPyramid = cell(numPyramidLevels,1);
outLPyramid{numPyramidLevels} = inGPyramid{numPyramidLevels};
for i = 1:numPyramidLevels-1
    outLPyramid{i} = zeros(size(inGPyramid{i}),'like',input);
end

% Gaussian and Laplacian pyramids of the remapped image
rGPyramid = cell(numPyramidLevels,1);
rLPyramid = cell(numPyramidLevels,1);

% Sequentially construct the Laplacian pyramid of the output
delta = (maxVal - minVal) / cast(numIntensityLevels-1,'like',input);
for k = 0:(numIntensityLevels-1)
    % Form the remapped, intermediate image
    refVal = minVal + single(k) * delta;

    remapped = images.internal.builtins.llf.remap(input, refVal, sigma, alpha, beta);

    % Make the Gaussian pyramid of the remapped image
    rGPyramid{1} = remapped;
    for i = 2:numPyramidLevels
        rGPyramid{i} = images.internal.builtins.llf.pyrdownsample(rGPyramid{i-1});
    end

    % Make the Laplacian pyramid of the remapped image
    rLPyramid{numPyramidLevels} = rGPyramid{numPyramidLevels};
    for i = numPyramidLevels-1:-1:1   
        % Do in-place update of outLPyramid{i}
        tmp = outLPyramid{i};
        outLPyramid{i} = []; % Release shared copy
        outLPyramid{i} = images.internal.builtins.llf.upSampleSubAddContribution(...
            matlab.lang.internal.move(tmp),...
            inGPyramid{i},rGPyramid{i},rGPyramid{i+1},refVal, delta);
    end
end


% Collapse the output Laplacian pyramid into the output image
for i = numPyramidLevels-1:-1:1
    requiredSize = size(outLPyramid{i});
    tmp = images.internal.builtins.llf.pyrupsample(outLPyramid{i+1}, requiredSize(1), requiredSize(2));
    outLPyramid{i} = outLPyramid{i} + tmp;
end

output = outLPyramid{1};
end

%   Copyright 2016-2022 The MathWorks, Inc.