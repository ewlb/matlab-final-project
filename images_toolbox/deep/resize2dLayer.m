function layer = resize2dLayer(NameValueArgs)
% resize2dLayer   2-D resize layer.
% 
%   layer = resize2dLayer('Scale', scale) creates a layer that resizes the
%   input by a scale factor. Scale must be nonzero positive real value.
%   Scale can be a scalar, in which case the width and height of input will
%   be scaled by the same factor, or it can be a two-element row vector
%   containing the scale factors for the row and column dimensions,
%   respectively. Scale must not be specified when OutputSize or 
%   EnableReferenceInput is specified.
% 
%   layer = resize2dLayer('OutputSize', outputsize) creates a layer that
%   resizes the input to the given output size. OutputSize is a two-element
%   row vector,[MROWS NCOLS], specifying the output size. MROWS and NCOLS
%   must be positive integers. One element may be NaN, in which case the
%   value is computed automatically to preserve the aspect ratio of the
%   input. OutputSize must not be specified when Scale or 
%   EnableReferenceInput is specified.
%
%   layer = resize2dLayer('EnableReferenceInput', true) creates a layer 
%   that resizes the input to the size determined by using the second input 
%   feature map connected to this layer. EnableReferenceInput is a boolean 
%   value. When set to true adds an additional input to connect the 
%   reference layer. EnableReferenceInput must not be specified when Scale 
%   or OutputSize is specified.
% 
%   layer = resize2dLayer(__, 'PARAM1', VAL1, 'PARAM2', VAL2, ...)
%   specifies optional parameter name/value pairs for creating the layer:
% 
%       'Method'                  - A string that specifies the
%                                   interpolation method to be used for
%                                   resizing the input and takes any one of
%                                   these values:
%                                    'nearest'  - Nearest neighbor
%                                                 interpolation
%                                    'bilinear' - Bilinear interpolation
%
%                                   Default : 'nearest'
% 
%       'GeometricTransformMode'  - A string or character array that
%                                   specifies how points in output space
%                                   map to points in input space. Supported
%                                   options are 'asymmetric', and
%                                   'half-pixel'.
%                                       
%                                   Default : 'half-pixel'
% 
%       'NearestRoundingMode'     - A string or character array that 
%                                   specifies the rounding mode used to
%                                   determine the nearest sample when
%                                   'Method' is 'nearest'. Options are
%                                   'onnx-10', 'floor', and 'round'. The
%                                   'round' option leads to the same
%                                   behavior as the MATLAB round function.
%                                   The 'floor' option uses the floor
%                                   function to determine nearest query
%                                   point indices. The 'onnx-10' option
%                                   reproduces the behavior from the Resize
%                                   operator in ONNX opset 10.
%
%                                   Default : 'round'
% 
%       'Name'                    - A string or character array that
%                                   specifies the name for the layer.
%
%                                   Default : ''
%
%   A resize 2d layer has the following inputs:
%       'in'  - Input feature map to resize.
%       'ref' - An optional reference feature map whose first and second 
%               dimension, [H W], are used to determine the first 
%               and second dimension of the resized output. This is only 
%               applicable when EnableReferenceInput is set to true. 
% 
%   Example 1: 
%       % Create a resize 2d layer with scale factor of 2. 
% 
%       layer = resize2dLayer('Scale', 2); 
% 
%   Example 2: 
%       % Create a resize 2d layer with output size of [224 224]. 
% 
%       layer = resize2dLayer('OutputSize', [224 224]); 
% 
%   Example 3: 
%       % Create a resize 2d layer with scale factor of 0.5, and
%       % interpolation method set to 'bilinear'.
% 
%       layer = resize2dLayer('Scale', 0.5, 'Method', 'bilinear');
%
%   Example 4:
%    % Create a resize 2d layer with reference port and connect both of its 
%    % inputs using a layerGraph object.
%
%    layers = [
%        imageInputLayer([32 32 3], 'Name', 'image')
%        resize2dLayer('EnableReferenceInput', true,'Name','resize')
%        ]
% 
%    % Create a layerGraph. The first input of resize2dLayer is automatically
%    % connected to the first output of the image input layer.
%    lgraph = layerGraph(layers)
% 
%    % Connect the second input to the image layer output.
%    lgraph = connectLayers(lgraph, 'image', 'resize/ref')
% 
%   See also nnet.cnn.layer.Resize2DLayer, resize3dLayer, dlresize,
%   transposedConv2dLayer, averagePooling2dLayer.
%
%   <a href="matlab:helpview('deeplearning','list_of_layers')">List of Deep Learning Layers</a>

%   Copyright 2020 The MathWorks, Inc.

% Parse and Validate the input arguments.
arguments
 NameValueArgs.Scale {iAssertValidScale(NameValueArgs.Scale)}
 NameValueArgs.OutputSize {iAssertValidOutputSize(NameValueArgs.OutputSize)}
 NameValueArgs.GeometricTransformMode string = 'half-pixel'
 NameValueArgs.Method string = 'nearest'
 NameValueArgs.NearestRoundingMode string = 'round'
 NameValueArgs.Name {iAssertValidLayerName(NameValueArgs.Name)} = ''
 NameValueArgs.EnableReferenceInput {iAssertValidEnableReferenceInput(NameValueArgs.EnableReferenceInput)} = false
end

validMode.isScaleSpecified = isfield(NameValueArgs,'Scale');
validMode.isOutputSizeSpecified = isfield(NameValueArgs,'OutputSize');
validMode.isReferenceInputSpecified = NameValueArgs.EnableReferenceInput;

valid = iValidateSpecifedMode(validMode);

if valid
    % If scale or output size not provided set as empty.
    if ~validMode.isScaleSpecified
        NameValueArgs.Scale = [];
    end
    if ~validMode.isOutputSizeSpecified
        NameValueArgs.OutputSize = [];
    end

    % Convert the name value arguments to canonical form.
    NameValueArgs = iConvertToCanonicalForm(NameValueArgs);

    % Check for deep learning toolbox.
    images.internal.requiresNeuralNetworkToolbox(mfilename);

    % Create the resize 2d layer based on given parameters.
    layer = nnet.cnn.layer.Resize2DLayer(NameValueArgs.Name, NameValueArgs.Scale,...
        NameValueArgs.OutputSize, NameValueArgs.EnableReferenceInput, NameValueArgs.Method,...
        NameValueArgs.GeometricTransformMode,...
        NameValueArgs.NearestRoundingMode);
else
    error(message('images:resizeLayer:mustSpecifyEitherScaleOrOutputSizeOrEnableReferenceInput'));
end
end

function valid = iValidateSpecifedMode(validMode)
isScaleSpecified = validMode.isScaleSpecified;
isOutputSizeSpecified = validMode.isOutputSizeSpecified;
isEnableReferenceInputSpecified = validMode.isReferenceInputSpecified;

if (isScaleSpecified && isEnableReferenceInputSpecified) || ...
        (isOutputSizeSpecified && isEnableReferenceInputSpecified) ...
        || (isScaleSpecified && isOutputSizeSpecified) || ...
        (isScaleSpecified && isEnableReferenceInputSpecified ...
        && isOutputSizeSpecified) || (~isScaleSpecified && ...
        ~isEnableReferenceInputSpecified && ~isOutputSizeSpecified)
    valid = false;
else 
    valid = true;
end
end

function args = iConvertToCanonicalForm(params)
args = struct;

% Make sure integral values are converted to double.
args.Scale = double(gather(iMakeIntoRowVectorOfTwo(params.Scale)));
args.OutputSize = double(gather(params.OutputSize));
args.EnableReferenceInput = params.EnableReferenceInput;
args.Method = params.Method;
args.GeometricTransformMode = params.GeometricTransformMode;
args.NearestRoundingMode = params.NearestRoundingMode;

% Make sure strings get converted to char vectors.
args.Name = char(params.Name);
end

function iAssertValidScale(value)
validateattributes(value, {'numeric'}, ...
    {'positive', 'real', 'nonempty', 'nonnan', 'finite'},'','Scale');
iAssertScalarOrRowVectorOfTwo(value,'Scale');
end

function iAssertValidOutputSize(value)
validateattributes(value, {'numeric'},{},'','OutputSize');
iAssertRowVectorOfTwo(value,'OutputSize');
iAssertValidNaNCount(value);
iAssertIntegerValues(value);
end

function value = iAssertValidEnableReferenceInput(value)
validateattributes(value, {'logical'}, ...
    {'nonsparse', 'scalar', 'nonempty'},'','EnableReferenceInput');
end

function iAssertScalarOrRowVectorOfTwo(value,name)
if ~(isscalar(value) || iIsRowVectorOfTwo(value))
    error(message('images:resizeLayer:paramMustBeScalarOrPair',name));
end
end

function iAssertRowVectorOfTwo(value,name)
if ~iIsRowVectorOfTwo(value)
    error(message('images:resizeLayer:paramMustBePair',name));
end
end

function out = iMakeIntoRowVectorOfTwo(in)
if iIsRowVectorOfTwo(in) || isempty(in)
    out = in;
else
    out = repelem(in, 2);
end
end

function iAssertValidLayerName(value)
isCharRowVectorOrEmtpy = ischar(value) && (isrow(value) || isempty(value));
isScalarStringNotMissing = (isstring(value) && isscalar(value) && ~ismissing(value));
if ~(isCharRowVectorOrEmtpy || isScalarStringNotMissing)
    error(message('images:resizeLayer:nameParameterIsInvalid'));
end
end

function tf = iIsRowVectorOfTwo(x)
tf = isrow(x) && numel(x)==2;
end

function iAssertValidNaNCount(value)
if sum(isnan(value)) > 1
    error(message('images:resizeLayer:invalidNaNOutputSizeSyntax',1));
end
end

function iAssertIntegerValues(value)
value = value(~isnan(value));
validateattributes(value, {'numeric'}, ...
    {'positive', 'integer', 'row', 'finite'},'','OutputSize');
end