function out = roisPerBlock(roiPos, refBlockXYLim)
%ROISPERBLOCK 
% Find out ROIs for each block of a blockedImage for efficient rasterization.
% Inputs ROI positions(roiPos - a cell array of Positions) and reference
% block XY-Lims for a blockedImage at a resolution level of interest.
% Output contains the ROI Indices present in each block of the blockedImage,
% at that resolution level.

% Copyright 2019-2020 The MathWorks, Inc.

% roiXYBound contains [Xmin Xmax Ymin Ymax; ...]
% Convert ROI positions passed in roiPos cell array to BoundingBox
% coordinate [Xmin, Xmax , Ymin, Ymax]
roiXYBound = zeros(length(roiPos),4);
for idx=1:size(roiXYBound,1)
    xmin = min(roiPos{idx}(:,1));
    xmax = max(roiPos{idx}(:,1));
    ymin = min(roiPos{idx}(:,2));
    ymax = max(roiPos{idx}(:,2));
    roiXYBound(idx,:) = [xmin xmax ymin ymax];
end

% find ROIs in each block (can be parallelized)
totalNumBlocks = size(refBlockXYLim,1);
roiPerBlock = cell(totalNumBlocks,1);

for idx=1:totalNumBlocks
    roiPerBlock{idx} = images.blocked.internal.overlappingBox(refBlockXYLim(idx,:),roiXYBound);
end

out = roiPerBlock;