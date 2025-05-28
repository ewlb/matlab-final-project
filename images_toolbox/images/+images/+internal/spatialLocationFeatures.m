function varargout = spatialLocationFeatures(I,type)
%SPATIALLOCATIONFEATURES Spatial Location Values for an input image/volume.
%   [X,Y] = spatialLocationFeatures(I,'2d') takes an image I and returns the X
%   and Y spatial locations for each pixel in the input image.
%
%   [X,Y,Z] = spatialLocationFeatures(V,'3d') takes a volume V and returns the
%   X, Y and Z locations for each voxel in the input volume.
%
%   Class Support 
%   -------------
%
%   Input must be a grayscale,color or hyperspectral image or 3D volume and
%   can be of class uint8, int8, uint16, int16, uint32, int32, single, or
%   double. It must be real, finite and nonsparse. The outputs are of class
%   single. If type is '2d' outputs maintain first two dimensions of input,
%   else if type is '3d' they maintain first three dimensions of input.
%
%   Notes
%   -----
%   This function serves as a helper function to imsegkmeans. It finds the
%   spatial locations that can be used to augment the input data as
%   additional feature to yield a better segmentation.

%   Copyright 2018 The MathWorks, Inc.
narginchk(2,2);
validateInp(I);
type = matlab.images.internal.stringToChar(type);
type = validatetype(type);
[m,n,p,~] = size(I);
x=1:n; % number of Columns
y=1:m; % number of Rows
if strcmp(type,'2d')
    z=1;
elseif strcmp(type,'3d')
    z=1:p; % number of Planes in 3d grayscale volume
end

[X,Y,Z] = meshgrid(x,y,z);
varargout{1} = single(X);
varargout{2} = single(Y);

if strcmp(type,'3d')
    varargout{3} = single(Z);
end

function validateInp(I)

validateattributes(I, {'numeric'} , {'nonempty',...
    'nonsparse', 'real', 'finite', '3d'}, mfilename, 'I');

function type = validatetype(type)

validateattributes(type, {'char'}, {}, mfilename, 'type');
type = validatestring(type, {'2d' , '3d'} , mfilename, 'type');


