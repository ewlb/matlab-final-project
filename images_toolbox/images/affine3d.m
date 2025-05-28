%affine3d 3-D Affine Geometric Transformation
%
%   An affine3d object encapsulates a 3-D affine geometric transformation.
%
%   affine3d properties:
%      T - 4x4 matrix representing forward affine transformation
%      Dimensionality - Dimensionality of geometric transformation
%
%   affine3d methods:
%      affine3d - Construct affine3d object
%      invert - Invert geometric transformation
%      isTranslation - Determine if transformation is pure translation special case
%      isRigid - Determine if transformation is rigid transformation special case
%      isSimilarity - Determine if transformation is similarity transformation special case
%      outputLimits - Find output spatial limits given input spatial limits
%      transformPointsForward - Apply forward 3-D geometric transformation to points
%      transformPointsInverse - Apply inverse 3-D geometric transformation to points
%
%   Example 1
%   ---------
%   % Construct an affine3d object that defines a different scale factor in
%   % each dimension.
%   Sx = 1.2;
%   Sy = 1.6;
%   Sz = 2.4;
%   tform = affine3d([Sx 0 0 0; 0 Sy 0 0; 0 0 Sz 0; 0 0 0 1]);
%
%   % Apply forward geometric transformation to an input (U,V,W) point (1,1,1)
%   [X,Y,Z] = transformPointsForward(tform,1,1,1)
%
%   % Apply inverse geometric transformation to output (X,Y,Z) point from
%   % previous step. We recover the point we started with from
%   % the inverse transformation.
%   [U,V,W] = transformPointsInverse(tform,X,Y,Z)
%
%   Example 2
%   ---------
%   % Apply scale transformation to an MRI volume using the function imwarp
%   A = load('mri');
%   A = squeeze(A.D);
%   Sx = 1.2;
%   Sy = 1.6;
%   Sz = 2.4;
%   tform = affine3d([Sx 0 0 0; 0 Sy 0 0; 0 0 Sz 0; 0 0 0 1]);
%   outputImage = imwarp(A,tform);
%
%   % Visualize axial slice through center of transformed volume to see
%   % effect of scale transformation.
%   figure, imshowpair(A(:,:,14),outputImage(:,:,27));
%
%   See also AFFINE2D, GEOMETRICTRANSFORM3D, RIGID3D, PROJECTIVE2D, RIGID2D,
%            GEOMETRICTRANSFORM2D, IMWARP.

% Copyright 2012-2021 The MathWorks, Inc.

classdef affine3d < images.internal.affine3dImpl
    
    methods
        %------------------------------------------------------------------
        %     Constructor
        %------------------------------------------------------------------
        function this = affine3d(varargin)
            this = this@images.internal.affine3dImpl(varargin{:});
        end
    end
    
    methods (Hidden)
        %------------------------------------------------------------------
        % saveobj and loadobj are implemented to ensure compatibility across
        % releases even if architecture of geometric transformation classes
        % changes.
        %------------------------------------------------------------------
        function S = saveobj(self)
            
            S = struct('TransformationMatrix',self.T);
            
        end
        
    end
    
    methods (Static, Hidden)
        %------------------------------------------------------------------
        function self = loadobj(S)
            
            self = affine3d(S.TransformationMatrix);
            
        end
        
    end
    
    methods(Access=public, Static, Hidden)
        %------------------------------------------------------------------
        function name = matlabCodegenRedirect(~)
            name = 'images.internal.coder.affine3d';
        end
    end
    
end
