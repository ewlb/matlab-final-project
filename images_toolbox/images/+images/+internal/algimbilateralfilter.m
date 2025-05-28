function Bout = algimbilateralfilter(Ain, NeighborhoodSize, RangeSigma, SpatialSigma, PadString, PadVal)
%

% Copyright 2017-2021 The MathWorks, Inc.

%#codegen

isColor = size(Ain,3)==3;

% Always work in floating point for most accuracy
origClass = class(Ain);
if ~isfloat(Ain)
    A = double(Ain);
else
    A = Ain;
end
coder.internal.prefer_const(NeighborhoodSize);
B = zeros(size(A), 'like', A);

% Pad (Note NeighborhoodSize is expected to be odd)
padSize = floor(NeighborhoodSize/2);
coder.internal.prefer_const(padSize);
if strcmpi(PadString, 'constant')
    A = padarray(A, padSize, PadVal, 'both');
else
    A = padarray(A, padSize, PadString, 'both');
end

% (Pre-normalized) Spatial Gaussian weights
spatialWeights = fspecial('gaussian',...
    NeighborhoodSize, SpatialSigma);
coder.internal.prefer_const(spatialWeights);

rangeSigmaTerm = 2*RangeSigma^2;

isCodegen = ~coder.target('MATLAB');
nCols = size(B,2);
nRows = size(B,1);
if isCodegen %codegen path
    % If GPU is enabled and input image is 2-D grayscale image
    % (MxN matrix) then calling GPU specific implementation here.
    % For variable input and spatialWeights size, calling MLC
    % implementation. For variable inputs stencil kernel will not generate
    % shared memory.
    if coder.gpu.internal.isGpuEnabled && ~isColor...
            && coder.internal.isConst(size(A)) ...
            && coder.internal.isConst(size(spatialWeights))
        B = images.internal.coder.gpu.algimbilateralfilterGPUImpl(A,...
            spatialWeights,padSize,NeighborhoodSize,rangeSigmaTerm);
    else
        parfor col = 1:nCols
            for row = 1:nRows
                B(row,col,:) = imbilatfilt_core(A,row,col,padSize, ...
                    isColor,spatialWeights,NeighborhoodSize,rangeSigmaTerm);
            end
        end
    end
else % simulation path
    for col = 1:size(B,2)
        for row = 1:size(B,1)
            % Account offset due to padding
            arow = row+padSize(1);
            acol = col+padSize(2);
            % Extract Neighborhood around current pixel
            ALocalNeighbor = A(arow-padSize(1):arow+padSize(1),...
                acol-padSize(2):acol+padSize(2), :);
            % Compute intensity weights
            ACenterPixel = A(arow, acol,:);
            if isColor
                % Euclidean distance. Defer sqrt in distance
                % computation to cancel out .^2 in Gaussian computation.
                intensityDiff = (ALocalNeighbor - ACenterPixel).^2;
                intensityDiff = sum(intensityDiff,3);
                intensityWeights = exp(-(intensityDiff) / rangeSigmaTerm);
            else
                intensityDiff = ALocalNeighbor(:,:,1)-ACenterPixel(1,1,1);
                intensityWeights = exp(-(intensityDiff).^2 / rangeSigmaTerm);
            end
            weights = spatialWeights.*intensityWeights;
            weightedPixels = weights.*ALocalNeighbor;
            B(row,col, :) = sum(sum(weightedPixels,1),2) ./ (sum(weights(:))+eps);
        end
    end
end

Bout = cast(B, origClass);

end

function b = imbilatfilt_core(A,row,col,padSize, ...
    isColor,spatialWeights,NeighborhoodSize,rangeSigmaTerm)
coder.inline('always');

% Account offset due to padding
arow = row+padSize(1);
acol = col+padSize(2);
% Extract Neighborhood around current pixel
ALocalNeighbor = A(arow-padSize(1):arow+padSize(1),...
    acol-padSize(2):acol+padSize(2), :);
% Compute intensity weights
ACenterPixel = A(arow, acol,:);
if isColor % process RGB image
    b = coder.nullcopy(zeros([1,1,3], 'like', A));
    b(1,1,:) = process_Neighbor3D(spatialWeights, ALocalNeighbor,NeighborhoodSize, ACenterPixel, rangeSigmaTerm);
else % process grayscale image
    b = coder.nullcopy(zeros([1,1,1], 'like', A));
    b(1,1,:) = process_Neighbor2D(spatialWeights, ALocalNeighbor(:,:,1),NeighborhoodSize, ACenterPixel(1,1,1), rangeSigmaTerm);
end

end

function outVal = process_Neighbor3D(spatialWeights, ALocalNeighbor, ...
    NeighborhoodSize, ACenterPixel, rangeSigmaTerm)
coder.inline('always');

sum_weights = zeros(1,'like',ALocalNeighbor);
sum_weightedPixels = zeros([1,1,3],'like',ALocalNeighbor);
for iy = 1:NeighborhoodSize(1)
    for ix = 1:NeighborhoodSize(2)
        intensityDiff1 = ALocalNeighbor(iy,ix,1)-ACenterPixel(1,1,1);
        intensityDiff2 = ALocalNeighbor(iy,ix,2)-ACenterPixel(1,1,2);
        intensityDiff3 = ALocalNeighbor(iy,ix,3)-ACenterPixel(1,1,3);
        intensityDiff = intensityDiff1 * intensityDiff1 + ...
            intensityDiff2 * intensityDiff2 + ...
            intensityDiff3 * intensityDiff3;
        intensityWeights = exp(-(intensityDiff) / rangeSigmaTerm);
        weights = spatialWeights(iy,ix).*intensityWeights;
        sum_weights = sum_weights + weights;
        % sum each channel separately
        sum_weightedPixels(1,1,:) = sum_weightedPixels(1,1,:) + weights.*ALocalNeighbor(iy,ix,:);
    end
end
outVal = sum_weightedPixels ./ (sum_weights +eps);

end

function outVal = process_Neighbor2D(spatialWeights, ALocalNeighbor, ...
    NeighborhoodSize, ACenterPixel, rangeSigmaTerm)
coder.inline('always');

sum_weights = zeros(1,'like',ALocalNeighbor);
sum_weightedPixels = zeros(1,'like',ALocalNeighbor);
for iy = 1:NeighborhoodSize(1)
    for ix = 1:NeighborhoodSize(2)
        intensityDiff = ALocalNeighbor(iy,ix,1)-ACenterPixel(1,1,1);
        intensityWeights =exp(-(intensityDiff.*intensityDiff) / rangeSigmaTerm);
        weights = spatialWeights(iy,ix).*intensityWeights;
        sum_weights= sum_weights + weights;
        sum_weightedPixels= sum_weightedPixels + weights.*ALocalNeighbor(iy,ix,1);
    end
end
outVal = sum_weightedPixels ./ (sum_weights +eps);

end
