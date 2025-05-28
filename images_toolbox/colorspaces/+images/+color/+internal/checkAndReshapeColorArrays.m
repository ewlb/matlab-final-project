function [AA,BB,out_size] = checkAndReshapeColorArrays(A,B)
%   [AA,BB,out_size] = checkAndReshapeColorArrays(A,B)
%
%   Return output color arrays reshaped to the format MxNx3xPx ...
%
%   Return the size that the final color difference output will be after
%   all expansions.
%
%   Allow either input to be 1x3.
%
%   If both inputs matrices, throw an error if they do not have compatible
%   sizes.
%
%   If both inputs are multidimensional arrays, throw an error if they do
%   not have the same size.
%
%   Throw error if either input does not have exactly three color
%   components.

% Make sure each input has three color components.
checkFormat(A);
checkFormat(B);

ndims_A = ndims(A);
ndims_B = ndims(B);
ndims_out = max(ndims_A,ndims_B);
size_A = size(A,1:ndims_out);
size_B = size(B,1:ndims_out);

k_diffs = find(size_A ~= size_B);
compatible_sizes = all((size_A(k_diffs) == 1) | (size_B(k_diffs) == 1));

if (ndims_A == 2) && (ndims_B == 2)
    % Both inputs are matrices. They must have compatible sizes.
    if compatible_sizes
        AA = reshape(A,size_A(1),1,3);
        BB = reshape(B,size_B(1),1,3);
        if size_A(1) == 1
            out_size = [size_B(1) 1];
        else
            out_size = [size_A(1) 1];
        end
    else
        error(message("images:deltaE:matricesIncompatibleSizes"))
    end

elseif (ndims_A > 2) && (ndims_B > 2)
    % Both inputs are multidimensional arrays. They must have the same
    % size.
    %
    % Developer note: to enable generalized scalar expansion behavior,
    % change this branch to allow the sizes of A and B to compatible.
    if isequal(size_A,size_B)
        AA = A;
        BB = B;
        out_size = size_A;
        out_size(3) = 1;
    else
        error(message("images:deltaE:multidimDifferentSizes"));
    end

elseif (size_A(1) == 1)
    % Input A is 1x3. The final output size is based on the size of B.
    AA = reshape(A,1,1,3);
    BB = B;
    out_size = [size_B(1:2) 1 size_B(4:end)];

elseif (size_B(1) == 1)
    % Input B is 1x3. The final output size is based on the size of A.
    BB = reshape(B,1,1,3);
    AA = A;
    out_size = [size_A(1:2) 1 size_A(4:end)];

else
    % The remaining case is one input is Mx3 (M not equal to 1) and the
    % other is a multidimensional array. That combination is not allowed.
    error(message("images:deltaE:incompatibleFormats"));
end
end

function checkFormat(A)
if ismatrix(A)
    if (size(A,2) ~= 3)
        error(message("images:deltaE:invalidInputFormat"));
    end
else
    if (size(A,3) ~= 3)
        error(message("images:deltaE:invalidInputFormat"));
    end
end
end

% Copyright 2022 The MathWorks, Inc.