function [B,D] = imlocalbrighten(im,varargin) %#codegen
% Copyright 2023 The MathWorks, Inc.

narginchk(1,4);
coder.internal.prefer_const(varargin);

% Validate Image
validateattributes(im,...
    {'single','double','uint8','uint16'},...
    {'real','nonsparse','nonempty'}, ...
    mfilename,'A',1);

coder.internal.errorIf(~(ismatrix(im) || (ndims(im) == 3) && (size(im,3) == 3)), ...
        'images:validate:invalidImageFormat','A');

if nargin > 1
    if nargin == 2
        amount = varargin{1};
        alphaBlend = false;
    else
        if isnumeric(varargin{1})
            amount = varargin{1};
            alphaBlend = parseNameValuePairs(varargin{2:end});
        else
            amount = 1;
            alphaBlend = parseNameValuePairs(varargin{:});
        end
    end
else
    amount = 1;
    alphaBlend = false;
end

% Validate Amount to brighten Image
validateattributes(amount, ...
    {'numeric'}, ...
    {'scalar','real','nonnegative','<=',1,'nonsparse'}, ...
    mfilename,'amount');

inputClass = class(im);

if ~isfloat(im)
    A = im2single(im);
else
    A = im;
end

if (amount == 0)
    B1 = A;
    D = [];
else
    Ainv = imcomplement(A);
    [Binv,D] = imreducehaze(Ainv,amount,'ContrastEnhancement','none');
    B1 = imcomplement(Binv);
    if alphaBlend
        B1 = A .* (1.0 - D) + B1.* D;
    end
end

B = images.internal.changeClass(inputClass,B1);
end

%--------------------------------------------------------------------------
function alphaBlend = parseNameValuePairs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin)

% Define parser mapping struct
params = struct('AlphaBlend', uint32(0));

% Specify parser options
options = struct(...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

% Parse name-value pairs
pstruct = coder.internal.parseParameterInputs(params, options, varargin{:});

alphaBlendIn =  coder.internal.getParameterValue(pstruct.AlphaBlend, false, varargin{:});

% Validate AlphaBlend
validateattributes(alphaBlendIn, ...
    {'numeric','logical'}, ...
    {'scalar','real','nonsparse','nonnan'}, ...
    mfilename,'AlphaBlend');

alphaBlend = logical(alphaBlendIn);
end