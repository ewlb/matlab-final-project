function [outputSize,scale] = getOutputSizeAndScale(NameValueArgs,numSpatialDims,inputSpatialDimSize)
%getOutputSizeAndScale Determine scale and output grid size for dlresize.
 
% Copyright 2020 The MathWorks, Inc.

scaleSpecified = isfield(NameValueArgs,'Scale');
sizeSpecified = isfield(NameValueArgs,'OutputSize');

if scaleSpecified && sizeSpecified
    error(message('images:dlresize:mustSpecifyScaleOrOutputSize'));
end

if scaleSpecified
    scale = NameValueArgs.Scale;
    if isscalar(scale)
        scale = repmat(scale,1,numSpatialDims);
    else
        if length(scale) ~= numSpatialDims
            error(message('images:dlresize:argumentMustAgreeWithSpatialDimsInX','''Scale'''));
        end
    end
    outputSize = scale .* inputSpatialDimSize;
else
    % outputSize specified
    outputSize = NameValueArgs.OutputSize;
    if length(outputSize) ~= numSpatialDims
        error(message('images:dlresize:argumentMustAgreeWithSpatialDimsInX','''OutputSize'''));
    end

    nanLoc = isnan(outputSize);
    nanCount = sum(nanLoc);
    validNaNSyntax = nanCount == (numSpatialDims-1);
    if validNaNSyntax
        homogeneousScale = outputSize ./ inputSpatialDimSize;
        homogeneousScale = homogeneousScale(~isnan(homogeneousScale));
        outputSize = homogeneousScale .* inputSpatialDimSize;
        scale = repmat(homogeneousScale,1,numSpatialDims);
    elseif ~nanCount
        outputSize = NameValueArgs.OutputSize;
        scale = outputSize ./ inputSpatialDimSize;
    else
        error(message('images:dlresize:invalidNaNOutputSizeSyntax'));
    end
    
end

outputSize = floor(outputSize);

end