function [lgraph, info] = createPix2PixHDGenerator(NameValueArgs, inputSize)
% createPix2PixHDgenerator creates a the generator layer graph. lgraph
% contains the constructed layergraph and info contains the information
% about the constructed network, like layer array of every block, layer
% name of the final layer of every block.


% Copyright 2020 The MathWorks, Inc.

% Extract the following fields from NameValueArgs.
depth = NameValueArgs.NumDownSamplingBlocks;
numfiltersFirstConv = NameValueArgs.NumFiltersInFirstBlock;
filterSizeFirstConv = NameValueArgs.FilterSizeInFirstAndLastBlocks;
filterSizeIntermediateConv = NameValueArgs.FilterSizeInIntermediateBlocks;
weightInit = NameValueArgs.ConvolutionWeightsInitializer;
padding = NameValueArgs.ConvolutionPaddingValue;
upsampleMethod = NameValueArgs.UpsampleMethod;
dropout = NameValueArgs.Dropout;
numResBlocks = NameValueArgs.NumResidualBlocks;
namePrefix = NameValueArgs.NamePrefix;
numOutputChannels = NameValueArgs.NumOutputChannels;

% Activation and Normalization are layer objects.
normalization = NameValueArgs.NormalizationLayer;
activation = NameValueArgs.ActivationLayer;
finalActivation = NameValueArgs.FinalActivationLayer;

% To store additional information.
info = struct;

% Add Initial layers.
[lgraph, info] = iCreateInitialBlock(inputSize, filterSizeFirstConv, ...
    numfiltersFirstConv, weightInit, normalization, activation, padding, namePrefix, info);

% Add Downsampling layers.
[lgraph, info] = iCreateDownsamplingBlock(lgraph, filterSizeIntermediateConv, ...
    numfiltersFirstConv, depth, weightInit, normalization, activation, padding, namePrefix, info);

numFiltersForResBlock = info.downsamplingBlocks.numOutFilters;

% Add Residual layers.
[lgraph, info] = iCreateResidualBlock(lgraph, filterSizeIntermediateConv, numFiltersForResBlock, ...
    numResBlocks, dropout, weightInit, normalization, activation, padding, namePrefix, info);

% Check if cropping required to match input and output sizes.
isCropRequired = any(mod(inputSize(1:2)/(2^depth),1)~=0);

% Add Upsample layers.
[lgraph, info] = iCreateUpsampleBlock(lgraph, filterSizeIntermediateConv, numFiltersForResBlock, ...
    depth, upsampleMethod, weightInit, normalization, activation, padding, namePrefix, isCropRequired, info);

% Add Final layers.
[lgraph, info] = iCreateFinalBlock(lgraph, filterSizeFirstConv, numOutputChannels, ...
    weightInit, padding, finalActivation, namePrefix, info);

end

function [lgraph, info] = iCreateInitialBlock(inputSize, filterSize, numFilters, weightInit, normalization, activation, padding, namePrefix, info)
% Assign unique name to normalization layer.
if ~isempty(normalization)
    normalization.Name = strcat(namePrefix,'iNorm');
end

% Assign unique name to activation layer.
activation.Name = strcat(namePrefix, 'iActivation');

layers = [ ...
    imageInputLayer(inputSize,'Normalization','none','Name',strcat(namePrefix,'inputLayer'))
    convolution2dLayer(filterSize,numFilters,'Name',strcat(namePrefix,'iConv'),'WeightsInitializer',weightInit,'Padding','same','PaddingValue',padding)
    normalization
    activation
    ];
lgraph = layerGraph(layers);

info.initialBlock.layers = layers;
info.initialBlock.finalLayerName = activation.Name;
info.initialBlock.numOutFilters = numFilters;
end

function [lgraph, info] = iCreateDownsamplingBlock(lgraph, filterSize, numFilters, numDownsample, weightInit, normalization, activation, padding, namePrefix, info)
prevLayerName = info.initialBlock.finalLayerName;
info.downsamplingBlocks.layers = [];
for idx = 1:numDownsample    
    blockIdx = int2str(idx);
    
    % Downsampling factor.
    stride = 2;
    
    % Assign unique name to normalization layer.
    if ~isempty(normalization)
        normalization.Name = strcat(namePrefix,'dNorm_',blockIdx);
    end
    
    % Assign unique name to activation layer.
    activation.Name = strcat(namePrefix, 'dActivation_',blockIdx);
    
    % Compute the number of filters in the next convolutional layer
    numFilters = numFilters*2;
    
    layers = [
        convolution2dLayer(filterSize,numFilters,"Name",strcat(namePrefix,"dConv_",blockIdx), ...
        "Stride",stride,"Padding",'same',"WeightsInitializer",weightInit,'PaddingValue',padding)
        normalization
        activation
        ];
    
    % Connect the layer graph.
    lgraph = addLayers(lgraph, layers);
    lgraph = connectLayers(lgraph,prevLayerName,layers(1).Name);
    prevLayerName = layers(end).Name;
    info.downsamplingBlocks.layers = vertcat(info.downsamplingBlocks.layers, layers);
end
info.downsamplingBlocks.finalLayerName = prevLayerName;
info.downsamplingBlocks.numOutFilters = numFilters;
end

function [lgraph, info] = iCreateResidualBlock(lgraph, filterSize, numFilters, numResBlocks, dropout, weightInit, normalization, activation, padding, namePrefix, info)
prevLayerName = info.downsamplingBlocks.finalLayerName;
info.residualBlocks.layers = [];

for idx = 1:numResBlocks
    blockId = int2str(idx);
    
    % Specify unique layer names of the residual block.
    convLayer1Name = strcat(namePrefix,"rConv_",blockId,"_1");
    norm1Name = strcat(namePrefix,"rNorm_",blockId,"_1");
    
    % Assign unique name to normalization layers.
    if ~isempty(normalization)
        normalization.Name = norm1Name;
    end
    
    % Assign unique name to activation layer.
    activation.Name = strcat(namePrefix,"rActivation_",blockId,"_1");
    
    % Resblock layers.
    l1 = [
        convolution2dLayer(filterSize,numFilters,"Name",convLayer1Name,"WeightsInitializer",weightInit,'Padding','same','PaddingValue',padding)
        normalization
        activation
        ];
    
    % Add dropout layer if specified.
    if dropout ~= 0
        l1 = vertcat(l1, dropoutLayer(dropout, 'Name', strcat(namePrefix, "rDropout_",blockId))); %#ok<AGROW>
    end
    
    % Unique Layer Names.
    convLayer2Name = strcat(namePrefix,"rConv_",blockId,"_2");
    additionName = strcat(namePrefix,"rAdd_",blockId);
    
    % Assign unique name to normalization layers.
    norm2Name = strcat(namePrefix,"rNorm_",blockId,"_2");
    if ~isempty(normalization)
        normalization.Name = norm2Name;
    end
    
    % Resblock layers.
    l2 = [
        convolution2dLayer(filterSize,numFilters,"Name",convLayer2Name,"WeightsInitializer",weightInit,'Padding','same','PaddingValue',padding)
        normalization
        additionLayer(2,'Name',additionName)
        ];
    
    % Combine residual block layers. 
    residualBlockLayers = vertcat(l1,l2);
    
    % Connect the layerGraph.
    lgraph = addLayers(lgraph,residualBlockLayers);
    lgraph = connectLayers(lgraph,prevLayerName,convLayer1Name);
    lgraph = connectLayers(lgraph,prevLayerName,strcat(additionName,"/in2"));
    prevLayerName = additionName;
    info.residualBlocks.layers = vertcat(info.residualBlocks.layers, residualBlockLayers);
end
info.residualBlocks.finalLayerName = prevLayerName;
info.residualBlocks.numOutFilters = numFilters;
end

function [lgraph, info] = iCreateUpsampleBlock(lgraph, filterSize, numFilters, numUpsample, upsampleMethod, weightInit, normalization, activation, padding, namePrefix, isCropRequired, info)
prevLayerName = info.residualBlocks.finalLayerName;
info.upsampleBlocks.layers = [];

% If cropping is required get the layer names of reference inputs.
if isCropRequired
    % Assuming number of layers are same in each block.
    numLayersinEachBlock = numel(info.downsamplingBlocks.layers)/numUpsample;
    layers = [info.initialBlock.layers; info.downsamplingBlocks.layers];
    
    % Arrange layers in reverse order and keep only required layers.
    layers = flipud(layers);
    layers = layers(numLayersinEachBlock+1:numLayersinEachBlock:end-1,1);  
end
for idx = 1:numUpsample
    blockIdx = int2str(idx);
   
    % Upsampling factor.
    stride = 2;
    
    if ~isempty(normalization)
        % Assign unique name to normalization layer.
        normalization.Name = strcat(namePrefix,"uNorm_",blockIdx);
    end
    
    % Create a crop layer if cropping required.
    if isCropRequired
        cropName = strcat(namePrefix,"uCrop2d_", blockIdx);
        cropLayer = crop2dLayer('centercrop','Name', cropName);
    else
        cropLayer = [];
    end
    % Assign unique name to activation layer.
    activation.Name = strcat(namePrefix, "uActivation_",blockIdx);
    
    % Compute the number of filters in the next convolutional layer.
    numFilters = numFilters./2;
    
    % Determine the upsampling layers.
    if strcmp(upsampleMethod,"transposedConv")
        upsamplingLayers = [
            transposedConv2dLayer(filterSize,numFilters,"Name",strcat(namePrefix,"uConv_", blockIdx), ...
            "Stride",stride,"Cropping","Same", "WeightsInitializer", weightInit)
            cropLayer
            ];
        
    elseif strcmp(upsampleMethod,"bilinearResize")
        upsamplingLayers = [
            resize2dLayer('Scale', stride, 'Method', 'bilinear', 'Name', strcat(namePrefix,"uResize_", blockIdx))
            convolution2dLayer(filterSize,numFilters,"Name",strcat(namePrefix,"uConv_", blockIdx),"WeightsInitializer",weightInit,'Padding','same','PaddingValue',padding)
            cropLayer
            ];
    else
        upsamplingLayers = [
            convolution2dLayer(filterSize,numFilters*4,"Name",strcat(namePrefix,"uConv_", blockIdx),"WeightsInitializer",weightInit,'Padding','same',"PaddingValue",padding)
            depthToSpace2dLayer(stride, 'Name',strcat(namePrefix,"uShuffle_", blockIdx))
            cropLayer
            ];
    end
    
    % Add norm and activation layers.
    upsamplingLayers = vertcat(upsamplingLayers, normalization, activation); %#ok<AGROW>
    
    % Connect the layer graph.
    lgraph = addLayers(lgraph, upsamplingLayers);
    lgraph = connectLayers(lgraph,prevLayerName,upsamplingLayers(1).Name);
    % Add reference input to crop layer.
    if isCropRequired
        lgraph = connectLayers(lgraph,layers(idx).Name, strcat(cropName,"/ref"));
    end
    prevLayerName = upsamplingLayers(end).Name;
    info.upsampleBlocks.layers = vertcat(info.upsampleBlocks.layers, upsamplingLayers);
end
info.upsampleBlocks.finalLayerName = prevLayerName;
info.upsampleBlocks.numOutFilters = numFilters;
end

function [lgraph, info] = iCreateFinalBlock(lgraph, filterSize, numFilters, weightInit, padding, finalActivation, namePrefix, info)
prevLayerName = info.upsampleBlocks.finalLayerName;
if ~isempty(finalActivation)
    finalActivation.Name = strcat(namePrefix,'fActivation');
end
layers = [ ...
    convolution2dLayer(filterSize,numFilters,'Name',strcat(namePrefix,'fConv'),'WeightsInitializer',weightInit,'Padding','same','PaddingValue',padding)
    finalActivation
    ];

lgraph = addLayers(lgraph, layers);
lgraph = connectLayers(lgraph,prevLayerName,layers(1).Name);
info.finalBlock.layers = layers;
info.finalBlock.finalLayerName = layers(end).Name;
info.finalBlock.numOutFilters = numFilters;
end