function blset = selectBlockLocations(bims, params)

arguments
    bims (1,:) {mustBeA(bims, ["blockedImage", "bigimage","blockedPointCloud"])}
    params.Levels (1,:) double {mustBeInteger, mustBePositive, validateLevels(params.Levels, bims)}
    params.BlockSize (1,:) double {mustBeReal, mustBeNumericOrLogical, mustBePositive} = bims(1).BlockSize(1,:)
    params.BlockOffsets (1,:) double {mustBeInteger, mustBePositive, mustBeNonempty}
    params.ExcludeIncompleteBlocks (1,1) logical = false
    params.InclusionThreshold (1,:) double {mustBeGreaterThanOrEqual(params.InclusionThreshold,0), mustBeLessThanOrEqual(params.InclusionThreshold,1), mustBeOfLength(params.InclusionThreshold, "double", bims, "InclusionThreshold")} = 0.5
    params.Masks (1,:) {mustBeA(params.Masks, ["blockedImage", "bigimage"]), mustBeOfLength(params.Masks, [], bims, "Masks")}
    params.UseParallel (1,1) logical {mustHavePCTInstalled(params.UseParallel)} = false
end

if isa(bims,'bigimage')
    blset = images.blocked.internal.selectBigimageBlockLocations(bims, params);
    elseif isa(bims,'blockedPointCloud')
        blset = lidar.blocked.internal.selectBlockedPointCloudBlockLocations(bims, params);
else
    blset = images.blocked.internal.selectBlockedImageBlockLocations(bims, params);
end
end


function validateLevels(levels, bims)
if isscalar(levels)
    % Make it equal to number of images
    levels = repmat(levels, [1 numel(bims)]);
end
numImages = numel(bims);
validateattributes(levels, "numeric", {"integer","positive", "vector", "numel", numImages}, mfilename, "levels", 2)
% Each level should be valid for its corresponding image
for ind = 1:numel(levels)
    if isa(bims, 'bigimage')
        numLevels = numel(bims(ind).SpatialReferencing);
    else
        numLevels = bims(ind).NumLevels;
    end
    validateattributes(levels(ind), "numeric", {'<=', numLevels}, mfilename, "levels", 2);
end
end


function mustBeOfLength(value, type, bims, paramName)
if isempty(type)
    type = class(bims);
end
if ~isscalar(value)
    validateattributes(value, type,...
        {'numel', numel(bims)},...
        mfilename, paramName)
end
end

function mustHavePCTInstalled(useParallel)
if useParallel && ~matlab.internal.parallel.isPCTInstalled()
    error(message('images:bigimage:couldNotOpenPool'))
end
end

% Copyright 2019-2022 The MathWorks, Inc.
