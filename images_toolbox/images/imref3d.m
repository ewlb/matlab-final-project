%imref3d Reference 3-D image to world coordinates
%
%   An imref3d object encapsulates the relationship between the "intrinsic
%   coordinates" anchored to the columns, rows, and planes of a 3-D image and the
%   spatial location of the same column, row, and plane locations in a world
%   coordinate system. The image is sampled regularly in the planar "world
%   X", "world Y", and "world Z" coordinates of the coordinate system such that the
%   "intrinsic" and "world" axes align. The pixel spacing in each dimension
%   may be different.
%
%   The intrinsic coordinate values (x,y,z) of the center point of any
%   pixel are identical to the values of the column, row, and plane
%   subscripts for that pixel. For example, the center point of the pixel
%   in row 5, column 3, plane 4 has intrinsic coordinates x = 3.0, y = 5.0,
%   z = 4.0. Be aware, however, that the order of the XY coordinate
%   specification (3.0,5.0,4.0) is reversed in intrinsic coordinates
%   relative to pixel subscripts (5,3,4). Intrinsic coordinates are defined
%   on a continuous plane while the subscript locations are discrete
%   locations with integer values.
%
%   imref3d properties:
%      XWorldLimits - Limits of image in world X [xMin xMax]
%      YWorldLimits - Limits of image in world Y [yMin yMax]
%      ZWorldLimits - Limits of image in world Z [zMin zMax]
%      ImageSize - Image size in each spatial dimension
%
%   imref3d properties (SetAccess = private):
%      PixelExtentInWorldX - Spacing along rows in world units
%      PixelExtentInWorldY - Spacing along columns in world units
%      PixelExtentInWorldZ - Spacing across planes in world units
%      ImageExtentInWorldX - Full image extent in X dimension
%      ImageExtentInWorldY - Full image extent in Y dimension
%      ImageExtentInWorldZ - Full image extent in Z dimension
%      XIntrinsicLimits - Limits of image in intrinsic X [xMin xMax]
%      YIntrinsicLimits - Limits of image in intrinsic Y [yMin yMax]
%      ZIntrinsicLimits - Limits of image in intrinsic Z [zMin zMax]
%
%   imref3d methods:
%      imref3d - Construct imref3d object
%      sizesMatch - True if object and image are size-compatible
%      intrinsicToWorld - Convert from intrinsic to world coordinates
%      worldToIntrinsic - Convert from world to intrinsic coordinates
%      worldToSubscript - World coordinates to row and column subscripts
%      contains - True if image contains points in world coordinate system
%
%   Example 1
%   ---------
%   % Construct an imref3d object given a knowledge of resolution in each
%   % dimension and image size.
%   m = analyze75info('brainMRI.hdr');
%   A = analyze75read(m);
%   % The PixelDimensions field of the metadata of the file specifies the
%   % resolution in each dimension in millimeters/pixel. Use this information
%   % to construct a spatial referencing object associated with the image
%   % data A.
%   RA = imref3d(size(A),m.PixelDimensions(2),m.PixelDimensions(1),m.PixelDimensions(3));
%   % Examine the extent of the image in each dimension in millimeters.
%   RA.ImageExtentInWorldX
%   RA.ImageExtentInWorldY
%   RA.ImageExtentInWorldZ
%
%   See also imref2d, imwarp

% Copyright 2012-2018 The MathWorks, Inc.

classdef imref3d
    
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
        
        %ZWorldLimits - Limits of image in world Z [zMin zMax]
        %
        %    ZWorldLimits is a two-element row vector.
        ZWorldLimits
        
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
        
        %PixelExtentInWorldZ - Pixel extent along planes in world units.
        PixelExtentInWorldZ
        
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
        
        %ImageExtentInWorldZ - Full image extent in Z direction
        %
        %   ImageExtentInWorldZ is the extent of the image as measured in
        %   the world system in the Z direction.
        ImageExtentInWorldZ
        
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
        
        %ZIntrinsicLimits - Limits of image in intrinsic Z [zMin zMax]
        %
        %    ZIntrinsicLimits is a two-element row vector. For an M-by-N
        %    image (or an M-by-N-by-P image) it equals [0.5, M + 0.5].
        ZIntrinsicLimits
                
    end
    
    properties (Access = private)
                
        XWorldLimitsInternal
        YWorldLimitsInternal
        ZWorldLimitsInternal
        ImageSizeInternal
        
    end
    
    properties(Hidden,SetAccess = private)
        
        TransformIntrinsicToWorld
        TransformWorldToIntrinsic
        
    end
    
    
    %-------------- Constructor and ordinary methods -------------------
    
    methods
        
        
        function self = imref3d(imageSize, varargin)
            %imref3d Construct imref3d object
            %
            %   R = imref3d() constructs an imref3d object with default
            %   property settings.
            %
            %   R = imref3d(imageSize) constructs an imref3d object given an
            %   image size. This syntax constructs a spatial referencing
            %   object for the default case in which the world coordinate
            %   system is co-aligned with the intrinsic coordinate system.
            %
            %   R = imref3d(imageSize,pixelExtentInWorldX,pixelExtentInWorldY,pixelExtentInWorldZ)
            %   constructs an imref3d object given an image size and the
            %   resolution in each dimension defined by the scalars
            %   pixelExtentInWorldX, pixelExtentInWorldY, and
            %   pixelExtentInWorldZ.
            %
            %   R = imref3d(imageSize,xWorldLimits,yWorldLimits,zWorldLimits)
            %   constructs an imref3d object given an image size and the
            %   world limits in each dimension defined by the vectors xWorldLimits,
            %   yWorldLimits and zWorldLimits.
            
            validSyntaxThatSpecifiesImageSize = (nargin == 1) || (nargin == 4);
            if validSyntaxThatSpecifiesImageSize
                validateattributes(imageSize, ...
                    {'uint8','uint16','uint32','int8','int16','int32','single','double'},...
                    {'positive','real','vector','integer','finite'}, ...
                    mfilename, ...
                    'ImageSize');
                if numel(imageSize) ~=3
                    error(message('images:spatialref:invalid3dImageSize','ImageSize'));
                end
                imageSize = double(imageSize);
            end
            
            if (nargin ==0)
                % imref3d()
                
                self.XWorldLimitsInternal = [0.5,2.5];
                self.YWorldLimitsInternal = [0.5,2.5];
                self.ZWorldLimitsInternal = [0.5,2.5];
                
                self.ImageSizeInternal = [2,2,2];
                
            elseif (nargin == 1)
                % imref3d(imageSize)
                self.ImageSizeInternal = imageSize;
                self.XWorldLimitsInternal = [0.5,imageSize(2)+0.5];
                self.YWorldLimitsInternal = [0.5,imageSize(1)+0.5];
                self.ZWorldLimitsInternal = [0.5,imageSize(3)+0.5];
                
            else
                narginchk(4,4);
                
                if isscalar(varargin{1})
                    % imref3d(imageSize,pixelExtentInWorldX,pixelExtentInWorldY,pixelExtentInWorldZ)
                    pixelExtentInWorldX = varargin{1};
                    pixelExtentInWorldY = varargin{2};
                    pixelExtentInWorldZ = varargin{3};
                    
                    validateattributes(pixelExtentInWorldX,{'numeric'},{'scalar','finite','positive'},...
                        mfilename,'PixelExtentInWorldX');
                    
                    validateattributes(pixelExtentInWorldY,{'numeric'},{'scalar','finite','positive'},...
                        mfilename,'PixelExtentInWorldY');
                    
                    validateattributes(pixelExtentInWorldZ,{'numeric'},{'scalar','finite','positive'},...
                        mfilename,'PixelExtentInWorldZ');
                    
                    pixelExtentInWorldX = double(pixelExtentInWorldX);
                    pixelExtentInWorldY = double(pixelExtentInWorldY);
                    pixelExtentInWorldZ = double(pixelExtentInWorldZ);
                    
                    self.ImageSizeInternal = imageSize;
                    self.XWorldLimitsInternal = [pixelExtentInWorldX/2,pixelExtentInWorldX/2+pixelExtentInWorldX*imageSize(2)];
                    self.YWorldLimitsInternal = [pixelExtentInWorldY/2,pixelExtentInWorldY/2+pixelExtentInWorldY*imageSize(1)];
                    self.ZWorldLimitsInternal = [pixelExtentInWorldZ/2,pixelExtentInWorldZ/2+pixelExtentInWorldZ*imageSize(3)];
                    
                else
                    % imref3d(imageSize,xWorldLimits,yWorldLimits,zWorldLimits)
                    self.ImageSizeInternal = imageSize;
                    
                    xWorldLimits = varargin{1};
                    yWorldLimits = varargin{2};
                    zWorldLimits = varargin{3};
                    iValidateWorldLimits(xWorldLimits,'X');
                    iValidateWorldLimits(yWorldLimits,'Y');
                    iValidateWorldLimits(yWorldLimits,'Z');
                    
                    self.XWorldLimitsInternal = double(xWorldLimits);
                    self.YWorldLimitsInternal = double(yWorldLimits);
                    self.ZWorldLimitsInternal = double(zWorldLimits);
                    
                end
                
            end
            
            self = self.recomputeTransforms();
            
        end
        
        
        function [xw,yw,zw] = intrinsicToWorld(self,xIntrinsic,yIntrinsic,zIntrinsic)
            %intrinsicToWorld Convert from intrinsic to world
            %coordinates
            %
            %   [xWorld, yWorld, zWorld] = intrinsicToWorld(R,...
            %   xIntrinsic,yIntrinsic,zIntrinsic) maps point locations from
            %   the intrinsic system (xIntrinsic, yIntrinsic, zIntrinsic)
            %   to the world system (xWorld, yWorld, zWorld) based on the
            %   relationship defined by the referencing object R. The input
            %   may include values that fall completely outside limits of
            %   the image in the intrinsic system. In this case world X, Y,
            %   and Z are extrapolated outside the bounds of the image in
            %   the world system.
            
            iValidateXYZPoints(xIntrinsic,yIntrinsic,zIntrinsic,'xIntrinsic','yIntrinsic','zIntrinsic');
            
            [xw,yw,zw] = intrinsicToWorldAlgo(self,xIntrinsic,yIntrinsic,zIntrinsic);
            
        end
        
        function [xi,yi,zi] = worldToIntrinsic(self,xWorld,yWorld,zWorld)
            %worldToIntrinsic Convert from world to intrinsic coordinates
            %
            %   [xIntrinsic, yIntrinsic, zIntrinsic] = worldToIntrinsic(R,...
            %   xWorld, yWorld, zWorld) maps point locations from the world
            %   system (xWorld, yWorld, zWorld) to the intrinsic system
            %   (xIntrinsic, yIntrinsic, zIntrinsic) based on the
            %   relationship defined by the referencing object R. The input
            %   may include values that fall completely outside limits of
            %   the image in the world system. In this case world X, Y, and
            %   Z are extrapolated outside the bounds of the image in the
            %   intrinsic system.
            
            iValidateXYZPoints(xWorld,yWorld,zWorld,'xWorld','yWorld','zWorld');
            
            [xi,yi,zi] = worldToIntrinsicAlgo(self,xWorld,yWorld,zWorld);
            
            
        end
        
        function [r,c,p] = worldToSubscript(self,xWorld,yWorld,zWorld)
            %worldToSubscript World coordinates to row,column,plane subscripts
            %
            %   [I,J,K] = worldToSubscript(R,xWorld, yWorld, zWorld) maps point
            %   locations from the world system (xWorld,yWorld,zWorld) to
            %   subscript arrays (I,J,K) based on the relationship defined
            %   by the referencing object R. xWorld, yWorld, and
            %   zWorld must have the same size. I, J, and K will have the
            %   same size as xWorld, yWorld, and zWorld. For an M-by-N-by-P
            %   image, 1 <= I <= M, 1 <= J <= N, and 1 <= K <= P except
            %   when a point xWorld(k), yWorld(k), zWorld(k) falls outside
            %   the image, as defined by contains(R,xWorld, yWorld,
            %   zWorld), then I(k), J(k), and K(k) are NaN.
            
            iValidateXYZPoints(xWorld,yWorld,zWorld,'xWorld','yWorld','zWorld');
            
            [r,c,p] = worldToSubscriptAlgo(self,xWorld,yWorld,zWorld);
            
        end
        
        function TF = contains(self,xWorld,yWorld,zWorld)
            %contains True if image contains points in world coordinate system
            %
            %   TF = contains(R,xWorld, yWorld, zWorld) returns a logical array TF
            %   having the same size as xWorld, yWorld, and zWorld such that TF(k) is
            %   true if and only if the point (xWorld(k), yWorld(k), zWorld(k)) falls
            %   within the bounds of the image associated with
            %   referencing object R.
            
            iValidateXYZPoints(xWorld,yWorld,zWorld,'xWorld','yWorld','zWorld');
            
            TF = containsAlgo(self,xWorld,yWorld,zWorld);
            
        end
        
        function TF = sizesMatch(self,I)
            %sizesMatch True if object and image are size-compatible
            %
            %   TF = sizesMatch(R,A) returns true if the size of the image A is consistent with the ImageSize property of
            %   the referencing object R. That is,
            %
            %           R.ImageSize == [size(A,1) size(A,2) size(A,3)].
                        
            imageSize = size(I);
            if ~isequal(size(self.ImageSize), size(imageSize))
                error(message('images:imref:sizeMismatch','ImageSize','imref3d'));
            end
            
            TF = isequal(imageSize(1),self.ImageSize(1))...
                && isequal(imageSize(2),self.ImageSize(2))...
                && isequal(imageSize(3),self.ImageSize(3));
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
        
        function zdim = get.ImageExtentInWorldZ(self)
            zdim = diff(self.ZWorldLimits);
        end
        
        function extentX = get.PixelExtentInWorldX(self)
            extentX = diff(self.XWorldLimits) ./ self.ImageSize(2);
        end
        
        function extentY = get.PixelExtentInWorldY(self)
            extentY = diff(self.YWorldLimits) ./ self.ImageSize(1);
        end
        
        function extentZ = get.PixelExtentInWorldZ(self)
            extentZ = diff(self.ZWorldLimits) ./ self.ImageSize(3);
        end
        
        function limits = get.XIntrinsicLimits(self)
            limits = [0.5,self.ImageSize(2)+0.5];
        end
        
        function limits = get.YIntrinsicLimits(self)
            limits = [0.5,self.ImageSize(1)+0.5];
        end
        
        function limits = get.ZIntrinsicLimits(self)
            limits = [0.5,self.ImageSize(3)+0.5];
        end
        
        function lim = get.XWorldLimits(self)
            lim = self.XWorldLimitsInternal;
        end
        
        function lim = get.YWorldLimits(self)
            lim = self.YWorldLimitsInternal;
        end
        
        function lim = get.ZWorldLimits(self)
            lim = self.ZWorldLimitsInternal;
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
        
        function self = set.ZWorldLimits(self, worldLimits)
            iValidateWorldLimits(worldLimits,'Z');
            self.ZWorldLimitsInternal = worldLimits;
            self = self.recomputeTransforms();
        end
        
        function self = set.ImageSize(self,imSize)
            
            validateattributes(imSize, ...
                {'uint8','uint16','uint32','int8','int16','int32','single','double'},...
                {'positive','real','vector','integer','finite'}, ...
                'imref2d.set.ImageSize', ...
                'ImageSize');
            
            if numel(imSize) ~=3
                error(message('images:spatialref:invalid3dImageSize','ImageSize'));
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
                'YWorldLimits',self.YWorldLimits,...
                'ZWorldLimits',self.ZWorldLimits);
            
        end
        
        function [xw,yw,zw] = intrinsicToWorldAlgo(self,xIntrinsic,yIntrinsic,zIntrinsic)
            
            M = self.TransformIntrinsicToWorld;
            xw = M(1,1).*xIntrinsic + M(4,1);
            yw = M(2,2).*yIntrinsic + M(4,2);
            zw = M(3,3).*zIntrinsic + M(4,3);
            
        end
        
        function [xi,yi,zi] = worldToIntrinsicAlgo(self,xWorld,yWorld,zWorld)
            
            M = self.TransformWorldToIntrinsic;
            xi = M(1,1).*xWorld + M(4,1);
            yi = M(2,2).*yWorld + M(4,2);
            zi = M(3,3).*zWorld + M(4,3);
            
        end
        
        function [r,c,p] = worldToSubscriptAlgo(self,xWorld,yWorld,zWorld)
            
            TF = containsAlgo(self,xWorld,yWorld,zWorld);
            [c,r,p] = worldToIntrinsicAlgo(self,xWorld,yWorld,zWorld);
            
            r(TF) = min(round(r(TF)), self.ImageSize(1));
            c(TF) = min(round(c(TF)), self.ImageSize(2));
            p(TF) = min(round(p(TF)), self.ImageSize(3));
            
            r(~TF) = nan;
            c(~TF) = nan;
            p(~TF) = nan;
            
        end
        
        function TF = containsAlgo(self,xWorld,yWorld,zWorld)
            
            TF = (xWorld >= self.XWorldLimits(1))...
                & (xWorld <= self.XWorldLimits(2))...
                & (yWorld >= self.YWorldLimits(1))...
                & (yWorld <= self.YWorldLimits(2))...
                & (zWorld >= self.ZWorldLimits(1))...
                & (zWorld <= self.ZWorldLimits(2));
            
        end
        
    end
    
    methods (Static, Hidden)
        
        function self = loadobj(S)
            
            self = imref3d(S.ImageSize,S.XWorldLimits,S.YWorldLimits,S.ZWorldLimits);
            
        end
        
    end
    
    methods (Access = private)
        
        function self = recomputeTransforms(self)
            
            sx = self.PixelExtentInWorldX;
            sy = self.PixelExtentInWorldY;
            sz = self.PixelExtentInWorldZ;
            tx = self.XWorldLimits(1);
            ty = self.YWorldLimits(1);
            tz = self.ZWorldLimits(1);
            
            shiftFirstPixelToOrigin = [1 0 0 0; 0 1 0 0; 0 0 1 0; -0.5 -0.5 -0.5 1];
            self.TransformIntrinsicToWorld = shiftFirstPixelToOrigin * [sx 0 0 0; 0 sy 0 0; 0 0 sz 0; tx ty tz 1] ;
            self.TransformWorldToIntrinsic = inv(self.TransformIntrinsicToWorld);
            
        end
        
    end
    
    %-----------------------------------------------------------------------
    methods(Access=private, Static)
        function name = matlabCodegenRedirect(~)
            name = 'images.internal.coder.imref3d';
        end
    end
    
end

function iValidateXYZPoints(X,Y,Z,xName,yName,zName)

validateattributes(X,{'numeric'},{'real','nonsparse'},'imref3d',xName);
validateattributes(Y,{'numeric'},{'real','nonsparse'},'imref3d',yName);
validateattributes(Z,{'numeric'},{'real','nonsparse'},'imref3d',zName);

if ~(isequal(size(X),size(Y)) && isequal(size(X),size(Z)))
    error(message('images:spatialref:invalidXYZPoint',xName,yName,zName));
end

end

function iValidateWorldLimits(worldLimits,dimStr)

validateattributes(worldLimits, ...
    {'double','single'}, {'real','finite','size',[1 2]}, ...
    'imref3d', ...
    sprintf('%sWorldLimits',dimStr));

if (worldLimits(2) <= worldLimits(1))
    error(message('images:spatialref:expectedAscendingLimits',...
        sprintf('%sWorldLimits',dimStr)));
end

end
