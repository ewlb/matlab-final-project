function lgraph = createResidualBlocks(inputSize, numResBlocks, filterSize, numFilters, ...
    convolutionWeightInitializer, paddingValue, normalizationLayer, activationLayer, hasInputLayer, layername)
% createResidualBlocks creates the residual block layergraph for UNIT generator.


% Copyright 2020 The MathWorks, Inc.

lgraph = layerGraph();

% Add input layer if that is required.
if hasInputLayer
    resBlockInput = imageInputLayer(inputSize,"Name", layername+"_input","Normalization","none");
    lgraph = addLayers(lgraph, resBlockInput);
end

for resBlockIdx = 1:numResBlocks
    % Add unique name to normalization layer.
    if ~isempty(normalizationLayer)
        normalizationLayer.Name = layername+"_res_norm_"+num2str(resBlockIdx)+num2str(1);
        normalizationLayer1 = normalizationLayer;
        normalizationLayer.Name = layername+"_res_norm_"+num2str(resBlockIdx)+num2str(2);
        normalizationLayer2 = normalizationLayer;
    else
        normalizationLayer1 = [];
        normalizationLayer2 = [];
    end        

    % Add unique name to activation layer. 
    activationLayer.Name = layername+"_res_activation_"+num2str(resBlockIdx)+num2str(1);
        
    layers = [
        convolution2dLayer(filterSize, numFilters, "Name",layername+"_res_conv_"+num2str(resBlockIdx)+num2str(1), ...
            "WeightsInitializer", convolutionWeightInitializer, 'Padding','same', 'PaddingValue', paddingValue)
        normalizationLayer1
        activationLayer
        convolution2dLayer(filterSize, numFilters, "Name",layername+"_res_conv_"+num2str(resBlockIdx)+num2str(2), ...
            "WeightsInitializer", convolutionWeightInitializer, 'Padding','same', 'PaddingValue', paddingValue)
        normalizationLayer2
        additionLayer(2,"Name",layername+"_addition_"+num2str(resBlockIdx))];
    lgraph = addLayers(lgraph,layers);

    if resBlockIdx > 1
        lgraph = connectLayers(lgraph,layername+"_addition_"+num2str(resBlockIdx-1),layername+"_res_conv_"+num2str(resBlockIdx)+num2str(1));
        lgraph = connectLayers(lgraph,layername+"_addition_"+num2str(resBlockIdx-1),layername+"_addition_"+num2str(resBlockIdx)+"/in2");
    end
end

% Make the connections if there is input layer in the layergraph.
if hasInputLayer
    lgraph = connectLayers(lgraph, layername+"_input", layername+"_res_conv_11");
    lgraph = connectLayers(lgraph, layername+"_input", layername+"_addition_1/in2");
end
end