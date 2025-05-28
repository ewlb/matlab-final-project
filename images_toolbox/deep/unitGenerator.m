function gen = unitGenerator(inputSizeSource, NameValueArgs)

arguments
    inputSizeSource {mustBeInteger, mustBePositive, imustBeThreeElementVector}
    NameValueArgs.NumDownsamplingBlocks (1,1) {mustBeInteger, mustBePositive, mustBeNumeric} = 2
    NameValueArgs.NumResidualBlocks (1,1) {mustBeInteger, mustBePositive, mustBeNumeric} = 5
    NameValueArgs.NumSharedBlocks (1,1) {mustBeInteger, mustBePositive, mustBeNumeric} = 2
    NameValueArgs.NumTargetInputChannels (1,1) {mustBeInteger, mustBePositive, mustBeNumeric} = inputSizeSource(3)
    NameValueArgs.NumFiltersInFirstBlock (1,1) {iValidateNumFilters(NameValueArgs.NumFiltersInFirstBlock)} = 64
    NameValueArgs.FilterSizeInFirstAndLastBlocks = 7
    NameValueArgs.FilterSizeInIntermediateBlocks = 3
    NameValueArgs.ConvolutionPaddingValue = 'symmetric-exclude-edge'
    NameValueArgs.ConvolutionWeightsInitializer = 'he'
    NameValueArgs.UpsampleMethod = 'transposedConv'
    NameValueArgs.NormalizationLayer = 'instance'
    NameValueArgs.ActivationLayer = 'relu'
    NameValueArgs.SourceFinalActivationLayer = 'tanh'
    NameValueArgs.TargetFinalActivationLayer = 'tanh'
end

images.internal.requiresNeuralNetworkToolbox(mfilename);

% Validate and return proper values.
numDownsamplingBlocks = iValidateNumDownsamplingBlocks(NameValueArgs.NumDownsamplingBlocks, inputSizeSource);
numResidualBlocks = iValidateNumResidualBlocks(NameValueArgs.NumResidualBlocks);
numSharedBlocks = iValidateNumSharedBlocks(NameValueArgs.NumSharedBlocks, NameValueArgs.NumResidualBlocks);
numTargetInputChannels = NameValueArgs.NumTargetInputChannels;
numFiltersInFirstBlock = NameValueArgs.NumFiltersInFirstBlock;
filterSizeInFirstAndLastBlocks = iValidateFilterSize(NameValueArgs.FilterSizeInFirstAndLastBlocks, 'FilterSizeInFirstAndLastBlocks');
filterSizeInIntermediateBlocks = iValidateFilterSize(NameValueArgs.FilterSizeInIntermediateBlocks, 'FilterSizeInIntermediateBlocks');
convolutionPaddingValue = iValidatePadding(NameValueArgs.ConvolutionPaddingValue, ["replicate", "symmetric-include-edge", "symmetric-exclude-edge"]);
upsampleMethod = iValidateUpsampleMethod(NameValueArgs.UpsampleMethod, ["transposedConv", "bilinearResize", "pixelShuffle"]);
normalizationLayer = iValidateNormalization(NameValueArgs.NormalizationLayer, ["none", "batch", "instance"]);
activationLayer = iValidateActivation(NameValueArgs.ActivationLayer, ["relu", "leakyRelu", "elu"]);
sourceFinalActivationLayer = iValidateFinalActivation(NameValueArgs.SourceFinalActivationLayer, ["tanh", "sigmoid", "softmax", "none"], 'SourceFinalActivationLayer');
targetFinalActivationLayer = iValidateFinalActivation(NameValueArgs.TargetFinalActivationLayer, ["tanh", "sigmoid", "softmax", "none"], 'TargetFinalActivationLayer');
convolutionWeightsInitializer = iValidateWeightInit(NameValueArgs.ConvolutionWeightsInitializer, ["glorot", "he", "narrow-normal"]);

% Create an UNIT generator dlnetwork.
gen = iCreateUnitGenerator(numDownsamplingBlocks, numResidualBlocks, numSharedBlocks, numTargetInputChannels, ...
    numFiltersInFirstBlock, filterSizeInFirstAndLastBlocks, filterSizeInIntermediateBlocks, convolutionPaddingValue, ...
    upsampleMethod, normalizationLayer, activationLayer, sourceFinalActivationLayer, targetFinalActivationLayer, ...
    convolutionWeightsInitializer, inputSizeSource);
end

% Internal function to create UNIT generator dlnetwork.
function gen = iCreateUnitGenerator(numDownsamplingBlocks, numResidualBlocks, numSharedBlocks, numTargetInputChannels, ...
    numFiltersInFirstBlock, filterSizeInFirstAndLastBlocks, filterSizeInIntermediateBlocks, convPaddingValue, ...
    upsampleMethod, normalization, activation, sourceFinalActivation, targetFinalActivation, convolutionWeightsInitializer, inputSizeSource)
% Number of residual blocks present in encoderSource, encoderTarget, decoderSource and decoderTarget blocks.
numIndResBlocks = numResidualBlocks - numSharedBlocks;

% Input size for encoderShared, decoderShared, decoderSource and decoderTarget blocks.
inputSize = [2*(ceil(inputSizeSource(1)/2^numDownsamplingBlocks)) ceil((inputSizeSource(2)/2^numDownsamplingBlocks)) ceil((2^numDownsamplingBlocks)*numFiltersInFirstBlock)];

% Input size for encoderTarget block.
inputSizeTarget = [inputSizeSource(1) inputSizeSource(2) numTargetInputChannels];

% Number of output channels for source and target domain.
outChannelSource = inputSizeSource(3);
outChannelTarget = numTargetInputChannels;

% Create different blocks of UNIT generator.
encoderSourceBlock = images.unitGenerator.internal.encoderLayer(inputSizeSource, ...
    numDownsamplingBlocks, numIndResBlocks, numFiltersInFirstBlock, filterSizeInFirstAndLastBlocks, ...
    filterSizeInIntermediateBlocks, convolutionWeightsInitializer, convPaddingValue, ...
    normalization, activation, 'encoderSourceBlock');
            
encoderTargetBlock = images.unitGenerator.internal.encoderLayer(inputSizeTarget, ...
    numDownsamplingBlocks, numIndResBlocks, numFiltersInFirstBlock, filterSizeInFirstAndLastBlocks, ...
    filterSizeInIntermediateBlocks, convolutionWeightsInitializer, convPaddingValue, ...
    normalization, activation, 'encoderTargetBlock');  
                      
encoderSharedBlock = images.unitGenerator.internal.encoderSharedLayer(inputSize, ...
    numSharedBlocks, (2^numDownsamplingBlocks)*numFiltersInFirstBlock, ...
    filterSizeInIntermediateBlocks, convolutionWeightsInitializer, convPaddingValue, ...
    normalization, activation, 'encoderSharedBlock');

decoderSharedBlock = images.unitGenerator.internal.decoderSharedLayer(inputSize, ...
    numSharedBlocks, (2^numDownsamplingBlocks)*numFiltersInFirstBlock, ...
    filterSizeInIntermediateBlocks, convolutionWeightsInitializer, convPaddingValue, ...
    normalization, activation, 'decoderSharedBlock');

decoderSourceBlock = images.unitGenerator.internal.decoderLayer(inputSize, ...
    numDownsamplingBlocks, numIndResBlocks, outChannelSource, (2^numDownsamplingBlocks)*numFiltersInFirstBlock, ...
    filterSizeInFirstAndLastBlocks, filterSizeInIntermediateBlocks, convolutionWeightsInitializer, ...
    convPaddingValue, upsampleMethod, normalization, activation, sourceFinalActivation, 'decoderSourceBlock');
      
decoderTargetBlock = images.unitGenerator.internal.decoderLayer(inputSize, ...
    numDownsamplingBlocks, numIndResBlocks, outChannelTarget, (2^numDownsamplingBlocks)*numFiltersInFirstBlock, ...
    filterSizeInFirstAndLastBlocks, filterSizeInIntermediateBlocks, convolutionWeightsInitializer, ...
    convPaddingValue, upsampleMethod, normalization, activation, targetFinalActivation, 'decoderTargetBlock');

% Integrate different blocks of UNIT generator. 
inputSource = imageInputLayer(inputSizeSource,"Name","inputSource","Normalization","none");
inputTarget = imageInputLayer(inputSizeTarget,"Name","inputTarget","Normalization","none");
concat = concatenationLayer(1, 2, "Name", "concat");
lgraph = layerGraph();
lgraph = addLayers(lgraph, inputSource);
lgraph = addLayers(lgraph, inputTarget);
lgraph = addLayers(lgraph, encoderSourceBlock);
lgraph = addLayers(lgraph, encoderTargetBlock);
lgraph = addLayers(lgraph, concat);
lgraph = connectLayers(lgraph, "inputSource", "encoderSourceBlock");
lgraph = connectLayers(lgraph, "inputTarget", "encoderTargetBlock");
lgraph = connectLayers(lgraph, "encoderSourceBlock", "concat/in1");
lgraph = connectLayers(lgraph, "encoderTargetBlock", "concat/in2");
lgraph = addLayers(lgraph, encoderSharedBlock);
lgraph = addLayers(lgraph, decoderSharedBlock);
lgraph = addLayers(lgraph, decoderSourceBlock);
lgraph = addLayers(lgraph, decoderTargetBlock);
lgraph = connectLayers(lgraph, "concat", "encoderSharedBlock");
lgraph = connectLayers(lgraph, "encoderSharedBlock", "decoderSharedBlock");
lgraph = connectLayers(lgraph, "decoderSharedBlock", "decoderSourceBlock");
lgraph = connectLayers(lgraph, "decoderSharedBlock", "decoderTargetBlock");

% Create dlnetwork object for UNIT generator.
gen = dlnetwork(lgraph);
end

% Input argument validation functions.
function val = iValidateNumDownsamplingBlocks(val, sz)
validateattributes(val, {'numeric'}, {'scalar', 'integer', 'positive', '>=' , 1},'','');
if rem(sz(1),2^val) ~= 0 || rem(sz(2),2^val) ~= 0
    error(message('images:unitGenerator:mustBeEvenlyDivisible'));
end
end

function val = iValidateNumResidualBlocks(val)
validateattributes(val, {'numeric'}, {'scalar', 'integer', 'positive', '>=' , 1},'','');
end

function val = iValidateNumSharedBlocks(val, ref)
validateattributes(val, {'numeric'}, {'scalar', 'integer', 'positive', '>=' , 1},'','');
if val > ref
    error(message('images:unitGenerator:mustBeLessThanNumResBlocks'));
end
end

function val = iValidatePadding(val, options)
validateattributes(val, {'char','string', 'numeric'},{},'','ConvolutionPaddingValue');
if ~isa(val,'numeric')
    val = validatestring(val, options,'','ConvolutionPaddingValue');
else
    validateattributes(val, {'numeric'},{'scalar', 'finite', 'real'},'','ConvolutionPaddingValue');
end
end

function val = iValidateUpsampleMethod(val, options)
validateattributes(val, {'char','string'},{},'','UpsampleMethod');
val = validatestring(val, options,'','UpsampleMethod');
end

function val = iValidateWeightInit(val, options)
validateattributes(val, {'char','string','function_handle'},{},'','ConvolutionWeightInitializer');
if ~isa(val,'function_handle')
    val = validatestring(val, options,'','ConvolutionWeightInitializer');
end
end

function val = iValidateFilterSize(val, name)
validateattributes(val, {'numeric'}, {'vector', 'nonempty', 'finite', 'real', 'positive', 'integer', 'odd'},'',name);
if numel(val) > 2
    error(message('images:unitGenerator:paramMustBeScalarOrPair',name));
end
if isscalar(val)
    val = [val, val];
end
end

function iValidateNumFilters(val)
validateattributes(val, {'numeric'},{'finite', 'real', 'positive', 'integer', 'even'},'','NumFiltersInFirstBlock');
end

function val = iValidateNormalization(val, options)
isCharOrStringScalar = ischar(val)||(isscalar(val)&&isstring(val));
isLayerObject = isa(val, "nnet.cnn.layer.Layer");
if isCharOrStringScalar
    val = validatestring(val, options,'','NormalizationLayer');
    switch val
        case 'instance'
            val = instanceNormalizationLayer('ScaleLearnRateFactor', 0, 'OffsetLearnRateFactor', 0);
        case 'batch'
            val = batchNormalizationLayer();
        case 'none'
            val = [];
    end
elseif isLayerObject
    if numel(val) == 1
        iCheckValidLayer(val, 'NormalizationLayer');
    else
        error(message('images:unitGenerator:mustBeSingleLayer','NormalizationLayer'));
    end
else
    error(message('images:unitGenerator:paramMustBeStringOrLayer','NormalizationLayer'));
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
        error(message('images:unitGenerator:mustBeSingleLayer','ActivationLayer'));
    end
else
    error(message('images:unitGenerator:paramMustBeStringOrLayer','ActivationLayer'));
end
end

function val = iValidateFinalActivation(val, options, name)
isCharOrStringScalar = ischar(val)||(isscalar(val)&&isstring(val));
isLayerObject = isa(val, "nnet.cnn.layer.Layer");
if isCharOrStringScalar
    val = validatestring(val, options,'',name);
    switch val
        case 'tanh'
            val = tanhLayer();
        case 'sigmoid'
            val = sigmoidLayer();
        case 'softmax'
            val = softmaxLayer();
        case 'none'
            val = [];
    end
elseif isLayerObject
    if numel(val) == 1
        iCheckValidLayer(val, name);
    else
        error(message('images:unitGenerator:mustBeSingleLayer', name));
    end
else
    error(message('images:unitGenerator:paramMustBeStringOrLayer', name));
end
end

function iCheckValidLayer(val, name)
% Check for number of inputs and outputs.
if ~(val.NumOutputs == 1 && val.NumInputs == 1)
    error(message('images:unitGenerator:layerSingleInputOutput',name));
end
end

function imustBeThreeElementVector(val)
validateattributes(val,{'numeric'},{'nonempty','vector','numel',3},mfilename,'inputSize');
end

%  Copyright 2020-2023 The MathWorks, Inc.