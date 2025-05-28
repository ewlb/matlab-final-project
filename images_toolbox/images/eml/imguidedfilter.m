function B = imguidedfilter(A, varargin) %#codegen
%IMGUIDEDFILTER Guided filtering of images

% Copyright 2021-2022 The MathWorks, Inc.

% Syntax
% ------
%
% B = imguidedfilter(A, G)
% B = imguidedfilter(A)
% B = imguidedfilter(__, NAME1, VAL1, ...)
%
% Input Specs
% ------------
%
% A & G:
% real
% binary, grayscale or RGB Image
% logical, uint8, int8, uint16, int16, uint32, int32, single, or double.
%
% NV Pairs:
% 'NeighborhoodSize': Scalar (Q) or two-element vector, [M N]
% real, positive
% numeric
% Default Value: [5 5]
%
% 'DegreeOfSmoothing':
% real, positive, scalar
% numeric
% Default Value: 0.01*diff(getrangefromclass(G)).^2
%
% Output Specs
% ------------
%
% B:
% same size and class as of A

% Copyright 2021 The MathWorks, Inc.

narginchk(1,6);

if isempty(A)
    B = A;
    return;
end

% Parse Inputs
[A, G, filtSize, inversionEpsilon] = parseInputs(A, varargin{:});

B = images.internal.coder.algimguidedfilter(A, G, filtSize, inversionEpsilon);
end

%--------------------------------------------------------------------------
function [A, G, filtSize, inversionEpsilon] = parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin{:});

% validate A
validImageTypes = {'uint8','int8','uint16','int16','uint32','int32', ...
    'single','double','logical'};
validateattributes(varargin{1}, validImageTypes,{'3d','nonsparse','real'}, ...
    mfilename,'A', 1);

A = varargin{1};

if nargin == 1 || (nargin > 1 && (ischar(varargin{2}) || isstring(varargin{2})))
    G = A;
    beginNVIdx = 2;
else
    % validate G
    validateattributes(varargin{2}, validImageTypes,{'3d','nonsparse','real'}, ...
        mfilename,'G', 2);
    G = varargin{2};
    beginNVIdx = 3;
end

% validate A & G
validateInputImages(A, G)

% Default Values
filtSizeDefault = [5 5];
smoothValueDefault  = 0.01*diff(getrangefromclass(G)).^2;

[filtSizeInput, inversionEpsilon] = parseNameValuePairs(filtSizeDefault, smoothValueDefault, ...
    varargin{beginNVIdx:end});

if length(filtSizeInput) == 1
    filtSize = [filtSizeInput filtSizeInput];
else
    filtSize = filtSizeInput;
end

% Validate NeighborhoodSize
coder.internal.errorIf(any(filtSize > [size(A,1) size(A,2)]), ...
    'images:imguidedfilter:nhoodSizeTooLarge', 'NeighborhoodSize');

end

%--------------------------------------------------------------------------
function [filtSize, smoothValue] = parseNameValuePairs(filtSizeDefault, ...
    smoothValueDefault, varargin)
coder.inline('always');
coder.internal.prefer_const(filtSizeDefault, smoothValueDefault, varargin);

% Parse Name-Value Pairs
params = struct(...
    'NeighborhoodSize', uint32(0),...
    'DegreeOfSmoothing', uint32(0));

options = struct(...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

optarg = coder.internal.parseParameterInputs(params, options, varargin{:});

filtSize = coder.internal.getParameterValue(...
    optarg.NeighborhoodSize, ...
    filtSizeDefault, ...
    varargin{:});

smoothValue = coder.internal.getParameterValue(...
    optarg.DegreeOfSmoothing, ...
    smoothValueDefault, ...
    varargin{:});

% Check NeighborhoodSize
validateattributes(filtSize, {'numeric'},{'vector', ...
    'finite','nonsparse','nonempty','real','positive','integer'}, ...
    mfilename,'NeighborhoodSize');

coder.internal.errorIf(numel(filtSize) > 2, ...
    'images:imguidedfilter:nhoodSizeVectTooLong', 'NeighborhoodSize');

% Check DegreeOfSmoothing
validateattributes(smoothValue, {'numeric'}, {'positive', ...
    'finite', 'real','nonempty','scalar'}, mfilename, ...
    'DegreeOfSmoothing');
end


%--------------------------------------------------------------------------
function validateInputImages(A,G)
coder.inline('always');
coder.internal.prefer_const(A,G);

coder.internal.errorIf(coder.const(numel(size(A)) == 3) && ~(size(A,3)==3 || size(A,3)==1), ...
    'images:imguidedfilter:wrongNumberOfChannels','A','G','A');

coder.internal.errorIf(coder.const(numel(size(G)) == 3) && ~(size(G,3)==3 || size(G,3)==1), ...
    'images:imguidedfilter:wrongNumberOfChannels','G','A','G');

sizeA = [size(A) 1];
sizeG = [size(G) 1];

coder.internal.errorIf(~isequal(sizeA(1:2),sizeG(1:2)), ...
    'images:imguidedfilter:unequalImageSizes', 'A','G')

if (sizeA(3) ~= sizeG(3))
    coder.internal.errorIf((sizeA(3) ~= 1 && sizeA(3) ~= 3), ...
        'images:imguidedfilter:wrongNumberOfChannels', 'A','G','A');

    coder.internal.errorIf((sizeG(3) ~= 1 && sizeG(3) ~= 3), ...
        'images:imguidedfilter:wrongNumberOfChannels', 'G','A','G');
end

end