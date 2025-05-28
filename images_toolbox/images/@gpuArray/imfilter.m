function b = imfilter(a, h, varargin)
%IMFILTER N-D filtering of multidimensional images.
%   B = IMFILTER(A,H) filters the multidimensional gpuArray A with the
%   multidimensional filter H.  A can be logical or it can be a nonsparse
%   numeric array of any class and dimension.  The result, B, has the same
%   size and class as A.
%
%   Each element of the output, B, is computed using either single-
%   or double-precision floating point, depending on the data type
%   of A.  When A contains double-precision or UINT32 values, the
%   computations are performed using double-precision values.  All
%   other data types use single-precision.  If A is an integer or
%   logical array, then output elements that exceed the range of
%   the given type are truncated, and fractional values are rounded.
%
%   B = IMFILTER(A,H,OPTION1,OPTION2,...) performs multidimensional
%   filtering according to the specified options.  Option arguments can
%   have the following values:
%
%   - Boundary options
%
%       X            Input array values outside the bounds of the array
%                    are implicitly assumed to have the value X.  When no
%                    boundary option is specified, IMFILTER uses X = 0.
%
%       'symmetric'  Input array values outside the bounds of the array
%                    are computed by mirror-reflecting the array across
%                    the array border.
%
%       'replicate'  Input array values outside the bounds of the array
%                    are assumed to equal the nearest array border
%                    value.
%
%       'circular'   Input array values outside the bounds of the array
%                    are computed by implicitly assuming the input array
%                    is periodic.
%
%   - Output size options
%     (Output size options for IMFILTER are analogous to the SHAPE option
%     in the functions CONV2 and FILTER2.)
%
%       'same'       The output array is the same size as the input
%                    array.  This is the default behavior when no output
%                    size options are specified.
%
%       'full'       The output array is the full filtered result, and so
%                    is larger than the input array.
%
%   - Correlation and convolution
%
%       'corr'       IMFILTER performs multidimensional filtering using
%                    correlation, which is the same way that FILTER2
%                    performs filtering.  When no correlation or
%                    convolution option is specified, IMFILTER uses
%                    correlation.
%
%       'conv'       IMFILTER performs multidimensional filtering using
%                    convolution.
%
%   Example
%   -------------
%       originalRGB = gpuArray(imread('peppers.png'));
%       h = fspecial('motion',50,45);
%       filteredRGB = imfilter(originalRGB,h);
%       figure, imshow(originalRGB)
%       figure, imshow(filteredRGB)
%       boundaryReplicateRGB = imfilter(originalRGB,h,'replicate');
%       figure, imshow(boundaryReplicateRGB)
%
%   See also FSPECIAL, GPUARRAY/CONV2, GPUARRAY/CONVN, GPUARRAY/FILTER2,
%            GPUARRAY.

%   Copyright 1993-2024 The MathWorks, Inc.

narginchk(2,5);
[a, h, boundary, sameSize] = parse_inputs(a, h, varargin{:});

[finalSize, pad] = computeSizes(a, h, sameSize);


%Empty Inputs
% 'Same' output then size(b) = size(a)
% 'Full' output then size(b) = size(h)+size(a)-1
if isempty(a) || isempty(h)
    if sameSize
        out_size = size(a);
    else
        % Follow CONV convention
        mndims = max(numel(size(a)),numel(size((h))));
        inSize = size(a,1:mndims);
        filtSize = size(h,1:mndims);
        out_size = max(inSize+filtSize,1) - 1;
        out_size = max(out_size, inSize);
        out_size = max(out_size, filtSize);
    end

    if islogical(a)
        b = false(out_size);
    else
        b = zeros(out_size,'like',a);
    end
    return
    
end

boundaryStr = boundary;
padVal      = 0;
if(~ischar(boundary) && ~isstring(boundary))
    boundaryStr = "constant";
    padVal      = boundary;
end

%Special case
% If the filter kernel is 3x3 and same size output is requested.
if(ismatrix(a) && isequal(size(h),[3 3]) && sameSize...
        && isreal(a) && isreal(h) && ~strcmp(boundaryStr,"circular"))

    h = gpuArray(double(h));
    [a,origClass] = convertToFloat(matlab.lang.internal.move(a));

    padVal = cast(gather(padVal), underlyingType(a));
    b = images.internal.gpu.imfilter(a, h, char(boundaryStr), padVal);
    if ~isempty(origClass)
        b = castData(matlab.lang.internal.move(b), origClass);
    end
    return;

end

[separableFlag, u, s, v] = isSeparable(a, h);

%Special case
% If the filter kernel is separable, input is to be zero-padded and output
% is requested at the same size, use conv2 instead of convn.
useConv2 = separableFlag && padVal==0 && strcmp(boundaryStr,"constant") && sameSize && ismatrix(h);
if useConv2

    % extract the components of the separable filter
    hcol = u(:,1) * sqrt(s(1));
    hrow = v(:,1)' * sqrt(s(1));

    [a,origClass] = convertToFloat(matlab.lang.internal.move(a));

    % perform convolution plane-by-plane
    for zInd = 1:size(a,3)
        % handle planes one at a time
        a(:,:,zInd) = conv2(hcol, hrow, a(:,:,zInd), "same");
    end

    if ~isempty(origClass)
        b = castData(matlab.lang.internal.move(a), origClass);
    else
        b = a;
    end

    return;
end

% zero-pad input based on dimensions of filter kernel.
a = padarray_algo(matlab.lang.internal.move(a),pad,boundaryStr,padVal,"both");

% cast data to appropriate floating point type
[a,origClass] = convertToFloat(matlab.lang.internal.move(a));

if (separableFlag)

    % extract the components of the separable filter
    hcol = u(:,1) * sqrt(s(1));
    hrow = v(:,1)' * sqrt(s(1));
    % apply the first component of the separable filter (hrow)
    out_size_row = [size(a,1) finalSize(2:end)];
    start = [0 pad(2:end)];
    b_tmp = filterPartOrWhole(matlab.lang.internal.move(a), ...
        out_size_row, hrow, start+1, sameSize);

    % apply the other component of the separable filter (hcol)
    start = [pad(1) 0 pad(3:end)];
    b = filterPartOrWhole(matlab.lang.internal.move(b_tmp), ...
        finalSize, hcol, start+1, sameSize);

else % non-separable filter case

    b = filterPartOrWhole(matlab.lang.internal.move(a), ...
        finalSize, h, pad+1, sameSize);

end

% cast back to input datatype
if ~isempty(origClass)
    b = castData(matlab.lang.internal.move(b), origClass);
end

%--------------------------------------------------------------
function [a, h, boundary, sameSize] = parse_inputs(a, h, varargin)

if ~isgpuarray(a)
    error(message("images:imfilter:gpuImageType"))
end

validateattributes(h,{'double'},{'nonsparse'},mfilename,"filter kernel H",2);

%Assign defaults
boundary = 0;  %Scalar value of zero
output = "same";
do_fcn = "corr";

allStrings = ["replicate", "symmetric", "circular", "conv", "corr", ...
    "full","same"];

for k = 1:length(varargin)
    if ischar(varargin{k}) || isstring(varargin{k})
        string = validatestring(varargin{k}, allStrings,...
            mfilename, "OPTION", k+2);
        switch string
            case {"replicate", "symmetric", "circular"}
                boundary = string;
            case {"full","same"}
                output = string;
            case {"conv","corr"}
                do_fcn = string;
        end
    else
        validateattributes(varargin{k},{'numeric'},{'nonsparse'},mfilename,"OPTION",k+2);
        boundary = varargin{k};
    end %else
end

sameSize = strcmp(output,"same");

convMode = strcmp(do_fcn,"conv");

% Reverse order of kernel elements for correlation
if isgpuarray(h)
    if ~convMode
        h(:) = h(end:-1:1);
    end
else
    if convMode
        h = gpuArray(h);
    else
        % When not convMode, filter must be reversed. Do this on the CPU for
        % small sizes, as it is likely to be slow.
        if numel(h) < 100000
            h(:) = h(end:-1:1);
            h = gpuArray(h);
        else
            h = gpuArray(h);
            h(:) = h(end:-1:1);
        end
    end
end

%--------------------------------------------------------------
function [separable, u, s, v] = isSeparable(a, h)

% check for filter separability
sep_threshold = getSeparableFilterThreshold(underlyingType(a));

if ((numel(h) >= sep_threshold) && ...
        ndims(a)<=3 &&...
        ismatrix(h) && ...
        all(size(h) ~= 1) && ...
        allfinite(h))

    [u, s, v] = svd(gather(h));
    s = diag(s);
    tol = length(h) * s(1) * eps;
    rank = sum(s > tol);

    if (rank == 1)
        separable = true;
    else
        separable = false;
    end

else

    separable = false;
    u = [];
    s = [];
    v = [];

end

%--------------------------------------------------------------
function [finalSize, pad] = computeSizes(a, h, sameSize)

rank_a = ndims(a);
rank_h = ndims(h);

% Pad dimensions with ones if filter and image rank are different
size_h = [size(h) ones(1,rank_a-rank_h)];
size_a = [size(a) ones(1,rank_h-rank_a)];

if (sameSize)
    %Same output
    finalSize = size_a;

    %Calculate the number of pad pixels
    filter_center = floor((size_h + 1)/2);
    pad = size_h - filter_center;
else
    %Full output
    finalSize = size_a+size_h-1;
    pad = size_h - 1;
end


%--------------------------------------------------------------
function a = filterPartOrWhole(a, outSize, h1, outputStartIdx, sameSize)

if (sameSize)
    sizeFlag = "same";
else
    sizeFlag = "full";
end

a = convn(a, h1, sizeFlag);

% Retrieve the part of the image that's required. All other indices are ':'.
starts = outputStartIdx;
ends = outputStartIdx + outSize - 1;

% We special case 2D since this is very common
if ismatrix(a) && ismatrix(h1)
    % Special case for 2D to keep it fast
    a = a(starts(1):ends(1), starts(2):ends(2));
else
    % Fill overlapping indices with the subset, trailing indices with :
    idxs = cell(1, ndims(a));
    for ind = 1:ndims(h1)
        idxs{ind} = starts(ind) : ends(ind);
    end
    for ind = ndims(h1)+1:ndims(a)
        idxs{ind} = ':';
    end
    a = a(idxs{:});
end

%--------------------------------------------------------------
function [a,origClass] = convertToFloat(a)
% Convert input matrix to double if datatype is uint32, else convert to
% single. origClass will be empty if no conversion was performed or will be
% the name of the original type of A before conversion.

if isfloat(a)
    origClass = [];
    return;
end

% We need to convert so store the original type name.
origClass = underlyingType(a);
if origClass == "uint32"
    % uint32 is too big for single, so use double
    a = double(a);
else
    % all other supported types fit in single
    a = single(a);
end


%--------------------------------------------------------------
function result = castData(result, origClass)

if (origClass=="logical")
    result = round(result) ~= 0;
else
    result = cast(result, origClass);
end
