%

%#codegen
function tf = matricesNearlyEqual(A,B)
    % matricesNearlyEqual
    %   matricesNearlyEqual(A,B) returns true if A and B are the
    %   same, within floating-point round-off error. A and B are assumed to
    %   be square and of the same class, and this is not checked.

    coder.inline('always');
    coder.internal.prefer_const(A,B);
                

    % Set a relative threshold based on roughly 75% of the significant
    % digits provided by the corresponding class.
    t = eps(class(A)) ^ (3/4);

    % Normalize by the max of the norms of the two matrices. This
    % formulation makes the nearly-equal test be commutative.
    R = max(norm(A),norm(B));

    % In case A and B are both zero or extremely tiny, use a different
    % normalization. "Extremely tiny" means roughly 1e-308 (for double) 
    % or 1e-38 (for single). 
    R0 = 100 * realmin(class(A)) / t;
    R = max(R,R0);

    % Compute the answer using the relative threshold and the denominator
    % normalization.
    tf = (norm(A - B) / R) <= t;
end

% Copyright 2021-2022 The MathWorks, Inc.