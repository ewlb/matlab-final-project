%

%#codegen
function R = anglesToRotationMatrix3D(r)
    coder.inline('always');
    coder.internal.prefer_const(r);

    % anglesToRotationMatrix3D(r) takes a vector of three axis rotations
    % (Euler angles in degrees) in XYZ order and returns a 3-D rotation
    % matrix. Note that the matrix is computed as Rz * Ry * Rx. Since the
    % rotation matrices are using the pre-multiply convention, this implies
    % that the resulting rotation matrix will have the effect of rotating
    % about the x-axis first, then the y-axis, and then the z-axis. This is
    % the same as the input order.

    rx = r(1);
    ry = r(2);
    rz = r(3);

    % Reference: https://en.wikipedia.org/wiki/Rotation_matrix#General_rotations
    Rz = [cosd(rz) -sind(rz) 0 ; sind(rz) cosd(rz) 0 ; 0 0 1];
    Ry = [cosd(ry) 0 sind(ry) ; 0 1 0 ; -sind(ry) 0 cosd(ry)];
    Rx = [1 0 0 ; 0 cosd(rx) -sind(rx) ; 0 sind(rx) cosd(rx)];
    R = Rz * Ry * Rx;
end

% Copyright 2021-2022 The MathWorks, Inc.