classdef decoderLayer < nnet.layer.Layer & nnet.layer.Formattable
% decoderLayer creates a layer for the decoder module for UNIT generator.


% Copyright 2020 The MathWorks, Inc.

    properties(Learnable)
        Decoder
    end
    
    properties (SetAccess = private)
        State
    end
   
    methods
        function this = decoderLayer(inputSize, numUpsampleBlocks, numResBlocks, outChannel, ...
                numInitialFilters, filterSizeInitial, filterSizeIntermediate, convolutionWeightInitializer, ...
                paddingValue, upsampleMethod, normalization, activation, finalActivation, name)
         this.Name = name;
         this.NumInputs = 1;    
         this.NumOutputs = 2;
         
         % Creating dlnetwork for the property 'Decoder'.
         this.Decoder = iCreateDecoderNetwork(inputSize, numUpsampleBlocks, numResBlocks, outChannel, ...
             numInitialFilters, filterSizeInitial, filterSizeIntermediate, convolutionWeightInitializer, ...
             paddingValue, upsampleMethod, normalization, activation, finalActivation, name);
         
         % Cacheing the state parameters of 'Decoder' dlnetwork to be used
         % in updating the state parameters for the layer.
         this.State = images.unitGenerator.internal.BasicCache(this.Decoder.State);
        end

        function [out1, out2] = forward(this, in)
            this.Decoder.State = this.State.Value;
            [out, state] = this.Decoder.forward(in);
            this.State.Value = state;
            [out1,out2] = splitArray(out);
        end
        
        function [out1, out2] = predict(this, in)
            [out1,out2] = splitArray(this.Decoder.predict(in));
        end
    end
end

function [out1,out2] = splitArray(in)
    % Split a multidimensional array along the row dimension.
    % Input is assumed to have an even number of rows.
    m = size(in,1)/2;
    subscripts = repmat({':'},1,ndims(in));
    subscripts{1} = 1:m;
    out1 = in(subscripts{:});

    subscripts{1} = m+1:2*m;
    out2 = in(subscripts{:});
end

% Internal function for creating decoder network.
function net = iCreateDecoderNetwork(inputSize, numUpsampleBlocks, numResBlocks, outChannel, ...
    numInitialFilters, filterSizeInitial, filterSizeIntermediate, convolutionWeightsInitializer, ...
    paddingValue, upsampleMethod, normalization, activation, finalActivation, name)
% Add residual blocks.
if numResBlocks ~= 0
    hasInputLayer = true;
    lgraph = images.unitGenerator.internal.createResidualBlocks(inputSize, numResBlocks, filterSizeIntermediate, ...
        numInitialFilters, convolutionWeightsInitializer, paddingValue, normalization, activation, hasInputLayer, name);
else
    lgraph = layerGraph();
end

% Add upsampling blocks.
lgraph = iUpsampleBlocks(lgraph, inputSize, numUpsampleBlocks, filterSizeIntermediate, numInitialFilters, ...
    convolutionWeightsInitializer, upsampleMethod, paddingValue, normalization, activation, name);

% Add output block.
lgraph = iOutputBlock(lgraph, outChannel, filterSizeInitial, convolutionWeightsInitializer, ...
    paddingValue, finalActivation, name);

% Create dlnetwork for decoder.
net = dlnetwork(lgraph);
end

% Internal function to create upsampling blocks of decoder.
function lgraph = iUpsampleBlocks(prevLgraph, inputSize, numUpsamplingBlocks, filterSize, numFilters, ...
    convolutionWeightInitializer, upsampleMethod, paddingValue, normalizationLayer, activationLayer, layername)
if isempty(prevLgraph.Layers)
    layers = imageInputLayer(inputSize,"Name", layername+"_input","Normalization","none");
else
    layers = [];
end

for upsamplingBlockIdx=1:numUpsamplingBlocks
    % Add unique name to normalization layer.
    if ~isempty(normalizationLayer)
        normalizationLayer.Name = layername+"_norm_"+num2str(upsamplingBlockIdx);
    end
    
    % Add unique name to activation layer.
    activationLayer.Name = layername+"_activation_"+num2str(upsamplingBlockIdx);
    
    % Update number of filters
    numFilters = numFilters/2;
    
    if strcmp(upsampleMethod,"transposedConv")
        upsamplingLayers = transposedConv2dLayer(filterSize, numFilters, ...
            "Name",layername+"_transposed_conv_"+num2str(upsamplingBlockIdx),"Stride",2, "Cropping", "same", "WeightsInitializer", convolutionWeightInitializer);
    elseif strcmp(upsampleMethod,"bilinearResize")
        upsamplingLayers = [
            resize2dLayer('Scale', 2, 'Method', 'bilinear', 'Name', layername+"_bilinear_resize_"+num2str(upsamplingBlockIdx))
            convolution2dLayer(filterSize, numFilters, "Name", layername+"_upsample_conv_"+num2str(upsamplingBlockIdx), ...
                "WeightsInitializer", convolutionWeightInitializer, 'Padding','same', 'PaddingValue', paddingValue)
            ];
    else 
        upsamplingLayers = [
            convolution2dLayer(filterSize, numFilters*4, "Name", layername+"_pixel_shuffle_conv_"+num2str(upsamplingBlockIdx), ...
                "WeightsInitializer", convolutionWeightInitializer, 'Padding', 'same', 'PaddingValue', paddingValue)
            depthToSpace2dLayer(2, 'Name', layername+"_shuffle_"+num2str(upsamplingBlockIdx))
            ];
    end
    
    layers2 = [  
        upsamplingLayers
        normalizationLayer
        activationLayer];
    
    layers = [
        layers
        layers2];
end

upsamplingBlockLgraph = layerGraph(layers);

% Integrate upsampling block layergraph to previous layergraph.
if ~isempty(prevLgraph.Layers)
    prevLgraphEndLayerName = prevLgraph.Layers(end).Name;
    upsamplingBlockLgraphFirstLayerName = upsamplingBlockLgraph.Layers(1).Name;

    layers = [prevLgraph.Layers 
        upsamplingBlockLgraph.Layers];
    connections = [prevLgraph.Connections
        upsamplingBlockLgraph.Connections];
    lgraph = iConnectLayerGraphs(layers,connections);
    lgraph = connectLayers(lgraph, prevLgraphEndLayerName, upsamplingBlockLgraphFirstLayerName);
else
    lgraph = upsamplingBlockLgraph;
end
end

% Internal function to create output block of decoder.
function lgraph = iOutputBlock(prevLgraph, outChannel, filterSize, convolutionWeightInitializer, ...
    paddingValue, finalActivation, layername) 
% Add unique name to final activation layer.
if ~isempty(finalActivation)
    finalActivation.Name = layername+"_final_activation";
end
    
layers = [];

layer2 =[
    convolution2dLayer(filterSize, outChannel, "Name",layername+"_final_conv", ...
        "WeightsInitializer", convolutionWeightInitializer, 'Padding','same', 'PaddingValue', paddingValue)
    finalActivation];

layers = [
    layers
    layer2];

lgraph = layerGraph(layers);

% Integrate output block layergraph to previous layergraph.
prevLgraphEndLayerName = prevLgraph.Layers(end).Name;
lgraphFirstLayer = lgraph.Layers(1).Name;

layers = [prevLgraph.Layers 
    lgraph.Layers];
connections = [prevLgraph.Connections
    lgraph.Connections];
lgraph = iConnectLayerGraphs(layers,connections);
lgraph = connectLayers(lgraph, prevLgraphEndLayerName, lgraphFirstLayer);
end

% Internal function to connect two layergraphs.
function lgraph = iConnectLayerGraphs(layers,connections)
lgraph = layerGraph();
for i = 1:numel(layers)
    lgraph = addLayers(lgraph,layers(i));
end

for c = 1:size(connections,1)
    lgraph = connectLayers(lgraph,connections.Source{c},connections.Destination{c});
end
end