function VOUT = imcrop3(varargin)
%IMCROP3 Crop a 3-D image.
%   VOUT = IMCROP3(V, CUBOID)returns a cropped 3-D sub-volume based on the
%   extents specified by CUBOID. CUBOID is a 6-element vector with the form 
%   [XMIN YMIN ZMIN WIDTH HEIGHT DEPTH];these values are specified in 
%   spatial coordinates. CUBOID can also be specified as a 
%   images.spatialref.Cuboid object which holds the X, Y and Z index ranges 
%   of the sub-volume to be cropped.
%
%   Class Support
%   -------------
%   The input volume, V can be logical, numeric or categorical, 3-D 
%   grayscale volume or multi-channel 3-D volume. CUBOID is a 1x6 numeric  
%   or an object of images.spatialref.Cuboid type.
%
%   The output image, VOUT has the same class as the input volume.
%
%
%   Example 1
%   ---------
%   D = load('mristack');
%   V = D.mristack;
%
%   VOUT = imcrop3(V,[30 40 10 100 100 10]);
%   figure, volshow(V)
%   figure, volshow(VOUT)
%
%   Example 2
%   --------- 
%   % Center crop input volume to desired target size
%   S = load('mri.mat','D');
%   volumeData = squeeze(S.D);
%   targetSize = [10,10,10]; 
%   win = centerCropWindow3d(size(volumeData),targetSize);
%   croppedVolume = imcrop3(volumeData, win);
%   volshow(croppedVolume);
%
%   See also images.spatialref.cuboid, randomCropWindow3d, centerCropWindow3d, imcrop.
 
%  Copyright 2019 The MathWorks, Inc.

narginchk(2,2);

[V, xLimits, yLimits, zLimits, isCuboidOutofBounds] = parseInputs(varargin{:});

if isCuboidOutofBounds
    VOUT = [];
    warning(message('images:imcrop3:cropCuboidDoesNotIntersectVolume'));
else
    % Crop the input volume
    VOUT =  V(yLimits(1):yLimits(2), xLimits(1):xLimits(2), zLimits(1):zLimits(2),:);
end

end

function [V, xLimits, yLimits, zLimits, isCuboidOutofBounds] = parseInputs(varargin)

    V = varargin{1};
    cuboidWindow = varargin{2}; 
    %X, Y and Z limits stored as - [lowIndex highIndex]
    xLimits = [];
    yLimits = [];
    zLimits = [];
    
    validateVolume(V);
    
    if(isnumeric(cuboidWindow))
        % cuboid specified as [x, y, z, w, h, d]
        validateCuboid(cuboidWindow);
        
        % Clip upper and lower limits to the image bounds.
        width  = cuboidWindow(4);
        height = cuboidWindow(5);
        depth  = cuboidWindow(6);
        xLimits(1) = round(cuboidWindow(1));
        xLimits(2) = round(cuboidWindow(1)+width);
        
        yLimits(1) = round(cuboidWindow(2));
        yLimits(2) = round(cuboidWindow(2)+height);
        
        zLimits(1) = round(cuboidWindow(3));
        zLimits(2) = round(cuboidWindow(3)+depth);
        
        
    elseif isa(cuboidWindow,'images.spatialref.Cuboid')
        
        xLimits = round(cuboidWindow.XLimits);
        yLimits = round(cuboidWindow.YLimits);
        zLimits = round(cuboidWindow.ZLimits);
        
    else
        error(message('images:imcrop3:invalidCuboidSpecification'));
    end
    
    isCuboidOutofBounds = validateCuboidBounds(V, xLimits, yLimits, zLimits);
        
end

function validateVolume(V)

validateattributes(V,{'numeric', 'categorical', 'logical'}, ...
                {'real','nonsparse','nonempty'}, mfilename, 'V', 1);
            
end


function validateCuboid(cuboid)

validateattributes(cuboid,{'numeric'},{'real','vector'}, ...
    mfilename,'CUBOID',2);

% cuboid must contain 6 elements: [x,y,z,w,h,d]
if(numel(cuboid) ~= 6)
    error(message('images:validate:badInputNumel',2,'CUBOID',6));
end

end

function isCuboidOutofBounds = validateCuboidBounds(V, xLimits, yLimits, zLimits)

% validate cuboid bounds
isCuboidOutofBounds = false;

% Check X bounds
isCuboidOutofBounds = isCuboidOutofBounds||...
                        (xLimits(1) < 1) || (xLimits(1) > size(V,2)) ||...
                        (xLimits(2) < 1) || (xLimits(2) > size(V,2));

% Check Y bounds
isCuboidOutofBounds = isCuboidOutofBounds||...
                        (yLimits(1) < 1) || (yLimits(1) > size(V,1)) ||...
                        (yLimits(2) < 1) || (yLimits(2) > size(V,1));

% Check Z bounds
isCuboidOutofBounds = isCuboidOutofBounds||...
                        (zLimits(1) < 1) || (zLimits(1) > size(V,3)) ||...
                        (zLimits(2) < 1) || (zLimits(2) > size(V,3));
                    
if isCuboidOutofBounds
    error(message('images:imcrop3:cropCuboidOutofBounds'));
end

end




