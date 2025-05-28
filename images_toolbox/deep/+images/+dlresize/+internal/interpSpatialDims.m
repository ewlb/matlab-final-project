function out = interpSpatialDims(X,start,stop,stride,method,nearestRoundingMode,scale,inputSpatialDimSize)
%interpSpatialDims  Core interpolation engine of dlresize.

% Copyright 2020 The MathWorks, Inc.

numSpatialDims = size(start,1);
numDims = ndims(X);

out = X;
for spatialDim = 1:numSpatialDims
    if size(out,spatialDim) > 1
        out = interpAlongSpatialDim(out,spatialDim,start,stride,stop,...
            method,nearestRoundingMode,scale,inputSpatialDimSize(spatialDim));
    else
        % interp1 requires input grid has at least two samples at each
        % dimension. Manage special case with repmat for singleton spatial
        % dimensions:
        % Y = dlresize(dlarray([1 2 3],'SS'),'Scale',2);
        
        % Since floor() is the OuptutSize rule for fractional scale
        % factors, scaling a singleton spatial dimension by a scale factor
        % less than one would result in no output samples in that
        % dimension.
        if scale(spatialDim) < 1
           error(message('images:dlresize:singletonSpatialDimScaleLessThanOne')); 
        end
        
        dims = ones(1,numDims);
        dims(spatialDim) = floor(scale(spatialDim));
        out = repmat(out,dims);
    end
end

end


function out = interpAlongSpatialDim(in,spatialDim,start,stride,stop,method,nearestRoundingMode,scale,inputDimSize)

dimsIn = 1:ndims(in);

permuteVec = dimsIn;
permuteVec([1 spatialDim]) = dimsIn([spatialDim 1]);

in = permute(in,permuteVec);

queryPoints = start(spatialDim):stride(spatialDim):stop(spatialDim);
queryPoints = adjustQueryPointsToManageBoundaryBehavior(queryPoints,inputDimSize);
if (method == "nearest") && (nearestRoundingMode ~= "round")
    queryPoints = updateQueryPointsToObeyNearestRoundingMode(queryPoints,nearestRoundingMode,scale(spatialDim));
end
    
out = interp1(1:inputDimSize,in,queryPoints',method);

out = ipermute(out,permuteVec);

end

function ptsOut = adjustQueryPointsToManageBoundaryBehavior(queryPoints,inputDimSize)
    % Implement 'replicate' padding by manipulating query points prior to
    % interpolation. If we ever support larger interpolation kernels or
    % anti-aliasing, we would need to do more math and actually implement
    % 'symmetric' padding to be equivalent to imresize.
    ptsOut = queryPoints;
    ptsOut(queryPoints < 1) = 1;
    ptsOut(queryPoints > inputDimSize) = inputDimSize;
end

function queryPoints = updateQueryPointsToObeyNearestRoundingMode(queryPoints,nearestRoundingMode,scale)
    
% For onnx-10: https://github.com/microsoft/onnxruntime/blob/master/onnxruntime/core/providers/cpu/tensor/upsample.h
%     case SIMPLE:
%         // versions older than 11 did not have nearest_mode attr. Use the original logic in this case
%         // to maintain backward compatibility
%         return [](float x_original, bool isDownSample) {
%           if (isDownSample) {
%             return static_cast<int64_t>(std::ceil(x_original));
%           } else {
%             return static_cast<int64_t>(x_original);
%           }
%         };

switch(nearestRoundingMode)
    
    case "onnx-10"
        isDownsample = scale < 1;
        if isDownsample
            queryPoints = ceil(queryPoints);
        else
            queryPoints = fix(queryPoints);
        end
    case "round-half-down"
        delta = repmat(0.5,size(queryPoints));
        delta = delta .* -sign(queryPoints);
        queryPoints = floor(delta + queryPoints);
    case "floor"
        queryPoints = floor(queryPoints);
    otherwise
        assert(false,'Unexpected NearestRoundingMode option');
end

end