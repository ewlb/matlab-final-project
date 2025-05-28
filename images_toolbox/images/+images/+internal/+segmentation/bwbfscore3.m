function [score,precision,recall] = bwbfscore3(bwpred,bwtrue,theta,alpha)
%BWBFSCORE3 BF score for 3-D logical images
%
%   SCORE = BWBFSCORE3(BWPRED,BWTRUE) computes the BF score between 3-D
%   binary images BWPRED and BWTRUE, where BWPRED represents the actual
%   predicted binary segmentation and BWTRUE represents the ground truth
%   binary segmentation.
%
%   [SCORE,PRECISION,RECALL] = BWBFSCORE3(BWPRED,BWTRUE) also returns the
%   PRECISION and RECALL values used in the computation of the SCORE. SCORE
%   is the harmonic mean of PRECISION and RECALL.
%
%   [___] = BWBFSCORE3(___,THETA,ALPHA) allows you to set additional
%   parameters of the BF score. THETA is the distance threshold below which
%   a predicted boundary point is considered to be a true positive. If
%   omitted, the default value of THETA is 0.75% of the volume diagonal.
%   ALPHA weighs the harmonic mean of the PRECISION and RECALL. Values of
%   ALPHA lower than 0.5 give more weight to the RECALL value, while values
%   higher than 0.5 give more weight to the PRECISION value. ALPHA must be
%   in [0,1]. If omitted, the default value of ALPHA is 0.5.
%
%   Notes
%   -----
%   [1] The BF score is the harmonic mean of the precision and recall
%   values, which is defined as
%
%     SCORE = 2 * PRECISION * RECALL / (RECALL + PRECISION)
%
%   [2] The alpha-weighted BF score is defined as
%
%     SCORE = 1 / ( (1-ALPHA)/RECALL + ALPHA/PRECISION )
%
%   [3] The precision is the ratio of the number of points on the boundary
%   of the predicted segmentation that are close enough to the boundary of
%   the ground truth segmentation to the length of the predicted boundary,
%   i.e., precision is the fraction of detections that are true positives
%   rather than false positives.
%
%   [4] The recall is the ratio of the number of points on the boundary of
%   the ground truth segmentation that are close enough to the boundary of
%   the predicted segmentation to the length of the ground truth boundary,
%   i.e., recall is the fraction of true positives that are detected rather
%   than missed.
%
%   [5] This function does not do any input validation to maximize speed.
%   This is a private implementation meant for internal use. The public
%   function you should use is BFSCORE.
%
%   Reference
%   ---------
%   Csurka, Gabriela, et al. "What is a good evaluation measure for
%   semantic segmentation?." BMVC. Vol. 27. 2013.
%
%   See also BFSCORE, images.internal.segmentation.bwbfscore2.

%   Copyright 2017-2020 The MathWorks, Inc.

if (nargin < 4)
    alpha = 0.5;
    if (nargin < 3)
        % 0.75% of the image diagonal (across the volume).
        theta = 0.75 / 100 * sqrt(size(bwpred,1)^2 + size(bwpred,2)^2 + size(bwpred,3)^2);
    end
end

% Erode objects by 1 pixel.
SE = cat(3, ...
    [0 0 0; 0 1 0; 0 0 0], ...
    [0 1 0; 1 1 1; 0 1 0], ...
    [0 0 0; 0 1 0; 0 0 0]);

% Pad with zeros so that objects that touch the
% image border are eroded away from the border.
bwpred_padded = padarray(bwpred,[1 1 1],false);
bwtrue_padded = padarray(bwtrue,[1 1 1],false);
bwpred_eroded = imerode(bwpred_padded,SE);
bwtrue_eroded = imerode(bwtrue_padded,SE);
bwpred_eroded = bwpred_eroded(2:end-1,2:end-1,2:end-1);
bwtrue_eroded = bwtrue_eroded(2:end-1,2:end-1,2:end-1);

% Predicted and true boundaries (surfaces in 3-D) as logical arrays.
boundarypred = bwpred & ~bwpred_eroded;
boundarytrue = bwtrue & ~bwtrue_eroded;

% Coordinates of the boundary points.
idxpred = find(boundarypred);
idxtrue = find(boundarytrue);

% Convert the coordinates from linear indices to sub-indices.
[Ipred,Jpred,Kpred] = ind2sub(size(bwpred), idxpred);
[Itrue,Jtrue,Ktrue] = ind2sub(size(bwtrue), idxtrue);

% The MEX function below executes code similar in concept
% to the following MATLAB block but is optimized for speed.
%
%     Npred = numel(idxpred);
%     Ntrue = numel(idxtrue);
%
%     D = (Itrue' - Ipred).^2 + (Jtrue' - Jpred).^2 + (Ktrue' - Kpred).^2;
%     D = D < theta^2;
%
%     Dpred = any(D,2);
%     Dtrue = any(D,1);
%
%     precision = nnz(Dpred) / Npred;
%     recall    = nnz(Dtrue) / Ntrue;
[precision,recall] = images.internal.builtins.bfscore(theta, ...
    single(Ipred),single(Jpred),single(Kpred), ...
    single(Itrue),single(Jtrue),single(Ktrue));

score = 1 / ((1-alpha) / recall + alpha / precision);
