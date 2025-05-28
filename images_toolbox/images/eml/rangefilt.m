function J = rangefilt(varargin) %#codegen
%RANGEFILT Local range of image.

% Copyright 2022 The MathWorks, Inc.

narginchk(1,2);

[I, h] = parseInputs(varargin{:});

% NHOOD is reflected across its origin in order for IMDILATE
% to return the local maxima of I in NHOOD if it is asymmetric. A symmetric NHOOD
% is naturally unaffected by this reflection.
reflectH = h(:);
reflectH = flipud(reflectH);
reflectH = reshape(reflectH, size(h));

dilateI = imdilate(I,reflectH);

% IMERODE returns the local minima of I in NHOOD.
erodeI = imerode(I,h);

% Set the output classes for signed integer data types.
switch class(I)
    case {'single','double','uint8','uint16','uint32','logical'}
        outputClass = class(I);
    case 'int8'
        outputClass = 'uint8';
    case 'int16'
        outputClass = 'uint16';
    case 'int32'
        outputClass = 'uint32';
    otherwise
        coder.internal.assert(false,'unsupported class');
end

% Calculate the range with imlincomb instead of imsubtract so that you can
% specify the output class.  Use the relational operator to calculate the
% range for a logical image to be efficient.
if islogical(I)
    J = dilateI > erodeI;
else
    J = imlincomb(1, dilateI, -1, erodeI, outputClass);
end

%--------------------------------------------------------------------------
% parseInputs
function [I,H] = parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);

validateattributes(varargin{1},{'numeric' 'logical'},...
    {'real','nonsparse','nonnan'}, ...
    mfilename,'I',1);

I = varargin{1};

if nargin == 2
    validateattributes(varargin{2},{'logical','numeric'},{'nonempty','nonsparse'}, ...
        mfilename,'NHOOD',2);
    H = varargin{2};

    % H must contain zeros and/or ones.
    badElements = (H ~= 0) & (H ~= 1);
    coder.internal.errorIf(any(badElements(:)),'images:rangefilt:invalidNeighborhoodValue');

    % H's size must be odd.
    sizeH = size(H);
    coder.internal.errorIf(any(floor(sizeH/2) == (sizeH/2)), 'images:rangefilt:invalidNeighborhoodSize')

    % Convert to logical
    H = H ~= 0;

else
    H = true(3);
end
