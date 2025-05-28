function tform = randomAffine3d(varargin)

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


t = zeros(4,4);

[rotationAxis,rotationAngle] = args.Rotation();
rotationAxis = rotationAxis ./ norm(rotationAxis);

% t is constructed as a post-multiply transformation matrix
t(1:3,1:3) = makeShearTransform(args.Shear()) *...
    makeRotationTransform(rotationAxis,rotationAngle) *...
    makeReflectionTransform(args.XReflection(),args.YReflection(),args.ZReflection()) *...
    makeScaleTransform(args.Scale());

t(4,:) = [double(args.XTranslation()),double(args.YTranslation()),double(args.ZTranslation()),1];

tform = affinetform3d(t');

end


function tform = makeShearTransform(ShearAngle)
% return a post-multiply transformation matrix

ShearAngle = double(ShearAngle);

% Sh = [1 ShearYwrtX ShearZwrtX,...
%       ShearXwrtY, 1, ShearZwrtY,...
%       ShearXwrtZ, ShearYwrtZ, 1];

tform = eye(3);
shearCoefficientIdxList = find(~tform);
idx = shearCoefficientIdxList(randi(6));
tform(idx) = tand(ShearAngle);

end

function tform = makeRotationTransform(rotationAxis,rotationAngle)
% return a post-multiply transformation matrix

tform = createRotationMatrix(rotationAxis, rotationAngle);

end

function tform = makeReflectionTransform(xReflection,yReflection,zReflection)
% return a post-multiply transformation matrix

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

if zReflection == 0
    zReflection = 1;
else
    zReflection = -1;
end

tform = [xReflection, 0, 0;...
    0, yReflection, 0;...
    0, 0, zReflection];

end

function tform = makeScaleTransform(scale)
% return a post-multiply transformation matrix

scale = double(scale);
tform = scale * eye(3);

end


function params = iParseInputs(varargin)

p = inputParser();
p.addParameter('XReflection',false,@(val) validateReflection(val,'XReflection'));
p.addParameter('YReflection',false,@(val) validateReflection(val,'YReflection'));
p.addParameter('ZReflection',false,@(val) validateReflection(val,'ZReflection'));
p.addParameter('Rotation',[0 0],@(val) validateInput(val,'Rotation'));
p.addParameter('Scale', [1, 1],@validateScale);
p.addParameter('Shear',[0, 0],@validateShear);
p.addParameter('XTranslation',[0,0],@(val) validateInput(val,'XTranslation'));
p.addParameter('YTranslation',[0,0],@(val) validateInput(val,'YTranslation'));
p.addParameter('ZTranslation',[0,0],@(val) validateInput(val,'ZTranslation'));

p.parse(varargin{:});

params = p.Results;
params = addErrorCheckingToSelectionFunctions(params);
params.Rotation = convertRangeToRotationSelectionFcn(params.Rotation);
params = structfun(@convertInputsToSelectionFcn,params,'UniformOutput',false);

end

function fcnOut = convertRangeToRotationSelectionFcn(val)

if isnumeric(val)
    fcnOut = @() defaultRotationSelectionFunction(val);
else
    fcnOut = val;
end

end

function [axis,theta] = defaultRotationSelectionFunction(rangeIn)

axis = createRandomVector();
theta = randomUniformValInRange(double(rangeIn));

end

function vec = createRandomVector
vec = rand(1,3) + eps;
end

function val = randomUniformValInRange(rangeIn)
val = rand*diff(rangeIn) + rangeIn(1);
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


function TF = validateReflection(val,name)

if ~isa(val,'function_handle')
    validateattributes(val,{'logical','numeric'},{'scalar','real','nonsparse','finite'},'randomAffine3d',name);
end

TF = true;

end


function TF = validateInput(val,name)

if ~isa(val,'function_handle')
    iValidateNumericRange(name,val);
end

TF = true;

end


function TF = validateScale(val)

if ~isa(val,'function_handle')
    iValidateNumericRange('Shear',val,'positive');
end

TF = true;

end

function TF = validateShear(val)

iValidateNumericRange('Shear',val,'<',90,'>',-90);

TF = true;

end

function iValidateNumericRange(name,range,varargin)

matlab.images.internal.errorIfgpuArray(range);
validateattributes(range,{'numeric'},cat(2,{'real','finite','nondecreasing','numel',2,'vector'},varargin),'randomAffine3d',...
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


function [axisVal,angleVal] = callRotationSelectionFcn(fcn)

try
    [axisVal,angleVal] = fcn();
    
    if ~isValidAxisOfRotation(axisVal)
        error(message('images:randomAffine2d:selectionFunctionYieldedInvalidValue','rotationAxis'));
    end
    
    if ~standardValidation(angleVal)
        error(message('images:randomAffine2d:selectionFunctionYieldedInvalidValue','theta'));
    end
    
catch ME
    if strcmp(ME.identifier,'images:randomAffine2d:selectionFunctionYieldedInvalidValue')
        rethrow(ME)
    else
        error(message('images:randomAffine2d:invalidSelectionFcn','Rotation'));
    end
end

end


function TF = isValidAxisOfRotation(v)

TF = all(isnumeric(v) & isreal(v) & isfinite(v)) && isvector(v) && (length(v) == 3);

end

function params = addErrorCheckingToSelectionFunctions(params)

if isa(params.Scale,'function_handle')
    params.Scale = @() callSelectionFcn(params.Scale,@(v) standardValidation(v) && (v > 0),'Scale');
end

if isa(params.Rotation,'function_handle')
    params.Rotation = @() callRotationSelectionFcn(params.Rotation);
end

if isa(params.Shear,'function_handle')
    params.Shear = @() callSelectionFcn(params.Shear,@(v) standardValidation(v) && (v > -90) && (v < 90),'Shear');
end

if isa(params.XTranslation,'function_handle')
    params.XTranslation = @() callSelectionFcn(params.XTranslation,@(v) standardValidation(v),'XTranslation');
end

if isa(params.YTranslation,'function_handle')
    params.YTranslation = @() callSelectionFcn(params.YTranslation,@(v) standardValidation(v),'YTranslation');
end

if isa(params.ZTranslation,'function_handle')
    params.ZTranslation = @() callSelectionFcn(params.ZTranslation,@(v) standardValidation(v),'ZTranslation');
end

if isa(params.XReflection,'function_handle')
    params.XReflection = @() callSelectionFcn(params.XReflection,@(v) isscalar(v) && ((isnumeric(v) && isreal(v)) || islogical(v)),'XReflection');
end

if isa(params.YReflection,'function_handle')
    params.YReflection = @() callSelectionFcn(params.YReflection,@(v) isscalar(v) && ((isnumeric(v) && isreal(v)) || islogical(v)),'YReflection');
end

if isa(params.ZReflection,'function_handle')
    params.ZReflection = @() callSelectionFcn(params.ZReflection,@(v) isscalar(v) && ((isnumeric(v) && isreal(v)) || islogical(v)),'ZReflection');
end

end

function TF = standardValidation(v)

TF = isscalar(v) && isnumeric(v) && isreal(v) && isfinite(v);

end

function t = createRotationMatrix(rotationAxis, angle)

a_x = rotationAxis(1,1);
a_y = rotationAxis(1,2);
a_z = rotationAxis(1,3);

c = cosd(angle);
s = sind(angle);

t1 = c + a_x^2*(1-c);
t2 = a_x*a_y*(1-c) - a_z*s;
t3 = a_x*a_z*(1-c) + a_y*s;
t4 = a_y*a_x*(1-c) + a_z*s;
t5 = c + a_y^2*(1-c);
t6 = a_y*a_z*(1-c)-a_x*s;
t7 = a_z*a_x*(1-c)-a_y*s;
t8 = a_z*a_y*(1-c)+a_x*s;
t9 = c+a_z^2*(1-c);

t = [t1 t2 t3;...
    t4 t5 t6;...
    t7 t8 t9];

end

% Copyright 2019-2022 The MathWorks, Inc.

