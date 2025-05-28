function [CC, scores,validIdx] = filterObjectsBySize(CC, scores, minObjArea, maxObjArea)
% Filter all objects below minsize,including filling holes.
% Filter all objects above max size.

%   Copyright 2023-2024 The MathWorks, Inc.

imSize = CC.ImageSize;
pxIdList = CC.PixelIdxList;

filteredPxIdList = {};
validIdx = [];
objArea = [];

for idx = 1:CC.NumObjects

    mask = false(imSize);
    mask(pxIdList{idx}) = true;
    
    % Remove any region smaller than minObjArea
    mask  = bwareaopen(mask,round(minObjArea));
    % Fill holes smaller than minobjArea
    mask= ~bwareaopen(~mask, round(minObjArea));
    
    % Convert mask to pixel Idx list
    pxIds = images.internal.sam.masks2PixelIdxList(mask);

    if(~isempty(pxIds{1}) && numel(pxIds{1})<=maxObjArea)
        objArea = [objArea numel(pxIds{1})];
        filteredPxIdList = [filteredPxIdList pxIds];
        validIdx = [validIdx idx];
    end

end
scores = scores(validIdx);

% Sort objects based on area
[~, sortIdx] = sort(objArea, "descend");

filteredPxIdList = filteredPxIdList(sortIdx);
scores = scores(sortIdx);

CC.NumObjects = length(filteredPxIdList);
CC.PixelIdxList = filteredPxIdList;