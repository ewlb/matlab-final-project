function [is_rotation_matrix,Rc,r] = checkRotationMatrix2D(R) %#codegen
    % checkRotationMatrix2D(R) returns 
    %    - a logical flag indicating whether R is a rotation matrix
    %      (within floating-point round-off error)
    %    - a matrix that has been constrained to be a true rotation matrix
    %    - the rotation angle (in degrees) corresponding to the constrained
    %      rotation matrix

    coder.inline('always');
    coder.internal.prefer_const(R);

    [Rc,r] = images.geotrans.internal.constrainToRotationMatrix2D(R);
    is_rotation_matrix = images.geotrans.internal.matricesNearlyEqual(R,Rc);
end

% Copyright 2021-2022 The MathWorks, Inc.