% Find similarity transformation to align moving image with fixed image.
%
% Input arguments are expected to be floating-point matrices, with no NaNs
% or Infs, and with minimum dimension of 2 (no vectors). These conditions
% are not checked here.

function [tform,peak] = findSimilarityNGC(moving,fixed)
    [s,r] = images.registration.internal.findScaleRotationNGC(moving,fixed);
    [tform,peak] = images.registration.internal.resolveSimilarityRotationAmbiguityNGC(moving,fixed,s,r);
end

% Copyright 2023-2024 The MathWorks, Inc.