classdef encoderLayer < nnet.layer.Layer & nnet.layer.Formattable
% encoderLayer creates a layer for the encoder module for UNIT generator.


% Copyright 2020 The MathWorks, Inc.

    properties(Learnable)
        Encoder
    end
    
    properties (SetAccess = private)
        State
    end
   
    methods
        function this = encoderLayer(inputSize, numDownsamplingBlocks, numIndResBlocks, ...
                numFiltersInFirstConv, filterSizeInFirstConv, filterSizeInIntermediateConv, ...
                convolutionWeightInitializer, paddingValue, normalization, activations, name)
         this.Name = name;
         this.NumInputs = 1;    
         this.NumOutputs = 1;
         
         % Creating dlnetwork for the property 'Encoder'.
         this.Encoder = iCreateEncoderNetwork(inputSize, numDownsamplingBlocks, numIndResBlocks, ...
             numFiltersInFirstConv, filterSizeInFirstConv, filterSizeInIntermediateConv, ...
             convolutionWeightInitializer, paddingValue, normalization, activations, name);
         
         % Cacheing the state parameters of 'Encoder' dlnetwork to be used
         % in updating the state parameters for the layer.
         this.State = images.unitGenerator.internal.BasicCache(this.Encoder.State);
        end
        
        function out = forward(this, in)
            this.Encoder.State = this.State.Value;
            [out, state] = this.Encoder.forward(in);
            this.State.Value = state;
        end
        
        function out = predict(this, in)
            out = this.Encoder.predict(in);
        end
    end
end

% Internal function for creating encoder network.
function net = iCreateEncoderNetwork(inputSize, numDownsamplingBlocks, numResBlocks, numInitialFilters, ...
    filterSizeInitial, filterSizeIntermediate, convolutionWeightInitializer, paddingValue, ...
    normalization, activations, layername)
% Add input block.
lgraph = iInputBlock(inputSize, filterSizeInitial, numInitialFilters, convolutionWeightInitializer, ...
    paddingValue, layername);

% Add downsampling Blocks.
lgraph = iDownsamplingBlocks(lgraph, numDownsamplingBlocks, filterSizeIntermediate, ...
    numInitialFilters, convolutionWeightInitializer, paddingValue, normalization, activations, layername);

% Add residual Blocks.
if numResBlocks ~= 0
    numResBlockFilters = numInitialFilters * (2^numDownsamplingBlocks);
    lgraph = iResidualBlocks(lgraph, numResBlocks, filterSizeIntermediate, numResBlockFilters, ...
        convolutionWeightInitializer, paddingValue, normalization, activations, layername);
end

% Create dlnetwork of encoder.
net = dlnetwork(lgraph);
end

% Internal function to create input block of encoder.
function lgraph = iInputBlock(inputSize, filterSize, numFilters, convolutionWeightInitializer, ...
    paddingValue, layername)
layers = [
    imageInputLayer(inputSize, "Name", layername+"_imageinput", "Normalization", "none")
    convolution2dLayer(filterSize, numFilters, "Name", layername+"_conv_"+num2str(1), "Stride", 1, ...
        "WeightsInitializer", convolutionWeightInitializer, 'Padding','same', 'PaddingValue', paddingValue)
    leakyReluLayer(0.2, "name", layername+"_lrelu_"+num2str(1))];

lgraph = layerGraph(layers);
end

% Internal function to create downsampling blocks of encoder.
function lgraph = iDownsamplingBlocks(prevLgraph, numDownsamplingBlocks, filterSize, numFilters, ...
    convolutionWeightInitializer, paddingValue, normalizationLayer, activationLayer, layername)
layers = [];

for downsamplingBlockIdx = 1:numDownsamplingBlocks
    % Add unique name to normalization layer.
    if ~isempty(normalizationLayer)
        normalizationLayer.Name = layername+"_norm_"+num2str(downsamplingBlockIdx);
    end

    % Add unique name to activation layer.
    activationLayer.Name = layername+"_activation_"+num2str(downsamplingBlockIdx);  
    
    % Update number of filters
    numFilters = numFilters * 2;

    layers2 =[
        convolution2dLayer(filterSize, numFilters, "Name", layername+"_conv_"+num2str(downsamplingBlockIdx+1), ...
            "Stride", 2, "WeightsInitializer", convolutionWeightInitializer, 'Padding','same', 'PaddingValue', paddingValue)
        normalizationLayer
        activationLayer];
    
    layers = [
        layers
        layers2];
end
downsamplingBlockLgraph = layerGraph(layers);

% Integrate downsampling block layergraph to previous layergraph.
prevLgraphEndLayerName = prevLgraph.Layers(end).Name;
layers = [prevLgraph.Layers 
    downsamplingBlockLgraph.Layers];
connections = [prevLgraph.Connections
    downsamplingBlockLgraph.Connections];
lgraph = iConnectLayerGraphs(layers,connections);
lgraph = connectLayers(lgraph, prevLgraphEndLayerName, layername+"_conv_2");
end

% Internal function to create residual blocks of encoder.
function lgraph = iResidualBlocks(prevLgraph, numResBlocks, filterSize, numFilters, ...
    convolutionWeightInitializer, paddingValue, normalizationLayer, activationLayer, layername)
% Create residual block layergraph.
hasInputLayer = false;
resblockLgraph = images.unitGenerator.internal.createResidualBlocks([], numResBlocks, filterSize, numFilters, ...
    convolutionWeightInitializer, paddingValue, normalizationLayer, activationLayer, hasInputLayer, layername);

% Integrate residual block layergraph to previous layergraph.
if ~isempty(resblockLgraph.Layers)
    prevLgraphEndLayerName = prevLgraph.Layers(end).Name;
    
    layers = [prevLgraph.Layers 
        resblockLgraph.Layers];
    connections = [prevLgraph.Connections
        resblockLgraph.Connections];
    lgraph = iConnectLayerGraphs(layers,connections);
    lgraph = connectLayers(lgraph, prevLgraphEndLayerName, layername+"_res_conv_11");
    lgraph = connectLayers(lgraph, prevLgraphEndLayerName, layername+"_addition_1/in2");
end
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