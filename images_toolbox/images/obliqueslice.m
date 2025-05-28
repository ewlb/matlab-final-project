function [B, XData, YData, ZData] = obliqueslice(varargin)
%OBLIQUESLICE Extract an oblique slice from a 3-D volume.
%   B = OBLIQUESLICE(V, POINT, NORMAL) extracts an oblique slice from a 3-D
%   (M-by-N-by-K) volume V, by using the POINT on the output slice B and
%   NORMAL to the output slice B. POINT is a 1-by-3 vector containing X, Y
%   and Z coordinates of the point in which output slice passes through. 
%   NORMAL is a 1-by-3 normal vector to the output slice.
%
%   [B, XDATA, YDATA, ZDATA] = OBLIQUESLICE(V, POINT, NORMAL)
%   also returns the X, Y and Z coordinates of the extracted slice B in
%   volume V.
%
%   B = OBLIQUESLICE(...,Name,Value) specifies additional parameters that
%   control various aspects of the geometric transformation. Parameter
%   names can be abbreviated. Parameters include:
%
%     'Method'      -  Specifies the interpolation method. The
%                      technique used for interpolation is a char array
%                      with one of the following values:
%
%                      'nearest'  -  Nearest neighbor interpolation.
%
%                      'linear'   -  Linear interpolation.
%                       This is the default.
%
%                      For categorical array inputs, 'nearest' is the only
%                      supported interpolation type and the default. 
%
%    'OutputSize'   -  Controls the size of the output image B. OutputSize
%                      is a char array with one of the following values:
%
%                      'full'  -   Make output image B the same size
%                                  as the maximum size of the output image
%                                  that can be obtained with respect to
%                                  given normal.
%
%                      'limit' -   Allow output image B to be large
%                                  enough to contain the entire sliced image.
%                                  This is the default.
%
%    'FillValues'   -  Numeric scalar value used to fill pixels in the
%                      output image B that are outside the limits of the
%                      volume.
%                      Default: 0.
%                       
%                      If input is a categorical, FillValues can take one 
%                      of the following values:
%                          - Valid category in input data specified as
%                            character array.
%
%                          - missing, which corresponds  to <undefined>
%                            category (default)
%
%   Class Support
%   -------------
%   The input volume V can be numeric or logical or categorical. The output
%   image B is of the same class as the input volume. The size of XData, 
%   YData and ZData is same as output image B. POINT and NORMAL must be 
%   numeric.
%
%   Notes
%   -----
%   Use surf function to know the orientation of the extracted slice. The
%   default value for camera up vector is set to [0 0 1].
%
%   Example 1
%   ----------
%   % Extract an oblique slice from a 3D volume
%
%   % Load input volume
%   s = load(fullfile(toolboxdir('images'),'imdata','BrainMRILabeled',...
%       'images','vol_001.mat'));
%   V = s.vol;
%
%   % Specify any point on the output slice
%   point = [120,120,78];
%
%   % Specify the normal of the output slice
%   normal = [0 1 1];
%
%   % Extract a slice using point and normal
%   [B,XData,YData,ZData] = obliqueslice(V, point, normal);
%
%   % Display the output slice
%   figure, surf(XData,YData,ZData,B,'edgecolor','none');
%   colormap gray;
%
%   Example 2
%   ----------
%   % Extract an orthogonal slice from a 3D volume
%
%   % Load input volume
%   s = load(fullfile(toolboxdir('images'),'imdata','BrainMRILabeled',...
%       'images','vol_001.mat'));
%   V = s.vol;
%
%   % Specify any point on the output slice
%   point = [120,120,78];
%
%   % Specify the normal of the output slice
%   normal = [0 1 0];
%
%   % Extract a slice using point and normal
%   B = obliqueslice(V, point, normal);
%
%   % Display the output slice
%   figure, imshow(B,[])
%
% See also slice, sliceViewer, volumeViewer, orthosliceViewer.

%   Copyright 2019-2020 The MathWorks, Inc.

[V, point, normal, method, outputsize, fillValue, catConverter] = parse_inputs(varargin{:});
originalClass = class(V);
[numRows, numCols, numChannels] = size(V);
sz = size(V);
chInd = 0;
if ~isa(V,'double')
    sz = single(sz);
    normal = single(normal);
    chInd = single(chInd);
end

% Initial normal vector
intialNormVector = [0 0 1];

% Unit normal vector
unitNormalVector = normal/norm(normal);

% Compute axis of rotation
if isequal(intialNormVector, unitNormalVector)
    W = unitNormalVector;
else
    W = cross(intialNormVector, unitNormalVector);
    W = W/norm(W);
    W(isnan(W)) = eps;
end

% Compute angle of rotation in radians
angle = acos(dot(intialNormVector, unitNormalVector));

% Quaternion rotation matrix
t_quat = quat_matrix(W, -angle);

% Quaternion rotation
T = affine3d(t_quat);
planeSize = 3*max(sz);
numRows1 = planeSize;
numCols1 = planeSize;

% X,Y and Z coordinates of a plane with origin as the center
[xp,yp,zp] = meshgrid(round(-numCols1/2):1:round(numCols1/2), round(-numRows1/2):1:round(numRows1/2), chInd);

% Rotate coordinates of a plane using transformation matrix T
[xr,yr,zr] = transformPointsForward(T,xp,yp,zp);

% Shift user input point, relative to input volume having origin as center
point(1) = point(1)-round(numCols/2);
point(2) = point(2)-round(numRows/2);
point(3) = point(3)-round(numChannels/2);

% Find the shortest distance between the plane that passes through input 
% point and origin
D = -(unitNormalVector(1)*point(1)+unitNormalVector(2)*point(2)+...
    unitNormalVector(3)*point(3));

% Translate a plane that passes from origin to input point
xq = xr - D*unitNormalVector(1) + round(numCols/2);
yq = yr - D*unitNormalVector(2) + round(numRows/2);
zq = zr - D*unitNormalVector(3) + round(numChannels/2);

% Obtain slice at desired coordinates using interpolation
obliqueSlice = images.internal.builtins.interp3d_halide(V,xq,yq,zq,method,fillValue);

% Make bounding box around the data in oblique slice
sliceMaskLimit = (xq>=1 & xq<=sz(2)) & (yq>=1 & yq<=sz(1)) & (zq>=1 & zq<=sz(3));

% Generate convex hull of an oblique slice if it has discontinuity regions 
B1 =  regionprops(bwconvhull(sliceMaskLimit),'BoundingBox');
if isempty(B1)
    croppedSlice = [];
    XData = [];
    YData = [];
    ZData = [];
else
    sliceSize = round(B1.BoundingBox);
    rows = [sliceSize(2),sliceSize(2)+sliceSize(4)-1];
    cols = [sliceSize(1),sliceSize(1)+sliceSize(3)-1];
    sliceCenter = ([(rows(1)+rows(2))/2, (cols(1)+cols(2))/2]);
    if (strcmp(outputsize,'limit'))
        % OutputSize 'limit'
        croppedSlice = obliqueSlice(rows(1):rows(2),cols(1):cols(2));
        XData  = xq(rows(1):rows(2),cols(1):cols(2));
        YData  = yq(rows(1):rows(2),cols(1):cols(2));
        ZData  = zq(rows(1):rows(2),cols(1):cols(2));
    else
        % OutputSize 'full'
        
        % Consider center of volume as a point
        point = floor([sz(1)/2,sz(2)/2,sz(3)/2]);
        % Translate the plane, so that the center of plane becomes center of volume
        XData1 = xr+point(1);
        YData1 = yr+point(2);
        ZData1 = zr+point(3);
        % create a mask for oblique slice
        sliceMaskFull= (XData1>=1 & XData1<=sz(2)) & (YData1>=1 & YData1<=sz(1)) & (ZData1>=1 & ZData1<=sz(3));
        % Make bounding box around the data in oblique slice
        B1 =  regionprops(sliceMaskFull,'BoundingBox');
        sliceSize = round(B1.BoundingBox);
        rowInd = [sliceSize(2),sliceSize(2)+sliceSize(4)-1];
        colInd = [sliceSize(1),sliceSize(1)+sliceSize(3)-1];
        numRows = rowInd(2)-rowInd(1)+1;
        numCols = colInd(2)-colInd(1)+1;
        rowIndFull = floor([sliceCenter(1)-((numRows-1)/2) sliceCenter(1)+((numRows+1)/2)-1]);
        colIndFull = floor([sliceCenter(2)-((numCols-1)/2) sliceCenter(2)+((numCols+1)/2)-1]);
        % Make size of the output slice same as the slice that passes through
        % center of volume with given normal
        croppedSlice = obliqueSlice(rowIndFull(1):rowIndFull(2), colIndFull(1):colIndFull(2));
        XData  = xq(rowIndFull(1):rowIndFull(2), colIndFull(1):colIndFull(2));
        YData  = yq(rowIndFull(1):rowIndFull(2), colIndFull(1):colIndFull(2));
        ZData  = zq(rowIndFull(1):rowIndFull(2), colIndFull(1):colIndFull(2));
    end
end

if ~isempty(catConverter)    
    B = catConverter.numeric2Categorical(croppedSlice);
else
    B = cast(croppedSlice,originalClass);
end
end


function t = quat_matrix(W, ANGLE)

a_x = W(1,1);
a_y = W(1,2);
a_z = W(1,3);

c = cos(ANGLE);
s = sin(ANGLE);

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


function [V,point,normal,method,outputsize,fillValues,catConverter] = parse_inputs(varargin)
% Specify minimum and maximum number of arguments
narginchk(3,9);
matlab.images.internal.errorIfgpuArray(varargin{:});
% Default values
catConverter = [];
isCategoricalInput = false;
parser = inputParser;
parser.CaseSensitive = false;
parser.PartialMatching = true;
parser.FunctionName = mfilename;
% Validate input volume
V = varargin{1};
parser.addRequired('V', @(V) validateattributes(V,{'uint8','int8','uint16',...
    'int16','uint32','int32','single','double','logical','categorical'},...
    {'real','nonsparse','nonempty','ndims',3},mfilename,'V',1));
if iscategorical(V)
    categoriesIn = categories(V);
    catConverter = images.internal.utils.CategoricalConverter(categoriesIn);
    V = catConverter.categorical2Numeric(V);
    isCategoricalInput = true;
end
% Validate point on the plane
point = varargin{2};
attributes = {'size',[1,3],'real','finite','nonsparse'};
parser.addRequired('point',@(point) validateattributes(point,...
    {'numeric'},{'size',[1,3],'real','finite','nonsparse'},...
    mfilename,'point',2));
% Validate normal vector to the plane
normal = varargin{3};
parser.addRequired('normal', @(normal) validateattributes(normal,...
    {'numeric'},attributes,mfilename,'normal',3));
% Default values for Method, OutputSize and FillValues 
parser.addParameter('OutputSize', 'limit');
if isCategoricalInput
    parser.addParameter('Method', 'nearest');
    parser.addParameter('FillValues',missing,...
        @(fillVal)validateCategoricalFillValues(fillVal,catConverter.Categories));
else
    parser.addParameter('Method', 'linear');
    parser.addParameter('FillValues',0,@validateFillValues);
end
parser.parse(varargin{:});
% Validate normal
if (~any(normal))
    error(message('images:obliqueslice:incorrectValue'))
end
point = cast(point,'double');
normal = cast(normal,'double');
% Validate interpolation methods
method = validatestring(parser.Results.Method, {'nearest','linear'}, ...
    mfilename, 'Method');
% Validate OutputSize and FillValues
outputsize = validatestring(parser.Results.OutputSize, {'full','limit'}, ...
    mfilename, 'OutputSize');
fillValues = parser.Results.FillValues;
if isCategoricalInput
    % For categorical the only valid 'Method' value is 'nearest'.
    if ~strncmpi(method,'nearest',numel(method))
        error(message('MATLAB:images:validate:badMethodForCategorical'));
    end
    fillValues = catConverter.getNumericValue(parser.Results.FillValues);
end
if ~images.internal.app.volview.isVolume(V)
    error(message('images:obliqueslice:requireVolumeData'));
end
end


function TF = validateFillValues(fillVal)
validateattributes(fillVal,{'numeric'},...
        {'nonempty','nonsparse','scalar','real'},'obliqueslice','FillValues');
TF = true;
end


function TF = validateCategoricalFillValues(fillVal,cats)
if ischar(fillVal) && any(contains(cats,fillVal)) && ~isempty(fillVal)
    TF = true;
elseif ~ischar(fillVal) && ~isnumeric(fillVal) && isscalar(fillVal) && ismissing(fillVal) 
    TF = true;
else
    error(message('MATLAB:images:validate:badFillValueForCategorical'));
end
end
