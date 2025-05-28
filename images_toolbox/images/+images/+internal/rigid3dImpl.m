%rigid3dImpl Common implementation for rigid3d
%
%   This class is for internal use only.
%
%   This class implements the core functionality of rigid3d. 
%   It is common for both simulation and codegen.  

% Copyright 2020-2021 The MathWorks, Inc.

%#codegen

classdef rigid3dImpl < images.geotrans.internal.GeometricTransformation
    
    properties (Constant)
        Dimensionality = 3
    end
    
    properties (Dependent = true)
        %T Forward transformation matrix
        %   T is a 4-by-4 floating point matrix that defines the forward
        %   transformation. The matrix T is a homogeneous transformation
        %   matrix that uses the post-multiply convention:
        %
        %   [x y z 1] = [u v w 1] * T
        %
        %   where T has the form:
        %   T = [r11 r12 r13 0; ...
        %        r21 r22 r23 0; ...
        %        r31 r32 r33 0; ...
        %         tx  ty  tz 1];
        T
        
        %Rotation Rotation matrix
        %   Rotation is a 3-by-3 floating point matrix that defines the
        %   rotation component of the transformation. The Rotation matrix
        %   uses the post-multiply convention:
        %
        %   [x y z] = [u v w] * R
        %
        %   where R is the rotation matrix
        Rotation
        
        %Translation Translation vector
        %   Translation is a 1-by-3 floating point vector that defines the
        %   translation component of the transformation. The Translation
        %   vector uses the convention:
        %
        %   [x y z] = [u v w] + t
        %
        %   where t is the translation vector
        Translation
    end
    
    properties (Dependent = true, Access = private)
        %Tinv Inverse transformation matrix
        %   Tinv is a 4-by-4 floating point matrix that defines the inverse
        %   transformation.
        Tinv
    end
    
    properties (Hidden)
        IsBidirectional = true;
    end
    
    properties (Access = private)
        AffineTform
    end
    
    methods
        %------------------------------------------------------------------
        function this = rigid3dImpl(varargin)
            
            narginchk(0, 2);
            
            if nargin==0
                this.AffineTform = affine3d;
            else
                if nargin==1
                    T = varargin{1};
                    
                    validateTransformationMatrix(T);
                else
                    rot   = varargin{1};
                    trans = varargin{2};
                    
                    validateRotationMatrix(rot);
                    validateTranslationVector(trans);
                    
                    if coder.gpu.internal.isGpuEnabled
                        % Calling GPU optimized implementation which
                        % concatenates the matrices.
                        T = images.internal.coder.gpu.rigid3d.createRigid3DMat(rot,trans);
                    else
                        T = [rot zeros(3,1,'like',rot); [trans, 1]];
                    end
                end
                
                if ~this.isTransformationMatrixRigid(T)
                    coder.internal.error('images:geotrans:invalidRigidMatrix');
                end
                
                this.AffineTform = affine3d(T);
            end
        end
        
        %------------------------------------------------------------------
        function this = set.T(this, T)
            
            validateTransformationMatrix(T);
            
            if ~this.isTransformationMatrixRigid(T)
                coder.internal.error('images:geotrans:invalidRigidMatrix');
            end
            
            this.AffineTform.T = T;
        end
        
        %------------------------------------------------------------------
        function T = get.T(this)
            
            T = this.AffineTform.T;
        end
        
        %------------------------------------------------------------------
        function this = set.Rotation(this, rot)
            
            validateRotationMatrix(rot);
            
            this.T(1:3, 1:3) = rot;
        end
        
        %------------------------------------------------------------------
        function this = set.Translation(this, trans)
            
            validateTranslationVector(trans);
            
            this.T(4, 1:3) = trans;
        end
        
        %------------------------------------------------------------------
        function rot = get.Rotation(this)
            
            rot = this.T(1:3, 1:3);
        end
        
        %------------------------------------------------------------------
        function trans = get.Translation(this)
            
            trans = this.T(4, 1:3);
        end
        
        %------------------------------------------------------------------
        function Tinv = get.Tinv(this)
            
            % Inverted transformation can be constructed as:
            %
            %   Tinv = [   R' 0;
            %           -t*R' 1];
            
            rot   = this.T(1:3, 1:3)';
            trans = this.T(4, 1:3);
            
            Tinv = [rot [0;0;0]; [-trans * rot 1]];
        end
        
        %------------------------------------------------------------------
        function this = invert(this)
            %invert Invert rigid transformation
            %
            %   invTform = invert(tform) returns a rigid3d object
            %   corresponding to the inverse geometric transformation of
            %   tform.
            %
            %   Example
            %   -------
            %   % Create rigid transformation with translation of [5, 4, 3]
            %   rot   = eye(3);     % no rotation
            %   trans = [5, 4, 3];  % translation
            %   tform = rigid3d(rot, trans);
            %
            %   % Invert transformation
            %   invTform = invert(tform);
            %
            %   disp(invTform.Translation)
            %
            %   See also rigid3d.
            this.T = this.Tinv;
        end
        
        %------------------------------------------------------------------
        function varargout = transformPointsForward(this, varargin)
            %transformPointsForward Apply forward rigid transformation
            %   [x, y, z] = transformPointsForward(tform, u, v, w) applies
            %   the forward transformation of tform to the input 3D point
            %   arrays u, v, w and returns point arrays x, y, z. The input
            %   point arrays u, v and w must be of the same size.
            %
            %   X = transformPointsForward(tform, U) applies the forward
            %   transformation of tform to the N-by-3 point matrix U and
            %   returns an N-by-3 point matrix X.
            %
            %   Example
            %   -------
            %   % Create a rigid transformation object
            %   theta = 45; % degrees (rotation about Z)
            %   rot   = [ cosd(theta) sind(theta) 0; ...
            %            -sind(theta) cosd(theta) 0; ...
            %                       0           0 1];
            %   trans = [4 0 0];
            %
            %   tform = rigid3d(rot, trans)
            %
            %   % Define points to transform
            %   disp('Before transformation')
            %   U = [ 0 0 0; ...
            %        10 5 0]
            %
            %   % Apply forward transformation to points
            %   disp('After forward transformation')
            %   X = transformPointsForward(tform, U)
            %
            %   % Apply inverse transformation to points
            %   disp('After inverse transformation')
            %   U2 = transformPointsInverse(tform, X)
            %
            %
            %   See also transformPointsInverse
            
            [varargout{1:nargout}] = transformPointsForward(this.AffineTform, ...
                varargin{:});
        end
        
        %------------------------------------------------------------------
        function varargout = transformPointsInverse(this, varargin)
            %transformPointsInverse Apply inverse rigid transformation
            %   [u, v, w] = transformPointsInverse(tform, x, y, z) applies
            %   the inverse transformation of tform to the input 3D point
            %   arrays x, y, z and returns point arrays u, v, w. The input
            %   point arrays x, y, z must be of the same size.
            %
            %   U = transformPointsInverse(tform, X) applies the inverse
            %   transformation of tform to the N-by-3 point matrix X and
            %   returns an N-by-3 point matrix U.
            %
            %   Example
            %   -------
            %   % Create a rigid transformation object
            %   theta = 45; % degrees (rotation about Z)
            %   rot   = [ cosd(theta) sind(theta) 0; ...
            %            -sind(theta) cosd(theta) 0; ...
            %                       0           0 1];
            %   trans = [4 0 0];
            %
            %   tform = rigid3d(rot, trans)
            %
            %   % Define points to transform
            %   disp('Before transformation')
            %   U = [ 0 0 0; ...
            %        10 5 0]
            %
            %   % Apply forward transformation to points
            %   disp('After forward transformation')
            %   X = transformPointsForward(tform, U)
            %
            %   % Apply inverse transformation to points
            %   disp('After inverse transformation')
            %   U2 = transformPointsInverse(tform, X)
            %
            %   See also transformPointsForward
            
            [varargout{1:nargout}] = transformPointsInverse(this.AffineTform, ...
                varargin{:});
        end
        
        %------------------------------------------------------------------
        function varargout = outputLimits(this, varargin)
            %outputLimits Find output limits of geometric transformation
            %
            %   [xlimsOut,ylimsOut,zlimsOut] = outputLimits(tform, xlimsIn,
            %   ylimsIn,zlimsIn) estimates the output spatial limits
            %   corresponding to a given geometric transformation and a set
            %   of input spatial limits.
            %
            %   Example
            %   -------
            %   % Create a rigid transformation object
            %   rot   = eye(3);
            %   trans = [4 2 0];
            %   tform = rigid3d(rot, trans)
            %
            %   % Find output limits for cube centered at origin
            %   xlimsIn = [-5 5];
            %   ylimsIn = [-5 5];
            %   zlimsIn = [-5 5];
            %   [xlimsOut, ylimsOut, zlimsOut] = outputLimits(tform, ...
            %       xlimsIn, ylimsIn, zlimsIn)
            %
            %   See also rigid3d/transformPointsForward
            
            [varargout{1:nargout}] = outputLimits(this.AffineTform, ...
                varargin{:});
        end
    end
    
    methods (Static, Access = private)
        %------------------------------------------------------------------
        function isRigid = isTransformationMatrixRigid(T)
            
            %This is looser than affine3d/isRigid, and is necessary for
            %chained transformation operations which are common in
            %registration workflows.
            rot = T(1:3,1:3);
            
            if ~coder.gpu.internal.isGpuEnabled
                singularValues = svd( rot );
                isRigid = max(singularValues) - min(singularValues) < 1000*eps(max(singularValues(:)));
                isRigid = isRigid && abs(det(rot)-1) < 1000*eps(class(rot));
            else
                % GPU implementation for SVD and det.
                isRigid = images.internal.coder.gpu.rigid3d.isRigidTransform(T,1000);
            end
        end
    end
    
end

%--------------------------------------------------------------------------
function validateTransformationMatrix(T)

validateattributes(T, {'single', 'double'}, ...
    {'size', [4 4], 'finite', 'nonnan', 'real'}, 'rigid3d', 'T');

if ~isequal(T(:,4),[0 0 0 1]')
    coder.internal.error('images:geotrans:invalidRigidMatrix');
end

end

%--------------------------------------------------------------------------
function validateRotationMatrix(rot)

validateattributes(rot, {'single', 'double'}, ...
    {'size', [3 3], 'finite', 'real'}, 'rigid3d', 'rot');
end

%--------------------------------------------------------------------------
function validateTranslationVector(trans)

validateattributes(trans, {'single', 'double'}, ...
    {'size', [1 3], 'finite', 'real'}, 'rigid3d', 'trans');
end
