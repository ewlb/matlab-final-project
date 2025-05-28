function R = leastSquaresRotationMatrix(U,X)
    % Compute a least-squares solution to finding a rotation matrix that
    % approximately maps the points in U to the points in X. U and X are
    % P-by-d, where d is the dimensionality of the points.

    % Reference: "Kabsch algorithm,"
    % https://en.wikipedia.org/wiki/Kabsch_algorithm 

    % Transpose U and X to get dxP matrices containing P points with
    % dimension d.
    U = U';
    X = X';
    d = size(U,1);

    B = X * U';

    [V1,~,V2] = svd(B);

    M = eye(d);
    M(end,end) = sign(det(V1)*det(V2));
    
    R = V1 * M * V2';
end

% Copyright 2023 The MathWorks, Inc.