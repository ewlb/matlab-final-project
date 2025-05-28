function out = imsharpen(varargin) %#codegen
%IMSHARPEN Sharpen image using unsharp masking.

% Copyright 2021-2022 The MathWorks, Inc.

narginchk(1,7);
[A, radius, amount, threshold] = parseInputs(varargin{:});

if isempty(A)
    out = A;
    return;
end

isRGB = ndims(A) == 3;
classA = coder.const(class(A));

if ~isfloat(A)
    typeMax = double(intmax(classA));
    typeMin = double(intmin(classA));
end

lab = coder.nullcopy(zeros(size(A,1),size(A,2),3));
if isRGB
    if isa(A, 'int8') || isa(A, 'int16') || isa(A, 'uint32') || isa(A, 'int32')
        rgb = (double(A) - typeMin)/(typeMax - typeMin);
        lab = rgb2lab(rgb);

    elseif isa(A, 'single')
        rgb = double(A); % If single, keep same range, just cast it as double
        lab = rgb2lab(rgb);

    else
        lab = rgb2lab(A); % If A is double, uint8 or uint16
    end
    I = lab(:,:,1);
else
    I = double(A);
end

% Gaussian blurring filter
filtRadius = ceil(radius*2); % 2 Standard deviations include >95% of the area.
filtSize = 2*filtRadius + 1;
gaussFilt = fspecial('gaussian',[filtSize filtSize],radius);

% High-pass filter
sharpFilt = zeros(filtSize,filtSize);
sharpFilt(filtRadius+1,filtRadius+1) = 1;
sharpFilt = sharpFilt - gaussFilt;

if threshold > 0
    % When threshold > 0, sharpening includes a non-linear (thresholding)
    % step

    classI = class(I);
    % Convert image to floating point for computation
    if isinteger(I)
        I1 = single(I);
    else
        I1 = I;
    end

    % Compute high-pass component
    B = imfilter(I1,sharpFilt,'replicate','conv');

    % Threshold the high-pass component
    B = getThresholdedEdgeComponent(B,threshold);

    % Sharpening - add the high-pass component
    B = imlincomb(1,I1,amount,B,classI);
else
    % For threshold = 0, sharpening is a linear filtering operation

    sharpFilt = amount*sharpFilt;
    % Add 1 to the center element of sharpFilt effectively add a unit
    % impulse kernel to sharpFilt.
    sharpFilt(filtRadius+1,filtRadius+1) = sharpFilt(filtRadius+1,filtRadius+1) + 1;
    B = imfilter(I,sharpFilt,'replicate','conv');
end

if isRGB
    lab(:,:,1) = B;
    if isa(A, 'int8') || isa(A, 'int16') || isa(A, 'uint32') || isa(A, 'int32')
        out = cast((lab2rgb(lab)*(typeMax - typeMin)) + typeMin, classA);
    else
        out = lab2rgb(lab, 'OutputType', classA);
    end
else
    out = cast(B, classA);
end
end

% -------------------------------------------------------------------------
function gradientImg = getThresholdedEdgeComponent(gradientImg,threshold)
coder.inline('always');
absGradientImg = abs(gradientImg);
Gmax = max(absGradientImg(:));
t = Gmax * threshold;
gradientImg(absGradientImg < t) = 0;
end

% -------------------------------------------------------------------------
function [A, radius, amount, threshold] = parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin{:});

A = varargin{1};
% Validate A
checkInputImage(A);

if numel(varargin) == 1
    % Default values for parameters
    radius = 1;
    amount = 0.8;
    threshold = 0;
else
    % Define parser mapping struct
    params = struct(...
        'Radius',    uint32(0), ...
        'Amount',    uint32(0), ...
        'Threshold', uint32(0));

    % Specify parser options
    poptions = struct( ...
        'CaseSensitivity',  false, ...
        'StructExpand',     true, ...
        'PartialMatching',  true);

    % Parse param-value pairs
    pstruct = coder.internal.parseParameterInputs(params, poptions, varargin{2:end});

    radius = coder.internal.getParameterValue(pstruct.Radius, 1, varargin{2:end});
    amount = coder.internal.getParameterValue(pstruct.Amount, 0.8, varargin{2:end});
    threshold = coder.internal.getParameterValue(pstruct.Threshold, 0, varargin{2:end});

    % Validate PV pairs
    checkRadius(radius);
    checkAmount(amount);
    checkThreshold(threshold);
end
end

% -------------------------------------------------------------------------
function checkInputImage(A)
coder.inline('always');
validImageTypes = {'uint8','int8','uint16','int16','uint32','int32', ...
    'single','double'};
validateattributes(A, validImageTypes, {'nonsparse','real'}, mfilename, 'A', 1);

N = ndims(A);

coder.internal.errorIf(N > 3,'images:imsharpen:invalidInputImage');
coder.internal.errorIf(isvector(A),'images:imsharpen:invalidInputImage');

coder.internal.errorIf(coder.const(numel(size(A)) == 3) && ...
    ~(size(A,3)==3 || size(A,3) == 1),'images:imsharpen:invalidImageFormat');
end

% -------------------------------------------------------------------------
function checkRadius(radius)
coder.inline('always');
validateattributes(radius, {'double'}, {'positive', 'finite', ...
    'real', 'nonempty', 'scalar'}, mfilename, 'Radius');
end

% -------------------------------------------------------------------------
function checkAmount(amount)
coder.inline('always');
validateattributes(amount, {'double'}, {'nonnegative', 'finite', ...
    'real', 'nonempty', 'scalar'}, mfilename, 'Amount');
end

% -------------------------------------------------------------------------
function checkThreshold(threshold)
coder.inline('always');
validateattributes(threshold, {'double'}, {'finite', ...
    'real','scalar', '>=', 0, '<=', 1}, mfilename, 'Threshold');
end