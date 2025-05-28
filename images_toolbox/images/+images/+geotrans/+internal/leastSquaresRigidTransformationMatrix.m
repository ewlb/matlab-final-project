function A = leastSquaresRigidTransformationMatrix(U,X)

    % Using a least-squares computation, find a rigid transformation matrix
    % that approximately maps the points U to the points X. U and X are
    % P-by-d, where d is the dimensionality of the points.

    % Step 1: Mean-shift U and X so that they are centered at the origin.
    d = size(U,2);
    c_u = mean(U,1);
    c_x = mean(X,1);

    U_c = U - c_u;
    X_c = X - c_x;

    % Step 2: Use an SVD-based technique (in leastSquaresRotationMatrix) to
    % find a minimum mean-squared solution for a rotation matrix that maps
    % mean-centered U points to mean-centered X points.
    R = images.geotrans.internal.leastSquaresRotationMatrix(U_c,X_c);

    % Step 3: Combine the mean-shift translations with the mean-centered
    % rotation matrix to form a rigid affine transformation matrix.
    A1 = [ ...
        eye(d)    -c_u'
        zeros(1,d)  1    ];

    A2 = [ ...
        R          zeros(d,1)
        zeros(1,d)   1         ];
    
    A3 = [ ...
        eye(d)     c_x'
        zeros(1,d)  1    ];

    A = A3 * A2 * A1;
end

% Copyright 2023 The MathWorks, Inc.