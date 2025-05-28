function out = imclearborder(varargin) %#codegen

% Copyright 2023 The MathWorks, Inc.

% Parse inputs
coder.internal.errorIf(numel(size(varargin{1})) > 3,...
    'images:imkeepborder:incorrectInputDims');
[in,borders,connectivity] = parseInputs(varargin{:});

% Algorithm: form a border image using IMKEEPBORDER and then subtract
% that from the original image, using either arithmetic subtraction or
% a logical AND NOT operation.

objects = imkeepborder(in, Borders = borders, ...
    Connectivity = connectivity);

if islogical(in)
    out = in & ~objects;
else
    out = in - objects;
end
end

%==========================================================================
function [I, borders, connectivity] = parseInputs(varargin)
narginchk(1,6);
coder.inline('always');
coder.internal.prefer_const(varargin);
I = varargin{1};
% validate Input Image
validateImage(I);
if nargin >= 2
    if isnumeric(varargin{2})
        connNew = varargin{2};
        validateConnectivity(connNew);
        [borders,connectivity] = parseNameValuePairs(I,connNew,varargin{3:end});
    else
        connNew = ones(repmat(3,1,numel(size(I))));
        [borders,connectivity] = parseNameValuePairs(I,connNew,varargin{2:end});
    end

else
    connNew = ones(repmat(3,1,numel(size(I))));
    [borders,connectivity] = parseNameValuePairs(I,connNew,varargin{2:end});
end

end

%==========================================================================
function [borders,connectivity] = parseNameValuePairs(I,connNew,varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);

%default values
defaultBorders = true(numel(size(I)),2);
defaultConnectivity = connNew;

% Define parser mapping struct
params = struct(...
    'Borders',     uint32(0), ...
    'Connectivity',    uint32(0));

% Specify parser options
options = struct( ...
    'CaseSensitivity',  false, ...
    'StructExpand',     true, ...
    'PartialMatching',  true);

% Parse param-value pairs
pstruct = coder.internal.parseParameterInputs(params, options,...
    varargin{:});
borders      =  coder.internal.getParameterValue(pstruct.Borders,...
    defaultBorders, varargin{:});
connectivity =  coder.internal.getParameterValue(pstruct.Connectivity,...
    defaultConnectivity, varargin{:});

validateBorders(borders);
validateConnectivity(connectivity);

end

%==========================================================================
% Validate the input image
function validateImage(I)
coder.inline('always');
validateattributes(I, {'numeric' 'logical'}, {'real' 'nonsparse'},...
    mfilename,'I', 1);
end

%==========================================================================
function validateBorders(borders)
images.internal.coder.mustBeBorders(borders);
end

%==========================================================================
function validateConnectivity(connectivity)
images.internal.mustBeConnectivity(connectivity);
end