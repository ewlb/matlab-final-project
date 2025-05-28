function layerOut = reduceInputLayerStats(layerIn,newInputSize)
% reduceInputLayerStats Modify input layer normalization stats for new input size.
%
%  layerOut = reduceInputLayerStats(layer,newInputSize) creates a new input
%  layer with a new inputSize and modifies any normalization statistics to
%  be channelwise in the event the layerIn stats are elementwise so that
%  normalization stats can be used with inputs of a different spatial size.

%   Copyright 2020 The MathWorks, Inc.

if isequal(newInputSize,layerIn.InputSize)
    layerOut = layerIn;
    return
end

numSpatialDims = length(layerIn.InputSize)-1;

if isa(layerIn,'nnet.cnn.layer.ImageInputLayer')
    layerOut = imageInputLayer(newInputSize,'Name',layerIn.Name,...
        'Normalization',layerIn.Normalization,...
        'NormalizationDimension',layerIn.NormalizationDimension,...
        'DataAugmentation',layerIn.DataAugmentation);
elseif isa(layerIn,'nnet.cnn.layer.Image3DInputLayer')
    layerOut = image3dInputLayer(newInputSize,'Name',layerIn.Name,...
        'Normalization',layerIn.Normalization,...
        'NormalizationDimension',layerIn.NormalizationDimension);
else
    assert(false,'Unexpected input layer type');
end

if ~isempty(layerIn.Mean)
    if statsAreElementwise(layerIn.Mean,numSpatialDims,layerIn.InputSize)
        layerOut.Mean = mean(layerIn.Mean,1:numSpatialDims);
    else
        layerOut.Mean = layerIn.Mean;
    end
end
    
if ~isempty(layerIn.Min)
    if statsAreElementwise(layerIn.Min,numSpatialDims,layerIn.InputSize)
        layerOut.Min = min(layerIn.Min,[],1:numSpatialDims);
    else
        layerOut.Min = layerIn.Min;
    end
end

if ~isempty(layerIn.Max)
    if statsAreElementwise(layerIn.Max,numSpatialDims,layerIn.InputSize)
        layerOut.Max = max(layerIn.Max,[],1:numSpatialDims);
    else
        layerOut.Max = layerIn.Max;
    end
end

if ~isempty(layerIn.StandardDeviation)
    if statsAreElementwise(layerIn.StandardDeviation,numSpatialDims,layerIn.InputSize)
        % Reuse reduction algorithm from DLT for this same case at inference time
        layerOut.StandardDeviation = nnet.internal.cnn.layer.util.computeMeanOfStds(layerIn.StandardDeviation,layerIn.Mean,1:numSpatialDims);
    else
        layerOut.StandardDeviation = layerIn.StandardDeviation;
    end
end

end

function TF = statsAreElementwise(stats,numSpatialDims,inputSize)
TF = isequal(size(stats,1:numSpatialDims),inputSize(1:numSpatialDims));
end