function generator = cycleGANGenerator(varargin)
% cycleGANGenerator Create a CycleGAN generator network for image-to-image translation
%
%  net = cycleGANGenerator(inputSize) constructs a CycleGAN generator
%  network from the given inputSize. Input size must be a 3 element vector
%  [H W C], where H is the height, W is the width, and C is the number of
%  input channels. The output, net is a dlnetwork object.
%
%  net = cycleGANGenerator(___,Name,Value) specifies Name/Value pairs that
%  control aspects of generator network construction:
%
%  'NumDownsamplingBlocks'              The depth determines the number of
%                                       downsampling operations in the
%                                       encoder module of the generator.
%                                       The encoder module downsamples the
%                                       input by a factor of
%                                       2^NumDownsamplingBlocks.
%
%                                       Default: 2
%
%  'NumFiltersInFirstBlock'             Specify the number of filters in
%                                       the first convolution layer.
%                                       Subsequent encoder modules double
%                                       the number of output channels. The
%                                       value must be even.
%
%                                       Default: 64
%
%  'NumOutputChannels'                  Specify the number of channels
%                                       output by the network as a scalar.
%                                       If you set it to "auto", the number
%                                       of output channels is the same as
%                                       the number of input channels.
%
%                                       Default: "auto"
%
%  'FilterSizeInFirstAndLastBlocks'     Specify the height and width used
%                                       in the first and last convolution
%                                       layer filters as a scalar or
%                                       vector. When the size is a scalar,
%                                       the same value is used for H and W.
%                                       The value must be odd.
%                                       
%                                       Default: 7
%
%  'FilterSizeInIntermediateBlocks'     Specify the height and width used
%                                       in all the convolution layer
%                                       filters except the first and last
%                                       convolution layers as a scalar or
%                                       vector. When the size is a scalar,
%                                       the same value is used for H and W.
%                                       Typical values are between 3 and 7.
%                                       The value must be odd.
%
%                                       Default: 3
%
%  'NumResidualBlocks'                  A positive scalar integer value
%                                       that denotes the number of residual
%                                       blocks in the generator
%                                       architecture. Each residual block
%                                       is a set of convolution,
%                                       normalization and non-linear layers
%                                       with skip connections between every
%                                       block. Typically this value is set
%                                       to 6 for images of size 128-by-128
%                                       or 9 for images of size 256-by-256
%                                       or larger.
%
%                                       Default: 9
%
%  'ConvolutionPaddingValue'            Value used to pad the input along
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
%                                       "bilinearResize" and
%                                       "pixelShuffle".
%
%                                       Default: "transposedConv".
%
%  'ConvolutionWeightsInitializer'      A string or function specifying the
%                                       weight initialization used in
%                                       convolution layers. Supported
%                                       strings are "glorot", "he" or
%                                       "narrow-normal".
%
%                                       Default: "narrow-normal"
%
%  'ActivationLayer'                    A string or layer object specifying
%                                       the desired activation functions to
%                                       use. Supported strings are "relu",
%                                       "leakyRelu", "elu". For "leakyRelu", 
%                                       a scale factor of 0.2 is used by
%                                       default.
%
%                                       Default: "relu"
%
%  'FinalActivationLayer'               A string or layer object specifying
%                                       the desired activation to use after
%                                       the final convolution. Supported
%                                       strings are "none", "sigmoid",
%                                       "softmax" and "tanh".
%
%                                       Default: "tanh"
%
%  'NormalizationLayer'                 A string or layer object specifying
%                                       the desired normalization
%                                       operations to use after each
%                                       convolution. Supported strings are
%                                       "none", "batch", "instance".
% 
%                                       Default: "instance"
%
%  'Dropout'                            A scalar value that determines the
%                                       drop out probability. Drop out
%                                       layers are not used when zero is
%                                       specified.
%
%                                       Default: 0
%
%
%  'NamePrefix'                         A name to prefix to each layer in
%                                       the generator.
%                                  
%                                       Default: ""
%
%  Example 1
%  ---------
%  % Create a CycleGAN generator to generate RGB images of size 256-by-256
%   
%  inputSize = [256 256 3];
%  net = cycleGANGenerator(inputSize, "NamePrefix", "cycleGAN");
%
%  Example 2
%  ---------
%  % Create a CycleGAN generator with 6 residual blocks to generate RGB 
%  % images of size 128-by-128
%   
%  inputSize = [128 128 3];
%  net = cycleGANGenerator(inputSize, "NumResidualBlocks", 6);
%
%  See also patchGANDiscriminator, pix2pixHDGlobalGenerator, dlnetwork.

%  Copyright 2020-2021 The MathWorks, Inc.

%  References: 
%  ----------- 
%  [1] Zhu, J., Park, T., Isola, P., & Efros, A.A. "Unpaired
%      Image-to-Image Translation Using Cycle-Consistent Adversarial
%      Networks.", 2017 IEEE International Conference on Computer Vision
%      (ICCV), 2242-2251.
%  [2] https://github.com/junyanz/pytorch-CycleGAN-and-pix2pix

images.internal.requiresNeuralNetworkToolbox(mfilename);

% Parse a subset of Name-Value pairs
params = iParseInputs(varargin{:});

inputSize = double(params.ImageSize);

% Set NumOutputChannels to the same value as input channels
if strcmpi(params.NumOutputChannels,"auto")
    params.NumOutputChannels = inputSize(3);
end

generator = pix2pixHDGlobalGenerator(inputSize, varargin{2:end}, ...
    'NumDownSamplingBlocks', params.NumDownsamplingBlocks,...
    'NumOutputChannels', params.NumOutputChannels,...
    'NamePrefix', params.NamePrefix);

end

function params = iParseInputs(varargin)

parser = inputParser();
parser.KeepUnmatched = true;
parser.addRequired('ImageSize',@iCheckImageSize);
parser.addParameter('NumDownsamplingBlocks',2,@iValidateNumDownsamplingBlocks);
parser.addParameter('NumOutputChannels',"auto");
parser.addParameter('NamePrefix',"",@iValidateNamePrefix);

parser.parse(varargin{:});
params = parser.Results;

params.NumOutputChannels = iValidateNumOutputChannels(params.NumOutputChannels);

end

function iValidateNumDownsamplingBlocks(val)
validateattributes(val, {'numeric'},{'real', 'positive', 'nonempty', 'finite'}, mfilename,'NumDownsamplingBlocks');
end

function val = iValidateNumOutputChannels(val)
validateattributes(val, {'char', 'string', 'numeric'}, {},'','NumOutputChannels');
if ~isa(val,'numeric')
    val = validatestring(val, {'auto'},'','ConvolutionPaddingValue');
else
    validateattributes(val, {'numeric'},{'real', 'positive', 'nonempty', 'finite'}, mfilename,'NumOutputChannels');
end
end

function iValidateNamePrefix(val)
validateattributes(val, {'char','string'},{},mfilename,'NamePrefix');
end

function iCheckImageSize(val)
validateattributes(val,{'numeric'},{'real', 'positive', 'integer', 'nonempty','vector','numel',3},mfilename,'inputSize');
end
