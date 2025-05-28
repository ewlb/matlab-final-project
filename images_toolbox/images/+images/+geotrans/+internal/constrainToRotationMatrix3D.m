%

%#codegen
function Rc = constrainToRotationMatrix3D(R)
    % constrainToRotationMatrix3D(R) modifies R so that it is exactly a
    % rotation matrix. It returns the constrained (modified) matrix.

    R_clamped = max(min(R,1),-1);

    [U,~,V] = svd(R_clamped);
    R2 = U*V';

    % The determinant of an orthogonal matrix is either -1 or 1. If the
    % determinant is -1, then it is not a rotation matrix, so an extra step
    % is needed. Avoid testing for equality to -1 by just checking to see
    % if it is negative.
    if det(R2) < 0
        % If the determinant of Rc_tmp is negative (and therefore -1), Rc
        % is not a rotation matrix. Swapping any 2 rows of a matrix
        % reverses the sign of the determinant and so will convert to a
        % rotation matrix.
        %
        % The choice of which rows to swap does not really matter here.
        % Since Rc is clearly not close to being a rotation matrix, make an
        % arbitrary choice.
        R2([1 2],:) = R2([2 1],:);
    end

    % Experiments with several hundred thousand randomly chosen rotation
    % matrices found that repeating the SVD constraint procedure above did
    % not perturb a rotation matrix more than about 6 times eps(type). Make
    % this operation idempotent by returning the original input matrix
    % (clamped to the range [-1,1]) if it is within 10*eps (by matrix norm)
    % of R2.
    d = norm(R_clamped - R2) / eps(class(R));
    if d < 10
        Rc = R_clamped;
    else
        Rc = R2;
    end
end

% Copyright 2021-2022 The MathWorks, Inc.
