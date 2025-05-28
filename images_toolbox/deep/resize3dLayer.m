function layer = resize3dLayer(NameValueArgs)
% resize3dLayer   3-D resize layer.
% 
%   layer = resize3dLayer('Scale', scale) creates a layer that resizes the
%   input by a scale factor. Scale must be nonzero positive real value.
%   Scale can be a scalar, in which case the same value is used for all
%   three dimensions, or it can be a three-element row vector containing
%   the scale factors for the row, column, and plane dimensions,
%   respectively. Scale must not be specified when OutputSize or 
%   EnableReferenceInput is specified.
% 
%   layer = resize3dLayer('OutputSize', outputsize) creates a layer that
%   resizes the input to the output size. OutputSize is a three-element row
%   vector,[NUMROWS NUMCOLS NUMPLANES], specifying the output size.
%   NUMROWS, NUMCOLS, and NUMPLANES must be positive integers. Two elements
%   may be NaN, in which case the values are computed automatically to
%   preserve the aspect ratio of the input. OutputSize must not be 
%   specified when Scale or EnableReferenceInput is specified.
%
%   layer = resize3dLayer('EnableReferenceInput',true) creates a layer that
%   resizes the input to the size determined by using the second input 
%   feature map connected to this layer. EnableReferenceInput is a boolean 
%   value. When set to true adds an additional input to connect the 
%   reference layer. EnableReferenceInput must not be specified when Scale 
%   or OutputSize is specified.
% 
%   layer = resize3dLayer(__, 'PARAM1', VAL1, 'PARAM2', VAL2, ...)
%   specifies optional parameter name/value pairs for creating the layer:
% 
%       'Method'                  - A string that specifies the
%                                   interpolation method to be used for
%                                   resizing the input and takes any one of
%                                   these values:
%                                    'nearest'   - Nearest neighbor
%                                                  interpolation
%                                    'trilinear' - Trilinear interpolation
%
%                                   Default : 'nearest'
% 
%       'GeometricTransformMode'  - A string or character array that
%                                   specifies how points in output space
%                                   map to points in input space. Supported
%                                   options are 'asymmetric', and
%                                   'half-pixel'. The default is
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
%   A resize 3d layer has the following inputs:
%       'in'  - Input feature map to resize.
%       'ref' - An optional Reference feature map whose first and second 
%               dimension, [H W D], are used to determine the first, 
%               second and third dimension of the resized output. This is only 
%               applicable when EnableReferenceInput is set to true.
% 
%   Example 1:
%       % Create a resize 3d layer with scale factor of 2.
% 
%       layer = resize3dLayer('Scale', 2);
% 
%   Example 2:
%       % Create a resize 3d layer with output size of [224 224 224].
% 
%       layer = resize3dLayer('OutputSize', [224 224 224]);
% 
%   Example 3:
%       % Create a resize 3d layer with scale factor of 0.5, and
%       % interpolation method set to 'trilinear'.
% 
%       layer = resize3dLayer('Scale', 0.5, 'Method', 'trilinear');
%
%   Example 4:
%    % Create a resize 3d layer with reference port and connect both of its 
%    % inputs using a layerGraph object.
%
%    layers = [
%        image3dInputLayer([32 32 32 3], 'Name', 'image')
%        resize3dLayer('EnableReferenceInput', true,'Name','resize')
%        ]
% 
%    % Create a layerGraph. The first input of resize3dLayer is automatically
%    % connected to the first output of the image input layer.
%    lgraph = layerGraph(layers)
% 
%    % Connect the second input to the image layer output.
%    lgraph = connectLayers(lgraph, 'image', 'resize/ref')
% 
%   See also nnet.cnn.layer.Resize3DLayer, resize2dLayer, dlresize,
%   transposedConv3dLayer, averagePooling3dLayer.
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

    % Create the resize 3d layer based on given parameters.
    layer = nnet.cnn.layer.Resize3DLayer(NameValueArgs.Name, NameValueArgs.Scale,...
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
args.Scale = double(gather(iMakeIntoRowVectorOfThree(params.Scale)));
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
iAssertScalarOrRowVectorOfThree(value,'Scale');
end

function iAssertValidOutputSize(value)
validateattributes(value, {'numeric'},{},'','OutputSize');
iAssertRowVectorOfThree(value,'OutputSize');
iAssertValidNaNCount(value);
iAssertIntegerValues(value);
end

function iAssertValidEnableReferenceInput(value)
validateattributes(value, {'logical','numeric'}, ...
    {'nonsparse', 'scalar', 'nonempty','binary'}, '','EnableReferenceInput');
end

function iAssertScalarOrRowVectorOfThree(value,name)
if ~(isscalar(value) || iIsRowVectorOfThree(value))
    error(message('images:resizeLayer:paramMustBeScalarOrTriple',name));
end
end

function iAssertRowVectorOfThree(value,name)
if ~iIsRowVectorOfThree(value)
    error(message('images:resizeLayer:paramMustBeTriple',name));
end
end

function out = iMakeIntoRowVectorOfThree(in)
if iIsRowVectorOfThree(in) || isempty(in)
    out = in;
else
    out = repelem(in, 3);
end
end

function iAssertValidLayerName(value)
isCharRowVectorOrEmtpy = ischar(value) && (isrow(value) || isempty(value));
isScalarStringNotMissing = (isstring(value) && isscalar(value) && ~ismissing(value));
if ~(isCharRowVectorOrEmtpy || isScalarStringNotMissing)
    error(message('images:resizeLayer:nameParameterIsInvalid'));
end
end

function tf = iIsRowVectorOfThree(x)
tf = isrow(x) && numel(x)==3;
end

function iAssertValidNaNCount(value)
nanCount = sum(isnan(value));
if nanCount ~= 2 && nanCount ~= 0
    error(message('images:resizeLayer:invalidNaNOutputSizeSyntax',2));
end
end

function iAssertIntegerValues(value)
value = value(~isnan(value));
validateattributes(value, {'numeric'}, ...
    {'positive', 'integer', 'row', 'finite'},'','OutputSize');
end