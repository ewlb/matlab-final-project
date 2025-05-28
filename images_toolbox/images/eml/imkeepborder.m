function out = imkeepborder(varargin) %#codegen

% Copyright 2023 The MathWorks, Inc.

% Parse inputs
coder.internal.errorIf(numel(size(varargin{1})) > 3,...
    'images:imkeepborder:incorrectInputDims');
[in,borders,connectivity] = parseInputs(varargin{:});

% Convert input connectivity to its canonical, multidimensional array
% representation.
connNew = images.internal.getBinaryConnectivityMatrix(connectivity);

% Convert borders specification to its canonical matrix representation.
canBorders = borderMatrix(borders);
rowsCanBorders = size(canBorders,1);

ndimsConn = coder.internal.indexInt(numel(size(connNew)));

ndimsIn = coder.internal.indexInt(numel(size(in)));

% Determine the working dimensionality.
wDims = ndimsIn;

coder.internal.errorIf(ndimsIn < rowsCanBorders,'images:imkeepborder:notGreaterThanRows');
coder.internal.errorIf(ndimsIn < ndimsConn,'images:imkeepborder:notGreaterThanDims');

if rowsCanBorders < wDims
    % Pad borders matrix with zeros to working dimensionality.
    padBorders = [canBorders ; false(wDims - rowsCanBorders, 2)];
else
    padBorders = canBorders;
end

if wDims > ndimsConn

    % The working dimensionality is higher than the dimensionality of
    % the connectivity array. Extend the connectivity to the working
    % dimensionality.
    %
    % When a connectivity array is extended to the next higher
    % dimension, do it so that there is no connectivity in that new
    % dimension. This is achieved by "sandwiching" the connectivity
    % array, along the new dimension, between two same-shape arrays of
    % zeros. Repeat this process for as many dimensions as needed.
    diff = wDims - ndimsConn;
    if diff == 1
        k = ndimsConn+1;
        extraZeros = false(size(connNew));
        conn = cat(k,extraZeros,connNew,extraZeros);
    elseif ndimsIn == 4 && diff == 2
        extraZeros = false(size(connNew));
        conn3D = cat(3,extraZeros,connNew,extraZeros);
        extraZerosNext = false(size(conn3D));
        conn4D = cat(4,extraZerosNext,conn3D,extraZerosNext);
        conn = conn4D;
    end
else
    conn = connNew;
end
% Get the input image size according to the working dimensionality.
sizeIn = size(in,1:wDims);

% General algorithm:
%
% Call the input image the mask image.
%
% Create a marker image array that is equal to the input array only
% along the specified borders. At every other location, the marker
% image is false or -Inf, depending on whether the input array is
% logical.
%
% Then, perform morphological reconstruction using the mask and marker
% images.
%
% Reference: Pierre Soille, Morphological Image Analysis: Principles
% and Applications, Springer, 1999, pp. 164-165.

% First, create a cell array of subscripts corresponding to where the
% marker image will be false or -Inf. The set of borders to use is
% specified by the matrix B. If B(k,1) is true, then we are using the
% starting border along the k-th dimension. If B(k,2) is true, then we
% are using the ending border along the k-th dimension.
subs = cell(1,wDims);

for dim = 1:coder.internal.indexInt(wDims)
    [useFirstBorder,useSecondBorder] = useBordersAlongDimension(dim,padBorders,conn);
    if useFirstBorder
        first = 2;
    else
        first = 1;
    end

    if useSecondBorder
        last = sizeIn(dim)-1;
    else
        last = sizeIn(dim);
    end

    subs{dim} = first:last;
end

% Determine the value to use on the interior of the marker image array.
if islogical(in)
    markerMinValue = false;
else
    markerMinValue = -Inf;
end

% Initialize the marker image to be the same as the input array, and
% then use the subscripts cell array to set all the interior elements
% to markerMinValue.
marker = in;
marker(subs{:}) = markerMinValue;

out = imreconstruct(marker,in,conn);
end

%==========================================================================
%borderMatrix Convert Borders input argument to canonical matrix form.
function canBorders = borderMatrix(borders)

if isstring(borders) || iscell(borders)
    canBorders = false(2,2);
    for k = 1:coder.internal.indexInt(length(borders))
        if isstring(borders)
            choice  = borders(k);
        else
            choice = borders{k};
        end
        switch choice
            case "top"
                canBorders(1,1) = true;
            case "bottom"
                canBorders(1,2) = true;
            case "left"
                canBorders(2,1) = true;
            case "right"
                canBorders(2,2) = true;
        end
    end
else
    % If the input is not a string, then it is a two-column matrix.
    % Validity of of the matrix is not checked here.
    canBorders = borders;
end
end
%==========================================================================
% useBordersAlongDimension(dim,B,conn) determines whether to use the first
% and second border along a given dimension, based on the Borders matrix
% and the specified connectivity. Using a particular border depends on two
% factors:
%
% - whether the Borders matrix, B, indicates it. B(dim,1) indicates the
% first border along the specified dimension, and B(dim,2) indicates the
% second.
%
% - whether the connectivity indicates that pixels along that border are
% connected to the outside of the image. For example, if dim is 2, then if
% any of the values conn(:,1,:) is nonzero, then pixels on the left border
% of the input array are connected to the outside of the image. Similarly,
% if any of the values conn(:,3,:) is nonzero, then pixels on the right
% border of the input array are connected to the outside of the image.
function [useFirstBorder,useSecondBorder] = useBordersAlongDimension(dim,padBorders,conn)
rowsBorder = size(padBorders,1);
connSubs = repmat({1:3},1,rowsBorder);

if ~padBorders(dim,1)
    useFirstBorder = false;
else
    connSubs{dim} = 1;
    useFirstBorder = any(conn(connSubs{:}),"all");
end

if ~padBorders(dim,2)
    useSecondBorder = false;
else
    connSubs{dim} = 3;
    useSecondBorder = any(conn(connSubs{:}),"all");
end
end

%==========================================================================
function [I, borders, connectivity] = parseInputs(varargin)
narginchk(1,5);
coder.inline('always');
coder.internal.prefer_const(varargin);
I = varargin{1};
% validate Input Image
validateImage(I);
[borders,connectivity] = parseNameValuePairs(I,varargin{2:end});
end

%==========================================================================
function [borders,connectivity] = parseNameValuePairs(I,varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);

%default values
defaultBorders = true(numel(size(I)),2);
defaultConnectivity = ones(repmat(3,1,numel(size(I))));


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
