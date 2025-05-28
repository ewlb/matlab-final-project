function blset = selectBlockedImageBlockLocations(bims, params)
% Internal implementation for blockedImage

% Copyright 2019-2020 The MathWorks, Inc.

% All bims should have same NumDimensions
if ~all([bims.NumDimensions]==bims(1).NumDimensions)
    error(message('images:blockedImage:inconsistentNumDims'))
end

if ~isfield(params,'Levels')
    params.Levels = 1; % finest level
end

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

if isfield(params,'BlockSize')
    validateattributes(params.BlockSize,{'numeric'},...
        {'nonempty'}, 'selectBlockLocations', 'BlockSize')
    if numel(params.BlockSize)> bims(1).NumDimensions
        validateattributes(params.BlockSize,{'numeric'},...
            {'numel', bims(1).NumDimensions}, 'selectBlockLocations', 'BlockSize')
    end
    params.BlockSize(end+1:bims(1).NumDimensions) = ...
        bims(1).Size(levels(1), numel(params.BlockSize)+1:end);
end

if isfield(params,'BlockOffsets')
    validateattributes(params.BlockOffsets,{'numeric'},...
        {'nonempty'}, 'selectBlockLocations', 'BlockOffsets')
    if numel(params.BlockOffsets)> bims(1).NumDimensions
        validateattributes(params.BlockOffsets,{'numeric'},...
            {'numel', bims(1).NumDimensions}, 'selectBlockLocations', 'BlockOffsets')
    end
    params.BlockOffsets(end+1:bims(1).NumDimensions) = ...
        bims(1).Size(levels(1), numel(params.BlockOffsets)+1:end);
else
    % Default value
    params.BlockOffsets = params.BlockSize;
end

% Choose dimensionality based on first image's chosen level
dims = numel(bims(1).Size(levels(1),:));

blockOriginCoords = zeros(0,dims);
imageNumbers = zeros(0,1);

for imgIdx = 1:numel(bims)
    thisImage = bims(imgIdx);
    thisLevel = levels(imgIdx);
    imageSize = thisImage.Size(thisLevel, :);
    
    if isfield(params,'Masks')
        thisMask = params.Masks(imgIdx);
        blockOrigins = ...
            maskedBlockLocations(thisImage,thisLevel, thisMask,...
            params.BlockOffsets, params.BlockSize, ...
            params.InclusionThreshold(imgIdx), params.ExcludeIncompleteBlocks,...
            params.UseParallel);
    else
        % Flip first two dimensions to go to coordinates
        x{1} = 1:params.BlockOffsets(2):imageSize(2);
        x{2} = 1:params.BlockOffsets(1):imageSize(1);
        for dimInd = 3:dims
            x{dimInd} = 1:params.BlockOffsets(dimInd):imageSize(dimInd);
        end
        blockOrigins = makeNDGrid(x);
        
        if params.ExcludeIncompleteBlocks
            % The edge beyond which any blockorigin will result in a
            % partial block:
            fullBlockEdge = imageSize-params.BlockSize+1;
            fullBlockEdgeInCoords = fullBlockEdge;
            fullBlockEdgeInCoords(1:2) = [fullBlockEdgeInCoords(2), fullBlockEdgeInCoords(1)];
            inBoundBlocks = all(blockOrigins<=fullBlockEdgeInCoords,2);
            blockOrigins = blockOrigins(inBoundBlocks,:);
        end
    end
    
    blockOriginCoords = cat(1, blockOriginCoords, blockOrigins);
    imageNumbers = cat(1, imageNumbers, repmat(imgIdx, [size(blockOrigins,1), 1]));
end

blset = blockLocationSet(imageNumbers, blockOriginCoords, params.BlockSize, levels);
end

function blockOrigins = maskedBlockLocations(bim, level, bmask, blockOffsets,...
    imBlockSize, inclThres, excludePartial, useParallel)

if bmask.NumDimensions > bim.NumDimensions
    error(message('images:blockedImage:maskMoreDimsThanImage'));
end

numDims = min(bim.NumDimensions, bmask.NumDimensions);

% image block origins in each dimension
imSub = cell(1, numDims);
for ind = 1:numDims
    % Capture the origin points of the blocks for each dimension
    imSub{ind} = 1:blockOffsets(ind):bim.Size(level, ind);
end

% Convert these origin points to mask pixel subscripts
maskSub = cell(1, numDims);
for ind = 1:numDims
    thisDimPoints = imSub{ind};
    imPixelSub = ones(numel(thisDimPoints),bim.NumDimensions);
    imPixelSub(:,ind) = thisDimPoints;
    worldCoord = bim.sub2world(imPixelSub, "level", level);
    worldCoord = worldCoord(:,1:numDims);
    maskPixelSub = bmask.world2sub(worldCoord, "level", 1, "Clamp", false);
    maskSub{ind} = maskPixelSub(:,ind);
end

% Find blocksize corresponding to mask
blockStartWorld = bim.sub2world(ones(1,bim.NumDimensions), "Level", level);
blockEndWorld = bim.sub2world(imBlockSize, "Level", level);

% Expand world region to pixel edges
halfPixelWidth = (bim.WorldEnd(level,:) - bim.WorldStart(level,:))./ bim.Size(level,:)/2;
blockStartWorld = blockStartWorld-halfPixelWidth;
blockEndWorld = blockEndWorld + halfPixelWidth - eps(blockEndWorld);

maskBlockStartSub = bmask.world2sub(blockStartWorld(1:numDims), 'Clamp', false);
maskBlockEndSub = bmask.world2sub(blockEndWorld(1:numDims), 'Clamp', false);
maskBlockSize = maskBlockEndSub- maskBlockStartSub + 1;

siz = cellfun(@numel, imSub);
totalNumberOfBlocks = prod(siz);

inDims = bim.NumDimensions;
imBlockOrigins = ones(totalNumberOfBlocks, inDims);

% Image edge after which any blockorigin will result in a partial block
imageEdgeForFullBlocks = bim.Size(level,:) - imBlockSize + 1;
maskedInFlag = false(1, totalNumberOfBlocks);

if useParallel
    parfor bInd = 1:totalNumberOfBlocks
        curOrigin = ones(1, inDims);
        blockSubs = cell(1, numDims);
        maskBlockOrigin = ones(1, numDims);
        [blockSubs{:}] = ind2sub(siz, bInd);
        for dInd = 1:numDims
            curOrigin(1, dInd) = imSub{dInd}(blockSubs{dInd}); %#ok<PFBNS>
            maskBlockOrigin(1, dInd) = maskSub{dInd}(blockSubs{dInd}); %#ok<PFBNS>
        end
        
        % Is it a partial block we need to exclude?
        if excludePartial && any(curOrigin>imageEdgeForFullBlocks)
            % Partial block that needs to be excluded, nothing to do
        else
            maskBlockEnd = maskBlockOrigin + maskBlockSize-1;
            maskRegion = bmask.getRegionPadded(maskBlockOrigin, maskBlockEnd, 1, 0, []);
            pct = nnz(maskRegion)/numel(maskRegion);
            maskedInFlag(bInd) = (inclThres == 0 && pct>0) ...
                || (inclThres ~= 0 && pct>=inclThres);
        end
        imBlockOrigins(bInd,:) = curOrigin;
    end
    
else
    blockSubs = cell(1, numDims);
    maskBlockOrigin = ones(1, numDims);
    for bInd = 1:totalNumberOfBlocks
        [blockSubs{:}] = ind2sub(siz, bInd);
        for dInd = 1:numDims
            imBlockOrigins(bInd, dInd) = imSub{dInd}(blockSubs{dInd});
            maskBlockOrigin(1, dInd) = maskSub{dInd}(blockSubs{dInd});
        end
        
        % Is it a partial block we need to exclude?
        if excludePartial && any(imBlockOrigins(bInd,:)>imageEdgeForFullBlocks)
            % Partial block that needs to be excluded, nothing to do
        else
            maskBlockEnd = maskBlockOrigin + maskBlockSize-1;
            maskRegion = bmask.getRegionPadded(maskBlockOrigin, maskBlockEnd, 1, 0, []);
            pct = nnz(maskRegion)/numel(maskRegion);
            maskedInFlag(bInd) = (inclThres == 0 && pct>0) ...
                || (inclThres ~= 0 && pct>=inclThres);
        end
    end
end

blockOrigins = imBlockOrigins(maskedInFlag, :);
% Flip to XY from RC
blockOrigins(:,1:2) = blockOrigins(:,[2 1]);
% Flip to row major (most images are row major, this is more efficient
% (e.g. say a stripped TIFF file)
blockOrigins = sortrows(blockOrigins,2);
end


function bo = makeNDGrid(xs)
% From ndgrid
numDims = numel(xs);
siz = cellfun(@numel,xs);
ys = cell(1, numDims);
% Loop fron NDGRID
for ind = 1:numDims
    x = xs{ind};
    s = ones(1,numDims);
    s(ind) = numel(x);
    x = reshape(x,s);
    s = siz;
    s(ind) = 1;
    ys{ind} = repmat(x,s);
end
bo = zeros(numel(ys{1}), numel(xs));
for ind = 1:numel(ys)
    y = ys{ind};
    bo(:,ind) = y(:);
end
end