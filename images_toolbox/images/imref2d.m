%imref2d Reference 2-D image to world coordinates
%
%   An imref2d object encapsulates the relationship between the "intrinsic
%   coordinates" anchored to the columns and rows of a 2-D image and the
%   spatial location of the same column and row locations in a world
%   coordinate system. The image is sampled regularly in the planar "world
%   X" and "world Y" coordinates of the coordinate system such that the
%   "intrinsic X" and "world X" axes align and likewise with the "intrinsic
%   Y" and "world Y" axes. The pixel spacing from row to row need not
%   equal the pixel spacing from column to column.
%
%   The intrinsic coordinate values (x,y) of the center point of any pixel
%   are identical to the values of the column and row subscripts for that
%   pixel. For example, the center point of the pixel in row 5, column 3
%   has intrinsic coordinates x = 3.0, y = 5.0. Be aware, however, that the
%   order of coordinate specification (3.0,5.0) is reversed in intrinsic
%   coordinates relative to pixel subscripts (5,3). Intrinsic coordinates
%   are defined on a continuous plane while the subscript locations are
%   discrete locations with integer values.
%
%   imref2d properties:
%      XWorldLimits - Limits of image in world X [xMin xMax]
%      YWorldLimits - Limits of image in world Y [yMin yMax]
%      ImageSize - Image size in each spatial dimension
%
%   imref2d properties (SetAccess = private):
%      PixelExtentInWorldX - Spacing along rows in world units
%      PixelExtentInWorldY - Spacing along columns in world units
%      ImageExtentInWorldX - Full image extent in X dimension
%      ImageExtentInWorldY - Full image extent in Y dimension
%      XIntrinsicLimits - Limits of image in intrinsic X [xMin xMax]
%      YIntrinsicLimits - Limits of image in intrinsic Y [yMin yMax]
%
%   imref2d methods:
%      imref2d - Construct imref2d object
%      sizesMatch - True if object and image are size-compatible
%      intrinsicToWorld - Convert from intrinsic to world coordinates
%      worldToIntrinsic - Convert from world to intrinsic coordinates
%      worldToSubscript - World coordinates to row and column subscripts
%      contains - True if image contains points in world coordinate system
%
%   Example 1
%   ---------
%   % Construct an imref2d object given a knowledge of world limits and
%   % image size.
%   A = imread('pout.tif');
%   xWorldLimits = [2 5];
%   yWorldLimits = [3 6];
%   RA = imref2d(size(A),xWorldLimits,yWorldLimits);
%   % Display spatially referenced image in imshow
%   figure, imshow(A,RA);
%
%   Example 2
%   ---------
%   % Construct an imref2d object given a knowledge of resolution in each
%   % dimension and image size.
%   m = dicominfo('knee1.dcm');
%   A = dicomread(m);
%   % The PixelSpacing field of the metadata of the file specifies the
%   % resolution in each dimension in millimeters/pixel. Use this information
%   % to construct a spatial referencing object associated with the image
%   % data A.
%   RA = imref2d(size(A),m.PixelSpacing(2),m.PixelSpacing(1));
%   % Examine the extent of the image in each dimension in millimeters.
%   RA.ImageExtentInWorldX
%   RA.ImageExtentInWorldY
%
%   See also imref3d, IMSHOW, IMWARP

% Copyright 2012-2018 The MathWorks, Inc.

classdef imref2d
    
    %------------------- Properties: Public + visible --------------------
    
    properties(Dependent)
                
        %XWorldLimits - Limits of image in world X [xMin xMax]
        %
        %    XWorldLimits is a two-element row vector.
        XWorldLimits
        
        %YWorldLimits - Limits of image in world Y [yMin yMax]
        %
        %    YWorldLimits is a two-element row vector.
        YWorldLimits
        
        %ImageSize Number of elements in each spatial dimension
        %
        %   ImageSize is a vector specifying the size of the image
        %   associated with the referencing object.
        ImageSize
        
    end
    
    properties(Dependent=true,SetAccess = private)
                
        %PixelExtentInWorldX - Pixel extent along rows in world units.
        PixelExtentInWorldX
        
        %PixelExtentInWorldY - Pixel extent along columns in world units.
        PixelExtentInWorldY
        
        %ImageExtentInWorldX - Full image extent in X direction
        %
        %   ImageExtentInWorldX is the extent of the image as measured in
        %   the world system in the X direction.
        ImageExtentInWorldX
        
        %ImageExtentInWorldY - Full image extent in Y direction
        %
        %   ImageExtentInWorldY is the extent of the image as measured in
        %   the world system in the Y direction.
        ImageExtentInWorldY
        
        %XIntrinsicLimits - Limits of image in intrinsic X [xMin xMax]
        %
        %    XIntrinsicLimits is a two-element row vector. For an M-by-N
        %    image (or an M-by-N-by-P image) it equals [0.5, N + 0.5].
        XIntrinsicLimits
        
        %YIntrinsicLimits - Limits of image in intrinsic Y [yMin yMax]
        %
        %    YIntrinsicLimits is a two-element row vector. For an M-by-N
        %    image (or an M-by-N-by-P image) it equals [0.5, M + 0.5].
        YIntrinsicLimits
                
    end
    
    properties (Access = private)
                
        XWorldLimitsInternal
        YWorldLimitsInternal
        ImageSizeInternal
        
    end
    
    properties (Hidden, SetAccess = private)
        
        TransformIntrinsicToWorld
        TransformWorldToIntrinsic
        
    end
    
    
    %-------------- Constructor and ordinary methods -------------------
    
    methods
        
        
        function self = imref2d(imageSize, varargin)
            %imref2d Construct imref2d object
            %
            %   R = imref2d() constructs an imref2d object with default
            %   property settings.
            %
            %   R = imref2d(imageSize) constructs an imref2d object given an
            %   image size. This syntax constructs a spatial referencing
            %   object for the default case in which the world coordinate
            %   system is co-aligned with the intrinsic coordinate system.
            %
            %   R = imref2d(imageSize, pixelExtentInWorldX,pixelExtentInWorldY)
            %   constructs an imref2d object given an image size and the
            %   resolution in each dimension defined by the scalars
            %   pixelExtentInWorldX and pixelExtentInWorldY.
            %
            %   R = imref2d(imageSize, xWorldLimits, yWorldLimits)
            %   constructs an imref2d object given an image size and the
            %   world limits in each dimension defined by the vectors
            %   xWorldLimits and yWorldLimits.
            
            validSyntaxThatSpecifiesImageSize = (nargin == 1) || (nargin == 3);
            if validSyntaxThatSpecifiesImageSize
                validateattributes(imageSize, ...
                    {'uint8','uint16','uint32','int8','int16','int32','single','double'},...
                    {'positive','real','vector','integer','finite'}, ...
                    'imref2d', ...
                    'ImageSize');
                if isscalar(imageSize)
                    error(message('images:spatialref:invalidImageSize','ImageSize'));
                end
                imageSize = double(imageSize);
                if numel(imageSize) > 2
                    imageSize = imageSize(1:2);
                end
            end
            
            if (nargin ==0)
                % imref2d()
                
                self.XWorldLimitsInternal = [0.5,2.5];
                self.YWorldLimitsInternal = [0.5,2.5];
                self.ImageSizeInternal = [2,2];
                
            elseif (nargin == 1)
                % imref2d(imageSize)
                self.ImageSizeInternal = imageSize;
                self.XWorldLimitsInternal = [0.5,imageSize(2)+0.5];
                self.YWorldLimitsInternal = [0.5,imageSize(1)+0.5];
            else
                narginchk(3,3);
                
                if isscalar(varargin{1})
                    % imref2d(imageSize,pixelExtentInWorldX,pixelExtentInWorldY)
                    pixelExtentInWorldX = varargin{1};
                    pixelExtentInWorldY = varargin{2};
                    
                    validateattributes(pixelExtentInWorldX,{'numeric'},{'scalar','finite','positive'},...
                        mfilename,'PixelExtentInWorldX');
                    
                    validateattributes(pixelExtentInWorldY,{'numeric'},{'scalar','finite','positive'},...
                        mfilename,'PixelExtentInWorldY');
                    
                    pixelExtentInWorldX = double(pixelExtentInWorldX);
                    pixelExtentInWorldY = double(pixelExtentInWorldY);
                    self.ImageSizeInternal = imageSize;
                    self.XWorldLimitsInternal = [pixelExtentInWorldX/2,pixelExtentInWorldX/2+pixelExtentInWorldX*imageSize(2)];
                    self.YWorldLimitsInternal = [pixelExtentInWorldY/2,pixelExtentInWorldY/2+pixelExtentInWorldY*imageSize(1)];
                else
                    % imref2d(imageSize,xWorldLimits,yWorldLimits)
                    self.ImageSizeInternal = imageSize;
                    
                    xWorldLimits = varargin{1};
                    yWorldLimits = varargin{2};
                    iValidateWorldLimits(xWorldLimits,'X');
                    iValidateWorldLimits(yWorldLimits,'Y');

                    self.XWorldLimitsInternal = double(xWorldLimits);
                    self.YWorldLimitsInternal = double(yWorldLimits);
                end
                
            end
            
            self = self.recomputeTransforms();
            
        end
        
        
        function [xw,yw] = intrinsicToWorld(self,xIntrinsic,yIntrinsic)
            %intrinsicToWorld Convert from intrinsic to world
            %coordinates
            %
            %   [xWorld, yWorld] = intrinsicToWorld(R,...
            %   xIntrinsic,yIntrinsic) maps point locations from the
            %   intrinsic system (xIntrinsic, yIntrinsic) to the world
            %   system (xWorld, yWorld) based on the relationship defined
            %   by the referencing object R. The input may include values
            %   that fall completely outside limits of the image in the
            %   intrinsic system. In this case world X and Y are
            %   extrapolated outside the bounds of the image in the world
            %   system.
            
            iValidateXYPoints(xIntrinsic,yIntrinsic,'xIntrinsic','yIntrinsic');
            
            [xw,yw] = intrinsicToWorldAlgo(self,xIntrinsic,yIntrinsic);
            
        end
        
        function [xi,yi] = worldToIntrinsic(self,xWorld,yWorld)
            %worldToIntrinsic Convert from world to intrinsic coordinates
            %
            %   [xIntrinsic, yIntrinsic] = worldToIntrinsic(R,...
            %   xWorld, yWorld) maps point locations from the
            %   world system (xWorld, yWorld) to the intrinsic
            %   system (xIntrinsic, yIntrinsic) based on the relationship
            %   defined by the referencing object R. The input may
            %   include values that fall completely outside limits of
            %   the image in the world system. In this case world X and Y
            %   are extrapolated outside the bounds of the image in the
            %   intrinsic system.
            
            iValidateXYPoints(xWorld,yWorld,'xWorld','yWorld');
            
            [xi,yi] = worldToIntrinsicAlgo(self,xWorld,yWorld);
          
        end
        
        function [r,c] = worldToSubscript(self,xWorld,yWorld)
            %worldToSubscript World coordinates to row and column subscripts
            %
            %   [I,J] = worldToSubscript(R,xWorld, yWorld) maps point
            %   locations from the world system (xWorld,yWorld) to
            %   subscript arrays I and J based on the relationship defined
            %   by the referencing object R. I and J are the row and column
            %   subscripts of the image pixels containing each element of a
            %   set of points given their world coordinates (xWorld,
            %   yWorld). xWorld and yWorld must have the same size. I and J
            %   will have the same size as xWorld and yWorld. For an M-by-N
            %   image, 1 <= I <= M and 1 <= J <= N, except when a point
            %   xWorld(k), yWorld(k) falls outside the image, as defined by
            %   contains(R,xWorld, yWorld), then both I(k) and J(k) are
            %   NaN.
            
            iValidateXYPoints(xWorld,yWorld,'xWorld','yWorld');
            
            [r,c] = worldToSubscriptAlgo(self,xWorld,yWorld);
            
        end
        
        function TF = contains(self,xWorld,yWorld)
            %contains True if image contains points in world coordinate system
            %
            %   TF = contains(R,xWorld, yWorld) returns a logical array TF
            %   having the same size as xWorld, yWorld such that TF(k) is
            %   true if and only if the point (xWorld(k), yWorld(k)) falls
            %   within the bounds of the image associated with
            %   referencing object R.
            
            iValidateXYPoints(xWorld,yWorld,'xWorld','yWorld');
            
            TF = containsAlgo(self,xWorld,yWorld);
            
        end
        
        function TF = sizesMatch(self,I)
            %sizesMatch True if object and image are size-compatible
            %
            %   TF = sizesMatch(R,A) returns true if the size of the image A is consistent with the ImageSize property of
            %   the referencing object R. That is,
            %
            %           R.ImageSize == [size(A,1) size(A,2)].
            imageSize = size(I);
            TF = isequal(imageSize(1),self.ImageSize(1))...
                && isequal(imageSize(2),self.ImageSize(2));
        end
        
        
    end
    
    
    %----------------- Get methods ------------------
    methods
        
        function width = get.ImageExtentInWorldX(self)
            width = diff(self.XWorldLimits);
        end
        
        function height = get.ImageExtentInWorldY(self)
            height = diff(self.YWorldLimits);
        end
        
        function extentX = get.PixelExtentInWorldX(self)
            extentX = diff(self.XWorldLimits) ./ self.ImageSize(2);
        end
        
        function extentY = get.PixelExtentInWorldY(self)
            extentY = diff(self.YWorldLimits) ./ self.ImageSize(1);
        end
        
        function limits = get.XIntrinsicLimits(self)
            limits = [0.5,self.ImageSize(2)+0.5];
        end
        
        function limits = get.YIntrinsicLimits(self)
            limits = [0.5,self.ImageSize(1)+0.5];
        end
        
        function lim = get.XWorldLimits(self)
            lim = self.XWorldLimitsInternal;
        end
        
        function lim = get.YWorldLimits(self)
            lim = self.YWorldLimitsInternal;
        end
        
        function sz = get.ImageSize(self)
            sz = self.ImageSizeInternal;
        end
        
    end
    
    
    %----------------- Set methods ------------------
    methods
        
        function self = set.XWorldLimits(self, worldLimits)
            iValidateWorldLimits(worldLimits,'X');
            self.XWorldLimitsInternal = worldLimits;
            self = self.recomputeTransforms();
        end
        
        function self = set.YWorldLimits(self, worldLimits)
            iValidateWorldLimits(worldLimits,'Y');
            self.YWorldLimitsInternal = worldLimits;
            self = self.recomputeTransforms();
        end
        
        function self = set.ImageSize(self,imSize)
            
            validateattributes(imSize, ...
                {'uint8','uint16','uint32','int8','int16','int32','single','double'},...
                {'positive','real','vector','integer','finite'}, ...
                'imref2d.set.ImageSize', ...
                'ImageSize');
            
            if isscalar(imSize)
                error(message('images:spatialref:invalidImageSize','ImageSize'));
            end
            
            self.ImageSizeInternal = double(imSize);
            
            self = self.recomputeTransforms();
            
        end
        
    end
    
    % saveobj and loadobj are implemented to ensure compatibility across
    % releases even if architecture of spatial referencing classes
    % changes.
    methods (Hidden)
        
        function S = saveobj(self)
            
            S = struct('ImageSize',self.ImageSize,...
                'XWorldLimits',self.XWorldLimits,...
                'YWorldLimits',self.YWorldLimits);
            
        end
        
        function [xw,yw] = intrinsicToWorldAlgo(self,xIntrinsic,yIntrinsic)
            
            M = self.TransformIntrinsicToWorld;
            xw = M(1,1).*xIntrinsic + M(3,1);
            yw = M(2,2).*yIntrinsic + M(3,2);
            
        end
        
        function [xi,yi] = worldToIntrinsicAlgo(self,xWorld,yWorld)
            
            M = self.TransformWorldToIntrinsic;
            xi = M(1,1).*xWorld + M(3,1);
            yi = M(2,2).*yWorld + M(3,2);
            
        end
        
        function [r,c] = worldToSubscriptAlgo(self,xWorld,yWorld)
            
            TF = containsAlgo(self,xWorld,yWorld);
            [c,r] = worldToIntrinsicAlgo(self,xWorld,yWorld);
            
            r(TF) = max(1, min(round(r(TF)), self.ImageSize(1)));
            c(TF) = max(1, min(round(c(TF)), self.ImageSize(2)));
            
            r(~TF) = nan;
            c(~TF) = nan;
            
        end
        
        function TF = containsAlgo(self,xWorld,yWorld)
            
            TF = (xWorld >= self.XWorldLimits(1))...
                & (xWorld <= self.XWorldLimits(2))...
                & (yWorld >= self.YWorldLimits(1))...
                & (yWorld <= self.YWorldLimits(2));
            
        end
        
    end
    
    methods (Static, Hidden)
        
        function self = loadobj(S)
            
            self = imref2d(S.ImageSize,S.XWorldLimits,S.YWorldLimits);
            
        end
        
    end
    
    methods (Access = private)
        
        function self = recomputeTransforms(self)
            
            sx = self.PixelExtentInWorldX;
            sy = self.PixelExtentInWorldY;
            tx = self.XWorldLimits(1);
            ty = self.YWorldLimits(1);            
            shiftFirstPixelToOrigin = [1 0 0; 0 1 0; -0.5 -0.5 1];
            self.TransformIntrinsicToWorld = shiftFirstPixelToOrigin * [sx 0 0; 0 sy 0; tx ty 1] ;
            
            sx = 1/self.PixelExtentInWorldX;
            sy = 1/self.PixelExtentInWorldY;
            tx = (self.XIntrinsicLimits(1))-1/self.PixelExtentInWorldX*self.XWorldLimits(1);
            ty = (self.YIntrinsicLimits(1))-1/self.PixelExtentInWorldY*self.YWorldLimits(1);
            self.TransformWorldToIntrinsic = [sx 0 0; 0 sy 0; tx ty 1];
            
        end
                        
    end
    
    %-----------------------------------------------------------------------
    methods(Access=private, Static)
        function name = matlabCodegenRedirect(~)
            name = 'images.internal.coder.imref2d';
        end
    end
    
end

function iValidateXYPoints(X,Y,xName,yName)

validateattributes(X,{'numeric'},{'real','nonsparse'},'imref2d',xName);
validateattributes(Y,{'numeric'},{'real','nonsparse'},'imref2d',yName);

if ~isequal(size(X),size(Y))
    error(message('images:spatialref:invalidXYPoint',xName,yName));
end

end

function iValidateWorldLimits(worldLimits,dimStr)

validateattributes(worldLimits, ...
    {'double','single'}, {'real','finite','size',[1 2]}, ...
    'imref2d', ...
    sprintf('%sWorldLimits',dimStr));

if (worldLimits(2) <= worldLimits(1))
    error(message('images:spatialref:expectedAscendingLimits',...
        sprintf('%sWorldLimits',dimStr)));
end

end
