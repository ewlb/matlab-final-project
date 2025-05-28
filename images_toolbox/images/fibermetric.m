function B = fibermetric(V,varargin)
%FIBERMETRIC Enhance elongated or tubular structures in images or 3D grayscale volumes.
%   B = FIBERMETRIC(A) enhances tubular structures in intensity image A
%   using Hessian based multiscale filtering. B contains the maximum
%   response of the filter at a thickness that approximately matches the
%   size of the tubular structure to detect.
%
%   B = FIBERMETRIC(V, ___) enhances tubular structures in the volume V.
%
%   B = FIBERMETRIC(A, THICKNESS) enhances the tubular structures of
%   thickness THICKNESS in A. THICKNESS is a scalar or a vector in pixels
%   which characterizes the thickness of tubular structures. It should be
%   of the order of the width of the tubular structures in the image
%   domain. When not provided, THICKNESS is [4, 6, 8, 10, 12, 14].
%
%   B = FIBERMETRIC(___, Name, Value) enhances the tubular structures in
%   the image using name-value pairs to control different aspects of the
%   filtering algorithm.
%
%   Parameters include:
%   'StructureSensitivity' - Specifies the sensitivity/threshold for
%                            differentiating the tubular structure from the
%                            background and is dependent on the gray scale
%                            range of the image. Default value is
%                            0.01*diff(getrangefromclass(V)).
%
%   'ObjectPolarity' - Specifies the polarity of the tubular structures
%   with respect to the background. Available options are:
%
%           'bright'     : The structure is brighter than the background.(Default)
%           'dark'       : The structure is darker than the background.
%
%   Class Support
%   -------------
%   Input image A must be a 2D grayscale image or a 3D volumetric image and
%   can be of class uint8, int8, uint16, int16, uint32, int32, single, or double. 
%   It must be real and nonsparse. The output variable B is of class single unless the
%   input is of type double in which case the output is also double.
%
%   Remarks
%   -------
%
%   The function FIBERMETRIC changed in version 9.4 (R2018b). Previous versions
%   of the Image Processing Toolbox used a different default for the
%   parameter 'StructuralSensitivity' which used to be half the 
%   maximum of Hessian norm. If you need the same results produced
%   by the previous implementation use the function 'maxhessiannorm' to
%   to find the 'StructureSensitivity' value which is 0.5*(output of maxhessiannorm).  
%   This is only supported for 2D images. 
%
%   Reference
%   ---------
%   Frangi, Alejandro F., et al. "Multiscale vessel enhancement filtering."
%   Medical Image Computing and Computer-Assisted Intervention -- MICCAI 1998.
%   Springer Berlin Heidelberg, 1998. 130-137
%
%   Example
%   -------
%       % Find threads approximately 7 pixels thick
%       A = imread('threads.png');
%       B = fibermetric(A, 7, 'ObjectPolarity', 'dark', 'StructureSensitivity', 7);
%       figure; imshow(B); title('Possible tubular structures 7 pixels thick')
%       C = B > 0.15;
%       figure; imshow(C); title('Thresholded result')
%
%   See also edge, imgradient.

%   Copyright 2016-2020 The MathWorks, Inc.

matlab.images.internal.errorIfgpuArray(V,varargin{:});

args = matlab.images.internal.stringToChar(varargin);
[thickness, c, objPolarity] = parseInputs(V, args{:});
thickness = double(thickness);

% Passing object Polarity as a boolean flag to C++ code (instead of string)
if strcmp(objPolarity,'bright')
    isBright=true;
elseif strcmp(objPolarity,'dark')
    isBright=false;
end

% Casting input to single if non-floating datatype
classOriginalData = class(V); 

% Default value for Structural Sensitivity := datatypeRange/100
if isempty(c)
    c = cast(diff(getrangefromclass(V))/100,classOriginalData);
end
switch (classOriginalData)
    case 'uint32'
        V = double(V);
    case 'double'
    otherwise
        V = single(V);
end

% Output can be double or single
B = zeros(size(V),'like',V);

for id = 1:numel(thickness)
    
    sigma = thickness(id)/6;
    if (ismatrix(V))
        Ig = imgaussfilt(V, sigma, 'FilterSize', 2*ceil(3*sigma)+1);
    elseif (ndims(V)==3)
        Ig = imgaussfilt3(V,sigma, 'FilterSize', 2*ceil(3*sigma)+1);
    end
    
    out = images.internal.builtins.fibermetric(Ig, c, isBright, sigma);    
    B = max(B,out);
end

end

function [thickness, c, objPolarity] = parseInputs(A, varargin)

narginchk(1,6);
validateInp(A);
parser = inputParser();
parser.PartialMatching = true;
parser.addOptional('Thickness', 4:2:14, @validateThickness);
parser.addParameter('StructureSensitivity', [], @validateStructureSensitivity);
parser.addParameter('ObjectPolarity','bright', @validateObjectPolarity);
parser.parse(varargin{:});
parsedInputs = parser.Results;

thickness   = parsedInputs.Thickness;
c           = parsedInputs.StructureSensitivity;
objPolarity = validatestring(parsedInputs.ObjectPolarity, {'bright','dark'});

end


function validateInp(A)

allowedImageTypes = {'uint8', 'uint16', 'uint32', 'double', 'single', 'int8', 'int16', 'int32'};
validateattributes(A, allowedImageTypes, {'nonempty',...
    'nonsparse', 'real', 'finite', '3d'}, mfilename, 'A', 1);
anyDimensionOne = any(size(A) == 1);
if (isvector(A) || anyDimensionOne)
    error(message('images:fibermetric:imageNot2or3D'));
end

end


function tf = validateThickness(thickness)

validateattributes(thickness, {'numeric'}, ...
    {'integer', 'nonsparse', 'nonempty', 'positive', 'finite', 'vector'}, ...
    mfilename, 'THICKNESS', 2);

tf = true;

end


function tf = validateStructureSensitivity(x)

validateattributes(x, {'numeric'}, ...
    {'scalar', 'real', 'positive', 'finite', 'nonsparse', 'nonempty'}, ...
    mfilename, 'StructureSensitivity');

tf = true;

end


function tf = validateObjectPolarity(x)

validateattributes(x, {'char'}, {}, mfilename, 'ObjectPolarity');
validatestring(x, {'bright','dark'}, mfilename, 'ObjectPolarity');

tf = true;

end

