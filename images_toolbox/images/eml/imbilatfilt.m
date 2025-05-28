function B = imbilatfilt(varargin) %#codegen

% Copyright 2017-2021 The MathWorks, Inc.


[A, neighborhoodSize, degreeOfSmoothing, spatialSigma, padding, padVal] = ...
    parseInputsCG(varargin{:});

% Convert to standard deviation
rangeSigma = sqrt(degreeOfSmoothing);

B = images.internal.algimbilateralfilter(A, [neighborhoodSize, neighborhoodSize],...
    rangeSigma, spatialSigma, padding, padVal);

end


function [A, neighborhoodSize, degreeOfSmoothing, spatialSigma, padding, padVal] = parseInputsCG(varargin)
coder.internal.prefer_const(varargin{:});

narginchk(1,inf);

A = varargin{1};
if ismatrix(A)
    % numeric grayscale
    validateattributes(...
        A, {'numeric'}, ...
        {'nonsparse','nonempty', 'real','ndims',2},...
        mfilename, 'A')
else
    % 3-channel color
    validateattributes(...
        A, {'numeric'}, ...
        {'nonsparse','nonempty', 'real','ndims',3},...
        mfilename, 'A')
    % errorIf number of channels != 3
    coder.internal.errorIf(size(A,3)~=3, 'images:validate:invalidImageFormat', 'A');
end


pvStartInd = 2;

if nargin > 1
    if ~(ischar(varargin{2}) || isstring(varargin{2}))
        degreeOfSmoothing = validateDegreeOfSmoothing(varargin{2});
        pvStartInd = pvStartInd+1;
    else
        degreeOfSmoothing = 0.01*diff(getrangefromclass(A)).^2;
    end
else
    degreeOfSmoothing = 0.01*diff(getrangefromclass(A)).^2;
end

if nargin > 2
    if ~(ischar(varargin{3}) || isstring(varargin{3}))
        spatialSigma = validateSpatialSigma(varargin{3});
        pvStartInd = pvStartInd+1;
    else
        spatialSigma = 1;
    end
else
    spatialSigma = 1;
end

neighborhoodSizeDefault = 2*ceil(2*spatialSigma)+1;
paddingDefault = 'replicate';

[neighborhoodSize,padding,padVal] = parseNameValuePairs( ...
    A,neighborhoodSizeDefault,paddingDefault, varargin{pvStartInd:end});


end

% Parse the (Name,Value) pairs
function [neighborhoodSize,padding,padVal] = parseNameValuePairs( ...
    A,neighborhoodSize_,padding_, varargin)

% PVs
params = struct(...
    'neighborhoodSize', uint32(0),...
    'padding', uint32(0));
options = struct(...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);
optarg = coder.internal.parseParameterInputs(params, options, varargin{:});
neighborhoodSize = coder.internal.getParameterValue(...
    optarg.neighborhoodSize,...
    neighborhoodSize_,...
    varargin{:});

padding = coder.internal.getParameterValue(...
    optarg.padding,...
    padding_,...
    varargin{:});

validateNeighborhoodSize(neighborhoodSize);
coder.internal.errorIf(min([size(A,1), size(A,2)]) <= neighborhoodSize,...
    'images:imbilatfilt:imageNotMinSize', neighborhoodSize);
[padding, padVal]=validatePadding(padding);

end

function degreeOfSmoothing = validateDegreeOfSmoothing(degreeOfSmoothing_)
validateattributes(...
    degreeOfSmoothing_, {'numeric'},...
    {'scalar','real','finite','positive'},...
    mfilename, 'degreeOfSmoothing');
degreeOfSmoothing = degreeOfSmoothing_;
end

function spatialSigma = validateSpatialSigma(spatialSigma_)
validateattributes(...
    spatialSigma_ , {'numeric'},...
    {'scalar','real','finite','positive'},...
    mfilename, 'spatialSigma');
spatialSigma = spatialSigma_;
end

function validateNeighborhoodSize(neighborhoodSize_)
validateattributes(neighborhoodSize_, ...
    {'numeric'},...
    {'nonsparse', 'nonempty', 'finite', 'real', 'odd', 'numel', 1},...
    mfilename, 'neighborhoodSize');
end

function [padding, padVal]=validatePadding(padding_)
if ~ischar(padding_) && ~isstring(padding_)
    validateattributes(padding_,...
        {'numeric','logical'}, ...
        {'real','scalar','nonsparse'}, ...
        mfilename, 'padding');
    padVal = double(padding_); % will be cast later
    padding = 'constant';
else
    padding = validatestring(padding_,...
        {'replicate','symmetric'}, ...
        mfilename, 'padding');
    padVal = 0;
end
end