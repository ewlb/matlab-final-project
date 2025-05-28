%

%#codegen
function [is_rotation_matrix,Rc] = checkRotationMatrix3D(R)
    % checkRotationMatrix3D(R) returns
    %    - a matrix that has been constrained to be a true rotation matrix
    %    - a logical flag indicating whether R is a rotation matrix
    %      (within floating-point round-off error)

    coder.inline('always');
    coder.internal.prefer_const(R);
            
    Rc = images.geotrans.internal.constrainToRotationMatrix3D(R);
    is_rotation_matrix = images.geotrans.internal.matricesNearlyEqual(R,Rc);
end

% Copyright 2021-2022 The MathWorks,Inc.