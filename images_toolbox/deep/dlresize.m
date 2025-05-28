function Y = dlresize(X, varargin)
%DLRESIZE  Resize of spatial dimensions of dlarray.
%
%   Y = DLRESIZE(X,'Scale',scale) resizes the spatial dimensions of the
%   dlarray X. The input scale is either a scalar describing homogenous
%   scale to apply to all spatial dimensions or a vector of length equal to
%   the number of spatial dimensions in X.
%
%   Y = DLRESIZE(X,'OutputSize',outputSize) resizes the dlarray X such that
%   the spatial dimension sizes are equal to the vector outputSize in each
%   dimension. All elements except for one may be NaN, in which case the
%   values are computed automatically to preserve the aspect ratio of the
%   input.
%
%   Y = DLRESIZE(___,'PARAM1',VAL1,'PARAM2',VAL2,...) computes the resize
%   of the dlarray X using Name/Value pairs to control specifics of the
%   resize operation.
%
%   Supported Name/Value pairs:
%
%   'DataFormat'              - Dimension labels of the input data X,
%                               specified as a string scalar or character
%                               vector. Required if X is not a formatted
%                               dlarray.
%
%   'Method'                  - A string scalar or character vector that
%                               specifies interpolation method. Options are
%                               "nearest" and "linear".
%
%                               Default: "nearest".
%
%   'GeometricTransformMode'  - A string scalar or character vector that
%                               specifies how points in output space map to
%                               points in input space. Supported options are
%                               "asymmetric" and "half-pixel".
%
%                               Default: "half-pixel".
%
%   'NearestRoundingMode'   -   A string scalar or character vector that
%                               specifies the rounding mode used to
%                               determine the nearest sample when 'Method'
%                               is "nearest". Options are "onnx-10",
%                               "floor", and "round". The "round" option is
%                               the same behavior as the MATLAB round
%                               function. The "floor" option uses the floor
%                               function to determine nearest query point
%                               indices. The "onnx-10" option reproduces
%                               the behavior from the Resize operator in
%                               ONNX opset 10.
%
%                               Default: "round"
%
%   Examples
%   --------
%   % Increase spatial dimensions by a factor of 2 using the default of
%   % nearest neighbor interpolation
%
%   A = im2single(imread('peppers.png'));
%   A = dlarray(A,'SSC');
%   B = dlresize(A,'Scale',2);
%   figure
%   imshow(extractdata(B))
%
%   See also DLARRAY, MAXPOOL, DLTRANSPCONV

% Copyright 2020-2023 The MathWorks, Inc.
%#codegen

coder.allowpcode('plain');

if isSimMode

    validateDlArray(X);
    nameValueArgs = parseOptionalInputs(varargin{:});

    coder.internal.errorIf(~isfield(nameValueArgs,'Scale') && ~isfield(nameValueArgs,'OutputSize'),'images:dlresize:mustSpecifyScaleOrOutputSize');

    nameValueArgs.GeometricTransformMode = iValidateString(nameValueArgs.GeometricTransformMode,["half-pixel","asymmetric"]);
    nameValueArgs.NearestRoundingMode = iValidateString(nameValueArgs.NearestRoundingMode,["onnx-10","round","floor"]);
    nameValueArgs.Method = iValidateString(nameValueArgs.Method,["linear","nearest"]);

    % Ensure X is a dlarray and include DataFormat
    labelString = iGetDimensionLabels(nameValueArgs);
    [X, perm] = deep.internal.dlarray.validateDataFormatArg(X, labelString);

    % Extract labels
    labels = dims(X);
    numSpatialDims = count(labels,'S');

    coder.internal.errorIf(numSpatialDims<1,'images:dlresize:requireAtLeastOneSpatialDim');

    % Determine desired output size
    inputSpatialDimSize = size(X, 1:numSpatialDims);

    % Determine output grid size and scale transformation based on inputs
    % provided.
    [outputSize, scale] = images.dlresize.internal.getOutputSizeAndScale(nameValueArgs, numSpatialDims, inputSpatialDimSize);

    % Determine start location and stride along each spatial dimension
    [start, stride, stop] = images.dlresize.internal.getInputQueryLocations(nameValueArgs.GeometricTransformMode, outputSize, scale);

    % Perform actual interpolation
    Y = images.dlresize.internal.interpSpatialDims(X, start, stop, stride, nameValueArgs.Method, nameValueArgs.NearestRoundingMode, scale, inputSpatialDimSize);

    % Remove dimensions from the dlarray if it was passed as unformatted.
    if isfield(nameValueArgs,'DataFormat')
        Y = stripdims(Y);

        % Permutes back in the same order as DataFormat
        Y = ipermute(Y, perm);
    end

else
    Y = nnet.internal.cnn.coder.dlresize(X, varargin{:});
end

end

%--------------------------------------------------------------------------
function labelString = iGetDimensionLabels(nameValueArgs)

if isfield(nameValueArgs,'DataFormat')
    labelString = nameValueArgs.DataFormat;
else
    labelString = [];
end

end

%--------------------------------------------------------------------------
function str = iValidateString(str,vals)
% Workaround to avoid needing to call validatestring against Name/Values
% set to the value set.

str = lower(str);
if any(str == lower(vals))
    return
else
    str = validatestring(str,vals);
end

end

%--------------------------------------------------------------------------
function validateDlArray(X)
validateattributes(X, {'dlarray'},{'nonempty'},'dlresize','X');
end

%--------------------------------------------------------------------------
function [nameValueArgs] = parseOptionalInputs(nameValueArgs)

arguments
    nameValueArgs.Scale {validateattributes(nameValueArgs.Scale,{'numeric'},{'positive','real','nonempty'},'dlresize','Scale')}
    nameValueArgs.OutputSize {validateattributes(nameValueArgs.OutputSize,{'numeric'},{'positive','real','nonempty'},'dlresize','OutputSize')}
    nameValueArgs.DataFormat
    nameValueArgs.GeometricTransformMode string = "half-pixel"
    nameValueArgs.Method string = "nearest"
    nameValueArgs.NearestRoundingMode string = "round";
end

end

%--------------------------------------------------------------------------
function mode = isSimMode()
mode = isempty(coder.target);
end