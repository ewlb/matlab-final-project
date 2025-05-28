function b = padarray_algo(a, padSize, method, padVal, direction)
%PADARRAY_ALGO Pad array.
%   B = PADARRAY_AGLO(A,PADSIZE,METHOD,PADVAL,DIRECTION) internal helper
%   function for PADARRAY, which performs no input validation.  See the
%   help for PADARRAY for the description of input arguments, class
%   support, and examples.

%   Copyright 2012-2023 The MathWorks, Inc.

if isempty(a)
    b = getConstantArray(a, padSize, padVal, direction);

elseif strcmpi(method,"constant")

    % constant value padding with padVal
    b = ConstantPad(a, padSize, padVal, direction);
else

    % compute indices then index into input image
    aSize = size(a);
    aIdx = getPaddingIndices(aSize,padSize,method,direction);
    b = a(aIdx{:});
end


%%%
%%% getPaddedSize
%%%
function [b, sizeA] = getConstantArray(a, padSize, padVal, direction)
% Determine the output size and build a constant array
if ~isrow(padSize)
    padSize = reshape(padSize, 1, []);
end
numDims = numel(padSize);
sizeA = size(a, 1:numDims);
if direction == "both"
    sizeB = sizeA + 2*padSize;
else
    sizeB = sizeA + padSize;
end

% Initialize output array with the padding value.  Make sure the
% output array is the same type as the input.
b = mkconstarray(a, padVal, sizeB);

%%%
%%% ConstantPad
%%%
function b = ConstantPad(a, padSize, padVal, direction)

[b, sizeA] = getConstantArray(a, padSize, padVal, direction);

% If ndims is small (3 or fewer) we use direct indexing. Otherwise build up
% the indexing expression iteratively.
numDims = numel(padSize);
switch numDims
    case 2
        if direction == "post"
            % Copy to top-left corner
            b(1:sizeA(1), 1:sizeA(2)) = a;
        else
            % Copy with offset
            b(1+padSize(1):sizeA(1)+padSize(1), ...
                1+padSize(2):sizeA(2)+padSize(2)) = a;
        end

    case 3
        if direction == "post"
            % Copy to top-left corner
            b(1:sizeA(1), 1:sizeA(2), 1:sizeA(3)) = a;
        else
            % Copy with offset
            b(1+padSize(1):sizeA(1)+padSize(1), ...
                1+padSize(2):sizeA(2)+padSize(2), ...
                1+padSize(3):sizeA(3)+padSize(3)) = a;
        end

    otherwise
        idx   = cell(1,numDims);
        for k = 1:numDims
            if direction == "post"
                % Copy to top-left corner
                idx{k} = 1:sizeA(k);
            else
                % Copy with offset
                idx{k} = padSize(k) + (1:sizeA(k));
            end
        end
        b(idx{:}) = a;
end
