function [decorrTransform, offset] = fitdecorrtrans(means, Cov, useCorr, targetMeanIn, targetSigmaIn) %#codegen
% FITDECORRTRANS Fit decorrelating transformation to image statistics.

% Copyright 2023 The MathWorks, Inc.

% Square-root variances in a diagonal matrix.
coder.inline('always');
coder.internal.prefer_const(means, Cov, useCorr, targetMeanIn, targetSigmaIn);

S = real(diag(sqrt(diag(complex(Cov)))));

if isempty(targetSigmaIn)
    % Restore original sample variances.
    targetSigma = S;
else
    targetSigma = targetSigmaIn;
end

if useCorr
    Corr = pinv(S) * Cov * pinv(S);
    Corr(logical(eye(size(Corr,1)))) = 1;
    [V1,D1] = eig(Corr);
    V = real(V1);
    D = real(D1);
    decorrTransform = pinv(S) * V * decorrWeight(real(D)) * V' * targetSigma;
else
    [V1,D1] = eig(Cov);
    V = real(V1);
    D = real(D1);
    decorrTransform = V * decorrWeight(D) * V' * targetSigma;
end

% Get the output variances right even for correlated bands, except
% for zero-variance bands---which can't be stretched at all.
decorrTransform = decorrTransform * ...
    pinv(diag(sqrt(diag(decorrTransform' * Cov * decorrTransform)))) * targetSigma;

if isempty(targetMeanIn)
    % Restore original sample means.
    targetMean = means;
else
    targetMean = targetMeanIn;
end

offset = targetMean - means * decorrTransform;

%--------------------------------------------------------------------------
% Given the diagonal eigenvalue matrix D, compute the decorrelating
% weights W.  In the full rank, well-conditioned case, decorrWeight(D)
% returns the same result as sqrt(inv(D)).  In addition, it provides
% a graceful way to handle rank-deficient or near-rank-deficient
% (ill-conditioned) cases resulting from situations of perfect or
% near-perfect band-to-band correlation and/or bands with zero variance.

function W = decorrWeight(D)
coder.inline('always');
D(D < 0) = 0;
W = sqrt(pinv(D));

%--------------------------------------------------------------------------
% Pseudoinverse of a diagonal matrix, with a larger-than-standard
% tolerance to help in handling edge cases.  We've provided our
% own in order to: (1) Avoid replacing all calls to PINV with calls to
% PINV(...,TOL) and (2) Take advantage of the fact that our input is
% always diagonal so we don't need to call SVD.

function S = pinv(D)
coder.inline('always');
coder.internal.prefer_const(D);

d = diag(D);
tol =length(d) * max(d) * sqrt(eps);
keep = d > tol;
s = ones(size(d));
s(keep) = s(keep) ./ d(keep);
s(~keep) = 0;
S = diag(s);