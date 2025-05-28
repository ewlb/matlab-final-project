function [labels, clusterCenters]  = imsegisodata(cube, options)
%

% Copyright 2023 The MathWorks, Inc.

arguments
    cube {mustBeACube(cube)}
    options.InitialNumClusters (1,1) {mustBeNumeric, mustBeNonsparse, ...
        mustBeNonempty,mustBeNonNan, mustBeFinite, mustBeInteger, mustBePositive} = 5;
    options.MinSamples {mustBeNumeric,mustBeNonsparse, mustBeNonNan,...
        mustBeFinite,mustBeScalarOrEmpty,mustBeReal, mustBePositive,mustBeInteger} = [];
    options.MaxIterations (1,1) {mustBeNumeric, mustBeNonsparse, ...
        mustBeNonempty,mustBeNonNan, mustBeFinite, mustBeInteger, mustBePositive} = 10;
    options.MaxStandardDeviation {mustBeNumeric,mustBeNonsparse,mustBeNonNan,...
        mustBeFinite,mustBeScalarOrEmpty,mustBeReal,mustBeNonnegative}= [];
    options.MinClusterSeparation (1,1) {mustBeNumeric, mustBeNonsparse, ...
        mustBeNonempty,mustBeNonNan, mustBeFinite, mustBeNonnegative} = 1;
    options.NormalizeInput (1,1) logical {mustBeNumericOrLogical} = true;
    options.MaxPairsToMerge (1,1) {mustBeNumeric, mustBeNonsparse, ...
        mustBeNonempty,mustBeNonNan, mustBeFinite, mustBeInteger, mustBePositive} = 2;
end

% Assign inputs
[cube,classInp, kinit,MinSamples, MaxIterations, MaxStandardDeviation, MinClusterSeparation, Pmax] = ...
    parseInputs(cube, options);

% Reshape the hyperspectral data
[numRows, numCols, numBands] = size(cube);
numPixels = numRows*numCols;
cube = reshape(cube, numPixels, numBands);

% Normalized the data
if options.NormalizeInput
    [cube, avgChn, stdDevChn] = normInp(cube);
end

% Error out if the input NumClusters are greater than numPixels in cube.
if numPixels < kinit
    error(message("images:imsegisodata:kTooLarge",numPixels));
end

% Step 1: Assign cluster centers
s = rng;
c = onCleanup(@() rng(s));
rng('default');
clusterCenters = cube(randperm(numPixels, kinit),:);

% Iteration
for iter = 1:MaxIterations
    % Step 2: Assign pixels to clusters
    d = images.internal.builtins.EuclideanDistance(cube, clusterCenters);
    [~, labels] = min(d,[],2);

    % Step 3: Remove clusters with assigned pixels count fewer than MinSamples
    [clusterCenters, hasClusterRemoved] = removeEmptyClusters(labels, clusterCenters, MinSamples,cube);
    if hasClusterRemoved
        % Relabel with remaining cluster centers
        d = images.internal.builtins.EuclideanDistance(cube, clusterCenters);
        [~, labels] = min(d,[],2);
    end

    % Step 4: Update cluster centers
    clusterCenters = updateClusterCenters(cube, labels);

    % Step 5: Check termination conditions
    goToSplit = true;
    goToMerge = false;
    if (iter == MaxIterations)
        goToSplit = false;
        goToMerge = true;
        MinClusterSeparation = 0;
    elseif (2 * size(clusterCenters,1) > kinit && ...
            (mod(iter, 2) == 0 || size(clusterCenters,1) >= 2 * kinit))
        goToSplit = false;
        goToMerge = true;
    end

    if goToSplit
        % Step 6: Calculate the average distances
        [avgLabelDistances, totalAvgDist] = calculateAvgDist(labels,d, size(clusterCenters,1));
        % Step 7: Split clusters if conditions are met
        [clusterCenters, labels] = splitClusters(cube, clusterCenters, labels,...
            MaxStandardDeviation, MinSamples, kinit, avgLabelDistances, totalAvgDist);
    end

    if goToMerge
        % Step 8: Merge clusters if the conditions are met
        clusterCenters = mergeClusters(labels, clusterCenters, MinClusterSeparation, Pmax);
    end
end

% Relabel with final clusters
d = images.internal.builtins.EuclideanDistance(cube, clusterCenters);
[~, labels] = min(d,[],2);
[clusterCenters, hasClusterRemoved] = removeEmptyClusters(labels, clusterCenters, MinSamples,cube);
if hasClusterRemoved
    % Relabel with remaining cluster centers
    d = images.internal.builtins.EuclideanDistance(cube, clusterCenters);
    [~, labels] = min(d,[],2);
end

labels = reshape(labels,numRows, numCols);
if options.NormalizeInput
    clusterCenters = denormalizeCenters(clusterCenters, avgChn, stdDevChn);
end
clusterCenters = cast(clusterCenters,classInp);
end


function [centroids, hasClusterRemoved] = removeEmptyClusters(labels, centroids, MinSamples,cube)
% Check if any classes have fewer samples than the minimum samples required
classCounts = accumarray(labels,1);
[~, orderIdx] = sort(classCounts);
undersampledClasses = find(classCounts < MinSamples);
hasClusterRemoved = false;

% Remove undersampled classes
if ~isempty(undersampledClasses)
    if isequal(numel(undersampledClasses),numel(classCounts))
        % All classes contains the samples less than MinSamples, so delete
        % one cluster by one and relabel between remaining clusters
        % Removing the cluster with lowest number of samples
        centroids(orderIdx(1), :) = [];
        d = images.internal.builtins.EuclideanDistance(cube, centroids);
        [~, labels] = min(d,[],2);
        [centroids, hasClusterRemoved] = removeEmptyClusters(labels, centroids, MinSamples,cube);

    else
        centroids(undersampledClasses, :) = [];
        hasClusterRemoved = true;
    end
end
end


function centroids = updateClusterCenters(cube, labels)
% Create a new cluster center array and initialize with zeros
k = max(labels,[],'all');
centroids = zeros(k,size(cube,2),'like',cube);

% Update the cluster centers with mean of corresponding labels
for i = 1:k
    centroids(i, :) = mean(cube(labels == i, :), 1);
end
end


function [clusterCenters, labels] = splitClusters(cube, clusterCenters, labels,...
    MaxStandardDeviation, MinSamples, kinit,avgLabelDistances, totalAvgDist)

% Get existing number of clusters and number of bands
k = size(clusterCenters,1);
numBands = size(cube,2);

% Calculate the standard deviation for each cluster
stdOfLabel = zeros(k, numBands);
numPixelsInCluster = zeros(k,1);

for j = 1:k
    % Find the pixels that belong to cluster j
    pixelsInEachCluster = cube(labels == j, :);
    numPixelsInCluster(j,1) = size(pixelsInEachCluster,1);
    % Calculate the standard deviation for cluster j
    stdOfLabel(j, :) = std(pixelsInEachCluster);
end
% Take the maximum standard deviation value and index of the corresponding
% band which contains Maximum standard deviation.
[stdMaxOfLabel,idx] = max(stdOfLabel, [], 2);

for i = 1:k
    if (stdMaxOfLabel(i)>MaxStandardDeviation) && (abs(avgLabelDistances(i)) > abs(totalAvgDist) ...
            && (numPixelsInCluster(i) > 2 * (MinSamples + 1)) || k <= (kinit / 2))
        % Store the original cluster centers in temp variable
        tempClusters = clusterCenters;
        Knew =  size(clusterCenters,1);

        % Reinitialize with new size to improve the performance, size of
        % cluster centers will be increased by 1.
        clusterCenters = zeros(Knew+1, numBands,'like',cube);

        % Split the clusters by adding and subtracting the quantity
        % 0.5*stdMax to the band of cluster center which corresponds to the
        % band of maximum standard deviation value.
        newCenter = tempClusters(i,:);
        newCenter(1,idx(i)) = tempClusters(i,idx(i))+ 0.5*stdMaxOfLabel(i);
        tempClusters(i,idx(i)) = tempClusters(i,idx(i)) - 0.5*stdMaxOfLabel(i);

        % Add the new clusters
        clusterCenters(1:Knew,:) = tempClusters;
        clusterCenters(Knew+1,:) = newCenter;
    end
end
end


function [avgLabelDistances, totalAvgDist] = calculateAvgDist(labels, d, k)
% Calculate the average distances
avgLabelDistances = zeros(k,1);
numPixelsInCluster = zeros(k,1);
for j = 1:k
    labelDistances = d(labels == j, j);
    numPixelsInCluster(j,1) = numel(labelDistances);
    avgLabelDistances(j,1) = sum(labelDistances)/numPixelsInCluster(j,1);
end
% Get the average of all distances
totalAvgDist = sum(avgLabelDistances.*numPixelsInCluster)/size(labels,1);
end


function clusterCenters = mergeClusters(labels, clusterCenters, Lmin, Pmax)
k = size(clusterCenters, 1);
% Get the euclidean distance between cluster centers
dij = images.internal.builtins.EuclideanDistance(clusterCenters, clusterCenters);
dij = triu(dij, 1); % Upper triangular part
[sortedDist, sortedIdx] = sort(dij(:));

mergedClusters = zeros(k, 1);
pairsMerged = 0;
% Check for only upper traingular part
startIdx = (k*(k+1))/2+1;
for idx = startIdx:numel(sortedDist)
    if (sortedDist(idx) > Lmin) || (pairsMerged >= Pmax)
        % Stop merging if either the number of merged pairs reached limit or
        % the distances are greater than minimum distance
        break;
    end

    [i, j] = ind2sub([k, k], sortedIdx(idx));

    if mergedClusters(i) || mergedClusters(j)
        continue;
    end

    Ni = sum(labels == i);
    Nj = sum(labels == j);
    % Merge the centers with weighted average
    mergedCenter = (Ni*clusterCenters(i, :) + Nj*clusterCenters(j, :))/(Ni+Nj);
    tempCenters = clusterCenters;
    clusterCenters = [tempCenters; mergedCenter];
    mergedClusters([i, j]) = size(clusterCenters, 1);
    pairsMerged = pairsMerged + 1;
end

% Erase
if pairsMerged > 0
    clusterCenters(mergedClusters>0,:) = [];
end
end


% validations
function mustBeACube(cube)
if isobject(cube)
    validateattributes(cube,{'hypercube'},{'nonempty'},'imsegisodata','cube');
    cube = cube.DataCube;
end
validateattributes(cube,{'numeric'},{'nonempty','nonsparse','finite'},'imsegisodata','cube');
if (ndims(cube) > 3)
    error(message('images:validate:tooManyDimensions', 'cube', 3));
end
end


function [cube,classInp, kinit,MinSamples, MaxIterations, maxstd, MinClusterSeparation, Pmax] =....
    parseInputs(cube, options)

% Convert cube to either single or double
if isobject(cube)
    cube = cube.DataCube;
end
classInp = class(cube);
if isinteger(cube)
    cube = single(cube);
end

kinit = options.InitialNumClusters;
MaxIterations = options.MaxIterations;
MinClusterSeparation = options.MinClusterSeparation;
Pmax = options.MaxPairsToMerge;

% Validations for MinSamples and MaxStandardDeviation
MinSamples = options.MinSamples;
numPixels = size(cube,1)*size(cube,2);
if isempty(MinSamples)
    MinSamples = round(numPixels/(10*kinit));
end
validateattributes(MinSamples,{'numeric'},{'nonnan'},'imsegisodata','MinSamples');
if (MinSamples > numPixels)
    error(message("images:imsegisodata:highMinSamples",numPixels));
end
maxstd = options.MaxStandardDeviation;
if isempty(maxstd)
    if options.NormalizeInput
        maxstd = 1;
    else
        maxstd = std(cube,0,'all');
    end
end
validateattributes(maxstd,{'numeric'},{'nonnan','real','nonnegative'},'imsegisodata','MaxStandardDeviation');
end


function [out, avgChn, stdDevChn] = normInp(X)
% normalize channels independently (each channel persists as a column in X).
avgChn = mean(X);
stdDevChn = std(X);
% EdgeCase Condition where standard Deviation is zero of any channel
% Modify channel's stdDev=1 as the channel is irrelevant from clustering perspective.
zeroLoc = stdDevChn==0;
stdDevChn(zeroLoc) = 1;
out = (X - avgChn)./stdDevChn;
end


function Centers = denormalizeCenters(NormCen, avgChn, stdDevChn)
% De-normalized centers to be returned in original user input space.
Centers = NormCen .* stdDevChn + avgChn ;
end
