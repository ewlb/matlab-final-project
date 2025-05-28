function checkTransformationMatrixCondition(A) %#codegen
    % Throw a warning message if the geometric transformation matrix A will
    % result in a badly-conditioned warning or a
    % singular-to-working-precision warning when used with the INV function
    % or the backslash operator.
    %
    % Input is assumed to be a square, double- or single-precision matrix.
    % This is not checked.

    if images.geotrans.internal.isAffine(A)
        % When an affine transformation matrix is applied by
        % transformPointsInverse, the translation portion is handled
        % separately, and only the upper left submatrix is passed to INV or
        % used with backslash. So, only the upper left submatrix needs to
        % be checked.
        [M,N] = size(A);
        do_warn = isBadlyConditioned(A(1:M-1,1:N-1));
    else
        do_warn = isBadlyConditioned(A);
    end

    coder.internal.warningIf(do_warn,...
        "images:geotrans:transformationMatrixBadlyConditioned");
end

function tf = isBadlyConditioned(A)
    if coder.target('MATLAB')
        % The isIllConditioned method of the decomposition class returns true
        % if inv(A) or A\x would throw a warning message about being badly
        % conditioned or singular to working precision.
        tf = isIllConditioned(decomposition(A));
    else
        % The decomposition object is not supported for code generation.
        % Instead, use the rcond function and compare to eps. This method
        % is close to the method used by the isIllConditioned method, but
        % it is known to be slightly different for upper and lower
        % triangular matrices.
        rc = rcond(A);
        tf = rc < eps('like',rc);
    end
end

% Copyright 2022 The MathWorks, Inc.