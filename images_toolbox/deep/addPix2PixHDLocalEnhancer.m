function localEnhancer = addPix2PixHDLocalEnhancer(inputNet, NameValueArgs)
% addPix2PixHDLocalEnhancer Add local enhancer network to the pix2pixHD
%   generator network.
%
%   net = addPix2PixHDLocalEnhancer(net) Adds the local enhancer layers to
%   the pix2pixHD generator. The input image size of the local enhancer
%   module is twice the input resolution of input network net, incase of
%   multiple image input layers in the input network net, the size with
%   maximum resolution is doubled. The output, net, is a dlnetwork object.
%
%   net = addPix2PixHDLocalEnhancer(___,Name,Value) specifies Name/Value
%   pairs that control aspects of generator network construction:
%
%   'FilterSizeInFirstAndLastBlocks'    Size of the first convolution layer
%                                       filter in the network specified as
%                                       a vector [H W], where H and W are
%                                       the height and width or a scalar
%                                       integer value, where the same value
%                                       is used for both the dimensions.
%                                       The filter size of the last
%                                       convolution layer in the decoder
%                                       module of the generator uses the
%                                       same value. Typical values are
%                                       between 3 and 7. The value must be
%                                       odd.
%
%                                       Default: 7
%
%   'FilterSizeInIntermediateBlocks'    Size of all convolution layer
%                                       filters except for the first and
%                                       last convolution layer, specified
%                                       as a vector [H W], where H and W
%                                       are the height and width or a
%                                       scalar integer value, where the
%                                       same value is used for both
%                                       dminsions. Typical values are
%                                       between 3 and 7. The value must be
%                                       odd.
%
%                                       Default: 3
%
%   'NumResidualBlocks'                 A positive scalar integer value
%                                       that denotes the number of residual
%                                       blocks in the generator
%                                       architecture. Each residual block
%                                       is a set of convolution,
%                                       normalization and non-linear layers
%                                       with skip connection between every
%                                       pair of blocks.
%
%                                       Default: 3
%
%   'ConvolutionPaddingValue'           Value used to pad the input along
%                                       the edges, specified as one of the
%                                       following values:
%                                       - Scalar value - Pad using the
%                                         specified value.
%                                       - "symmetric-include-edge" - Pad
%                                         using mirrored layer input,
%                                         including the edge values.
%                                       - "symmetric-exclude-edge" - Pad
%                                         using mirrored layer input,
%                                         excluding the edge values.
%                                       - "replicate" - Pad using repeated
%                                         layer input border elements.
%
%                                       Default: "symmetric-exclude-edge"
%
%  'UpsampleMethod'                     A string or character vector
%                                       specifying the method used to
%                                       upsample activations. Options
%                                       include "transposedConv",
%                                       "bilinearResize", and
%                                       "pixelShuffle".
%
%                                       Default: 'transposedConv'.
%
%   'ConvolutionWeightsInitializer'     A string or function specifying the
%                                       weight initialization used in
%                                       convolution layers. Supported
%                                       strings are "glorot", "he", and
%                                       "narrow-normal".
%
%                                       Default: "narrow-normal"
%
%   'ActivationLayer'                   A string or layer object specifying
%                                       the desired activation function to
%                                       use. Supported strings are "relu",
%                                       "leakyrelu", and "elu". For
%                                       "leakyRelu", a scale factor of 0.2
%                                       is used by default.
%
%                                       Default: "relu"
%
%   'NormalizationLayer'                A string or layer object specifying
%                                       the desired normalization operation
%                                       to use after each convolution.
%                                       Supported strings are "none",
%                                       "batch", and "instance".
%
%                                       Default: "instance"
%
%   'Dropout'                           A scalar value that determines the
%                                       drop out probability. Drop out
%                                       layers are not used when zero is
%                                       specified.
%
%                                       Default: 0
%
%   'NamePrefix'                        A name to prefix to each layer in
%                                       the generator.
%                                 
%                                       Default: "LocalEnhancer_"
%
%  % Example 1- Add local enhancer layers to a pix2pixHD global generator.
%  % ---------------------------------------------------------------------
%
%    net = pix2pixHDGlobalGenerator([512 1024 32]);
%    net = addPix2PixHDLocalEnhancer(net);
%
%    % Analyze the network.
%    analyzeNetwork(net);
%
%  See also pix2pixHDGlobalGenerator.

%  References
%  ----------
%  Wang, Ting-Chun, Ming-Yu Liu, Jun-Yan Zhu, Andrew Tao, Jan Kautz, and
%  Bryan Catanzaro. "High-Resolution Image Synthesis and Semantic
%  Manipulation with Conditional GANs." In 2018 IEEE/CVF Conference on
%  Computer Vision and Pattern Recognition, 8798–8807, 2018.
%  https://doi.org/10.1109/CVPR.2018.00917.

%  Copyright 2020 The MathWorks, Inc.

arguments
    inputNet
    NameValueArgs.NumResidualBlocks (1,1) {mustBeInteger, mustBeNonnegative, mustBeNumeric} = 3
    NameValueArgs.FilterSizeInFirstAndLastBlocks = 7
    NameValueArgs.FilterSizeInIntermediateBlocks = 3
    NameValueArgs.ConvolutionPaddingValue = "symmetric-exclude-edge"
    NameValueArgs.UpsampleMethod  = "transposedConv"
    NameValueArgs.ConvolutionWeightsInitializer  = "narrow-normal"
    NameValueArgs.NormalizationLayer = "instance"
    NameValueArgs.ActivationLayer = "relu"
    NameValueArgs.Dropout (1,1) {mustBeNumeric, mustBeNonnegative, mustBeLessThanOrEqual(NameValueArgs.Dropout,1)} = 0
    NameValueArgs.NamePrefix {mustBeTextScalar}= "LocalEnhancer_"
end
% Check for deep learning toolbox.
images.internal.requiresNeuralNetworkToolbox(mfilename);

% Validate and return proper values.
NameValueArgs.FilterSizeInFirstAndLastBlocks = iValidateFilterSize(NameValueArgs.FilterSizeInFirstAndLastBlocks, 'FilterSizeInFirstAndLastBlocks');
NameValueArgs.FilterSizeInIntermediateBlocks = iValidateFilterSize(NameValueArgs.FilterSizeInIntermediateBlocks, 'FilterSizeInIntermediateBlocks');
NameValueArgs.ConvolutionPaddingValue = iValidatePadding(NameValueArgs.ConvolutionPaddingValue, ["replicate", "symmetric-include-edge", "symmetric-exclude-edge"]);
NameValueArgs.UpsampleMethod = iValidateUpsample(NameValueArgs.UpsampleMethod, ["transposedConv", "bilinearResize", "pixelShuffle"]);
NameValueArgs.ConvolutionWeightsInitializer = iValidateWeightInit(NameValueArgs.ConvolutionWeightsInitializer, ["glorot", "he", "narrow-normal"]);
NameValueArgs.NormalizationLayer = iValidateNormalization(NameValueArgs.NormalizationLayer, ["none", "batch", "instance"]);
NameValueArgs.ActivationLayer = iValidateActivation(NameValueArgs.ActivationLayer, ["relu", "leakyRelu", "elu"]);

networkInfo = iValidateNetworkAndExtractNetworkInfo(inputNet);
analyzedLgraph = networkInfo.analyzedLgraph;
lgraph = analyzedLgraph.LayerGraph;

% Remove the layers after feature output layer.
layersToRemove = networkInfo.finalBlockLayers;  
inputNet = removeLayers(lgraph, layersToRemove);

% Get the input size of the local enhancer.
factor = 2;
inputHW = networkInfo.outputSize(1:2).*factor;
inputNumChannels = networkInfo.numInputChannels;
inputSize = [inputHW, inputNumChannels];

% Fill the required parameters from network info.
NameValueArgs.NumOutputChannels = networkInfo.numOutputChannels;
NameValueArgs.NumFiltersInFirstBlock = ceil(networkInfo.finalBlockNumInputFilters/factor);
NameValueArgs.NumDownSamplingBlocks = 1;
NameValueArgs.FinalActivationLayer = networkInfo.finalActivation;
NameValueArgs.NamePrefix = iCreateUniqueNamePrefix(analyzedLgraph.LayerAnalyzers, NameValueArgs, inputSize);

% Construct the local enhancer.
[localEnhancer, localEnhancerInfo] = images.pix2pixHDGenerator.internal.createPix2PixHDGenerator(NameValueArgs, inputSize);

% Insert feature addition layer after downsampling block.
[localEnhancer, featureAddLayerName] = insertFeatureAddLayer(localEnhancer, localEnhancerInfo, NameValueArgs.NamePrefix);

% Combine both networks in layer graph and connect them.
featureLayerName = networkInfo.featureOutLayer;
localEnhancer = combineLayerGraphs(localEnhancer, inputNet, featureLayerName, featureAddLayerName);

% Convert to dlnetwork.
localEnhancer = dlnetwork(localEnhancer);
end

% Input argument validation functions.
function val = iValidatePadding(val, options)
validateattributes(val, {'char','string', 'numeric'},{},'','ConvolutionPaddingValue');
if ~isa(val,'numeric')
    val = validatestring(val, options,'','ConvolutionPaddingValue');
else
    validateattributes(val, {'numeric'},{'scalar','finite','real'},'','ConvolutionPaddingValue');
end
end

function val = iValidateUpsample(val, options)
validateattributes(val, {'char','string'},{},'','UpsampleMethod');
val = validatestring(val, options,'','UpsampleMethod');
end

function val = iValidateWeightInit(val, options)
validateattributes(val, {'char','string','function_handle'},{},'','ConvolutionWeightsInitializer');
val = validatestring(val, options,'','ConvolutionWeightsInitializer');
end

function val = iValidateNormalization(val, options)
isCharOrStringScalar = ischar(val)||(isscalar(val)&&isstring(val));
isLayerObject = isa(val, "nnet.cnn.layer.Layer");
if isCharOrStringScalar
    val = validatestring(val, options,'','Normalization');
    switch val
        case 'instance'
            val = instanceNormalizationLayer();
        case 'batch'
            val = batchNormalizationLayer();
        case 'none'
            val = [];
    end
elseif isLayerObject
    if numel(val) == 1
        iCheckValidLayer(val, 'NormalizationLayer');
    else
        error(message('images:pix2pixHD:mustBeSingleLayer','NormalizationLayer'));
    end
else
    error(message('images:pix2pixHD:paramMustBeStringOrLayer','NormalizationLayer'));
end
end

function val = iValidateActivation(val, options)
isCharOrStringScalar = ischar(val)||(isscalar(val)&&isstring(val));
isLayerObject = isa(val, "nnet.cnn.layer.Layer");
if isCharOrStringScalar
    val = validatestring(val, options,'','ActivationLayer');
    switch val
        case 'relu'
            val = reluLayer();
        case 'elu'
            val = eluLayer();
        case 'leakyRelu'
            val = leakyReluLayer(0.2);
    end
elseif isLayerObject
    if numel(val) == 1
        iCheckValidLayer(val, 'ActivationLayer');
    else
        error(message('images:pix2pixHD:mustBeSingleLayer','ActivationLayer'));
    end
else
    error(message('images:pix2pixHD:paramMustBeStringOrLayer','ActivationLayer'));
end
end

function val = iValidateFilterSize(val, name)
validateattributes(val, {'numeric'}, {'vector', 'nonempty', 'positive', 'odd'},'',name);
if numel(val) > 2
    error(message('images:pix2pixHD:paramMustBeScalarOrPair',name));
end
if isscalar(val)
    val = [val, val];
end
end

function iCheckValidLayer(val, name)
% Check for number of inputs and outputs.
if ~(val.NumOutputs == 1 && val.NumInputs == 1)
    error(message('images:pix2pixHD:layerSingleInputOutput',name));
end

% The layer should not change the input shape.
% Create a 2 layer dummy network with the layer and call forward and
% predict to compare their output shapes.
val.Name = "layer2";
dummyInputSize = [20,30,5];
dummyLayers = [
    imageInputLayer(dummyInputSize,'Normalization','none','Name',"layer1")
    val
    ];
try
    dummyNetwork = dlnetwork(layerGraph(dummyLayers));
catch ME
    error(message('images:pix2pixHD:layerHasError',name));
end
dummyInput = dlarray(zeros(dummyInputSize),'SSC');
dummyPredict = predict(dummyNetwork, dummyInput);
dummyForward = forward(dummyNetwork, dummyInput);
if ~(all(size(dummyInput) == size(dummyPredict)) && all(size(dummyInput) == size(dummyForward)))
    error(message('images:pix2pixHD:layerOutputShapeDifferent',name));
end
end

function info = iValidateNetworkAndExtractNetworkInfo(net)
% Initialize the info struct.
info = struct;

% Only scalar dlnetworks are allowed.
if ~isa(net, 'dlnetwork')
    error(message('images:pix2pixHD:mustBeDlnetwork'));
else
    if ~isscalar(net)
        error(message('images:pix2pixHD:scalarDlnetwork'));
    end
end

% Network must have single output.
if numel(net.OutputNames)>1
    error(message('images:pix2pixHD:dlnetworkSingleOutput'));
end

% Get the output layer name.
outputLayerName = string(net.OutputNames);

% Convert dlnetwork to layerGraph. 
net = layerGraph(net);

% Analyze the input network.
analyzedLgraph = nnet.internal.cnn.analyzer.NetworkAnalyzer(net);

% Check if the network has atleast minimum number of layers generated by
% pix2pixHDGlobalGenerator. Create a global generator with minimum layers
% and compare the number of layers.
minGen = pix2pixHDGlobalGenerator([2,2,1],'NormalizationLayer','none', ...
    'NumDownsamplingBlocks',1,'FinalActivationLayer','none','NumResidualBlocks',0,'NumFiltersInFirstBlock',2);
numLayersMinGen = size(minGen.Layers,1);
if size(net.Layers,1) < numLayersMinGen
    error(message('images:pix2pixHD:numLayersLessThanExpected'));
end

% Find the output layer size and use the same number of out channnels.
finalLayerIdx = iFindLayerIdxByName(outputLayerName, analyzedLgraph.LayerAnalyzers);
outputSize = analyzedLgraph.LayerAnalyzers(finalLayerIdx).Outputs.Size{:};
outputLayer = analyzedLgraph.LayerAnalyzers(finalLayerIdx);
finalActivation = iValidateOutputLayerType(outputLayer);
numOutputChannels = outputSize(3);
[finalBlockLayers, finalBlockNumInputFilters, featureOutLayer] = iExtractFinalBlockInfo(analyzedLgraph.LayerAnalyzers, finalActivation, finalLayerIdx);

% Find input layers and validate the num input channels.
numInputChannels = iValidateAndExtractInputChannels(analyzedLgraph.LayerAnalyzers);

% Fill the info struct with required information extracted from input
% network.
info.outputSize = outputSize;
info.finalActivation = finalActivation;
info.numOutputChannels = numOutputChannels;
info.finalBlockLayers = finalBlockLayers;
info.finalBlockNumInputFilters = finalBlockNumInputFilters;
info.featureOutLayer = featureOutLayer;
info.analyzedLgraph = analyzedLgraph;
info.numInputChannels = numInputChannels;
end

function finalActivation = iValidateOutputLayerType(layer)
if isa(layer.ExternalLayer, 'nnet.cnn.layer.Convolution2DLayer')
    finalActivation = [];
else
    iCheckValidFinalLayer(layer);
    finalActivation = layer.ExternalLayer;
end
end

function [fBlockLayers, fBlockNumInputFilters, featureOutLayer] = iExtractFinalBlockInfo(analyzedLayers, finalActivationType, finalLayerIdx)
if isempty(finalActivationType)
    fBlockLayers = [analyzedLayers(finalLayerIdx).Name];
    fBlockNumInputFilters = analyzedLayers(finalLayerIdx).Inputs.Size{1}(3);
    featureOutLayer = analyzedLayers(finalLayerIdx).Inputs.Source{1};
else
    fBlockLayers = [analyzedLayers(finalLayerIdx).Inputs.Source{1},...
        analyzedLayers(finalLayerIdx).Name];
    preFinalIdx = iFindLayerIdxByName(fBlockLayers(1),analyzedLayers);
    if ~isa(analyzedLayers(preFinalIdx).ExternalLayer, 'nnet.cnn.layer.Convolution2DLayer')
        error(message('images:pix2pixHD:expectedConvLayerInPenultimate'));
    end
    fBlockNumInputFilters = analyzedLayers(preFinalIdx).Inputs.Size{1}(3);
    featureOutLayer = analyzedLayers(preFinalIdx).Inputs.Source{1};
end
end

function numInputChannels = iValidateAndExtractInputChannels(layers)
inputImgMask = arrayfun(@(x)(isa(x.InternalLayer,'nnet.internal.cnn.layer.ImageInput')),layers);
inputImgIdx = find(inputImgMask);
if isempty(inputImgIdx)
    error(message('images:pix2pixHD:dlnetworkMustHaveImageInputLayer'));
end
imageInputSizes = arrayfun(@(x) layers(x).Outputs.Size,inputImgIdx);
imageInputSizes = cell2mat(imageInputSizes);
if size(imageInputSizes,1) == 1
    numInputChannels = imageInputSizes(1,3);
else
    if all(imageInputSizes(:,3) == imageInputSizes(1,3))
        numInputChannels = imageInputSizes(1,3);
    else
        error(message('images:pix2pixHD:imageInputLayersMustHaveSameChannels'));
    end
end
end

function layerIdx = iFindLayerIdxByName(layerName, analyzedLayers)
mask = arrayfun(@(x)(strcmp(x.Name,layerName)),analyzedLayers);
layerIdx = find(mask,1);
end

function namePrefix = iCreateUniqueNamePrefix(layers, NameValueArgs, inputSize)
% Create unique prefix for local enhancer layers.
namesList = arrayfun(@(x) x.Name ,layers);
uniqueNameReq = iCheckIfUniqueNameRequired(namesList, NameValueArgs, inputSize);
if uniqueNameReq
    regex = [char(NameValueArgs.NamePrefix),'[1-9]+'];
    [startIdx, endIdx] = cellfun(@(x) regexpi(x,regex),namesList,'UniformOutput',false);
    newIdx = computeLocalEnhancerIdx(namesList, startIdx, endIdx, string(NameValueArgs.NamePrefix));
    namePrefix = strcat(NameValueArgs.NamePrefix,num2str(newIdx));
else
    namePrefix = NameValueArgs.NamePrefix;
end
end

function tf = iCheckIfUniqueNameRequired(namesList, nvps, inputSize)
tf = false;
dummyNetwork = images.pix2pixHDGenerator.internal.createPix2PixHDGenerator(nvps, inputSize);
dummyNames = arrayfun(@(x) string(x.Name) ,dummyNetwork.Layers);
namesList = [namesList;dummyNames];
uniqueNames = unique(namesList);
if ~(size(namesList,1) == size(uniqueNames,1))
    tf = true;
end
end

function curr = computeLocalEnhancerIdx(names, startidx, endidx, prefix)
% Extract current local enhancer idx from input network, for generating
% unique names.
curr = 0;
isNumPresent = ~(cellfun(@isempty,startidx));
if any(isNumPresent)
    for i = 1:size(names,1)
        if numel(startidx{i}) == 0
            curr = max(curr, 0);
        elseif startidx{i}(1) ~= 1
            curr = max(curr, 0);
        else
            name = char(names(i));
            name = name(startidx{i,1}(1):endidx{i,1}(1));
            num = erase(string(name),prefix);
            num = str2double(num);
            curr = max(curr, num);
        end
    end
end
curr = curr+1;
end

function lgraph = combineLayerGraphs(localNet, inputNet, imgenFeatureLayer, localFeatureName)
% Function to combine two layer graphs and connect them.
externalLayers = [localNet.Layers; inputNet.Layers];
externalConnections = [localNet.Connections; inputNet.Connections];
internalConnections = nnet.internal.cnn.util.externalToInternalConnections(externalConnections, externalLayers);
hiddenConnections = nnet.internal.cnn.util.internalToHiddenConnections(internalConnections);
lgraph = nnet.cnn.LayerGraph(externalLayers, hiddenConnections);
lgraph = connectLayers(lgraph, imgenFeatureLayer, strcat(localFeatureName,"/in2"));
end

function [lgraph, featureAddLayerName] = insertFeatureAddLayer(lgraph, info, namePrefix)
% Insert addition layer after the downsampling block of local enhancer.
analyzedLgraph = nnet.internal.cnn.analyzer.NetworkAnalyzer(lgraph);
featureLayerIdx = iFindLayerIdxByName(info.downsamplingBlocks.finalLayerName, analyzedLgraph.LayerGraph.Layers);
featureLayer = analyzedLgraph.LayerGraph.Layers(featureLayerIdx);
featureAddLayer = additionLayer(2,'Name',strcat(namePrefix,"featureAddLayer"));
larray = [
    featureLayer
    featureAddLayer
    ];
lgraph = replaceLayer(lgraph, featureLayer.Name, larray);
featureAddLayerName = featureAddLayer.Name;
end

function iCheckValidFinalLayer(val)
% Check for number of inputs and outputs.
if ~(size(val.Inputs,1) == size(val.Outputs))
    error(message('images:pix2pixHD:finalLayerSingleInputOutput'));
end

% Check if input and output shape are same.
inputShape = val.Inputs.Size{1};
outputShape = val.Outputs.Size{1};

if ~(all(size(inputShape) == size(outputShape)))
    error(message('images:pix2pixHD:finalLayerShapeMismatch'));
end
end