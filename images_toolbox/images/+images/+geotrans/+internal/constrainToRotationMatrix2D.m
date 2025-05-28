function [Rc,r] = constrainToRotationMatrix2D(R)
    % constrainToRotationMatrix2D(R) modifies R so that it is exactly a
    % rotation matrix. It returns the constrained (modified) matrix, as
    % well as the rotation angle (in degrees) corresponding to the
    % constrained matrix.

    % First, constrain the rotation matrix values to be inside the closed
    % interval [-1,1]. If those values are very slightly outside that
    % range, then the subsequent call to atan2d could return complex
    % values.

    %#codegen

    R_clamped = max(min(R,1),-1);

    cosd_r = R_clamped(2,2);
    sind_r = R_clamped(2,1);
    r = atan2d(sind_r,cosd_r);

    r = images.geotrans.internal.canonicalizeDegreeAngle(r);

    R2 = [cosd(r) -sind(r) ; sind(r) cosd(r)];

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
