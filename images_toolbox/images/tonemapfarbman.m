function LDR = tonemapfarbman(HDR, varargin)
%TONEMAPFARBMAN converts high dynamic range (HDR) image to low dynamic range
%  (LDR) image using edge-preserving multi-scale decompositions
%
%   LDR = tonemapfarbman(HDR) converts the high dynamic range HDR image to 
%   a lower dynamic range image, LDR, suitable for display, using a process 
%   called edge-preserving decompositions for multi-scale tone and detail 
%   manipulation.
%
%   LDR = tonemapfarbman(HDR, Name, Value, ...) performs tone mapping where
%   parameters control various aspects of the operation. Parameter names
%   can be abbreviated. Parameters include:
%
%      'RangeCompression'         Positive numeric scalar specifying the
%                                 amount of compression applied to the
%                                 dynamic range of HDR. Must be in [0,1]. A
%                                 value of 1 represents maximum compression
%                                 and 0 represents minimum compression.
%
%                                 Default: 0.3
%
%
%      'Saturation'               Positive numerical scalar specifying the
%                                 amount of the saturation. Appropriate
%                                 range is [0 5]. This value is used to
%                                 increase or decrease the amount of
%                                 saturation. When saturation is high, the
%                                 colors are richer and more intense. A low
%                                 value of saturation (closer to zero),
%                                 makes the colors fade away to grayscale.
%
%                                 Default: 1.6
%
%
%      'Exposure'                 Positive numerical scalar specifying the
%                                 exposure of the output image. Appropriate
%                                 range is (0 5]. Low value of exposure
%                                 produces dark image and high value
%                                 produces bright image.
%
%                                 Default: 3.0
%            
%
%      'NumberOfScales'           Positive integer scalar specifying number
%                                 of scales used for the decomposition.
%                                 Appropriate range is [1 5].
%
%                                 Default: 3, or number of elements in
%                                 weight vector (if provided)
%
%
%      'Weights'                  Numerical vector 1-by-N specifying the
%                                 weights of each detail layers (estimated
%                                 using multi-scale). Recovered image is
%                                 the weighted summation of the detail and
%                                 base layers. Size N of the weight vector
%                                 equals to the number of scales used in
%                                 multi-scale decomposition. Appropriate
%                                 range for each element of weight vector
%                                 is (0 3]. Weight elements having value
%                                 less than one reduce the details in the
%                                 output image and value greater than one
%                                 increases the details.
%
%                                 Default: Vector of size 1-by-N (N = 3 or
%                                 NumberOfScales (if provided)) having all
%                                 elements as 1.5 ex. [1.5 1.5 1.5]
%
%
%   Class Support
%   -------------
%   The high dynamic range image HDR must be a M-by-N or M-by-N-by-3 array
%   of class single or double. The output image LDR is a uint8 array of the
%   same size as HDR.
%
%   Notes
%   ---------
%   [1] This function uses imdiffusefilt (anisotropic diffusion filter) for
%   the approximation of WLS filter as proposed by Farbman et al.
%   [2] There is no effect of 'Saturation' on grayscale image.
%
%   References
%   ---------
%   [1] Z. Farbman, R. Fattal, D. Lischinski, R. Szeliski,"Edge-preserving
%       decompositions for multi-scale tone and detail manipulation", ACM
%       Trans. Graph., vol. 27, no. 3, pp. 1-10, Aug. 2008.
%
%   Example 1: Convert HDR image to LDR image with Default values 
%   --------------------------------------------------------------
%   % Load a high dynamic range (HDR) image
%   HDR = hdrread('office.hdr');
% 
%   % Apply tone mapping algorithm
%   LDR = tonemapfarbman(HDR);
%
%   % Display input and output images
%   figure,montage({HDR,LDR});
%
%   Example 2: Convert HDR image to LDR image with Name-Value pairs
%   ---------------------------------------------------------------
%   % Load a high dynamic range (HDR) image
%   HDR = hdrread('office.hdr');
%
%   % Apply tone mapping algorithm with Name-Value pair
%   LDR = tonemapfarbman(HDR,'NumberOfScales',4,'Exposure',1.5);
%
%   % Display input and output images
%   figure,montage({HDR,LDR});
%
%   See also tonemap, localtonemap, imdiffusefilt, locallapfilt, hdrread, makehdr

%   Copyright 2018-2019 The MathWorks, Inc.

matlab.images.internal.errorIfgpuArray(HDR, varargin{:});
[HDR, gamma, sat, exposure, weight, numScale] = parseInputs(HDR, varargin{:});

if size(HDR,3) == 1
    lum = HDR;
else
    lum = imapplymatrix([0.299 0.587 0.114],HDR) + eps('single');
    rgb = HDR./ lum;
end

% Compute log luminance
logLum = log(lum);
% If logLum isn't real, then HDR contained negative values.
% Error early with a nice message.
if ~isreal(logLum)
    validateattributes(-1,{'double'},{'nonnegative'},mfilename,'HDR',1);
end

% Apply diffusion filter for multi-scale decomposition
% Compute detail layers
% Recombine the layers together while moderately boosting multiple scale detail
uPre = logLum;
comLogLum = zeros(size(HDR,1),size(HDR,2), 'like', HDR);
numItr = 5; % No. of iterations ('NumberOfIterations' of anisotropic diffusion) for the first level decomposition.
logLum(~isfinite(logLum)) = (realmax('single')/100); % replaced Inf with a high value.
rangeLum = sum([max(logLum(:)) - min(logLum(:)),eps('single')],'omitnan'); % range of the image
for scaleInd = 1:numScale
    % gradThresh is the 'GradientThreshold' parameter of the anisotropic diffusion.
    % Here, it is taken as 5% of the dynamic range of the image.
    % gradThresh is increased for each decomposition level (multiplied by scaleInd (No. of iterations))
    gradThresh = scaleInd*5*(rangeLum)/100;
    uCurr = imdiffusefilt(logLum,'NumberOfIterations',numItr*scaleInd,'GradientThreshold',gradThresh);
    detail = uPre - uCurr; % multi-scale decomposition (detail extraction)
    comLogLum = comLogLum + weight(scaleInd).*detail; % weighted summation
    uPre = uCurr;
end
comLogLum = comLogLum + uCurr;

% Convert back to RGB
% The 99.9% intensities of the compressed image are remapped to give the output image a consistent look
newI = exp(comLogLum);
sI = sort(newI(:));
mx = sI(round(length(sI) * (99.9/100)));
newI = newI/mx;

% Exposure, RangeCompression and saturation correction
expoCorrect = exposure*newI;
if size(HDR,3) == 1
    LDR = expoCorrect.^gamma;
else
    LDR = (expoCorrect .* (rgb .^ sat)).^gamma;
end
LDR = im2uint8(LDR);
end


%%%%% Parsing %%%%%
function [I, gamma, sat, exposure, weight, numScale] = parseInputs(I, varargin)
narginchk(1,11);
% Input parser
parser = inputParser;
parser.FunctionName = mfilename;
parser.CaseSensitive = false;
parser.PartialMatching = true;

validateattributes(I,...
    {'single', 'double'},...
    {'real', 'nonsparse', 'nonempty'}, ...
    mfilename, 'HDR', 1);

% default values 
parser.addParameter('RangeCompression', 0.3, @checkgamma);
parser.addParameter('Saturation', 1.6, @checksaturation);
parser.addParameter('Exposure', 3.0, @checkexposure);
parser.addParameter('Weights', [], @checkweights);
parser.addParameter('NumberOfScales', [], @checknumberofscales);

parser.parse(varargin{:});
gamma = parser.Results.RangeCompression;
sat = parser.Results.Saturation;
exposure = parser.Results.Exposure;
weight = parser.Results.Weights;
numScale = parser.Results.NumberOfScales;

%%%% conditions on weights and number of scales matching
N = 3; %% (default) number of scales and number of elements in weights vector
if (isempty(numScale) && ~isempty(weight))
    numScale = numel(weight);
elseif (~isempty(numScale) && isempty(weight))
    weight = 1.5*ones(1,numScale);
elseif (isempty(numScale) && isempty(weight))
    numScale = N;
    weight = 1.5*ones(1,N);
else
    % Do nothing
end
if (~isequal(numel(weight),numScale))
    error(message('images:tonemapfarbman:weightscalesize'));
end

% NameValue 'RangeCompression'
function check = checkgamma(gamma)
validateattributes(gamma, ...
    {'numeric'}, ...
    {'real', 'nonempty', 'scalar','nonnegative', 'finite', '>=', 0, '<=',1,'nonsparse'}, ...
    mfilename, 'RangeCompression');
check = true;
end

% NameValue 'Saturation' 
function check = checksaturation(sat)
validateattributes(sat, ...
    {'numeric'}, ...
    {'real','nonempty','scalar','nonnegative','finite','>=', 0,'nonsparse'}, ...
    mfilename, 'Saturation');
check = true;
end

% NameValue 'Exposure'  
function check = checkexposure(exposure)
validateattributes(exposure, ...
    {'numeric'}, ...
    {'real','nonempty','scalar','nonnegative','finite', '>', 0, 'nonsparse'}, ...
    mfilename, 'Exposure');
check = true;
end

% NameValue 'Weights'
function check = checkweights(weight)
validateattributes(weight, ...
    {'numeric'}, ...
    {'nonempty','vector','real', 'nonnegative','finite', '>', 0, 'nonsparse'}, ...
    mfilename, 'Weights');
check = true;
end

% NameValue 'NumberOfScales'
function check = checknumberofscales(numScale)
validateattributes(numScale, ...
    {'numeric'}, ...
    {'real','nonempty','scalar','nonnegative','finite','>', 0, 'nonsparse','integer'}, ...
    mfilename, 'NumberOfScales');
check = true;
end

% HDR must be MxN or MxNx3
validImage = (ndims(I) == 3) && (size(I,3) == 3);
if ~(ismatrix(I) || validImage)
    error(message('images:validate:invalidImageFormat','Input HDR image'));
end

end
