function B = imrotate3(varargin) %#codegen
%IMROTATE3 Rotate 3-D grayscale image

% Copyright 2023 The MathWorks, Inc.

%   Syntax
%   ------
%
%       B = imrotate3(V, ANGLE, W)
%       B = imrotate3(V, ANGLE, W, METHOD)
%       B = imrotate3(V, ANGLE, W, METHOD, BBOX)
%       B = imrotate3(___,'FillValues',fillValues)
%
%   Input Specs
%   -----------
%
%      V:
%        3-D numeric array | 3-D logical array | 3-D categorical array
%
%      ANGLE:
%        numeric scalar
%
%      W:
%        1x3 numeric vector
%
%      METHOD:
%        string with value either 'nearest','linear' or 'cubic'
%        default: 'nearest' for categorical images
%                 'linear' for numeric and logical images
%
%      BBOX:
%        string with value either 'loose' or 'crop'
%        default: 'loose'
%
%      fillValues:
%        numeric scalar | string scalar | character vector | missing
%        default: 0 for numeric and logical images
%                 missing for cateforical images
%
%   Output Specs
%   ------------
%
%     B:
%       numeric array | logical array | categorical array
%

[V,angle,W,method,bbox,fillValues] = parseInputs(varargin{:});

if isempty(V) || all(W==0)
    B = V; % No rotation needed
else
    % Get unit direction vector
    unit_W = W/norm(W);

    % Quaternion rotation matrix
    t_quat = quat_matrix(unit_W,angle);

    % Quaternion rotation
    tf = affine3d(t_quat);

    RA = imref3d(size(V));
    Rout = images.spatialref.internal.applyGeometricTransformToSpatialRef(RA,tf);

    if bbox == CROP
        % Trim Rout, preserve center and resolution.
        Rout.ImageSize = RA.ImageSize;
        xTrans = mean(Rout.XWorldLimits) - mean(RA.XWorldLimits);
        yTrans = mean(Rout.YWorldLimits) - mean(RA.YWorldLimits);
        zTrans = mean(Rout.ZWorldLimits) - mean(RA.ZWorldLimits);
        Rout.XWorldLimits = RA.XWorldLimits+xTrans;
        Rout.YWorldLimits = RA.YWorldLimits+yTrans;
        Rout.ZWorldLimits = RA.ZWorldLimits+zTrans;
    end
    methodStr = coder.const(methodEnumToString(method));
    B = imwarp(V,tf,methodStr,'OutputView',Rout,'FillValues',fillValues);
end
end

%==========================================================================
function t = quat_matrix(W, ANGLE)
% quat_matrix expects the input angle to be in degrees
coder.inline('always');
coder.internal.prefer_const(W, ANGLE)

a_x = W(1,1);
a_y = W(1,2);
a_z = W(1,3);

% This avoids floating point round off for simple angles like 90 degrees
c = cosd(ANGLE);
s = sind(ANGLE);

t1 = c + a_x^2*(1-c);
t2 = a_x*a_y*(1-c) - a_z*s;
t3 = a_x*a_z*(1-c) + a_y*s;
t4 = a_y*a_x*(1-c) + a_z*s;
t5 = c + a_y^2*(1-c);
t6 = a_y*a_z*(1-c)-a_x*s;
t7 = a_z*a_x*(1-c)-a_y*s;
t8 = a_z*a_y*(1-c)+a_x*s;
t9 = c+a_z^2*(1-c);

t = [t1 t2 t3 0
    t4 t5 t6 0
    t7 t8 t9 0
    0  0  0  1];
end

%==========================================================================
function [V,angle,W,method,bbox,fillValues] = parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);

narginchk(3,7);

% validateimage
V = varargin{1};
validateattributes(V,{'numeric','logical','categorical'},{'ndims',3},mfilename,'V',1);

% validate angle
angle = double(varargin{2});
validateattributes(angle,{'numeric'},{'real','scalar'},mfilename,'ANGLE',2);

% validate axis of rotation
W = double(varargin{3});
validateattributes(W,{'numeric'},{'size',[1,3],'real','finite'},mfilename,'W',3);

% Default interpolation method, bounding box and fill values
method = LINEAR;
bbox = LOOSE;
fillValues = 0;
methodFlag = false;
bboxFlag = false;
fillFlag = false;


if nargin > 3
    validStrings  = {'nearest','linear','cubic','crop','loose','fillvalues'}; %#ok<NASGU>
    if nargin == 4
        % Parse the fourth argument
        [method, bbox] = getArgVal(varargin{4},4,nargin,method,bbox,fillValues,...
            methodFlag,bboxFlag,fillFlag,varargin{:});
    elseif nargin == 5
        % Parse the fourth argument
        [method, bbox, fillValues,methodFlag,bboxFlag,fillFlag] = getArgVal(varargin{4},4,nargin,method,bbox,fillValues,...
            methodFlag,bboxFlag,fillFlag,varargin{:});

        % If the fourth argument is not Fillvalues, parse the fifth argument
        if fillFlag == false
            [method, bbox] = getArgVal(varargin{5},4,nargin,method,bbox,fillValues,...
                methodFlag,bboxFlag,fillFlag,varargin{:});
        end

    elseif nargin == 6
        % "getArgVal" will error out if the 4th argument is 'FillValues' or any
        % invalid 'method'/'bbox'
        [method, bbox,fillValues,methodFlag,bboxFlag,fillFlag] = getArgVal(varargin{4},4,nargin,method,bbox,fillValues,...
            methodFlag,bboxFlag,fillFlag,varargin{:});

        % Parse the fifth argument. "getArgVal" will error out if the 5th
        % argument is not 'FillValues'. If the 5th argument is 'FillValues', "getArgVal"
        % will parse the 6th argument to extract the scalar value.
        [~, ~, fillValues] = getArgVal(varargin{5},5,nargin,method,bbox,fillValues,...
            methodFlag,bboxFlag,fillFlag,varargin{:});
    else %nargin==7
        % "getArgVal" will error out if the 4th argument is 'FillValues' or any
        % invalid 'method'/'bbox'
        [method, bbox, ~,methodFlag,bboxFlag,fillFlag] = getArgVal(varargin{4},4,nargin,method,bbox,fillValues,...
            methodFlag,bboxFlag,fillFlag,varargin{:});

        % "getArgVal" will error out if the 5th argument is 'FillValues' or any
        % invalid 'method'/'bbox'
        [method, bbox, ~,methodFlag,bboxFlag,fillFlag] = getArgVal(varargin{5},5,nargin,method, bbox, fillValues,...
            methodFlag,bboxFlag,fillFlag,varargin{:});

        % Parse the sixth argument. "getArgVal" will error out if the 6th
        % argument is not 'FillValues'. If the 6th argument is 'FillValues', "getArgVal"
        % will parse the 7th argument to extract the scalar value.
        [~, ~, fillValues] = getArgVal(varargin{6},6,nargin,method, bbox, fillValues,...
            methodFlag,bboxFlag,fillFlag,varargin{:});
    end
else

end
end

function [method, bbox, fillValues,methodFlag,bboxFlag,fillFlag] = getArgVal(arg,argNum,argCount,method, bbox, fillValues,...
    methodFlag,bboxFlag,fillFlag,varargin)
coder.inline('always');
coder.internal.prefer_const(arg,argNum,argCount,methodFlag,bboxFlag,fillFlag,varargin);

validStrings  = {'nearest','linear','cubic','crop','loose','fillvalues'};

% Error if argument is not string
coder.internal.errorIf(~(ischar(arg) || isstring(arg)),'images:imrotate3:expectedString');

% % Default interpolation method, bounding box and fill values

argStr = validatestring(arg,validStrings,mfilename);
argInterpBboxFillFlag = stringToInterpBboxFill(argStr);

% Error out when secondlast argument is not 'FillValues' when
% total number of arguments is 6 or 7
if argCount == 6
    coder.internal.errorIf((argInterpBboxFillFlag ~= FILLVALUE && argNum == 5),...
        'images:imrotate3:invalidParameterLocation');
    coder.internal.errorIf((argInterpBboxFillFlag == FILLVALUE && argNum ~= 5),...
        'images:imrotate3:invalidParameterLocation');
elseif argCount == 7
    coder.internal.errorIf((argInterpBboxFillFlag ~= FILLVALUE && argNum == 6),...
        'images:imrotate3:invalidParameterLocation');
    coder.internal.errorIf((argInterpBboxFillFlag == FILLVALUE && argNum ~= 6),...
        'images:imrotate3:invalidParameterLocation');
end

% Identify if the argument is interpolation method, bounding box or
% fill values.
if argInterpBboxFillFlag == INTERPOLATIONMETHOD
    coder.internal.errorIf(methodFlag,'images:imrotate3:invalidParameterLocation');
    method = stringToMethod(argStr);
    methodFlag = true;
elseif argInterpBboxFillFlag == BBOX
    coder.internal.errorIf(bboxFlag,'images:imrotate3:invalidParameterLocation');
    bbox = stringToBbox(argStr);
    bboxFlag = true;

    % If argument is 'fillvalues', parse the next argument for fill value
elseif argInterpBboxFillFlag == FILLVALUE
    coder.internal.errorIf((argNum+1 > argCount),'images:imrotate3:specifyFillvalue');
    fillValues = varargin{argNum+1};
    coder.internal.errorIf(~ischar(fillValues) && ~isscalar(fillValues),...
        'images:imrotate3:expectedScalarFillValue');
    fillFlag = true;
end
end

%--------------------------------------------------------------------------
function methodFlag = NEAREST()
coder.inline('always');
methodFlag = int8(1);
end

%--------------------------------------------------------------------------
function methodFlag = LINEAR()
coder.inline('always');
methodFlag = int8(2);
end

%--------------------------------------------------------------------------
function methodFlag = CUBIC()
coder.inline('always');
methodFlag = int8(3);
end

%--------------------------------------------------------------------------
function bboxFlag = LOOSE()
coder.inline('always');
bboxFlag = int8(4);
end

%--------------------------------------------------------------------------
function bboxFlag = CROP()
coder.inline('always');
bboxFlag = int8(5);
end

%--------------------------------------------------------------------------
function strEnum = INTERPOLATIONMETHOD()
coder.inline('always');
strEnum = int8(10);
end

%--------------------------------------------------------------------------
function strEnum = BBOX()
coder.inline('always');
strEnum = int8(11);
end

%--------------------------------------------------------------------------
function strEnum = FILLVALUE()
coder.inline('always');
strEnum = int8(12);
end

%--------------------------------------------------------------------------
function method = stringToMethod(mStr)
% Convert Method to its corresponding Enumeration
if strcmpi(mStr,'nearest')
    method = NEAREST;
elseif strcmpi(mStr,'linear')
    method = LINEAR;
else % if strcmpi(mStr,'cubic')
    method = CUBIC;
end
end

%--------------------------------------------------------------------------
function mStr = methodEnumToString(method)
% Convert Method Enumeration to its corresponding String
if method == NEAREST
    mStr = 'nearest';
elseif method == LINEAR
    mStr = 'linear';
else % if method == CUBIC
    mStr = 'cubic';
end
end

%--------------------------------------------------------------------------
function bbox = stringToBbox(bStr)
% Convert Method to its corresponding Enumeration
if strcmpi(bStr,'loose')
    bbox = LOOSE;
else % if strcmpi(bStr,'crop')
    bbox = CROP;
end
end

%--------------------------------------------------------------------------
function flag = stringToInterpBboxFill(str)
coder.inline('always');
if strcmpi(str,'nearest') || strcmpi(str,'linear') || strcmpi(str,'cubic')
    flag = INTERPOLATIONMETHOD;
elseif strcmpi(str,'crop') || strcmpi(str,'loose')
    flag = BBOX;
else %if strcmpi(str,'fillvalues')
    flag = FILLVALUE;
end
end