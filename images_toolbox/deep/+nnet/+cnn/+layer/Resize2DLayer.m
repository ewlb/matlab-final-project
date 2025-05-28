classdef Resize2DLayer < nnet.layer.Layer & nnet.internal.cnn.layer.Traceable
    % Resize2DLayer   Resize 2D Layer that resizes input along height and
    %                 width
    %
    %   To create a resize 2D layer, use resize2dlayer.
    %
    %   Resize2DLayer properties:
    %       Name                   - A name for the layer.
    %       Scale                  - The value to scale the input
    %                                size.
    %       OutputSize             - The value to resize the input.
    %       EnableReferenceInput   - The value to enable the reference
    %                                input.
    %       Method                 - The interpolation method.
    %       GeometricTransformMode - The transformation mode to map points
    %                                from input space to output space.
    %       NearestRoundingMode    - The rounding mode to determine the
    %                                nearest sample.
    %       NumInputs              - The number of inputs of the layer.
    %       InputNames             - The names of the inputs of the layer.
    %       NumOutputs             - The number of outputs of the layer.
    %       OutputNames            - The names of the outputs of the layer.
    %
    %   Example:
    %       Create a resize 2d layer.
    %
    %       layer = resize2dLayer('Scale', 2)
    %
    %   See also resize2dLayer
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties (SetAccess = private)
        % Scale   Scale factor for the layer
        %   Scale can be a scalar or a row vector of two elements.
        Scale
        
        % OutputSize   Output size for the layer
        %   OutputSize is a row vector of two elements. One element may be
        %   NaN in which case it preserves the aspect ratio of the input.
        OutputSize
        
        % EnableReferenceInput  Logical flag to accept reference activation 
        %                       as input
        %   EnableReferenceInput is a boolean value. 
        EnableReferenceInput
        
        % Method   Interpolation method for the layer
        %   Method is either 'nearest' or 'bilinear'.
        Method
        
        % GeometricTransformMode   The transformation to map points from
        %                          input space to output space
        %   GeometricTransformMode is either 'asymmetric' or 'half-pixel'.
        GeometricTransformMode
        
        % NearestRoundingMode   Determines the nearest sample
        %   NearestRoundingMode is either 'onnx-10' or 'round'.
        NearestRoundingMode
    end
    
    properties (SetAccess = private, Hidden)
        % These properties prevent redundant computations during predict
        % call.
        
        % DlresizeMethodName   A cache to store the method name for
        %                      dlresize
        %   DlresizeMethodName is either 'nearest' or 'linear'.
        DlresizeMethodName
        
        % GetOutputSizeAndScale   A cache to store the function handle to
        %                         compute scale and outputsize.       
        GetOutputSizeAndScale
    end
    
    methods
        function layer = Resize2DLayer(name, scale, outputSize, enableReferenceInput, method, geometricTransformMode, nearestRoundingMode)
            
            % Validate scale, output size and reference input.
            isScaleSpecified = ~isempty(scale);
            isOutputSizeSpecified = ~isempty(outputSize);
            isEnableReferenceInputSpecified = enableReferenceInput;
            
           
           if isEnableReferenceInputSpecified
               % Reference input is given.
                layer.NumInputs = 2;
                layer.InputNames = {'in','ref'};
                layer.GetOutputSizeAndScale = "iComputeScaleFromReferenceLayer";
            elseif (isScaleSpecified)
                % Scale is given.
                layer.Description = iGetMessageString('images:resizeLayer:oneLineDisplay',2,'scale',mat2str(scale));
                layer.GetOutputSizeAndScale = "iComputeOutputSizeFromScale";
           elseif isOutputSizeSpecified
                % Output size given.
                if any(isnan(outputSize))
                    layer.GetOutputSizeAndScale = "iComputeScaleFromOutputSizeWithNaN";
                else
                    layer.GetOutputSizeAndScale = "iComputeScaleFromOutputSize";
                end
                layer.Description = iGetMessageString('images:resizeLayer:oneLineDisplay',2,'output size',mat2str(outputSize));      
            end
            
            layer.Name = name;
            layer.Scale = scale;
            layer.OutputSize = outputSize;
            layer.EnableReferenceInput = enableReferenceInput;
            layer.Method = method;
            layer.DlresizeMethodName = iConvertToDlresizeMethod(layer.Method);
            layer.GeometricTransformMode = geometricTransformMode;
            layer.NearestRoundingMode = nearestRoundingMode;
            layer.Type = iGetMessageString('images:resizeLayer:type');
        end
        
        function Z = predict(layer, varargin)
            % Forward input data through the layer at prediction time and
            % output the result.
            
            % Check for valid input size and return valid input. Input data
            % X is always dlarray since it uses autodiff to compute the
            % backward.  
            
            numSpatialDims = 2;
            if layer.NumInputs == 1
                X = varargin{1};
            elseif layer.NumInputs == 2
                X = varargin{1};
                layer.OutputSize = size(varargin{2},1:numSpatialDims);
            end
            [X,isInputDataFormatted] = iCheckAndReturnValidInput(X,layer.Name);
            
            inputSpatialDimSize = size(X,1:numSpatialDims);
            labels = dims(X);
            
            fh = str2func(layer.GetOutputSizeAndScale);
            [scale, outputSize] = fh(layer, inputSpatialDimSize);
            
            % Determine start location and stride along each spatial
            % dimension.
            [start,stride,stop] = images.dlresize.internal.getInputQueryLocations(layer.GeometricTransformMode,outputSize,scale);
            
            % Perform interpolation.
            X = stripdims(X);
            Z = images.dlresize.internal.interpSpatialDims(X,start,stop,stride,layer.DlresizeMethodName,layer.NearestRoundingMode,scale,inputSpatialDimSize);
            
            if isInputDataFormatted
                Z = dlarray(Z,labels);
            end
            
        end
    end
    
    methods
        function obj = set.Method(obj, val)
            obj.Method = iCheckAndReturnValidMethod(val);
        end
        
        function obj = set.GeometricTransformMode(obj, val)
            obj.GeometricTransformMode = iCheckAndReturnValidGeometricTransform(val);
        end
        
        function obj = set.NearestRoundingMode(obj, val)
            obj.NearestRoundingMode = iCheckAndReturnValidRoundingMode(val);
        end
    end
    
    methods(Static, Hidden = true)
        function name = matlabCodegenRedirect(~)
            name = 'nnet.internal.cnn.coder.Resize2DLayer';
        end
    end
    
    methods(Static, Hidden)
        function this = loadobj(in)
            if in.Version <= 1
                in = iUpgradeVersionOneToVersionTwo(in);
                in = iUpgradeVersionTwoToVersionThree(in);
            elseif in.Version == 2
                in = iUpgradeVersionTwoToVersionThree(in);
            end
            this = iLoadResize2DLayerFromCurrentVersion(in);
        end
    end
    
    methods(Hidden)
        function s = saveobj(this)
            s.Version = 3;
            s.Name = this.Name;
            s.Scale = this.Scale;
            s.OutputSize = this.OutputSize;
            s.EnableReferenceInput = this.EnableReferenceInput;
            s.Method = this.Method;
            s.GeometricTransformMode = this.GeometricTransformMode;
            s.NearestRoundingMode = this.NearestRoundingMode;
            s.Description = this.Description;
            s.Type = this.Type;
            s.DlresizeMethodName = this.DlresizeMethodName;
            s.GetOutputSizeAndScale = this.GetOutputSizeAndScale;
        end
    end
end

function messageString = iGetMessageString( varargin )
messageString = getString( message( varargin{:} ) );
end

function method = iConvertToDlresizeMethod(method)
if strcmp(method, 'bilinear')
    method = 'linear';
end
end

function [input,isInputDataFormatted] = iCheckAndReturnValidInput(input,layerName)
if ~isdlarray(input)
    error(message('images:resizeLayer:invalidInputType',class(input)));
end
if ndims(input)> 4
    error(message('images:resizeLayer:invalidInput2D',layerName));
end
isInputDataFormatted = ~isempty(dims(input));
if isInputDataFormatted
    if numel(finddim(input,'S')) ~= 2
        error(message('images:resizeLayer:requireTwoSpatialDim',layerName));
    end
else
    input = deep.internal.dlarray.validateDataFormatArg(input, 'SSCB');
end
end

function value = iCheckAndReturnValidGeometricTransform(value)
validateattributes(value, {'char','string'}, {}, '', 'GeometricTransformMode');
value = validatestring(value, {'asymmetric', 'half-pixel'},'','GeometricTransformMode');
end

function value = iCheckAndReturnValidRoundingMode(value)
validateattributes(value, {'char','string'}, {}, '', 'NearestRoundingMode');
value = validatestring(value, {'floor', 'onnx-10', 'round'},'','NearestRoundingMode');
end

function value = iCheckAndReturnValidMethod(value)
validateattributes(value, {'char','string'},{},'','Method');
value = validatestring(value, {'nearest', 'bilinear'},'','Method');
end

function [scale, outputSize] = iComputeOutputSizeFromScale(layer, inputSpatialDimSize)
scale = layer.Scale;
outputSize = scale .* inputSpatialDimSize;
outputSize = floor(outputSize);
end

function [scale, outputSize] = iComputeScaleFromOutputSize(layer, inputSpatialDimSize)
outputSize = layer.OutputSize;
scale = layer.OutputSize ./ inputSpatialDimSize;
end

function [scale, outputSize] = iComputeScaleFromOutputSizeWithNaN(layer, inputSpatialDimSize)
outputSize = layer.OutputSize;
homogeneousScale = outputSize ./ inputSpatialDimSize;
homogeneousScale = homogeneousScale(~isnan(homogeneousScale));
outputSize = floor(homogeneousScale .* inputSpatialDimSize);
scale = repmat(homogeneousScale,1,numel(inputSpatialDimSize));
end

function [scale, outputSize] = iComputeScaleFromReferenceLayer(layer, inputSpatialDimSize)
outputSize = layer.OutputSize;
scale = layer.OutputSize ./ inputSpatialDimSize;
end

function S = iUpgradeVersionOneToVersionTwo(S)
% iUpgradeVersionOneToVersionTwo   Upgrade a v1 saved struct to a v2 saved
% struct. This means updating the GetOutputSizeAndScale property from
% function handle to string.

S.Version = 2;
if isa(S.GetOutputSizeAndScale,'function_handle')
    S.GetOutputSizeAndScale = func2str(S.GetOutputSizeAndScale);
end
end

function S = iUpgradeVersionTwoToVersionThree(S)
% iUpgradeVersionTwoToVersionThree   Upgrade a v2 saved struct to a v3 saved
% struct. This means setting the EnableReferenceInput to false.

S.Version = 3;
S.EnableReferenceInput = 0;
end

function obj = iLoadResize2DLayerFromCurrentVersion(in)
obj = nnet.cnn.layer.Resize2DLayer(in.Name, in.Scale, in.OutputSize, in.EnableReferenceInput, in.Method, in.GeometricTransformMode, in.NearestRoundingMode);
obj.Description = in.Description;
obj.Type = in.Type;
obj.GetOutputSizeAndScale = in.GetOutputSizeAndScale;
obj.DlresizeMethodName = in.DlresizeMethodName;
end