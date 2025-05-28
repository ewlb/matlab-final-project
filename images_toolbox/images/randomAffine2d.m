function tform = randomAffine2d(varargin)

matlab.images.internal.errorIfgpuArray(varargin{:});
persistent args previousInput

% As performance optimization, don't re-parse inputs if arg list is exactly
% the same as the last call.
if isempty(args) || ~isequal(varargin,previousInput)
    previousInput = varargin;
    args = iParseInputs(varargin{:});
end
    
tform = constructNextTransform(args);

end

function tform = constructNextTransform(args)

% tLinear is computed as a post-multiply transformation matrix.
tLinear = makeShearTransform(args.XShear(),args.YShear()) *...
          makeRotationTransform(args.Rotation()) *...
          makeReflectionTransform(args.XReflection(),args.YReflection()) *...
          makeScaleTransform(args.Scale());

t = cat(1,tLinear,[double(args.XTranslation()),double(args.YTranslation())]);

tform = affinetform2d(t');

end


function tform = makeShearTransform(xShearAngle,yShearAngle)
% returns a post-multiply transformation matrix

xShearAngle = double(xShearAngle);
yShearAngle = double(yShearAngle);

tform = [1, tand(yShearAngle);...
    tand(xShearAngle), 1];

end

function tform = makeRotationTransform(rotationAngle)
% returns a post-multiply transformation matrix

rotationAngle = double(rotationAngle);

tform = [cosd(rotationAngle), -sind(rotationAngle);...
    sind(rotationAngle), cosd(rotationAngle)];

end

function tform = makeReflectionTransform(xReflection,yReflection)
% returns a post-multiply transformation matrix

if xReflection == 0
    xReflection = 1;
else
    xReflection = -1;
end

if yReflection == 0
    yReflection = 1;
else
    yReflection = -1;
end

tform = [xReflection, 0;...
    0, yReflection];

end

function tform = makeScaleTransform(scale)
% returns a post-multiply transformation matrix

scale = double(scale);

tform = [scale, 0;...
    0, scale];
end


function params = iParseInputs(varargin)

p = inputParser();
p.addParameter('XReflection',false,@validateXReflection);
p.addParameter('YReflection',false,@validateYReflection);
p.addParameter('Rotation',[0 0],@validateRotation);
p.addParameter('Scale', [1, 1],@validateScale);
p.addParameter('XShear',[0, 0],@validateXShear);
p.addParameter('YShear',[0, 0],@validateYShear);
p.addParameter('XTranslation',[0,0],@validateXTranslation);
p.addParameter('YTranslation',[0,0],@validateYTranslation);

p.parse(varargin{:});

params = p.Results;
params = addErrorCheckingToSelectionFunctions(params);
params = structfun(@convertInputsToSelectionFcn,params,'UniformOutput',false);

end

function fcnOut = convertInputsToSelectionFcn(valIn)
if isnumeric(valIn) && ~isscalar(valIn)
    valIn = double(valIn);
    fcnOut = @() rand*diff(valIn) + valIn(1);
elseif isscalar(valIn) && (isnumeric(valIn) || islogical(valIn))
    if valIn
        fcnOut = @() logical(rand > 0.5);
    else
        fcnOut = @() false;
    end
else    
    fcnOut = valIn;
end
end


function TF = validateXReflection(val)

if ~isa(val,'function_handle')
    validateattributes(val,{'logical','numeric'},{'scalar','real','nonsparse','finite'},'randomAffine2d','XReflection');    
end

TF = true;

end

function TF = validateYReflection(val)

if ~isa(val,'function_handle')
    validateattributes(val,{'logical','numeric'},{'scalar','real','nonsparse','finite'},'randomAffine2d','YReflection');
end

TF = true;

end

function TF = validateRotation(val)

if ~isa(val,'function_handle')
    iValidateNumericRange('Rotation',val);
end

TF = true;

end

function TF = validateXTranslation(val)

if ~isa(val,'function_handle')
    iValidateNumericRange('XTranslation',val);
end

TF = true;

end

function TF = validateYTranslation(val)

if ~isa(val,'function_handle')
    iValidateNumericRange('YTranslation',val);
end

TF = true;

end

function TF = validateScale(val)

if ~isa(val,'function_handle')
    iValidateNumericRange('Scale',val,'positive');
end

TF = true;

end

function TF = validateXShear(val)

if ~isa(val,'function_handle')
    iValidateNumericRange('XShear',val,'<',90,'>',-90);
end

TF = true;

end

function TF = validateYShear(val)

if ~isa(val,'function_handle')
    iValidateNumericRange('YShear',val,'<',90,'>',-90);
end

TF = true;

end

function iValidateNumericRange(name,range,varargin)

validateattributes(range,{'numeric'},cat(2,{'real','finite','nondecreasing','numel',2,'vector'},varargin),'randomAffine2d',...
    name);

end

function val = callSelectionFcn(fcn,validationFcn,paramName)

try
    val = fcn();
    if ~validationFcn(val)
       error(message('images:randomAffine2d:selectionFunctionYieldedInvalidValue',paramName));
    end
catch ME
    if strcmp(ME.identifier,'images:randomAffine2d:selectionFunctionYieldedInvalidValue')
        rethrow(ME)
    else
        error(message('images:randomAffine2d:invalidSelectionFcn',paramName));
    end
end

end

function params = addErrorCheckingToSelectionFunctions(params)

if isa(params.Scale,'function_handle')
    params.Scale = @() callSelectionFcn(params.Scale,@(v) standardValidation(v) && (v > 0),'Scale');
end

if isa(params.Rotation,'function_handle')
    params.Rotation = @() callSelectionFcn(params.Rotation,@(v) standardValidation(v),'Rotation');
end

if isa(params.XShear,'function_handle')
    params.XShear = @() callSelectionFcn(params.XShear,@(v) standardValidation(v) && (v > -90) && (v < 90),'XShear');
end

if isa(params.YShear,'function_handle')
    params.YShear = @() callSelectionFcn(params.YShear,@(v) standardValidation(v) && (v > -90) && (v < 90),'YShear');
end

if isa(params.XTranslation,'function_handle')
    params.XTranslation = @() callSelectionFcn(params.XTranslation,@(v) standardValidation(v),'XTranslation');
end

if isa(params.YTranslation,'function_handle')
    params.YTranslation = @() callSelectionFcn(params.YTranslation,@(v) standardValidation(v),'YTranslation');
end

if isa(params.XReflection,'function_handle')
    params.XReflection = @() callSelectionFcn(params.XReflection,@(v) isscalar(v) && ((isnumeric(v) && isreal(v)) || islogical(v)),'XReflection');
end

if isa(params.YReflection,'function_handle')
    params.YReflection = @() callSelectionFcn(params.YReflection,@(v) isscalar(v) && ((isnumeric(v) && isreal(v)) || islogical(v)),'YReflection');
end

end

function TF = standardValidation(v)
    
TF = isscalar(v) && isnumeric(v) && isreal(v) && isfinite(v);

end

% Copyright 2019-2022 The MathWorks, Inc.

