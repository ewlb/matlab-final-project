function net = pix2pixHDGlobalGenerator(InputSize, NameValueArgs)

arguments
    InputSize {mustBeInteger, mustBePositive, iMustBeThreeElementVector}
    NameValueArgs.NumDownSamplingBlocks (1,1) {mustBeInteger, mustBePositive, mustBeNumeric} = 4
    NameValueArgs.NumResidualBlocks (1,1) {mustBeInteger, mustBeNonnegative, mustBeNumeric} = 9
    NameValueArgs.NumFiltersInFirstBlock (1,1) {iValidateNumFilters(NameValueArgs.NumFiltersInFirstBlock)} = 64
    NameValueArgs.NumOutputChannels (1,1) {mustBeInteger, mustBePositive, mustBeNumeric} = 3
    NameValueArgs.FilterSizeInFirstAndLastBlocks = 7
    NameValueArgs.FilterSizeInIntermediateBlocks = 3
    NameValueArgs.ConvolutionPaddingValue = "symmetric-exclude-edge"
    NameValueArgs.UpsampleMethod  = "transposedConv"
    NameValueArgs.ConvolutionWeightsInitializer  = "narrow-normal"
    NameValueArgs.NormalizationLayer = "instance"
    NameValueArgs.ActivationLayer = "relu"
    NameValueArgs.FinalActivationLayer = "tanh"
    NameValueArgs.Dropout (1,1) {mustBeNumeric, mustBeNonnegative, mustBeLessThanOrEqual(NameValueArgs.Dropout,1)} = 0
    NameValueArgs.NamePrefix {mustBeTextScalar}= "GlobalGenerator_"  
end

images.internal.requiresNeuralNetworkToolbox(mfilename);

% Validate and return proper values.
NameValueArgs.FilterSizeInFirstAndLastBlocks = iValidateFilterSize(NameValueArgs.FilterSizeInFirstAndLastBlocks, 'FilterSizeInFirstAndLastBlocks');
NameValueArgs.FilterSizeInIntermediateBlocks = iValidateFilterSize(NameValueArgs.FilterSizeInIntermediateBlocks, 'FilterSizeInIntermediateBlocks');
NameValueArgs.ConvolutionPaddingValue = iValidatePadding(NameValueArgs.ConvolutionPaddingValue, ["replicate", "symmetric-include-edge", "symmetric-exclude-edge"]);
NameValueArgs.UpsampleMethod = iValidateUpsample(NameValueArgs.UpsampleMethod, ["transposedConv", "bilinearResize", "pixelShuffle"]);
NameValueArgs.ConvolutionWeightsInitializer = iValidateWeightInit(NameValueArgs.ConvolutionWeightsInitializer, ["glorot", "he", "narrow-normal"]);
NameValueArgs.NormalizationLayer = iValidateNormalization(NameValueArgs.NormalizationLayer, ["none", "batch", "instance"]);
NameValueArgs.ActivationLayer = iValidateActivation(NameValueArgs.ActivationLayer, ["relu", "leakyRelu", "elu"]);
NameValueArgs.FinalActivationLayer = iValidateFinalActivation(NameValueArgs.FinalActivationLayer, ["tanh", "sigmoid", "softmax", "none"]);
InputSize = iConvertToRowVector(InputSize);

% Create the global generator with NVPs.
lgraph = images.pix2pixHDGenerator.internal.createPix2PixHDGenerator(NameValueArgs, InputSize);

% Convert layergraph to dlnetwork.
net = dlnetwork(lgraph);
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
if ~isa(val,'function_handle')
    val = validatestring(val, options,'','ConvolutionWeightsInitializer');
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

function iValidateNumFilters(val)
validateattributes(val, {'numeric'},{'positive','even'},'','NumFiltersInFirstBlock');
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

function val = iValidateFinalActivation(val, options)
isCharOrStringScalar = ischar(val)||(isscalar(val)&&isstring(val));
isLayerObject = isa(val, "nnet.cnn.layer.Layer");
if isCharOrStringScalar
    val = validatestring(val, options,'','FinalActivationLayer');
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
        iCheckValidLayer(val, 'FinalActivationLayer');
    else
        error(message('images:pix2pixHD:mustBeSingleLayer','FinalActivationLayer'));
    end
else
    error(message('images:pix2pixHD:paramMustBeStringOrLayer','FinalActivationLayer'));
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

function iMustBeThreeElementVector(val)
validateattributes(val,{'numeric'},{'nonempty','vector','numel',3},mfilename,'inputSize');
end

function val = iConvertToRowVector(val)
if iscolumn(val)
    val = val';
end
end

%  Copyright 2020-2023 The MathWorks, Inc.