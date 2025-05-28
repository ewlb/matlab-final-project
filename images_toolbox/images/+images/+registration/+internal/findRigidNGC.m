% Find rigid transformation to align moving image with fixed image.
%
% Input arguments are expected to be floating-point matrices, with no NaNs
% or Infs, and with minimum dimension of 2 (no vectors). These conditions
% are not checked here.

function [tform,peak] = findRigidNGC(moving,fixed)
    [~,r] = images.registration.internal.findScaleRotationNGC(moving,fixed);
    % Set the scale factor to 1.
    s = 1;
    [tform,peak] = images.registration.internal.resolveSimilarityRotationAmbiguityNGC(moving,fixed,s,r);
end

% Copyright 2023-2024 The MathWorks, Inc.