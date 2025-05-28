function [A,is_ill_conditioned] = leastSquaresAffineMatrix(U,X)
    % Return the affine matrix A that minimizes the sum of least-squares
    % residual for mapping a set of input-space points, U, to output-space
    % points, X: 
    %
    %     X \approx A * U
    %
    % U and X are P-by-d, where d is the point dimensionality.
    %
    % Note: If the number of linearly independent points in U is less than
    % d + 1, then the matrix A is not unique, and this function returns
    % just one of many possible solutions.

    % Transpose U and X to make dxP matrices containing P input-space
    % points with dimension d.
    U = U';
    X = X';

    % Normalize the input-space points. 
    %
    % U_nh is the matrix of origin-centered, scaled input-space points in
    % homogeneous coordinates.
    %
    % B_u is the normalization matrix that converts the homogeneous
    % input-space points, U_h, to U_nh: 
    %
    %     U_nh = B_u * U_h
    %
    [U_nh,B_u] = normalizeControlPoints(U);

    % Normalize the output-space points.
    %
    % X_nh is the matrix of origin-centered, scaled output-space points in
    % homogeneous coordinates.
    %
    % B_x is the matrix that converts the homogeneous output-space points,
    % X_h, to X_nh: 
    %
    %     X_nh = B_x * X_h 
    %
    [X_nh,B_x] = normalizeControlPoints(X);

    % Compute A_n, a least-squares solution to X_nh \approx A_n * U_nh.
    %
    % Instead of performing the computation using the "/" operator directly
    % on U_nh, compute the complete orthogonal decomposition of U_nh first
    % and use that. Set CheckCondition to false so that no warning message
    % is issued here.
    U_nh_d = decomposition(U_nh, "cod", CheckCondition=false);
    A_n = X_nh / U_nh_d;

    % Using the normalization matrices, compute A from A_n.
    %
    % As above, use the decomposition with CheckCondition set to false.
    B_x_d = decomposition(B_x, "cod", CheckCondition=false);
    A = B_x_d \ A_n * B_u;

    % Use the isIllConditioned method of decomposition objects to return
    % the ill-conditioned flag.
    is_ill_conditioned = isIllConditioned(U_nh_d) || isIllConditioned(B_x_d);
end

function [U_nh,B_u] = normalizeControlPoints(U)
    % Normalize the set of input points by shifting the mean to the origin
    % and then scaling by the maximum absolute value of all the point
    % coordinates.
    %
    % Also return the affine matrix that performs this normalization.
    
    [d,P] = size(U);

    % c_u is the centroid of the set of points.
    c_u = mean(U,2);

    % U_c is a matrix of origin-centered points.
    U_c = U - c_u;

    % s_u is the maximum absolute value of the elements in U_c.
    s_u = max(abs(U_c),[],"all");
    if (s_u == 0)
        % The centered coordinates are all 0. Don't try to scale. Replace
        % s_u with 1.0, using the same data type.
        s_u = ones(1,1,"like",s_u);
    end

    % U_n is the matrix of normalized, origin-centered points.
    U_n = (1/s_u) * U_c;

    % U_nh is the homogeneous coordinate form of U_n.
    U_nh = [U_n ; ones(1,P)];

    % B_u is the matrix that converts the original points to the
    % normalized, origin-centered points (in homogeneous coordinate form):
    % U_nh = B_u * U_h
    B_u = [ ...
        (1/s_u)*eye(d)    -c_u/s_u
        zeros(1,d)         1       ];
end
