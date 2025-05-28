function outstats = regionprops3(varargin)
%REGIONPROPS3 Measure properties of 3-D volumetric image regions.
%   STATS = REGIONPROPS3(BW,PROPERTIES) measures a set of properties for
%   each connected component (object) in the 3-D volumetric binary image
%   BW. The output STATS is a MATLAB table with height (number of rows)
%   equal to the number of objects in BW, CC.NumObjects, or max(L(:)). The
%   variables of the table denote different properties for each region, as
%   specified by PROPERTIES. See help for 'table' in MATLAB for additional
%   methods for the table.
%
%   STATS = REGIONPROPS3(CC,PROPERTIES) measures a set of properties for
%   each connected component (object) in CC, which is a structure returned
%   by BWCONNCOMP. CC must be the connectivity of a 3-D volumetric image i.e.
%   CC.ImageSize must be a 1x3 vector.
%
%   STATS = REGIONPROPS3(L,PROPERTIES) measures a set of properties for
%   each labeled region in the 3-D label matrix L. L can be numeric or
%   categorical. When L is numeric, positive integer elements of L
%   correspond to different regions. For example, the set of elements of L
%   equal to 1 corresponds to region 1; the set of elements of L equal to 2
%   corresponds to region 2; and so on. When L is categorical, each
%   category corresponds to different region.
%
%   STATS = REGIONPROPS3(...,V,PROPERTIES) measures a set of properties for
%   each labeled region in the 3-D volumetric grayscale image V. The first
%   input to REGIONPROPS3 (BW, CC, or L) identifies the regions in V.  The
%   sizes must match: SIZE(V) must equal SIZE(BW), CC.ImageSize, or
%   SIZE(L).
%
%   PROPERTIES can be a comma-separated list of strings or character
%   vectors, a cell array containing strings or character vectors,
%   "all", or "basic". The set of valid measurement strings or character
%   vectors includes:
%
%   Shape Measurements
%
%     "Volume"              "PrincipalAxisLength"  "Orientation"               
%     "BoundingBox"         "Extent"               "SurfaceArea"          
%     "Centroid"            "EquivDiameter"        "VoxelIdxList" 
%     "ConvexVolume"        "VoxelList"            "ConvexHull"   
%     "Solidity"            "ConvexImage"          "Image"  
%     "SubarrayIdx"         "EigenVectors"         "EigenValues"
%
%   Voxel Value Measurements (requires 3-D volumetric grayscale image as the second input)
%
%     "MaxIntensity"
%     "MeanIntensity"
%     "MinIntensity"
%     "VoxelValues"
%     "WeightedCentroid"
%
%   Property strings or character vectors are case insensitive and can be
%   abbreviated.
%
%   If PROPERTIES is set to "all", REGIONPROPS3 returns all of the Shape
%   measurements. If called with a 3-D volumetric grayscale image,
%   REGIONPROPS3 also returns Voxel value measurements. If PROPERTIES is
%   not specified or if it is set to "basic", these measurements are
%   computed: "Volume", "Centroid", and "BoundingBox".
%
%   If the input is categorical, a property 'LabelName' is added to the
%   output along with any of the above selected properties.
%
%   Note that negative-valued voxels are treated as background
%   and voxels that are not integer-valued are rounded down.
%
%   Class Support
%   -------------
%   If the first input is BW, BW must be a 3-D logical array. If the first
%   input is CC, CC must be a structure returned by BWCONNCOMP. If the
%   first input is L, L must be categorical or numeric array which must be
%   real and nonsparse containing 3 dimensions.
%
%   Example 1
%   ---------
%   % Estimate the centers and radii of objects in a 3-D volumetric image
%
%         % Create a binary image with two spheres
%         [x, y, z] = meshgrid(1:50, 1:50, 1:50);
%         bw1 = sqrt((x-10).^2 + (y-15).^2 + (z-35).^2) < 5;
%         bw2 = sqrt((x-20).^2 + (y-30).^2 + (z-15).^2) < 10;
%         bw = bw1 | bw2;
%         s = regionprops3(bw, "Centroid", ...
%                            "PrincipalAxisLength");
%
%         % Get centers and radii of the two spheres
%         centers = s.Centroid;
%         diameters = mean(s.PrincipalAxisLength,2);
%         radii = diameters/2;
%
%   See also BWCONNCOMP, BWLABELN, ISMEMBER, REGIONPROPS.

%   Copyright 2017-2021 The MathWorks, Inc.

narginchk(1, inf);

catConverter = [];
isInputCategorical = false;

matlab.images.internal.errorIfgpuArray(varargin{:})
args = matlab.images.internal.stringToChar(varargin);

if islogical(args{1}) || isstruct(args{1})
    %REGIONPROPS3(BW,...) or REGIONPROPS3(CC,...)
    
    L = [];
    
    if islogical(args{1})
        %REGIONPROPS3(BW,...)
        if ndims(args{1}) > 3
            error(message('images:regionprops3:invalidSizeBW'));
        end
        CC = bwconncomp(args{1});
    else
        %REGIONPROPS3(CC,...)
        CC = args{1};
        checkCC(CC);
        if numel(CC.ImageSize) > 3
            error(message('images:regionprops3:invalidSizeCC'));
        end
    end
    
    imageSize = CC.ImageSize;
    numObjs = CC.NumObjects;   
    
else
    %REGIONPROPS3(L,...)
    
    CC = [];
    L = args{1};
   
    if iscategorical(L)
        % Converting to numeric before validation as incoming categorical
        % matrix could have <undefined>s (which when converted to double
        % corresponds to NaN). We want the matrix to be 'finite', so
        % converting before validation avoids a second pass through the
        % matrix
        % Additionally, still keeping 'categorical' in validateattributes
        % for correct error message.
        catConverter = images.internal.utils.CategoricalConverter(categories(L));
        L = catConverter.categorical2Numeric(L);
        isInputCategorical = true;
    end
    
    supportedTypes = {'uint8','uint16','uint32','int8','int16','int32','single','double','categorical'};
    supportedAttributes = {'3d','real','nonsparse','finite'};
    validateattributes(L, supportedTypes, supportedAttributes, ...
        mfilename, 'L', 1);
    imageSize = size(L);
    
    if isempty(L)
        numObjs = 0;
    else
        numObjs = max( 0, floor(double(max(L(:)))) );
    end
end

[V,requestedStats,officialStats] = parseInputs(imageSize, args{:});

[stats, statsAlreadyComputed] = initializeStatsTable(...
    numObjs, requestedStats, officialStats);

% Compute VoxelIdxList
[stats, statsAlreadyComputed] = ...
    computeVoxelIdxList(L, CC, numObjs, stats, statsAlreadyComputed);

if isInputCategorical
    labelNames = string(catConverter.Categories);
    [stats, statsAlreadyComputed] = ComputLabelNames(labelNames, stats, statsAlreadyComputed);
    requestedStats = ['LabelName',requestedStats];
end

% Compute other statistics.
numRequestedStats = length(requestedStats);
for k = 1 : numRequestedStats
    switch requestedStats{k}
        
        case 'Volume'
            [stats, statsAlreadyComputed] = ...
                computeVolume(stats, statsAlreadyComputed);
            
        case 'Centroid'
            [stats, statsAlreadyComputed] = ...
                computeCentroid(imageSize,stats, statsAlreadyComputed);
            
        case 'EquivDiameter'
            [stats, statsAlreadyComputed] = ...
                computeEquivDiameter(stats, statsAlreadyComputed);
            
        case 'SurfaceArea'
            [stats, statsAlreadyComputed] = ...
                computeSurfaceArea(imageSize,stats, statsAlreadyComputed);
            
        case 'BoundingBox'
            [stats, statsAlreadyComputed] = ...
                computeBoundingBox(imageSize,stats,statsAlreadyComputed);
            
        case 'SubarrayIdx'
            [stats, statsAlreadyComputed] = ...
                computeSubarrayIdx(imageSize,stats,statsAlreadyComputed);
            
        case {'PrincipalAxisLength', 'Orientation', 'EigenVectors', 'EigenValues'}
            [stats, statsAlreadyComputed] = ...
                computeEllipsoidParams(imageSize,stats,statsAlreadyComputed);
            
        case 'Extent'
            [stats, statsAlreadyComputed] = ...
                computeExtent(imageSize,stats,statsAlreadyComputed);
            
        case 'Image'
            [stats, statsAlreadyComputed] = ...
                computeImage(imageSize,stats,statsAlreadyComputed);
            
        case 'VoxelList'
            [stats, statsAlreadyComputed] = ...
                computeVoxelList(imageSize,stats,statsAlreadyComputed);
            
        case 'VoxelValues'
            [stats, statsAlreadyComputed] = ...
                computeVoxelValues(V,stats,statsAlreadyComputed);
            
        case 'ConvexVolume'
            [stats, statsAlreadyComputed] = ...
                computeConvexVolume(imageSize, stats,statsAlreadyComputed);
    
        case 'ConvexImage'
            [stats, statsAlreadyComputed] = ...
                computeConvexImage(imageSize,stats,statsAlreadyComputed);

        case 'ConvexHull'
            [stats, statsAlreadyComputed] = ...
                computeConvexHull(imageSize,stats,statsAlreadyComputed);
            
        case 'Solidity'
            [stats, statsAlreadyComputed] = ...
                computeSolidity(imageSize,stats,statsAlreadyComputed);
            
        case 'WeightedCentroid'
            [stats, statsAlreadyComputed] = ...
                computeWeightedCentroid(imageSize,V,stats,statsAlreadyComputed);
            
        case 'MeanIntensity'
            [stats, statsAlreadyComputed] = ...
                computeMeanIntensity(V,stats,statsAlreadyComputed);
            
        case 'MinIntensity'
            [stats, statsAlreadyComputed] = ...
                computeMinIntensity(V,stats,statsAlreadyComputed);
            
        case 'MaxIntensity'
            [stats, statsAlreadyComputed] = ...
                computeMaxIntensity(V,stats,statsAlreadyComputed);
    end
end

% Create the output table.
outstats = createOutputTable(requestedStats, stats, isInputCategorical);


% ComputeLabelName
function [stats, statsAlreadyComputed] = ComputLabelNames(labelNames, stats, statsAlreadyComputed)
statsAlreadyComputed.LabelName = 1;

for i=1:length(labelNames)
    stats(i).LabelName = labelNames(i);
end

% computeVoxelIdxList
function [stats, statsAlreadyComputed] = ...
    computeVoxelIdxList(L,CC,numObjs,stats,statsAlreadyComputed)
%   A P-by-1 matrix, where P is the number of voxels belonging to
%   the region.  Each element contains the linear index of the
%   corresponding voxel.

statsAlreadyComputed.VoxelIdxList = 1;

if numObjs ~= 0
    if ~isempty(CC)
        idxList = CC.PixelIdxList;
    else
        idxList = images.internal.builtins.label2idx(L, double(numObjs));
    end
    [stats.VoxelIdxList] = deal(idxList{:});
end

% computeVolume
function [stats, statsAlreadyComputed] = ...
    computeVolume(stats, statsAlreadyComputed)
%   The volume is defined to be the number of voxels belonging to
%   the region.

if ~statsAlreadyComputed.Volume
    statsAlreadyComputed.Volume = 1;
    
    for k = 1:length(stats)
        stats(k).Volume = size(stats(k).VoxelIdxList, 1);
    end
end

% computeEquivDiameter
function [stats, statsAlreadyComputed] = ...
    computeEquivDiameter(stats, statsAlreadyComputed)
%   Computes the diameter of the sphere that has the same volume as
%   the region.

if ~statsAlreadyComputed.EquivDiameter
    statsAlreadyComputed.EquivDiameter = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeVolume(stats,statsAlreadyComputed);
    
    factor = 2*(3/(4*pi))^(1/3);
    for k = 1:length(stats)
        stats(k).EquivDiameter = factor * (stats(k).Volume)^(1/3);
    end
end

% ComputeCentroid
function [stats, statsAlreadyComputed] = ...
    computeCentroid(imageSize,stats, statsAlreadyComputed)
%   [mean(r) mean(c) mean(p)]

if ~statsAlreadyComputed.Centroid
    statsAlreadyComputed.Centroid = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeVoxelList(imageSize,stats,statsAlreadyComputed);
    
    for k = 1:length(stats)
        stats(k).Centroid = mean(stats(k).VoxelList,1);
    end
    
end

% computeSurfaceArea
function [stats, statsAlreadyComputed] = ...
                computeSurfaceArea(imageSize,stats, statsAlreadyComputed)

if ~statsAlreadyComputed.SurfaceArea
    statsAlreadyComputed.SurfaceArea = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeSubarrayIdx(imageSize,stats,statsAlreadyComputed);
    
    for k = 1:length(stats)
        if statsAlreadyComputed.Image == 1
            image3D = stats(k).Image;
        else
            image3D = getImageForEachRegion(imageSize,stats(k).SubarrayIdx,stats(k).VoxelList);
        end
        
        if (isempty(image3D))
            stats(k).SurfaceArea  = 0;
        else
            % image3D can be a 2-D matrix for some flat regions. Make it a
            % true 3-D matrix
            if ismatrix(image3D)
                % Use plane size of 2 to account for both sides of the flat
                % surface
                im = false([size(image3D) 2]);
                im(:,:,1) = image3D;
                image3D = im;
            end
            stats(k).SurfaceArea = images.internal.builtins.surfacearea(image3D);
        end
    end
end

% computeBoundingBox
function [stats, statsAlreadyComputed] = ...
    computeBoundingBox(imageSize,stats,statsAlreadyComputed)
%   Note: The output format is [minC minR minP width height depth] and
%   minC, minR, minP end in .5, where minC, minR and minP are the minimum
%   column, minimum row and minimum plane values respectively

if ~statsAlreadyComputed.BoundingBox
    statsAlreadyComputed.BoundingBox = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeVoxelList(imageSize,stats,statsAlreadyComputed);
  
    for k = 1:length(stats)
        list = stats(k).VoxelList;
        if (isempty(list))
            stats(k).BoundingBox = [0.5*ones(1,3) zeros(1,3)];
        else
            minCorner = min(list,[],1) - 0.5;
            maxCorner = max(list,[],1) + 0.5;
            stats(k).BoundingBox = [minCorner (maxCorner - minCorner)];
        end
    end
end

% computeSubarrayIdx
function [stats, statsAlreadyComputed] = ...
    computeSubarrayIdx(imageSize,stats,statsAlreadyComputed)
%   Find a cell-array containing indices so that L(idx{:}) extracts the
%   elements of L inside the bounding box.

if ~statsAlreadyComputed.SubarrayIdx
    statsAlreadyComputed.SubarrayIdx = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeBoundingBox(imageSize,stats,statsAlreadyComputed);
    num_dims = numel(imageSize);
    idx = cell(1,num_dims);
    for k = 1:length(stats)
        boundingBox = stats(k).BoundingBox;
        left = boundingBox(1:(end/2));
        right = boundingBox((1+end/2):end);
        left = left(1,[2 1 3:end]);
        right = right(1,[2 1 3:end]);
        for p = 1:num_dims
            first = left(p) + 0.5;
            last = first + right(p) - 1;
            idx{p} = first:last;
        end
        stats(k).SubarrayIdx = idx;
    end
end

% computeEllipseParams
function [stats, statsAlreadyComputed] = ...
    computeEllipsoidParams(imageSize,stats,statsAlreadyComputed)
%   Find the ellipsoid that has the same normalized second central moments
%   as the region.  Compute the principal axes lengths, orientation, and
%   eigenvectors and eigenvalues of the ellipsoid.

if ~(statsAlreadyComputed.PrincipalAxisLength && ...
        statsAlreadyComputed.Orientation && ...
        statsAlreadyComputed.EigenValues && ...        
        statsAlreadyComputed.EigenVectors)
    statsAlreadyComputed.PrincipalAxisLength = 1;
    statsAlreadyComputed.Orientation = 1;
    statsAlreadyComputed.EigenValues = 1;
    statsAlreadyComputed.EigenVectors = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeSubarrayIdx(imageSize,stats,statsAlreadyComputed);
    [stats, statsAlreadyComputed] = ...
        computeCentroid(imageSize,stats,statsAlreadyComputed);
    
    for k = 1:length(stats)
        list = stats(k).VoxelList;
        if (isempty(list))
            stats(k).PrincipalAxisLength = [0 0 0];
            stats(k).Orientation = [0 0 0];
            stats(k).EigenValues = [0 0 0];
            stats(k).EigenVectors = zeros(3,3);
            
        else
            if statsAlreadyComputed.Image == 1
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
            
            % See g2534933 and the accompanying TS escalation for detailed
            % notes on the formula used below to compute the principal axis
            % lengths
            stats(k).PrincipalAxisLength = [ 2*sqrt(5*S(1)*numPoints) ...
                                             2*sqrt(5*S(2)*numPoints) ...
                                             2*sqrt(5*S(3)*numPoints) ];
            stats(k).Orientation = rotm2euler(U);
            stats(k).EigenValues = D*numPoints;
            stats(k).EigenVectors = V;
        end
    end
end

function [mu200, mu020, mu002, mu110, mu011, mu101] = ...
                                    computeRequiredMoments(im, centroid)

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
    zTempVal = reshape((1:p) - centroid(3), [1 1 p]);
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

function eulerAngles = rotm2euler(rotm)
%ROTM2EULER Convert rotation matrix to Euler angles
%
%   eulerAngles = rotm2euler(rotm) converts 3x3 3D rotation matrix to Euler
%   angles
%
%   Reference:
%   ---------
%   
%   Ken Shoemake, Graphics Gems IV, Edited by Paul S. Heckbert,
%   Morgan Kaufmann, 1994, Pg 222-229.

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

% computeExtent
function [stats, statsAlreadyComputed] = ...
    computeExtent(imageSize,stats,statsAlreadyComputed)
%   Volume / (BoundingBoxWidth * BoundingBoxHeight * BoundingBoxDepth)

if ~statsAlreadyComputed.Extent
    statsAlreadyComputed.Extent = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeVolume(stats,statsAlreadyComputed);
    [stats, statsAlreadyComputed] = ...
        computeBoundingBox(imageSize,stats,statsAlreadyComputed);
    
    for k = 1:length(stats)
        if (stats(k).Volume == 0)
            stats(k).Extent = NaN;
        else
            stats(k).Extent = stats(k).Volume / prod(stats(k).BoundingBox(4:6));
        end
    end
end

% computeImage
function [stats, statsAlreadyComputed] = ...
    computeImage(imageSize,stats,statsAlreadyComputed)
%   Binary image containing "on" voxels corresponding to voxels
%   belonging to the region.  The size of the image corresponds
%   to the size of the bounding box for each region.

if ~statsAlreadyComputed.Image
    statsAlreadyComputed.Image = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeSubarrayIdx(imageSize,stats,statsAlreadyComputed);
    
    for k = 1:length(stats)
        stats(k).Image = getImageForEachRegion(imageSize,stats(k).SubarrayIdx,stats(k).VoxelList);        
    end
end

function imageKthRegion = getImageForEachRegion(imageSize,regionSubarrayIdx,regionVoxelList)

ndimsL = numel(imageSize);
if any(cellfun(@isempty,regionSubarrayIdx))
    imageKthRegion = logical([]);
else
    maxBound = cellfun(@max,regionSubarrayIdx);
    minBound = cellfun(@min,regionSubarrayIdx);
    sizeOfSubImage = maxBound - minBound + 1;
    
    % Shift the VoxelList subscripts so that they is relative to
    % sizeOfSubImage.
    if min(sizeOfSubImage) == 0
        imageKthRegion = logical(sizeOfSubImage);
    else
        subtractby = maxBound-sizeOfSubImage;
        
        % swap subtractby so that it is in the same order as
        % VoxelList, i.e., c r ....
        subtractby = subtractby(:, [2 1 3:end]);
        
        subscript = cell(1,ndimsL);
        for m = 1 : ndimsL
            subscript{m} = regionVoxelList(:,m) - subtractby(m);
        end
        
        % swap subscript back into the order sub2ind expects, i.e.
        % r c ...
        subscript = subscript(:,[2 1 3:end]);
        
        idx = sub2ind(sizeOfSubImage,subscript{:});
        imageKthRegion = false(sizeOfSubImage);
        imageKthRegion(idx) = true;
    end
end

% computeVoxelList
function [stats, statsAlreadyComputed] = ...
    computeVoxelList(imageSize,stats,statsAlreadyComputed)
%   A P-by-3 matrix, where P is the number of voxels belonging to
%   the region.  Each row contains the row, column and plane
%   coordinates of a voxel.

if ~statsAlreadyComputed.VoxelList
    statsAlreadyComputed.VoxelList = 1;
    
    ndimsL = 3;
    % Convert the linear indices to subscripts and store
    % the results in the voxel list.  Reverse the order of the first
    % two subscripts to form x-y order.
    In = cell(1,ndimsL);
    for k = 1:length(stats)
        if ~isempty(stats(k).VoxelIdxList)
            [In{:}] = ind2sub(imageSize, stats(k).VoxelIdxList);
            stats(k).VoxelList = [In{:}];
            stats(k).VoxelList = stats(k).VoxelList(:,[2 1 3]);
        else
            stats(k).VoxelList = zeros(0,ndimsL);
        end
    end
end

%%%
% ComputeSurfaceVoxelList
%%%
function [stats, statsAlreadyComputed] = ...
    computeSurfaceVoxelList(imageSize,stats,statsAlreadyComputed)
%   Find the pixels on the perimeter/surface of the region; make a list
%   of the coordinates of their corners; sort and remove
%   duplicates.

if ~statsAlreadyComputed.SurfaceVoxelList
    statsAlreadyComputed.SurfaceVoxelList = 1;


    [stats, statsAlreadyComputed] = ...
        computeBoundingBox(imageSize,stats,statsAlreadyComputed);
    [stats, statsAlreadyComputed] = ...
        computeVoxelList(imageSize,stats,statsAlreadyComputed);
    [stats, statsAlreadyComputed] = ...
        computeSubarrayIdx(imageSize,stats,statsAlreadyComputed);

    for k = 1:length(stats)
        
        image_K = getImageForEachRegion(imageSize,stats(k).SubarrayIdx,stats(k).VoxelList);
        
        if(isempty(image_K))
            stats(k).SurfaceVoxelList = [];
            continue;
        end
        
        if(ndims(image_K) < 3) %#ok<ISMAT>
            perimVolume = bwperim(image_K, 8);
        else
            perimVolume = bwperim(image_K, 26);
        end
        
        firstRow   = stats(k).BoundingBox(2) + 0.5;
        firstCol   = stats(k).BoundingBox(1) + 0.5;
        firstPlane = stats(k).BoundingBox(3) + 0.5;
        
        perimIdx = find(perimVolume);
        
        [r, c, p] = ind2sub(size(image_K), perimIdx);
        % Force rectangular empties.
        r = r(:) + firstRow - 1;
        c = c(:) + firstCol - 1;
        p = p(:) + firstPlane -1;
        
        rr = [r-.5 ; r    ; r+.5 ; r    ; r    ; r   ];
        cc = [c    ; c+.5 ; c    ; c-.5 ; c    ; c   ];
        pp = [p    ; p    ; p    ; p    ; p+.5 ; p-.5];    
        stats(k).SurfaceVoxelList = unique([cc rr pp],'rows');
    end

end

% computeConvexHull
function [stats, statsAlreadyComputed] = ...
    computeConvexHull(imageSize,stats,statsAlreadyComputed)
%   A P-by-3 array representing the convex hull of the region.
%   The first column contains row coordinates; the second column
%   contains column coordinates; the third column contains plane
%   coordinates. The resulting polygon goes through voxel corners, 
%   not voxel centers.

if ~statsAlreadyComputed.ConvexHull
    statsAlreadyComputed.ConvexHull = 1;
          
    [stats, statsAlreadyComputed] = ...
        computeSurfaceVoxelList(imageSize,stats,statsAlreadyComputed);
    [stats, statsAlreadyComputed] = ...
        computeBoundingBox(imageSize,stats,statsAlreadyComputed);
 
    for k = 1:length(stats)
        list = stats(k).SurfaceVoxelList;
        if (isempty(list))
            stats(k).ConvexHull = zeros(0,3);
        else
            % compute the convhull triangulations.
            conHullTriIdx = convhulln(list);
            
            % Flatten the triangle vertices on the hull
            conHullTriIdx = reshape(conHullTriIdx,[numel(conHullTriIdx), 1]);
            % Drop repeated vertices
            % ConvHull will be in X, Y, Z format
            conHullXYZ = list(unique(conHullTriIdx),:);
            stats(k).ConvexHull   = conHullXYZ;
            
        end
    end
    
end

% computeConvexImage
function [stats, statsAlreadyComputed] = ...
    computeConvexImage(imageSize, stats,statsAlreadyComputed)
%   Uses delaunayTriangulation to fill in the convex hull.

if ~statsAlreadyComputed.ConvexImage
    statsAlreadyComputed.ConvexImage = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeConvexHull(imageSize,stats,statsAlreadyComputed);
    [stats, statsAlreadyComputed] = ...
        computeBoundingBox(imageSize,stats,statsAlreadyComputed);

    for k = 1:length(stats)
        M = stats(k).BoundingBox(5);
        N = stats(k).BoundingBox(4);
        P = stats(k).BoundingBox(6); 
        hull = stats(k).ConvexHull;
        if (isempty(hull))
            stats(k).ConvexImage = false(M,N,P);
        else
            firstRow   = stats(k).BoundingBox(2) + 0.5;
            firstCol   = stats(k).BoundingBox(1) + 0.5;
            firstPlane = stats(k).BoundingBox(3) + 0.5;
            
            [c, r, p] = meshgrid(1:1:N, 1:1:M, 1:1:P);
            p = p(:) + firstPlane -1;
            r = r(:) + firstRow - 1;
            c = c(:) + firstCol - 1;
            
            dt = delaunayTriangulation(hull);
            % Get indices of internal points (non NaN)
            idx = pointLocation(dt, c(:), r(:), p(:));
                
            % non-NaN indices are internal points
            convImage = ~isnan(idx);
             
            image_K = getImageForEachRegion(imageSize,stats(k).SubarrayIdx,stats(k).VoxelList);

            %reshape to the same size as input           
            stats(k).ConvexImage = reshape(convImage, [size(image_K,1),...
                                                       size(image_K,2),...
                                                       size(image_K,3)]);
        end
    end
end


% computeConvexVolume
function [stats, statsAlreadyComputed] = ...
    computeConvexVolume(imageSize, stats,statsAlreadyComputed)
%   Computes the number of "on" voxels in ConvexImage.

if ~statsAlreadyComputed.ConvexVolume
    statsAlreadyComputed.ConvexVolume = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeConvexImage(imageSize,stats,statsAlreadyComputed);

    for k = 1:length(stats)
        stats(k).ConvexVolume = sum(stats(k).ConvexImage(:));
    end


end

% computeSolidity
function [stats, statsAlreadyComputed] = ...
    computeSolidity(imageSize,stats,statsAlreadyComputed)
%   Volume / ConvexVolume

if ~statsAlreadyComputed.Solidity
    statsAlreadyComputed.Solidity = 1; 
    
    [stats, statsAlreadyComputed] = ...
        computeVolume(stats,statsAlreadyComputed);
    [stats, statsAlreadyComputed] = ...
        computeConvexVolume(imageSize,stats,statsAlreadyComputed);
    
    for k = 1:length(stats)
        if (stats(k).ConvexVolume == 0)
            stats(k).Solidity = NaN;
        else
            stats(k).Solidity = stats(k).Volume / stats(k).ConvexVolume;
        end
    end
end

% computeVoxelValues
function [stats, statsAlreadyComputed] = ...
    computeVoxelValues(V,stats,statsAlreadyComputed)

if ~statsAlreadyComputed.VoxelValues
    statsAlreadyComputed.VoxelValues = 1;
    
    for k = 1:length(stats)
        stats(k).VoxelValues = V(stats(k).VoxelIdxList);
    end
end

% computeWeightedCentroid
function [stats, statsAlreadyComputed] = ...
    computeWeightedCentroid(imageSize,V,stats,statsAlreadyComputed)

if ~statsAlreadyComputed.WeightedCentroid
    statsAlreadyComputed.WeightedCentroid = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeVoxelList(imageSize,stats,statsAlreadyComputed);
    
    for k = 1:length(stats)
        Intensity = V(stats(k).VoxelIdxList);
        sumIntensity = sum(Intensity);
        numDims = size(stats(k).VoxelList,2);
        wc = zeros(1,numDims);
        for n = 1 : numDims
            M = sum(stats(k).VoxelList(:,n) .* ...
                double( Intensity(:) ));
            wc(n) = M / sumIntensity;
        end
        stats(k).WeightedCentroid = wc;
    end
end

% computeMeanIntensity
function [stats, statsAlreadyComputed] = ...
    computeMeanIntensity(V,stats,statsAlreadyComputed)

if ~statsAlreadyComputed.MeanIntensity
    statsAlreadyComputed.MeanIntensity = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeVoxelValues(V,stats,statsAlreadyComputed);
    
    for k = 1:length(stats)
        stats(k).MeanIntensity = mean(stats(k).VoxelValues);
    end
end

% computeMinIntensity
function [stats, statsAlreadyComputed] = ...
    computeMinIntensity(V,stats,statsAlreadyComputed)

if ~statsAlreadyComputed.MinIntensity
    statsAlreadyComputed.MinIntensity = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeVoxelValues(V,stats,statsAlreadyComputed);
    
    for k = 1:length(stats)
        stats(k).MinIntensity = min(stats(k).VoxelValues);
    end
end

% computeMaxIntensity
function [stats, statsAlreadyComputed] = ...
    computeMaxIntensity(V,stats,statsAlreadyComputed)

if ~statsAlreadyComputed.MaxIntensity
    statsAlreadyComputed.MaxIntensity = 1;
    
    [stats, statsAlreadyComputed] = ...
        computeVoxelValues(V,stats,statsAlreadyComputed);
    
    for k = 1:length(stats)
        stats(k).MaxIntensity = max(stats(k).VoxelValues);
    end
end

function [V, reqStats, officialStats] = parseInputs(sizeImage, varargin)

shapeStats = {
    'LabelName'
    'Volume'
    'Centroid'
    'BoundingBox'
    'SubarrayIdx'
    'Image'
    'EquivDiameter'
    'Extent'
    'VoxelIdxList'
    'VoxelList'
    'PrincipalAxisLength'
    'Orientation'
    'EigenVectors'
    'EigenValues'
    'ConvexHull'
    'ConvexImage'
    'ConvexVolume'
    'Solidity'
    'SurfaceArea'};

voxelValueStats = {
    'VoxelValues'
    'WeightedCentroid'
    'MeanIntensity'
    'MinIntensity'
    'MaxIntensity'};

basicStats = {
    'LabelName'
    'Volume'
    'Centroid'
    'BoundingBox'};

V = [];
officialStats = shapeStats;

numOrigInputArgs = numel(varargin);

if numOrigInputArgs == 1
    %REGIONPROPS3(BW) or REGIONPROPS3(CC) or REGIONPROPS3(L)
    
    reqStats = basicStats';
    return;
    
elseif isnumeric(varargin{2}) || islogical(varargin{2})
    %REGIONPROPS3(...,V) or REGIONPROPS3(...,V,PROPERTIES)
    
    V = varargin{2};
    validateattributes(V, {'numeric','logical'},{}, mfilename, 'V', 2);
    
    iptassert(isequal(sizeImage,size(V)), ...
        'images:regionprops3:sizeMismatch')
    
    officialStats = [shapeStats;voxelValueStats];
    if numOrigInputArgs == 2
        %REGIONPROPS3(BW) or REGIONPROPS3(CC,V) or REGIONPROPS3(L,V)
        reqStats = basicStats';
        return;
    else
        %REGIONPROPS3(BW,V,PROPERTIES) of REGIONPROPS3(CC,V,PROPERTIES) or
        %REGIONPROPS3(L,V,PROPERTIES)
        startIdxForProp = 3;
        reqStats = getPropsFromInput(startIdxForProp, ...
            officialStats, voxelValueStats, basicStats, varargin{:});
    end
    
else
    %REGIONPROPS3(BW,PROPERTIES) or REGIONPROPS3(CC,PROPERTIES) or
    %REGIONPROPS3(L,PROPERTIES)
    startIdxForProp = 2;
    reqStats = getPropsFromInput(startIdxForProp, ...
        officialStats, voxelValueStats, basicStats, varargin{:});
end

function [reqStats,officialStats] = getPropsFromInput(startIdx, ...
    officialStats, voxelValueStats, basicStats, varargin)

if iscell(varargin{startIdx})
    %REGIONPROPS3(...,PROPERTIES)
    propList = varargin{startIdx};
elseif strcmpi(varargin{startIdx}, 'all')
    %REGIONPROPS3(...,'all')
    reqStats = officialStats';
    return;
elseif strcmpi(varargin{startIdx}, 'basic')
    %REGIONPROPS3(...,'basic')
    reqStats = basicStats';
    return;
else
    %REGIONPROPS3(...,PROP1,PROP2,..)
    propList = varargin(startIdx:end);
end

numProps = length(propList);
reqStats = cell(1, numProps);
for k = 1 : numProps
    if ischar(propList{k})
        noGrayscaleImageAsInput = startIdx == 2;
        if noGrayscaleImageAsInput
            % This code block exists so that regionprops3 can throw a more
            % meaningful error message if the user want a voxel value based
            % measurement but only specifies a label matrix as an input.
            tempStats = [officialStats; voxelValueStats];
            prop = validatestring(propList{k}, tempStats, mfilename, ...
                'PROPERTIES', k+1);
            if any(strcmp(prop,voxelValueStats))
                error(message('images:regionprops3:needsGrayscaleImage', prop));
            end
        else
            prop = validatestring(propList{k}, officialStats, mfilename, ...
                'PROPERTIES', k+2);
        end
        reqStats{k} = prop;
    else
        error(message('images:regionprops3:invalidType'));
    end
end

function [stats, statsAlreadyComputed] = initializeStatsTable(...
    numObjs, requestedStats, officialStats)

if isempty(requestedStats)
    error(message('images:regionprops3:noPropertiesWereSelected'));
end

% Initialize the stats table.
tempStats = {'SurfaceVoxelList';'DelaunayTriangulation'};
allStats = [officialStats; tempStats];
numStats = length(allStats);
empties = cell(numObjs,numStats);
stats = cell2struct(empties,allStats,2);
% Initialize the statsAlreadyComputed structure array. Need to avoid
% multiple calculations of the same property for performance reasons.
zz = cell(numStats, 1);
for k = 1:numStats
    zz{k} = 0;
end
statsAlreadyComputed = cell2struct(zz, allStats, 1);

function outstats = createOutputTable(requestedStats, stats, isInputCategorical)

% Figure out what fields to keep and what fields to remove.
fnames = fieldnames(stats);
idxRemove = ~ismember(fnames, requestedStats);

% FieldNames include 'LabelName' property by default, which was added for
% the categorical support. But 'LabelName' property should only be present
% in the output when the input is categorical. So remove 'LabelName' from
% fieldNames when not needed.
if ~isInputCategorical
    [~,idxLabelName] = ismember('LabelName',fnames);
    idxRemove(idxLabelName) = 1;
end

idxKeep = ~idxRemove;

% Convert to cell array
c = struct2cell(stats);
sizeOfc = size(c);

% Determine size of new cell array that will contain only the requested
% fields.
newSizeOfc = sizeOfc;
newSizeOfc(1) = sizeOfc(1) - numel(find(idxRemove));
newFnames = fnames(idxKeep);

% Create the output table.
outstats = cell2struct(reshape(c(idxKeep,:), newSizeOfc),newFnames);

outstats = struct2table(outstats,'AsArray',true);

hasVoxelIdxList = any(cellfun(@(x)strcmp(x,'VoxelIdxList'),...
                              outstats.Properties.VariableNames));

if (hasVoxelIdxList)    
    if (~ iscell(outstats.VoxelIdxList))
         % Convert voxelIdList to a cell array
          voxelIdList = outstats.VoxelIdxList;
          % row of size of each cell array
          rowSizes = ones(1, size(voxelIdList,1));
          columnSize = size(voxelIdList, 2);

          outstats.VoxelIdxList = mat2cell(voxelIdList, rowSizes, columnSize);
    end
end
