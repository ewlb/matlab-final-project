function outstatsTable = regionprops3(varargin) %#codegen
%REGIONPROPS3 Measure properties of 3-D volumetric image regions.

% Copyright 2022-2023 The MathWorks, Inc.

narginchk(1,inf);
coder.internal.prefer_const(varargin);

if islogical(varargin{1}) || isstruct(varargin{1})
    %REGIONPROPS3(BW,...) or REGIONPROPS3(CC,...)
    if islogical(varargin{1})
        %REGIONPROPS3(BW,...)

        coder.internal.errorIf(numel(size(varargin{1}))>3,'images:regionprops3:invalidSizeBW');
        CC = bwconncomp(varargin{1});

        if (numel(size(varargin{1})) == 2) && coder.internal.isConst(size(varargin{1})) &&...
                (size(varargin{1},1)== 0 || size(varargin{1},2) == 0)
            numObjs = 0;
        elseif (numel(size(varargin{1})) == 3) && coder.internal.isConst(size(varargin{1})) &&...
                (size(varargin{1},1) == 0 || size(varargin{1},2) == 0 || size(varargin{1},3) == 0)
            numObjs = 0;
        else
            numObjs = CC.NumObjects;
        end
    else
        %REGIONPROPS3(CC,...)
        CC = varargin{1};
        validateCC(CC);
        coder.internal.errorIf(numel(CC.ImageSize)>3,'images:regionprops3:invalidSizeCC');
        if coder.internal.isConst(size(CC.PixelIdxList)) && size(CC.PixelIdxList,2) == 0
            numObjs = 0;
        else
            numObjs = CC.NumObjects;
        end
    end

    imageSize = CC.ImageSize;
    L = []; % Input Label Image
else
    %REGIONPROPS3(L,...)

    L = varargin{1};

    supportedTypes = {'uint8','uint16','uint32','int8','int16','int32','single','double'};
    supportedAttributes = {'3d','real','nonsparse','finite'};

    validateattributes(L,supportedTypes,supportedAttributes, ...
        mfilename,'L',1);

    imageSize = size(L);

    if isempty(L)
        numObjs = 0;
    else
        numObjs = max(0,floor(double(max(L(:)))) );
    end

    CC = [];
end

[V,requestedStats,outstats,startIdxForProp,isGrayScaleImageProvided] = ...
    parseInputsAndInitializeOutStruct(imageSize,numObjs,varargin{:});

[stats,statsAlreadyComputed] = initializeStatsStruct(V,imageSize,numObjs,TEMPSTATS_ALL);

% Compute VoxelIdxList
[stats,statsAlreadyComputed] = ...
    computeVoxelIdxList(L,CC,numObjs,stats,statsAlreadyComputed);

% Compute other statistics.
numRequestedStats = coder.const(length(requestedStats));
for k = coder.unroll(1:numRequestedStats)
    switch requestedStats(k)
        case VOLUME
            [stats,statsAlreadyComputed] = ...
                computeVolume(stats,statsAlreadyComputed);
        case CENTROID
            [stats,statsAlreadyComputed] = ...
                computeCentroid(imageSize,stats,statsAlreadyComputed);

        case BOUNDINGBOX
            [stats,statsAlreadyComputed] = ...
                computeBoundingBox(imageSize,stats,statsAlreadyComputed);

        case SUBARRAYIDX
            [stats,statsAlreadyComputed] = ...
                computeSubarrayIdx(imageSize,stats,statsAlreadyComputed);

        case IMAGE
            [stats,statsAlreadyComputed] = ...
                computeImage(imageSize,stats,statsAlreadyComputed);

        case EQUIVDIAMETER
            [stats,statsAlreadyComputed] = ...
                computeEquivDiameter(stats,statsAlreadyComputed);

        case EXTENT
            [stats, statsAlreadyComputed] = ...
                computeExtent(imageSize,stats,statsAlreadyComputed);

        case VOXELIDXLIST
            %Do Nothing, Already Done

        case VOXELLIST
            [stats,statsAlreadyComputed] = ...
                computeVoxelList(imageSize,stats,statsAlreadyComputed);

        case {PRINCIPALAXISLENGTH,ORIENTATION,EIGENVECTORS,EIGENVALUES}
            [stats,statsAlreadyComputed] = ...
                computeEllipsoidParams(imageSize,stats,statsAlreadyComputed);

        case VOXELVALUES
            [stats,statsAlreadyComputed] = ...
                computeVoxelValues(V,stats,statsAlreadyComputed);

        case WEIGHTEDCENTROID
            [stats,statsAlreadyComputed] = ...
                computeWeightedCentroid(imageSize,V,stats,statsAlreadyComputed);

        case MEANINTENSITY
            [stats, statsAlreadyComputed] = ...
                computeMeanIntensity(V,stats,statsAlreadyComputed);

        case MININTENSITY
            [stats,statsAlreadyComputed] = ...
                computeMinIntensity(V,stats,statsAlreadyComputed);

        case MAXINTENSITY
            [stats,statsAlreadyComputed] = ...
                computeMaxIntensity(V,stats,statsAlreadyComputed);

        otherwise
            assert(false, 'Invalid property string');
    end
end

% Create the output stats structure array.
[outstats,stats] = populateOutputStatsStructure(outstats,stats); %#ok<ASGLU>

if isempty(outstats)
    % Explicitly handling the case when the table output is empty at runtime
    varnames = fieldnames(outstats);

    if startIdxForProp == NOPROPERTIESREQUESTED
        vars = initializeStatsCellArray(imageSize,V,numObjs,isGrayScaleImageProvided);
    else
        vars = initializeStatsCellArray(imageSize,V,numObjs,isGrayScaleImageProvided,varnames,varargin{startIdxForProp});
    end
    outstatsTable = table(vars{:},'VariableNames',varnames);
    return;
end

% Convert Stats Struct to Table
outstatsTable = struct2table(outstats,'AsArray',true);
end

%--------------------------------------------------------------------------
function [vars] = initializeStatsCellArray(imageSize,V,numObjs,isGrayScaleImageProvided,varnames,varargin)
coder.inline('always');
coder.internal.prefer_const(imageSize,V,numObjs,varnames,varargin);

shapeMeasurements = {'Volume', ...
    'Centroid', ...
    'BoundingBox', ...
    'SubarrayIdx', ...
    'Image', ...
    'EquivDiameter', ...
    'Extent', ...
    'VoxelIdxList', ...
    'VoxelList', ...
    'PrincipalAxisLength', ...
    'Orientation', ...
    'EigenVectors', ...
    'EigenValues'};

basicMeasurements = {'Volume', ...
    'Centroid', ...
    'BoundingBox'};

allMeasurements = {'Volume', ...
    'Centroid', ...
    'BoundingBox', ...
    'SubarrayIdx', ...
    'Image', ...
    'EquivDiameter', ...
    'Extent', ...
    'VoxelIdxList', ...
    'VoxelList', ...
    'PrincipalAxisLength', ...
    'Orientation', ...
    'EigenVectors', ...
    'EigenValues',...
    'VoxelValues', ...
    'WeightedCentroid', ...
    'MeanIntensity', ...
    'MinIntensity', ...
    'MaxIntensity'};

numProps = coder.const(numel(varargin));
if numProps == 0
    reqStatsStr = basicMeasurements;
else
    if coder.const(strcmpi(varargin{1},'all'))
        if isGrayScaleImageProvided
            reqStatsStr = allMeasurements;
        else
            reqStatsStr = shapeMeasurements;
        end
    elseif coder.const(strcmpi(varargin{1},'basic'))
        reqStatsStr = basicMeasurements;
    else
        reqStatsStr = varnames;
    end
end

vars = coder.nullcopy(cell(1,numel(reqStatsStr)));

% Initialize output vars one property at a time
for j = coder.unroll(1:numel(reqStatsStr))
    if strcmpi(reqStatsStr{j},'Volume')
        vars{j} = zeros(numObjs,1);
    elseif strcmpi(reqStatsStr{j},'Centroid')
        vars{j} = zeros(numObjs,3);
    elseif strcmpi(reqStatsStr{j},'BoundingBox')
        vars{j} = zeros(numObjs,6);
    elseif strcmpi(reqStatsStr{j},'SubarrayIdx')
        vars{j} = repmat(repmat({zeros(1,coder.ignoreConst(0))},1,numel(imageSize)),numObjs,1);
    elseif strcmpi(reqStatsStr{j},'Image')
        if numel(imageSize) == 2
            vars{j} = repmat({false(coder.ignoreConst(0),coder.ignoreConst(0))},numObjs,1);
        else %3d
            vars{j} = repmat({false(coder.ignoreConst(0),coder.ignoreConst(0),coder.ignoreConst(0))},...
                numObjs,1);
        end
    elseif strcmpi(reqStatsStr{j},'EquivDiameter')
        vars{j} = zeros(numObjs,1);
    elseif strcmpi(reqStatsStr{j},'Extent')
        vars{j} = zeros(numObjs,1);
    elseif strcmpi(reqStatsStr{j},'VoxelIdxList')
        vars{j} = repmat({zeros(coder.ignoreConst(0),1)},numObjs,1);
    elseif strcmpi(reqStatsStr{j},'VoxelList')
        vars{j} = repmat({zeros(coder.ignoreConst(0),3)},numObjs,1);
    elseif strcmpi(reqStatsStr{j},'PrincipalAxislength')
        vars{j} = zeros(numObjs,3);
    elseif strcmpi(reqStatsStr{j},'Orientation')
        vars{j} = zeros(numObjs,3);
    elseif strcmpi(reqStatsStr{j},'EigenVectors')
        vars{j} = repmat({zeros(3,3)},numObjs,1);
    elseif strcmpi(reqStatsStr{j},'EigenValues')
        vars{j} = repmat({zeros(3,1)},numObjs,1);
    elseif strcmpi(reqStatsStr{j},'VoxelValues')
        if islogical(V)
            vars{j} = repmat({false(coder.ignoreConst(0),1)},numObjs,1);
        else
            vars{j} = repmat({zeros(coder.ignoreConst(0),1,'like',V)},numObjs,1);
        end
    elseif strcmpi(reqStatsStr{j},'WeightedCentroid')
        if isreal(V)
            vars{j}  = zeros(numObjs,3);
        else
            vars{j}  = complex(zeros(numObjs,3));
        end
    elseif strcmpi(reqStatsStr{j},'MeanIntensity')
        if isa(V,'single')
            initMeanValue = single(0);
        else
            initMeanValue = 0;
        end

        if isreal(V)
            vars{j} = repmat(initMeanValue,numObjs,1);
        else
            vars{j} = repmat(complex(initMeanValue),numObjs,1);
        end
    elseif strcmpi(reqStatsStr{j},'MinIntensity')
        if isreal(V)
            vars{j} = zeros(numObjs,1,'like',V);
        else
            vars{j} = complex(zeros(numObjs,1,'like',V));
        end
    else %strcmpi(reqStatsStr{j},'MaxIntensity')
        if isreal(V)
            vars{j} = zeros(numObjs,1,'like',V);
        else
            vars{j} = complex(zeros(numObjs,1,'like',V));
        end
    end
end
end

%--------------------------------------------------------------------------
function [stats,statsAlreadyComputed] = ...
    computeVoxelIdxList(L,CC,numObjs,stats,statsAlreadyComputed)
%   A P-by-1 matrix, where P is the number of voxels belonging to
%   the region.  Each element contains the linear index of the
%   corresponding voxel.
coder.inline('always');
coder.internal.prefer_const(L,CC,numObjs,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.VoxelIdxList
    statsAlreadyComputed.VoxelIdxList = true;
    if numObjs ~= 0
        if ~isempty(CC)
            % Calculate regionLengths and regionIndices from CC struct
            idxList = CC.PixelIdxList;
        else
            idxList = label2idxImpl(L,double(numObjs));
        end

        for k = 1:coder.internal.indexInt(length(stats))
            stats(k).VoxelIdxList = idxList{k};
        end
    end
end
end

%--------------------------------------------------------------------------
function idxList = label2idxImpl(L,numObjs)
coder.inline('always');
coder.internal.prefer_const(L,numObjs);

idxList = repmat({zeros(coder.ignoreConst(0),1)},1,numObjs);

for i=1:coder.internal.indexInt(numel(L))
    % Floor label value by casting.
    idx = coder.internal.indexInt(L(i));

    % Zero and negative label values represent the background.
    if idx > coder.internal.indexInt(0)
        temp = idxList{1,idx};
        temp = [temp;double(i)]; %#ok<AGROW>
        idxList{idx} = temp;
    end
end

end

%--------------------------------------------------------------------------
function [stats,statsAlreadyComputed] = ...
    computeVolume(stats,statsAlreadyComputed)
%   The volume is defined to be the number of voxels belonging to
%   the region.
coder.inline('always');
coder.internal.prefer_const(stats,statsAlreadyComputed);

if ~statsAlreadyComputed.Volume
    statsAlreadyComputed.Volume = true;

    for k = 1:coder.internal.indexInt(length(stats))
        stats(k).Volume = size(stats(k).VoxelIdxList, 1);
    end
end
end

%--------------------------------------------------------------------------
function [stats,statsAlreadyComputed] = ...
    computeCentroid(imageSize,stats,statsAlreadyComputed)
%   [mean(r) mean(c) mean(p)]
coder.inline('always');
coder.internal.prefer_const(imageSize,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.Centroid
    statsAlreadyComputed.Centroid = true;

    [stats, statsAlreadyComputed] = ...
        computeVoxelList(imageSize,stats,statsAlreadyComputed);

    for k = 1:coder.internal.indexInt(length(stats))
        stats(k).Centroid = mean(stats(k).VoxelList,1);
    end

end
end

%--------------------------------------------------------------------------
function [stats,statsAlreadyComputed] = ...
    computeBoundingBox(imageSize,stats,statsAlreadyComputed)
%   Note: The output format is [minC minR minP width height depth] and
%   minC, minR, minP end in .5, where minC, minR and minP are the minimum
%   column, minimum row and minimum plane values respectively
coder.inline('always');
coder.internal.prefer_const(imageSize,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.BoundingBox
    statsAlreadyComputed.BoundingBox = true;

    [stats,statsAlreadyComputed] = ...
        computeVoxelList(imageSize,stats,statsAlreadyComputed);

    for k = 1:coder.internal.indexInt(length(stats))
        list = stats(k).VoxelList;
        if isempty(list)
            stats(k).BoundingBox = [0.5*ones(1,3) zeros(1,3)];
        else
            minCorner = min(list,[],1) - 0.5;
            maxCorner = max(list,[],1) + 0.5;
            stats(k).BoundingBox = [minCorner (maxCorner - minCorner)];
        end
    end
end
end

%--------------------------------------------------------------------------
function [stats,statsAlreadyComputed] = ...
    computeSubarrayIdx(imageSize,stats,statsAlreadyComputed)
%   Find a cell-array containing indices so that L(idx{:}) extracts the
%   elements of L inside the bounding box.
coder.inline('always');
coder.internal.prefer_const(imageSize,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.SubarrayIdx
    statsAlreadyComputed.SubarrayIdx = true;

    [stats, statsAlreadyComputed] = ...
        computeBoundingBox(imageSize,stats,statsAlreadyComputed);

    numDims = coder.const(coder.internal.indexInt(numel(imageSize)));
    idx = coder.nullcopy(cell(1,numDims));

    for k = 1:coder.internal.indexInt(length(stats))
        boundingBox = stats(k).BoundingBox;
        left = boundingBox(1:(end/2));
        right = boundingBox((1+end/2):end);
        left = left(1,[2 1 3:end]);
        right = right(1,[2 1 3:end]);
        for p = 1:numDims
            first = left(p) + 0.5;
            last = first + right(p) - 1;
            idx{p} = first:last;
        end
        stats(k).SubarrayIdx = idx;
    end
end
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = ...
    computeImage(imageSize,stats,statsAlreadyComputed)
%   Binary image containing "on" voxels corresponding to voxels
%   belonging to the region.  The size of the image corresponds
%   to the size of the bounding box for each region.
coder.inline('always');
coder.internal.prefer_const(imageSize,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.Image
    statsAlreadyComputed.Image = true;

    [stats, statsAlreadyComputed] = ...
        computeSubarrayIdx(imageSize,stats,statsAlreadyComputed);

    for k = 1:coder.internal.indexInt(length(stats))
        stats(k).Image = getImageForEachRegion(imageSize,stats(k).SubarrayIdx,stats(k).VoxelList);
    end
end
end

%--------------------------------------------------------------------------
function imageKthRegion = getImageForEachRegion(imageSize,regionSubarrayIdx,regionVoxelList)
coder.inline('always');
coder.internal.prefer_const(imageSize,regionSubarrayIdx,regionVoxelList);

numDims = coder.const(numel(imageSize));

isSubArrayIdxEmpty = coder.nullcopy(false(1,numDims));
for i = coder.unroll(1:numDims)
    isSubArrayIdxEmpty(i) = isempty(regionSubarrayIdx{i});
end

if any(isSubArrayIdxEmpty)
    imageKthRegion = logical([]);
    return;
end

maxBound = coder.nullcopy(zeros(1,numDims));
minBound = coder.nullcopy(zeros(1,numDims));
for i = coder.unroll(1:numDims)
    maxBound(i) = max(regionSubarrayIdx{i});
    minBound(i) = min(regionSubarrayIdx{i});
end

sizeOfSubImage = maxBound - minBound + 1;

% Shift the VoxelList subscripts so that they is relative to
% sizeOfSubImage.
if min(sizeOfSubImage) == 0
    imageKthRegion = logical(sizeOfSubImage);
else
    subtractby = maxBound-sizeOfSubImage;

    % swap subtractby so that it is in the same order as
    % VoxelList, i.e., c r ....
    subtractby = subtractby(:,[2 1 3:end]);

    subscript = coder.nullcopy(cell(1,numDims));

    % swap subscript back into the order sub2ind expects, i.e.
    % r c ...
    for m = coder.unroll(1 : numDims)
        if m == 1
            subscript{2} = regionVoxelList(:,m) - subtractby(m);
        elseif m == 2
            subscript{1} = regionVoxelList(:,m) - subtractby(m);
        else
            subscript{m} = regionVoxelList(:,m) - subtractby(m);
        end

    end

    idx = sub2ind(sizeOfSubImage,subscript{:});

    imageKthRegion = false(sizeOfSubImage);
    imageKthRegion(idx) = true;
end
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = ...
    computeEquivDiameter(stats, statsAlreadyComputed)
%   Computes the diameter of the sphere that has the same volume as
%   the region.
coder.inline('always');
coder.internal.prefer_const(stats,statsAlreadyComputed);

if ~statsAlreadyComputed.EquivDiameter
    statsAlreadyComputed.EquivDiameter = true;

    [stats, statsAlreadyComputed] = ...
        computeVolume(stats,statsAlreadyComputed);

    factor = 2*(3/(4*pi))^(1/3);
    for k = 1:coder.internal.indexInt(length(stats))
        stats(k).EquivDiameter = factor * (stats(k).Volume)^(1/3);
    end
end
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = ...
    computeExtent(imageSize,stats,statsAlreadyComputed)
%   Volume / (BoundingBoxWidth * BoundingBoxHeight * BoundingBoxDepth)
coder.inline('always');
coder.internal.prefer_const(imageSize,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.Extent
    statsAlreadyComputed.Extent = true;

    [stats, statsAlreadyComputed] = ...
        computeVolume(stats,statsAlreadyComputed);
    [stats, statsAlreadyComputed] = ...
        computeBoundingBox(imageSize,stats,statsAlreadyComputed);

    for k = 1:coder.internal.indexInt(length(stats))
        if stats(k).Volume == 0
            stats(k).Extent = NaN;
        else
            stats(k).Extent = stats(k).Volume/prod(stats(k).BoundingBox(4:6));
        end
    end
end
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = ...
    computeEllipsoidParams(imageSize,stats,statsAlreadyComputed)
%   Find the ellipsoid that has the same normalized second central moments
%   as the region.  Compute the principal axes lengths, orientation, and
%   eigenvectors and eigenvalues of the ellipsoid.
coder.inline('always');
coder.internal.prefer_const(imageSize,stats,statsAlreadyComputed);

if ~(statsAlreadyComputed.PrincipalAxisLength && ...
        statsAlreadyComputed.Orientation && ...
        statsAlreadyComputed.EigenValues && ...
        statsAlreadyComputed.EigenVectors)
    statsAlreadyComputed.PrincipalAxisLength = true;
    statsAlreadyComputed.Orientation = true;
    statsAlreadyComputed.EigenValues = true;
    statsAlreadyComputed.EigenVectors = true;

    [stats, statsAlreadyComputed] = ...
        computeSubarrayIdx(imageSize,stats,statsAlreadyComputed);
    [stats, statsAlreadyComputed] = ...
        computeCentroid(imageSize,stats,statsAlreadyComputed);

    for k = 1:coder.internal.indexInt(length(stats))
        list = stats(k).VoxelList;
        if (isempty(list))
            stats(k).PrincipalAxisLength = [0 0 0];
            stats(k).Orientation = [0 0 0];
            stats(k).EigenValues = zeros(3,1);
            stats(k).EigenVectors = zeros(3,3);
        else
            if statsAlreadyComputed.Image == true
                image3D = stats(k).Image;
            else
                image3D = getImageForEachRegion(imageSize,stats(k).SubarrayIdx,stats(k).VoxelList);
            end

            centroid = stats(k).Centroid-stats(k).BoundingBox(1:3)+0.5;

            % Computing all the required moments together to avoid
            % duplicated computations.
            [mu200, mu020, mu002, mu110, mu011, mu101] = ...
                computeRequiredMoments(image3D, centroid);

            numPoints = size(stats(k).VoxelList,1);
            covMat = [mu200 mu110 mu101; ...
                mu110 mu020 mu011; ...
                mu101 mu011 mu002]./numPoints;

            [U,S] = svd(covMat);
            [S,ind] = sort(diag(S), 'descend');

            U = U(:,ind);
            % Update U so that the first axis points to positive x
            % direction and make sure that the rotation matrix determinant
            % is positive
            if U(1,1) < 0
                U = -U;
                U(:,3) = -U(:,3);
            end

            [V,D] = eig(covMat);
            [D,ind] = sort(diag(D), 'descend');

            V = V(:,ind);

            stats(k).PrincipalAxisLength = [ 2*sqrt(5*S(1)*numPoints) ...
                2*sqrt(5*S(2)*numPoints) ...
                2*sqrt(5*S(3)*numPoints) ];
            stats(k).Orientation = rotm2euler(U);
            stats(k).EigenValues = real(D)*numPoints;
            stats(k).EigenVectors = real(V);
        end
    end
end
end

%--------------------------------------------------------------------------
function [mu200, mu020, mu002, mu110, mu011, mu101] = ...
    computeRequiredMoments(im, centroid)
coder.inline('always');
coder.internal.prefer_const(im, centroid);

[r, c, p] = size(im);

% COMPLETE FORMULA for computing the momemnts mu_ijk is below:
% [r,c,p] = size(im);
% centralMoments = ((1:r)-centroid(2))'.^i * ((1:c)-centroid(1)).^j;
% z = reshape(((1:p)-centroid(3)).^k,[1 1 p]);
% centralMoments = centralMoments.*z.*im;
% centralMoments = sum(centralMoments(:));

% The code below implements the above formulae but tries the minimize
% repeated computations to improve performance.

% Corresponds to ((1:r)-centroid(2))'.^i for i = 0, 1, 2
rowTempVal = (1:r)' - centroid(2);
cm_i0 = ones(r, 1);
cm_i1 = rowTempVal;
cm_i2 = rowTempVal.^2;

% Corresponds to ((1:c)-centroid(1)).^j for j = 0, 1, 2
colTempVal = (1:c) - centroid(1);
cm_j0 = ones(1, c);
cm_j1 = colTempVal;
cm_j2 = colTempVal.^2;

% Corresponds to reshape(((1:p)-centroid(3)).^k,[1 1 p]) for k = 0, 1, 2
zTempVal = reshape((1:p) - centroid(3),[1 1 p]);
% z_k0 = ones(1, 1, p); % Not required as .* with z_k0 gives same value
z_k1 = zTempVal;
z_k2 = zTempVal.^2;

% Computing the required central moments below.
% The additive term 1/12 for the mu200, mu020 and mu002 arises because
% the voxels are modeled as cubes having unit volume. See the geck for
% details about this.

mu000 = sum(im, 'all');

% Complete formula: (cm_i2 * cm_j0) .* z_k0. However, z_k0 is all 1's
% and so skipping the multiplications
mu200 = sum((cm_i2 * cm_j0) .* im, 'all') / mu000 + 1/12;

% Complete formula: (cm_i0 * cm_j2) .* z_k0. However, z_k0 is all 1's
% and so skipping the multiplications
mu020 = sum((cm_i0 * cm_j2) .* im, 'all') / mu000 + 1/12;
mu002 = sum((cm_i0 * cm_j0) .* z_k2 .* im, 'all') / mu000 + 1/12;

% Complete formula: (cm_i1 * cm_j1) .* z_k0. However, z_k0 is all 1's
% and so skipping the multiplications
mu110 = sum((cm_i1 * cm_j1) .* im, 'all') / mu000;
mu011 = sum((cm_i0 * cm_j1) .* z_k1 .* im, 'all') / mu000;
mu101 = sum((cm_i1 * cm_j0) .* z_k1 .* im, 'all' ) / mu000;
end

%-----------------------------------------------------------------------
function eulerAngles = rotm2euler(rotm)
%ROTM2EULER Convert rotation matrix to Euler angles
coder.inline('always');
coder.internal.prefer_const(rotm);

% Scale factor to convert radians to degrees
k = 180 / pi;

cy = hypot(rotm(1, 1), rotm(2, 1));

if cy > 16*eps(class(rotm))
    psi     = k * atan2( rotm(3, 2), rotm(3, 3));
    theta   = k * atan2(-rotm(3, 1), cy);
    phi     = k * atan2( rotm(2, 1), rotm(1, 1));
else
    psi     = k * atan2(-rotm(2, 3), rotm(2, 2));
    theta   = k * atan2(-rotm(3, 1), cy);
    phi     = 0;
end

eulerAngles = [phi, theta, psi];
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = ...
    computeVoxelList(imageSize,stats,statsAlreadyComputed)
%   A P-by-3 matrix, where P is the number of voxels belonging to
%   the region.  Each row contains the row, column and plane
%   coordinates of a voxel.
coder.inline('always');
coder.internal.prefer_const(imageSize,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.VoxelList
    statsAlreadyComputed.VoxelList = true;

    % Convert the linear indices to subscripts and store
    % the results in the voxel list.  Reverse the order of the first
    % two subscripts to form x-y order
    for k = 1:coder.internal.indexInt(length(stats))
        if ~isempty(stats(k).VoxelIdxList)
            [col, row, plane] = ind2sub(imageSize, stats(k).VoxelIdxList);

            % swap subscripts returned from ind2sub i.e. c r ...
            stats(k).VoxelList = [row, col, plane];
        else
            stats(k).VoxelList = zeros(0,3);
        end
    end
end
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = ...
    computeVoxelValues(V,stats,statsAlreadyComputed)
coder.inline('always');
coder.internal.prefer_const(V,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.VoxelValues
    statsAlreadyComputed.VoxelValues = true;

    for k = 1:coder.internal.indexInt(length(stats))
        if isrow(V)
            V1 = V(:);
        else
            V1 = V;
        end
        stats(k).VoxelValues = V1(stats(k).VoxelIdxList);
    end
end
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = ...
    computeWeightedCentroid(imageSize,V,stats,statsAlreadyComputed)
coder.inline('always');
coder.internal.prefer_const(imageSize,V,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.WeightedCentroid
    statsAlreadyComputed.WeightedCentroid = true;

    [stats, statsAlreadyComputed] = ...
        computeVoxelList(imageSize,stats,statsAlreadyComputed);

    for k = 1:coder.internal.indexInt(length(stats))
        Intensity = V(stats(k).VoxelIdxList);
        sumIntensity = sum(Intensity);
        numDims = size(stats(k).VoxelList,2);
        if isreal(V)
            wc = zeros(1,numDims);
        else
            wc = complex(zeros(1,numDims));
        end
        for n = 1 : numDims
            M = sum(stats(k).VoxelList(:,n) .* ...
                double( Intensity(:) ));
            wc(n) = M / sumIntensity;
        end
        stats(k).WeightedCentroid = wc;
    end
end
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = ...
    computeMeanIntensity(V,stats,statsAlreadyComputed)
coder.inline('always');
coder.internal.prefer_const(V,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.MeanIntensity
    statsAlreadyComputed.MeanIntensity = true;

    [stats, statsAlreadyComputed] = ...
        computeVoxelValues(V,stats,statsAlreadyComputed);

    for k = 1:coder.internal.indexInt(length(stats))
        stats(k).MeanIntensity = mean(stats(k).VoxelValues);
    end
end
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = ...
    computeMinIntensity(V,stats,statsAlreadyComputed)
coder.inline('always');
coder.internal.prefer_const(V,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.MinIntensity
    statsAlreadyComputed.MinIntensity = true;

    [stats, statsAlreadyComputed] = ...
        computeVoxelValues(V,stats,statsAlreadyComputed);

    for k = 1:coder.internal.indexInt(length(stats))
        stats(k).MinIntensity = min(stats(k).VoxelValues);
    end
end
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = ...
    computeMaxIntensity(V,stats,statsAlreadyComputed)
coder.inline('always');
coder.internal.prefer_const(V,stats,statsAlreadyComputed);

if ~statsAlreadyComputed.MaxIntensity
    statsAlreadyComputed.MaxIntensity = true;

    [stats, statsAlreadyComputed] = ...
        computeVoxelValues(V,stats,statsAlreadyComputed);

    for k = 1:coder.internal.indexInt(length(stats))
        stats(k).MaxIntensity = max(stats(k).VoxelValues);
    end
end
end


%--------------------------------------------------------------------------
function [V,reqStats,outstats,startIdxForProp,isGrayScaleImageProvided] = ...
    parseInputsAndInitializeOutStruct(imageSize,numObjs,varargin)
% Parse input property strings and create output stats struct array,
% requested stats property enumeration and grayscale image, if specified.
coder.inline('always');
coder.internal.prefer_const(imageSize, numObjs, varargin);

% List of enumerated property strings is used to create the temporary stats
% structure to store computed statistics. This list is different from
% the list of property strings used to create the output structure
% subsequently.
shapeStats = [...
    VOLUME
    CENTROID
    BOUNDINGBOX
    SUBARRAYIDX
    IMAGE
    EQUIVDIAMETER
    EXTENT
    VOXELIDXLIST
    VOXELLIST
    PRINCIPALAXISLENGTH
    ORIENTATION
    EIGENVECTORS
    EIGENVALUES];

voxelValueStats = [...
    VOXELVALUES
    WEIGHTEDCENTROID
    MEANINTENSITY
    MININTENSITY
    MAXINTENSITY];

basicStats = [...
    VOLUME
    CENTROID
    BOUNDINGBOX];

numOrigInputArgs = coder.const(numel(varargin));

if coder.const(numOrigInputArgs == 1)
    %REGIONPROPS3(BW) or REGIONPROPS3(CC) REGIONPROPS3(L)
    V = [];
    reqStats = basicStats;
    startIdxForProp = NOPROPERTIESREQUESTED;
    isGrayScaleImageProvided = false;
    [outstats,~] = initializeStatsStruct([],imageSize,numObjs,OUTPUTSTATS_BASIC);
    return;

elseif coder.const(isnumeric(varargin{2}) || islogical(varargin{2}))
    %REGIONPROPS3(...,V) or REGIONPROPS3(...,V,PROPERTIES)

    V = varargin{2};
    validateattributes(V,{'numeric','logical'},{},mfilename,'V',2);

    coder.internal.errorIf(~isequal(imageSize,size(V)), ...
        'images:regionprops3:sizeMismatch');

    if numOrigInputArgs == 2
        %REGIONPROPS3(BW,V) or REGIONPROPS3(L,V)
        reqStats = basicStats;
        startIdxForProp = NOPROPERTIESREQUESTED;
        isGrayScaleImageProvided = true;
        [outstats,~] = initializeStatsStruct([],imageSize,numObjs,OUTPUTSTATS_BASIC);
    else
        %REGIONPROPS(BW,V,PROPERTIES) or REGIONPROPS(CC,V,PROPERTIES)
        % or REGIONPROPS(L,V,PROPERTIES)
        officialStats = [shapeStats;voxelValueStats];
        startIdxForProp = 3;
        isGrayScaleImageProvided = true;
        [reqStats,outstats] = getPropsFromInputAndInitializeOutStruct(...
            startIdxForProp,officialStats,basicStats,V,imageSize,numObjs,varargin{:});
    end

else
    %REGIONPROPS3(BW,PROPERTIES) or REGIONPROPS3(CC,PROPERTIES)
    % orREGIONPROPS3(L,PROPERTIES)
    V = [];
    officialStats = shapeStats;
    startIdxForProp = 2;
    isGrayScaleImageProvided = false;
    [reqStats,outstats] = getPropsFromInputAndInitializeOutStruct(...
        startIdxForProp,officialStats,basicStats,V,imageSize,numObjs,varargin{:});
end
end


%--------------------------------------------------------------------------
function [reqStats,outstats] = getPropsFromInputAndInitializeOutStruct(...
    startIdx, officialStats, basicStats, V, imageSize, numObjs, varargin)

% Parse property strings and initialize the output stats structure array.
coder.inline('always');
coder.internal.prefer_const(startIdx, officialStats, basicStats, V, imageSize, numObjs, varargin);

for k = coder.unroll(startIdx:numel(varargin))
    if ischar(varargin{k}) || isstring(varargin{k})
        coder.internal.errorIf(~coder.internal.isConst(varargin{k}),...
            'images:regionprops3:optionalStringNotConst');
    end
end

if coder.const(strcmpi(varargin{startIdx},'all'))
    %REGIONPROPS3(...,'all')
    reqStats = officialStats;
    if startIdx == 3
        % 3-D Volumetric Grayscale image was specified
        [outstats,~] = initializeStatsStruct(V,imageSize,numObjs,OUTPUTSTATS_ALL_VOXELVALUESTATS);
    else
        % No Grayscale image was specified
        [outstats,~] = initializeStatsStruct([],imageSize,numObjs,OUTPUTSTATS_ALL_SHAPESTATS);
    end
    return;
elseif coder.const(strcmpi(varargin{startIdx}, 'basic'))
    %REGIONPROPS3(...,'basic')
    reqStats = basicStats;
    [outstats,~] = initializeStatsStruct([],imageSize,numObjs,OUTPUTSTATS_BASIC);
    return;
else
    %REGIONPROPS3(...,PROP1,PROP2,..)
    % Do nothing here and continue parsing individual properties.
end

% List of valid property strings used to create the output stats structure
% array. Note: 'all' and 'basic' are not included in this list.
voxelValueStatsStrs = { ...
    'MaxIntensity', 'MeanIntensity', 'MinIntensity', ...
    'VoxelValues', 'WeightedCentroid'};

shapeMeasurementProperties = { ...
    'Volume', 'BoundingBox', 'Centroid', 'EigenVectors',...
    'EigenValues', 'EquivDiameter', 'Extent', ...
    'Image', 'PrincipalAxisLength', 'Orientation', ...
    'VoxelIdxList', 'VoxelList','SubarrayIdx'};

unsupportedProperties = { ...
    'ConvexHull','ConvexImage','ConvexVolume','Solidity','SurfaceArea'};

% Concatenate official and pixel value statistics.
officialAndVoxelValueStatsStrs = { ...
    voxelValueStatsStrs{:} shapeMeasurementProperties{:} unsupportedProperties{:}};

numProps = coder.const(numel(varargin)-startIdx+1);
reqStatsInput = zeros(numProps,1);
propIdx = 1;

for k = coder.unroll(startIdx:numel(varargin))
    coder.internal.errorIf(~(ischar(varargin{k}) || isstring(varargin{k})),...
        'images:regionprops3:invalidType');

    % Verify that the property is legal
    prop = validatestring(varargin{k}, officialAndVoxelValueStatsStrs, ...
        mfilename, 'PROPERTIES', k);
    % Exclude properties that are not supported
    % for codegen with a meaningful error message
    for idx = coder.unroll(1:numel(unsupportedProperties))
        coder.internal.errorIf(strcmpi(prop, unsupportedProperties{idx}),...
            'images:regionprops3:codegenUnsupportedProperty', prop);
    end

    noGrayscaleImageAsInput = (startIdx == 2);
    if noGrayscaleImageAsInput
        % This code block exists so that regionprops3 can throw a more
        % meaningful error message if the user want a pixel value based
        % measurement but only specifies a label matrix as an input.
        for idx = coder.unroll(1:numel(voxelValueStatsStrs))
            coder.internal.errorIf(strcmpi(prop, voxelValueStatsStrs{idx}),...
                'images:regionprops3:needsGrayscaleImage', prop);
        end
    end

    % Convert requested property string to enum
    propEnum = convertPropStrToEnum(prop);
    reqStatsInput(propIdx) = coder.const(propEnum);
    propIdx = propIdx + 1;
end

reqStats = sort(reqStatsInput);

for k = coder.unroll(1:numel(reqStats))
    % Initialize output stats one property at a time (excluding 'basic'
    % and 'all').
    if reqStats(k) == VOLUME
        statsOneObj.Volume = 0;
    elseif reqStats(k) == CENTROID
        statsOneObj.Centroid = zeros(1,3);
    elseif reqStats(k) == BOUNDINGBOX
        statsOneObj.BoundingBox = zeros(1,6);
    elseif reqStats(k) == SUBARRAYIDX
        statsOneObj.SubarrayIdx = repmat({zeros(1,coder.ignoreConst(0))},1,numel(imageSize));
    elseif reqStats(k) == IMAGE
        if numel(imageSize) == 2
            statsOneObj.Image = false(coder.ignoreConst(0),coder.ignoreConst(0));
        else %3d
            statsOneObj.Image = false(coder.ignoreConst(0),coder.ignoreConst(0),coder.ignoreConst(0));
        end
    elseif reqStats(k) == EQUIVDIAMETER
        statsOneObj.EquivDiameter = 0;
    elseif reqStats(k) == EXTENT
        statsOneObj.Extent = 0;
    elseif reqStats(k) == VOXELIDXLIST
        statsOneObj.VoxelIdxList = zeros(coder.ignoreConst(0),1);
    elseif reqStats(k) == VOXELLIST
        statsOneObj.VoxelList = zeros(coder.ignoreConst(0),3);
    elseif reqStats(k) == PRINCIPALAXISLENGTH
        statsOneObj.PrincipalAxisLength = zeros(1,3);
    elseif reqStats(k) == ORIENTATION
        statsOneObj.Orientation = zeros(1,3);
    elseif reqStats(k) == EIGENVECTORS
        statsOneObj.EigenVectors = zeros(3,3);
    elseif reqStats(k) == EIGENVALUES
        statsOneObj.EigenValues = zeros(3,1);
    elseif reqStats(k) == VOXELVALUES
        if islogical(V)
            statsOneObj.VoxelValues = false(coder.ignoreConst(0),1);
        else
            statsOneObj.VoxelValues = zeros(coder.ignoreConst(0),1,'like',V);
        end
    elseif reqStats(k) == WEIGHTEDCENTROID
        if isreal(V)
            statsOneObj.WeightedCentroid = zeros(1,3);
        else
            statsOneObj.WeightedCentroid = complex(zeros(1,3));
        end
    elseif reqStats(k) == MEANINTENSITY
        if isa(V,'single')
            initMeanValue = single(0);
        else
            initMeanValue = 0;
        end

        if isreal(V)
            statsOneObj.MeanIntensity = initMeanValue;
        else
            statsOneObj.MeanIntensity = complex(initMeanValue);
        end
    elseif reqStats(k) == MININTENSITY
        if islogical(V)
            statsOneObj.MinIntensity = zeros(1,1,'like',V);
        else
            statsOneObj.MinIntensity = complex(zeros(1,1,'like',V));
        end
    else %reqStats(k) == MAXINTENSITY
        if isreal(V)
            statsOneObj.MaxIntensity = zeros(1,1,'like',V);
        else
            statsOneObj.MaxIntensity = complex(zeros(1,1,'like',V));
        end
    end
end
outstats = repmat(statsOneObj,numObjs,1);
end

%--------------------------------------------------------------------------
function [stats, statsAlreadyComputed] = initializeStatsStruct(V,imageSize,numObjs, statsType)
% Use property enumeration to create and intialize fields of regionprops3
% structure

% Initialize the statsAlreadyComputed structure array. Need to avoid
% multiple calculations of the same property for performance reasons.
if isequal(statsType, TEMPSTATS_ALL) || ...
        isequal(statsType, OUTPUTSTATS_ALL_VOXELVALUESTATS) || ...
        isequal(statsType, OUTPUTSTATS_ALL_SHAPESTATS)

    statsAlreadyComputed.Volume = false;
    statsOneObj.Volume = 0;

    statsAlreadyComputed.Centroid = false;
    statsOneObj.Centroid = zeros(1,3);

    statsAlreadyComputed.BoundingBox = false;
    statsOneObj.BoundingBox = zeros(1,6);

    statsAlreadyComputed.SubarrayIdx = false;
    statsOneObj.SubarrayIdx = repmat({zeros(1,coder.ignoreConst(0))},1,numel(imageSize));

    statsAlreadyComputed.Image = false;
    if numel(imageSize) == 2
        statsOneObj.Image = false(coder.ignoreConst(0),coder.ignoreConst(0));
    else %3d
        statsOneObj.Image = false(coder.ignoreConst(0),coder.ignoreConst(0),coder.ignoreConst(0));
    end

    statsAlreadyComputed.EquivDiameter = false;
    statsOneObj.EquivDiameter = 0;

    statsAlreadyComputed.Extent = false;
    statsOneObj.Extent = 0;

    statsAlreadyComputed.VoxelIdxList = false;
    statsOneObj.VoxelIdxList = zeros(coder.ignoreConst(0),1);

    statsAlreadyComputed.VoxelList = false;
    statsOneObj.VoxelList = zeros(coder.ignoreConst(0),3);

    statsAlreadyComputed.PrincipalAxisLength = false;
    statsOneObj.PrincipalAxisLength = zeros(1,3);

    statsAlreadyComputed.Orientation = false;
    statsOneObj.Orientation = zeros(1,3);

    statsAlreadyComputed.EigenVectors = false;
    statsOneObj.EigenVectors = zeros(3,3);

    statsAlreadyComputed.EigenValues = false;
    statsOneObj.EigenValues = zeros(3,1);

    % Create voxel value statistics for a valid grayscale image
    if isequal(statsType, TEMPSTATS_ALL) || ...
            isequal(statsType, OUTPUTSTATS_ALL_VOXELVALUESTATS)

        statsAlreadyComputed.VoxelValues = false;
        if islogical(V)
            statsOneObj.VoxelValues = false(coder.ignoreConst(0),1);
        else
            statsOneObj.VoxelValues = zeros(coder.ignoreConst(0),1,'like',V);
        end

        statsAlreadyComputed.WeightedCentroid = false;
        if isreal(V)
            statsOneObj.WeightedCentroid = zeros(1,3);
        else
            statsOneObj.WeightedCentroid = complex(zeros(1,3));
        end

        statsAlreadyComputed.MeanIntensity = false;
        if isa(V,'single')
            initMeanValue = single(0);
        else
            initMeanValue = 0;
        end

        if isreal(V)
            statsOneObj.MeanIntensity = initMeanValue;
        else
            statsOneObj.MeanIntensity = complex(initMeanValue);
        end

        statsAlreadyComputed.MinIntensity = false;
        if isreal(V)
            statsOneObj.MinIntensity = zeros(1,1,'like',V);
        else
            statsOneObj.MinIntensity = complex(zeros(1,1,'like',V));
        end

        statsAlreadyComputed.MaxIntensity = false;
        if isreal(V)
            statsOneObj.MaxIntensity = zeros(1,1,'like',V);
        else
            statsOneObj.MaxIntensity = complex(zeros(1,1,'like',V));
        end

    end
elseif isequal(statsType, OUTPUTSTATS_BASIC)
    statsAlreadyComputed = struct('Volume',false,'Centroid',false, ...
        'BoundingBox',false);
    statsOneObj = struct('Volume',0,'Centroid',zeros(1,3),'BoundingBox',zeros(1,6));
end

stats = repmat(statsOneObj,numObjs,1);
end

%--------------------------------------------------------------------------
function [outstats,stats] = populateOutputStatsStructure(outstats,stats)
% Copy requested properties from the temporary stats struct array to the
% output stats struct array.
coder.inline('always');
for k = 1:coder.internal.indexInt(length(stats))
    for fIdx = coder.unroll(0:eml_numfields(outstats(k))-1)
        fieldName = eml_getfieldname(outstats(k),fIdx);
        outstats(k).(fieldName) = coder.nullcopy(stats(k).(fieldName));

        for vIdx = 1:coder.internal.indexInt(numel(outstats(k).(fieldName)))
            if iscell(stats(k).(fieldName))
                outstats(k).(fieldName){vIdx} = stats(k).(fieldName){vIdx};
            else
                outstats(k).(fieldName)(vIdx) = stats(k).(fieldName)(vIdx);
            end
        end
    end
end
end

%--------------------------------------------------------------------------
function validateCC(CC)
%VALIDATECC Validates CC struct returned by bwconncomp
coder.inline('always');
coder.internal.prefer_const(CC);

coder.internal.assert(isstruct(CC),'images:checkCC:expectedStruct');

tf = true;
for fIdx = coder.unroll(0:eml_numfields(CC)-1)
    fieldName = eml_getfieldname(CC,fIdx);
    tf = tf && any(strcmpi(fieldName,{'Connectivity','ImageSize','NumObjects',...
        'RegionLengths','RegionIndices','PixelIdxList'}));
end

coder.internal.assert(tf, 'images:checkCC:codegenMissingField');
end

%--------------------------------------------------------------------------
function propEnum = convertPropStrToEnum(prop)
% Convert property string to an enumeration
coder.inline('always');
coder.internal.prefer_const(prop);
if strcmpi(prop,'Volume')
    propEnum = VOLUME;
elseif strcmpi(prop,'BoundingBox')
    propEnum = BOUNDINGBOX;
elseif strcmpi(prop,'Centroid')
    propEnum = CENTROID;
elseif strcmpi(prop,'SubarrayIdx')
    propEnum = SUBARRAYIDX;
elseif strcmpi(prop,'Image')
    propEnum = IMAGE;
elseif strcmpi(prop,'EquivDiameter')
    propEnum = EQUIVDIAMETER;
elseif strcmpi(prop,'Extent')
    propEnum = EXTENT;
elseif strcmpi(prop,'VoxelIdxList')
    propEnum = VOXELIDXLIST;
elseif strcmpi(prop,'VoxelList')
    propEnum = VOXELLIST;
elseif strcmpi(prop,'PrincipalAxisLength')
    propEnum = PRINCIPALAXISLENGTH;
elseif strcmpi(prop,'Orientation')
    propEnum = ORIENTATION;
elseif strcmpi(prop,'EigenVectors')
    propEnum = EIGENVECTORS;
elseif strcmpi(prop,'EigenValues')
    propEnum = EIGENVALUES;
elseif strcmpi(prop,'ConvexHull')
    propEnum = CONVEXHULL;
elseif strcmpi(prop,'ConvexImage')
    propEnum = CONVEXIMAGE;
elseif strcmpi(prop,'ConvexVolume')
    propEnum = CONVEXVOLUME;
elseif strcmpi(prop,'Solidity')
    propEnum = SOLIDITY;
elseif strcmpi(prop,'SurfaceArea')
    propEnum = SURFACEAREA;
elseif strcmpi(prop,'MaxIntensity')
    propEnum = MAXINTENSITY;
elseif strcmpi(prop,'MeanIntensity')
    propEnum = MEANINTENSITY;
elseif strcmpi(prop,'MinIntensity')
    propEnum = MININTENSITY;
elseif strcmpi(prop,'VoxelValues')
    propEnum = VOXELVALUES;
elseif strcmpi(prop,'WeightedCentroid')
    propEnum = WEIGHTEDCENTROID;
else
    assert(false,'Invalid property string');
end
end

%--------------------------------------------------------------------------
% Shape Measurements
function propEnum = VOLUME()
coder.inline('always');
propEnum = int8(1);
end

function propEnum = CENTROID()
coder.inline('always');
propEnum = int8(2);
end

function propEnum = BOUNDINGBOX()
coder.inline('always');
propEnum = int8(3);
end

function propEnum = SUBARRAYIDX()
coder.inline('always');
propEnum = int8(4);
end

function propEnum = IMAGE()
coder.inline('always');
propEnum = int8(5);
end

function propEnum = EQUIVDIAMETER()
coder.inline('always');
propEnum = int8(6);
end

function propEnum = EXTENT()
coder.inline('always');
propEnum = int8(7);
end

function propEnum = VOXELIDXLIST()
coder.inline('always');
propEnum = int8(8);
end

function propEnum = VOXELLIST()
coder.inline('always');
propEnum = int8(9);
end

function propEnum = PRINCIPALAXISLENGTH()
coder.inline('always');
propEnum = int8(10);
end

function propEnum = ORIENTATION()
coder.inline('always');
propEnum = int8(11);
end

function propEnum = EIGENVECTORS()
coder.inline('always');
propEnum = int8(12);
end

function propEnum = EIGENVALUES()
coder.inline('always');
propEnum = int8(13);
end

function propEnum = CONVEXHULL()
coder.inline('always');
propEnum = int8(14);
end

function propEnum = CONVEXIMAGE()
coder.inline('always');
propEnum = int8(15);
end

function propEnum = CONVEXVOLUME()
coder.inline('always');
propEnum = int8(16);
end

function propEnum = SOLIDITY()
coder.inline('always');
propEnum = int8(17);
end

function propEnum = SURFACEAREA()
coder.inline('always');
propEnum = int8(18);
end

%--------------------------------------------------------------------------
% Voxel Value Measurements
function propEnum = VOXELVALUES()
coder.inline('always');
propEnum = int8(19);
end

function propEnum = WEIGHTEDCENTROID()
coder.inline('always');
propEnum = int8(20);
end

function propEnum = MEANINTENSITY()
coder.inline('always');
propEnum = int8(21);
end

function propEnum = MININTENSITY()
coder.inline('always');
propEnum = int8(22);
end

function propEnum = MAXINTENSITY()
coder.inline('always');
propEnum = int8(23);
end

function statsTypeEnum = TEMPSTATS_ALL()
coder.inline('always');
statsTypeEnum = int8(30);
end

function statsTypeEnum = OUTPUTSTATS_BASIC()
coder.inline('always');
statsTypeEnum = int8(31);
end

function statsTypeEnum = OUTPUTSTATS_ALL_SHAPESTATS()
coder.inline('always');
statsTypeEnum = int8(32);
end

function statsTypeEnum = OUTPUTSTATS_ALL_VOXELVALUESTATS()
coder.inline('always');
statsTypeEnum = int8(33);
end

function propFlag = NOPROPERTIESREQUESTED()
coder.inline('always');
propFlag = int8(-1);
end