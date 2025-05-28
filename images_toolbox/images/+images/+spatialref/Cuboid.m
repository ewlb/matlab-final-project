%images.spatialref.Cuboid 3-D Cuboid region
%   CUBOID = images.spatialref.Cuboid(XLimits,YLimits,ZLimits) constructs a 3-D
%   cuboid region given XLimits, YLimits, and ZLimits, which are two-element
%   vectors that define spatial limits of the form [min,max].
%
%   See also centerCropWindow3d, randomCropWindow3d.

% Copyright 2019 The MathWorks, Inc.

classdef Cuboid
    
    properties(SetAccess = 'private')
        XLimits
        YLimits
        ZLimits
    end
    
    methods
        
        function self = Cuboid(xLimits,yLimits,zLimits)
            
            narginchk(3,3)
            
            validateattributes(xLimits,{'numeric'},{'numel',2,'vector','real','nonsparse','nondecreasing'},...
                'images.spatialref.Cuboid','xLimits');
            
            validateattributes(yLimits,{'numeric'},{'numel',2,'vector','real','nonsparse','nondecreasing'},...
                'images.spatialref.Cuboid','yLimits');
            
            validateattributes(zLimits,{'numeric'},{'numel',2,'vector','real','nonsparse','nondecreasing'},...
                'images.spatialref.Cuboid','zLimits');
            
            self.XLimits = xLimits;
            self.YLimits = yLimits;
            self.ZLimits = zLimits;
        end
        
        function TF = contains(self,xWorld,yWorld,zWorld)
            %contains True if cuboid contains points in world coordinate system
            %
            %   TF = contains(R,xWorld, yWorld, zWorld) returns a logical array TF
            %   having the same size as xWorld, yWorld, and zWorld such that TF(k) is
            %   true if and only if the point (xWorld(k), yWorld(k), zWorld(k)) falls
            %   within the bounds of the cuboid.
            
            iValidateXYZPoints(xWorld,yWorld,zWorld,'xWorld','yWorld','zWorld');
            
            TF = (xWorld >= self.XLimits(1))...
                & (xWorld <= self.XLimits(2))...
                & (yWorld >= self.YLimits(1))...
                & (yWorld <= self.YLimits(2))...
                & (zWorld >= self.ZLimits(1))...
                & (zWorld <= self.ZLimits(2));
            
        end
                
    end
    
end

function iValidateXYZPoints(X,Y,Z,xName,yName,zName)

validateattributes(X,{'numeric'},{'real','nonsparse'},'images.spatialref.Cuboid',xName);
validateattributes(Y,{'numeric'},{'real','nonsparse'},'images.spatialref.Cuboid',yName);
validateattributes(Z,{'numeric'},{'real','nonsparse'},'images.spatialref.Cuboid',zName);

if ~(isequal(size(X),size(Y)) && isequal(size(Y),size(Z)))
    error(message('images:spatialref:invalidXYZPoint',xName,yName,zName));
end

end