function discriminatorNet = patchGANDiscriminator(inputSize, params)
% patchGANDiscriminator Create a PatchGAN discriminator network
%
%   net = patchGANDiscriminator(inputSize) constructs a discriminator
%   network given inputSize, a vector that describes the input size in the
%   form [H W C]. If the input to the discriminator is a channel-wise
%   concatenated dlarray, the channel size, C must be the concatenated
%   size. The output, net, is a dlnetwork object.
%
%   net = patchGANDiscriminator(___,Name,Value,___) specifies Name/Value
%   pairs that control aspects of discriminator network construction:
%
%  'NetworkType'                   Specify a string to select the type of
%                                  discriminator network. Set this value to
%                                  'patch' to create a PatchGAN
%                                  discriminator. Set this value to 'pixel'
%                                  to create a 1-by-1 PatchGAN
%                                  discriminator i.e. a pixel
%                                  discriminator. Valid values are 'patch'
%                                  or 'pixel'.
%
%                                  Default: 'patch'
%
%  'NumDownsamplingBlocks'         The number of stages in the
%                                  discriminator. The discriminator network
%                                  downsamples the input image by a factor
%                                  of 2^(NumDownsamplingBlocks). The depth
%                                  of the network along with the parameters
%                                  of the convolutional layers determines
%                                  the patch size of the PatchGAN
%                                  discriminator.  This parameter has an
%                                  effect only when 'NetworkType' is set to
%                                  'patch'. Otherwise, this value is
%                                  ignored.
%
%                                  Default: 3
%
%  'NumFiltersInFirstBlock'        The number of output channels
%                                  for the first discriminator subsection.
%                                  Each of the subsequent discriminator
%                                  subsections double the number of output
%                                  channels.
%
%                                  Default: 64
%
%  'FilterSize'                    Specify the height and width used for
%                                  all convolution layer filters as a
%                                  scalar or vector. When the size is
%                                  a scalar, the same value is used for H
%                                  and W. Typical values are between 1 and
%                                  4. This parameter has an effect only
%                                  when 'NetworkType' is set to 'patch'.
%                                  Otherwise, this value is ignored.
%
%                                  Default: 4
%
%  'ConvolutionPaddingValue'       Value used to pad the input along the
%                                  edges, specified as one of the following
%                                  values: 
%                                  - Scalar value - Pad using the specified
%                                  value. 
%                                  - "symmetric-include-edge" - Pad using
%                                  mirrored layer input, including the edge
%                                  values. 
%                                  - "symmetric-exclude-edge" - Pad using
%                                  mirrored layer input, excluding the edge
%                                  values. 
%                                  - "replicate" - Pad using repeated layer
%                                  input border elements.
%                                      
%                                  This parameter has an effect only when
%                                  'NetworkType' is set to 'patch'.
%                                  Otherwise, this value is ignored.
%
%                                  Default: 0.
%
%  'ConvolutionWeightsInitializer' A string or function specifying the
%                                  weight initialization used in
%                                  convolution layers. Supported strings
%                                  are "glorot", "he", "narrow-normal".
%
%                                  Default: "glorot".
%
%  'ActivationLayer'               A string or layer object specifying the
%                                  desired activation function to use.
%                                  Supported strings are "relu",
%                                  "leakyRelu", "elu" and "none". For
%                                  "leakyRelu", a scale factor of 0.2 is
%                                  used by default.
%
%                                  Default: "leakyRelu"
%
%  'FinalActivationLayer'          A string or layer object specifying the
%                                  desired activation to use after the
%                                  final convolution. Supported strings are
%                                  "none", "sigmoid", "softmax" and "tanh".
%
%                                  Default: "none".
%
%  'NormalizationLayer'            A string or layer object specifying the
%                                  desired normalization to use after each
%                                  convolution. Supported strings are
%                                  "none", "batch" and "instance".
%
%                                  Default: "batch".
%
%  'NamePrefix'                    A name to prefix to each layer in the
%                                  discriminator. Use this to distinguish
%                                  between multiple scales.
%                                  
%                                  Default: ""
%
%
%   Example 1
%   ---------
%   % Create a 70-by-70 PatchGAN discriminator to discriminate RGB images
%   % created by some generator
%   
%   inputSize = [256 256 3];
%   net = patchGANDiscriminator(inputSize, "NamePrefix", "scale_1_");
%
%   Example 2
%   ---------
%   % Create a pixel discriminator i.e. a 1-by-1 PatchGAN discriminator to
%   % discriminate RGB images
%   
%   inputSize = [256 256 3];
%   net = patchGANDiscriminator(inputSize, "NetworkType", "pixel");
% 
%   See also pix2pixHDGlobalGenerator, cycleGANGenerator, unitGenerator,
%            dlnetwork.

%   Copyright 2020 The MathWorks, Inc.

%  References: 
%  ----------- 
%  [1] Isola, Phillip, Jun-Yan Zhu, Tinghui Zhou and Alexei A. Efros.
%      "Image-to-Image Translation with Conditional Adversarial Networks."
%      2017 IEEE Conference on Computer Vision and Pattern Recognition
%      (CVPR): 5967-5976.
%  [2] https://github.com/junyanz/pytorch-CycleGAN-and-pix2pix

% Validate input arguments.
arguments
    inputSize (1,3) {mustBeInteger, mustBeReal, mustBePositive}
    params.NetworkType {mustBeMember(params.NetworkType,...
        ["patch", "pixel"])} = "patch"
    params.NumDownsamplingBlocks (1,1) {mustBeInteger, mustBeReal, mustBePositive} = 3
    params.NumFiltersInFirstBlock (1,1) {iValidateNumFilters(params.NumFiltersInFirstBlock)} = 64
    params.FilterSize = 4
    params.ConvolutionPaddingValue = 0
    params.ConvolutionWeightsInitializer = "narrow-normal"
    params.NormalizationLayer = "batch"
    params.ActivationLayer = "leakyRelu"
    params.FinalActivationLayer = "none"
    params.NamePrefix {mustBeTextScalar} = ""
end

% Check for deep learning toolbox.
images.internal.requiresNeuralNetworkToolbox(mfilename);

% Validate and return proper values.
params.FilterSize = iValidateFilterSize(params.FilterSize, 'FilterSize');
params.ConvolutionPaddingValue = iValidatePaddingValue(params.ConvolutionPaddingValue, ["symmetric-include-edge", "symmetric-exclude-edge", "replicate"]);
params.ConvolutionWeightsInitializer = iValidateWeightInitializer(params.ConvolutionWeightsInitializer, ["glorot", "he", "narrow-normal"]);
params.NormalizationLayer = iValidateNormalization(params.NormalizationLayer, ["none", "batch", "instance"]);
params.ActivationLayer = iValidateActivation(params.ActivationLayer, "ActivationLayer", ["none", "relu", "leakyRelu", "elu"]);
params.FinalActivationLayer = iValidateActivation(params.FinalActivationLayer, "FinalActivationLayer", ["none", "sigmoid", "softmax", "tanh"]);
params.NamePrefix = iValidateNamePrefix(params.NamePrefix, 'NamePrefix');

inputChannels = inputSize(3);
inputSize = inputSize(1:2);
filterSize = double(params.FilterSize);
numFilters = double(params.NumFiltersInFirstBlock);
numDownsamplingBlocks = double(params.NumDownsamplingBlocks);
normalizationLayer = params.NormalizationLayer;
activationLayer = params.ActivationLayer;
finalActivationLayer = params.FinalActivationLayer;
networkType = params.NetworkType;
convolutionWeightsInitializer = params.ConvolutionWeightsInitializer;
convolutionPaddingValue = params.ConvolutionPaddingValue;
namePrefix = params.NamePrefix;

lgraph = layerGraph();
inputLayerName = 'input_top';
lgraph = addLayers(lgraph, imageInputLayer([inputSize inputChannels], 'Normalization', 'none', 'Name', inputLayerName));

layers = images.internal.patchGANDiscriminatorLayers(namePrefix, inputChannels, filterSize, numFilters, numDownsamplingBlocks, convolutionPaddingValue, convolutionWeightsInitializer, activationLayer, normalizationLayer, networkType);
lgraph = addLayers(lgraph,layers);

currentLayerName = inputLayerName;
nextLayerName = lgraph.Layers(2).Name;
lgraph = connectLayers(lgraph, currentLayerName, nextLayerName);

if ~strcmpi(finalActivationLayer, "none")
    currentLayerName = lgraph.Layers(end).Name;
    nextLayerName = sprintf('%s%s', namePrefix, 'act_final');
    finalActivationLayer.Name = nextLayerName;
    lgraph = addLayers(lgraph, finalActivationLayer);    
    lgraph = connectLayers(lgraph, currentLayerName, nextLayerName);
end

discriminatorNet = dlnetwork(lgraph);

end

% Input argument validation functions.
function val = iValidatePaddingValue(val, options)
validateattributes(val, {'char','string', 'numeric'},{},mfilename,'ConvolutionPaddingValue');
if ~isa(val,'numeric')
    val = validatestring(val, options, mfilename,'ConvolutionPaddingValue');
else
    validateattributes(val, {'numeric'},{'scalar', 'real', 'nonempty', 'finite', 'nonnegative'},mfilename,'ConvolutionPaddingValue');
    val = uint64(val);
end
end

function val = iValidateWeightInitializer(val, options)
validateattributes(val, {'char','string','function_handle'},{},mfilename,'ConvolutionWeightsInitializer');
val = validatestring(val, options,mfilename,'ConvolutionWeightsInitializer');
end

function val = iValidateNamePrefix(val, paramName)
validateattributes(val, {'char','string'},{},mfilename,paramName);
end

function val = iValidateFilterSize(val, name)
validateattributes(val, {'numeric'}, {'vector', 'real', 'nonempty', 'finite', 'positive'},mfilename,name);
if numel(val) > 2
    error(message('images:patchGANDiscriminator:paramMustBeScalarOrPair',name));
end

val = double(val);

if isscalar(val)
    val = [val, val];
end
end

function iValidateNumFilters(val)
validateattributes(val, {'numeric'},{'real', 'positive', 'nonempty', 'finite', 'even'}, mfilename,'NumFiltersInFirstBlock');
end

function val = iValidateNormalization(val, options)

paramName = 'NormalizationLayer';
if isa(val, 'char') || isa(val, 'string')
    val = validatestring(val, options, mfilename,paramName);
    switch val
        case 'instance'
            val = groupNormalizationLayer('channel-wise');
        case 'batch'
            val = batchNormalizationLayer();
    end
elseif isa(val, 'nnet.cnn.layer.Layer')
    iValidateLayer(val, paramName)
else
    error(message('images:patchGANDiscriminator:paramMustBeStringOrLayer',paramName));
end

end

function val = iValidateActivation(val, paramName, options)
if isa(val, 'char') || isa(val, 'string')
    val = validatestring(val, options, mfilename, paramName);
    switch val
        case 'relu'
            val = reluLayer();
        case 'elu'
            val = eluLayer();
        case 'leakyRelu'
            val = leakyReluLayer(0.2);
        case 'sigmoid'
            val = sigmoidLayer();
        case 'tanh'
            val = tanhLayer();
        case 'softmax'
            val = softmaxLayer();
    end
elseif isa(val, 'nnet.cnn.layer.Layer')
    iValidateLayer(val, paramName)
else
    error(message('images:patchGANDiscriminator:paramMustBeStringOrLayer','ActivationLayer'));
end

end

function iCheckValidLayer(val, paramName)
% Check for num outputs.
if val.NumOutputs ~= 1
    error(message('images:patchGANDiscriminator:layerSingleOutput',paramName));
end
end

function iValidateLayer(val, paramName)

if numel(val) == 1
    iCheckValidLayer(val, paramName);
else
    error(message('images:patchGANDiscriminator:mustBeSingleLayer',paramName));
end
end
