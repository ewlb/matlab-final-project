%

%#codegen
function tf = isTransformationMatrixSingular(A)
    % isTransformationMatrixSingular - True if transformation matrix is singular.
    %   isTransformationMatrixSingular(A) returns true if A is singular. A
    %   is assumed to be square, and this is not checked.
    %
    %   If A has the form of an affine matrix, where the lower right
    %   element is 1 and the bottom row is otherwise 0, then this function
    %   checks to see whether the submatrix A(1:end-1,1:end-1) is singular.

    coder.inline('always');
    coder.internal.prefer_const(A);
                
    m = size(A,1);
    is_affine = (A(m,m) == 1) && all(A(m,1:m-1) == 0);
    if is_affine
        tf = rank(A(1:m-1,1:m-1)) < (m-1);
    else
        tf = rank(A) < m;
    end

end

% Copyright 2021-2022 The MathWorks, Inc.