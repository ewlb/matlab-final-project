%images.spatialref.Rectangle 2-D Rectangular region
%   RECT = images.spatialref.Rectangle(XLimits,YLimits) constructs a 2-D
%   rectangular region given XLimits and YLimits which are two-element
%   vectors that define spatial limits of the form [min,max].
%
%   See also centerCropWindow2d, randomCropWindow2d.

% Copyright 2019 The MathWorks, Inc.

classdef Rectangle
    
    properties(SetAccess = 'private')
        XLimits
        YLimits
    end
    
    methods
        
        function self = Rectangle(xLimits,yLimits)
            narginchk(2,2)
            validateattributes(xLimits,{'numeric'},{'numel',2,'vector','real','nonsparse','nondecreasing'},...
                'images.spatialref.Rectangle','xLimits');
            
            validateattributes(yLimits,{'numeric'},{'numel',2,'vector','real','nonsparse','nondecreasing'},...
                'images.spatialref.Rectangle','yLimits');
            
            self.XLimits = xLimits;
            self.YLimits = yLimits;
        end
        
        function TF = contains(self,xWorld,yWorld)
            %contains True if rectangle contains points in world coordinate system
            %
            %   TF = contains(R,xWorld, yWorld) returns a logical array TF
            %   having the same size as xWorld, yWorld such that TF(k) is
            %   true if and only if the point (xWorld(k), yWorld(k)) falls
            %   within the rectangle bounds.
            
            iValidateXYPoints(xWorld,yWorld,'xWorld','yWorld');

            TF = (xWorld >= self.XLimits(1))...
                & (xWorld <= self.XLimits(2))...
                & (yWorld >= self.YLimits(1))...
                & (yWorld <= self.YLimits(2));
            
        end
                
    end
    
end


function iValidateXYPoints(X,Y,xName,yName)

validateattributes(X,{'numeric'},{'real','nonsparse'},'images.spatialref.Rectangle',xName);
validateattributes(Y,{'numeric'},{'real','nonsparse'},'images.spatialref.Rectangle',yName);

if ~isequal(size(X),size(Y))
    error(message('images:spatialref:invalidXYPoint',xName,yName));
end

end