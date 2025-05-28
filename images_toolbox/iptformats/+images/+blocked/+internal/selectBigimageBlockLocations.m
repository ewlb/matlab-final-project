function blset = selectBigimageBlockLocations(bims, params)
% Internal implementation for bigimage

% Copyright 2019-2020 The MathWorks, Inc.

if ~isfield(params,'Levels')
    params.Levels = bims(1).FinestResolutionLevel;
end

if isscalar(params.BlockSize)
    params.BlockSize = [params.BlockSize, params.BlockSize];
end

validateattributes(params.BlockSize,{'double'}, {'numel',2});

% Syntax sugar
levels = params.Levels;
if isscalar(levels)
    % Make it equal to number of images
    levels = repmat(params.Levels, [1 numel(bims)]);
end
if isfield(params,'Masks') && isscalar(params.Masks)
    % Make it equal to number of images
    params.Masks = repmat(params.Masks, [1, numel(bims)]);
end
if isfield(params,'InclusionThreshold') && isscalar(params.InclusionThreshold)
    % Make it equal to number of images
    params.InclusionThreshold = repmat(params.InclusionThreshold, [1, numel(bims)]);
end

if isfield(params,'BlockOffsets')
    validateattributes(params.BlockOffsets,{'double'}, {'numel',2});
else
    % Default value
    params.BlockOffsets = params.BlockSize;
end

blockOriginXY = zeros(0,2);
imageNumbers = zeros(0,1);

for imgIdx = 1:numel(bims)
    thisImage = bims(imgIdx);
    thisLevel = levels(imgIdx);
    imRef = thisImage.SpatialReferencing(thisLevel);
    
    if isfield(params,'Masks')
        thisMask = params.Masks(imgIdx);
        validateattributes(thisMask.Channels, {'numeric'},...
            {'<=',1}, mfilename, 'MASK.Channels');
        blockOrigins = ...
            maskedBlockLocations(imRef, thisMask,...
            params.BlockOffsets, params.BlockSize, ...
            params.InclusionThreshold(imgIdx), params.ExcludeIncompleteBlocks,...
            params.UseParallel);
    else
        % Pick blocks from a regular grid
        X = 1:params.BlockOffsets(2):imRef.ImageSize(2);
        Y = 1:params.BlockOffsets(1):imRef.ImageSize(1);
        [allY, allX] = meshgrid(Y,X);
        blockOrigins = [allX(:), allY(:)];
        if params.ExcludeIncompleteBlocks
            % The edge beyond which any blockorigin will result in a
            % partial block:
            fullBlockEdge = imRef.ImageSize-params.BlockSize+1;
            inBoundBlocks = blockOrigins(:,1)<=fullBlockEdge(2) & blockOrigins(:,2)<=fullBlockEdge(1);
            blockOrigins = blockOrigins(inBoundBlocks,:);
        end
    end
    
    blockOriginXY = cat(1, blockOriginXY, blockOrigins);
    imageNumbers = cat(1, imageNumbers, repmat(imgIdx, [size(blockOrigins,1), 1]));
end

blset = blockLocationSet(imageNumbers, blockOriginXY, params.BlockSize, levels);
end

function blockOrigins = maskedBlockLocations(imRef, mask, blockOffsets, blockSize, inclThres, excludePartial, useParallel)

% image _intrinsic_ coordinates for block origins
imIntX = 1:blockOffsets(2):imRef.ImageSize(2);
imIntY = 1:blockOffsets(1):imRef.ImageSize(1);

% Convert to world, these will be used on the mask
[mwX, ~] = imRef.intrinsicToWorldAlgo(imIntX,1);
[~, mwY] = imRef.intrinsicToWorldAlgo(1,imIntY);

% Find the extent of a block in world coordinates:
% Offsets are in (r,c), so flip to get intrinsic coordinates
[bx,by] = imRef.intrinsicToWorldAlgo(blockSize(2),blockSize(1));
% This when added to the origin gives a location just before the next block
% starts
origin = [imRef.XWorldLimits(1), imRef.YWorldLimits(1)];
blockSizeInWorld = [bx,by]-origin-[imRef.PixelExtentInWorldX, imRef.PixelExtentInWorldY]/2;

numXPoints = numel(mwX);
numYPoints = numel(mwY);

imageEndWorld = [imRef.XWorldLimits(2), imRef.YWorldLimits(2)];

% Loop through each block
if useParallel
    % For each 'world' location of a block, save the intrinsic origin (2
    % elements) and the include/exclude flag (1 element)
    blockOrigins = zeros(numXPoints,numYPoints, 2);
    includeFlags = false(numXPoints,numYPoints);
    parfor yInd = 1:numYPoints
        % Process and collect ALL blocks so that we can do valid indexing
        % within the parfor loop, trim later
        for xInd = 1:numXPoints
            [blockStart, includeFlag] = processMaskRegion(mwX, mwY, ...
                blockSizeInWorld, imageEndWorld, excludePartial, ...
                mask, imIntX, imIntY, inclThres, xInd, yInd);
            blockOrigins(yInd, xInd,:) = blockStart;
            includeFlags(yInd, xInd) = includeFlag;
        end
    end
    blockOrigins = reshape(blockOrigins, [size(blockOrigins,1)*size(blockOrigins,2), 2]);
    % Trim down to only include blocks which satisfied the threshold
    blockOrigins = blockOrigins(includeFlags(:),:);
    
else
    blockOrigins = [];
    for yInd = 1:numYPoints
        for xInd = 1:numXPoints
            [blockStart, includeFlag] = processMaskRegion(mwX, mwY, ...
                blockSizeInWorld, imageEndWorld, excludePartial, ...
                mask, imIntX, imIntY, inclThres, xInd, yInd);
            if includeFlag
                blockOrigins(end+1,:) = blockStart; %#ok<AGROW>
            end
        end
    end
end

end


function [blockStartInImageIntrinsic, includeFlag] = processMaskRegion(mwX, mwY, blockSizeInWorld, imageEndWorld, excludePartial, mask, imIntX, imIntY, inclThres, xInd, yInd)
% Process one image block worth of region from the mask

blockStartInImageIntrinsic = [imIntX(xInd), imIntY(yInd)];

% Mask extents for this block in world coordinates
blockStartWorld = [mwX(xInd), mwY(yInd)];
blockEndWorld = blockStartWorld + blockSizeInWorld;

if excludePartial && any(blockEndWorld>imageEndWorld)
    % Partial block - exclude.
    includeFlag = false;
else
    % Percentage nnz for this region of the mask
    pct = mask.computeWorldRegionNNZ(mask.FinestResolutionLevel,...
        blockStartWorld, blockEndWorld);
    includeFlag  =  (inclThres == 0 && pct>0) ...
        || (inclThres ~= 0 && pct>=inclThres);
end
end
