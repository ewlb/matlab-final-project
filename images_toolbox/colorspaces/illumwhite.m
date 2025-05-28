function illuminant = illumwhite(varargin)

[A,p,mask] = parseInputs(varargin{:});

numBins = 2^8;
if ~isa(A,'uint8')
    numBins = 2^16;
end

illuminant = zeros(1,3,'like',A);
for k = 1:3
    plane = A(:,:,k);
    plane = plane(mask);
    if isempty(plane)
        error(message('images:awb:maskExpectedNonZero','Mask'))
    end
    [counts, binLocations] = imhist(plane, numBins);
    cumhist = cumsum(counts,'reverse');
    idx = find(cumhist > numel(plane) * p/100);
    if ~isempty(idx)
        illuminant(k) = binLocations(idx(end));
    end
end
illuminant = im2double(illuminant);

%--------------------------------------------------------------------------
function [A,p,mask] = parseInputs(varargin)

narginchk(1,4);

parser = inputParser();
parser.FunctionName = mfilename;

% A
validateImage = @(x) validateattributes(x, ...
    {'single','double','uint8','uint16'}, ...
    {'real','nonsparse','nonempty'}, ...
    mfilename,'A',1);
parser.addRequired('A', validateImage);

% percentile
defaultPercentile = 1;
validatePercentile = @(x) validateattributes(x, ...
    {'numeric'}, ...
    {'real','nonsparse','nonempty','nonnan','scalar','nonnegative','<',100}, ...
    mfilename,'percentile',2);
parser.addOptional('percentile', ...
    defaultPercentile, ...
    validatePercentile);

% NameValue 'Mask'
defaultMask = true;
validateMask = @(x) validateattributes(x, ...
    {'logical','numeric'}, ...
    {'real','nonsparse','nonempty','2d','nonnan'}, ...
    mfilename,'Mask');
parser.addParameter('Mask', ...
    defaultMask, ...
    validateMask);

parser.parse(varargin{:});
inputs = parser.Results;
A    = inputs.A;
p    = double(inputs.percentile);
mask = inputs.Mask;

% Additional validation

% A must be MxNx3 RGB
validColorImage = (ndims(A) == 3) && (size(A,3) == 3);
if ~validColorImage
    error(message('images:validate:invalidRGBImage','A'));
end

if isequal(mask, defaultMask)
    mask = true(size(A,1),size(A,2));
end

% The sizes of A and Mask must agree
if (size(A,1) ~= size(mask,1)) || (size(A,2) ~= size(mask,2))
    error(message('images:validate:unequalNumberOfRowsAndCols','A','Mask'));
end

% Convert to logical
mask = logical(mask);

%   Copyright 2016-2022 The MathWorks, Inc.
