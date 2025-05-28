%rigid2d 2-D Rigid Geometric Transformation
%
%   A rigid2d object encapsulates a 2-D rigid transformation.
%
%   tform = rigid2d() creates a rigid2d object corresponding to an identity
%   transformation.
%
%   tform = rigid2d(T) creates a rigid2d object given a 3-by-3 matrix T
%   that specifies a valid rigid transformation matrix. T must be of the
%   form:
%
%   T = [r11 r12 0; ...
%        r21 r22 0; ...
%        tx  ty  1];
%
%   tform = rigid2d(rot, trans) creates a rigid2d object given a 2-by-2
%   rotation matrix rot and 1-by-2 translation vector trans.
%
%   rigid2d properties:
%   T               - 3-by-3 matrix representing forward rigid transformation
%   Dimensionality  - Dimensionality of geometric transformation
%   Rotation        - 2-by-2 rotation matrix
%   Translation     - 1-by-2 translation vector
%
%   rigid2d methods:
%   invert                  - Invert geometric transformation
%   outputLimits            - Compute output spatial limits
%   transformPointsForward  - Apply forward 2-D geometric transformation to points
%   transformPointsInverse  - Apply inverse 2-D geometric transformation to points
%   isTranslation           - Determine if transformation is pure translation special case
%
%   Example
%   -------
%   % Construct a rigid2d object that defines translation and rotation
%   theta = 30; % degrees
%   rot   = [cosd(theta) sind(theta); ...
%           -sind(theta) cosd(theta)];
%
%   trans = [2 3];
%
%   tform = rigid2d(rot, trans)
%
%   See also rigid3d, affine2d, projective2d, geometricTransform2d, affine3d.

% Copyright 2020 The MathWorks, Inc.

%#codegen

classdef rigid2d < images.geotrans.internal.GeometricTransformation & images.internal.CustomDisplay

    properties (Constant)
        Dimensionality = 2
    end

    properties (Dependent = true)
        %T Forward transformation matrix
        %   T is a 3-by-3 floating point matrix that defines the forward
        %   transformation. The matrix T is a homogeneous transformation
        %   matrix that uses the post-multiply convention:
        %
        %   [x y 1] = [u v 1] * T
        %
        %   where T has the form:
        %   T = [r11 r12  0; ...
        %        r21 r22  0; ...
        %        tx  ty  1];
        T
        
        %Rotation Rotation matrix
        %   Rotation is a 2-by-2 floating point matrix that defines the
        %   rotation component of the transformation. The rotation matrix
        %   uses the post-multiply convention:
        %
        %   [x y] = [u v] * R
        %
        %   where R is the rotation matrix.
        Rotation

        %Translation Translation vector
        %   Translation is a 1-by-2 floating point vector that defines the
        %   translation component of the transformation. The translation
        %   vector uses the convention:
        %
        %   [x y] = [u v] + t
        %
        %   where t is the translation vector.
        Translation
    end

    properties (Dependent = true, Access = private, Hidden = true)
        %Tinv Inverse transformation matrix
        %   Tinv is a 3-by-3 floating point matrix that defines the inverse
        %   transformation.
        Tinv
    end

    properties (Hidden)
        IsBidirectional = true
    end

    properties (Constant, Access = private)
        %Version
        %   Version of the objects serialization/deserialization format.
        %   This is used to manage forward compatibility. Value is saved in
        %   a 'Version' field when an instance is serialized.
        Version = 1
    end

    properties (Access = private)
        AffineTform
    end

    methods
        %------------------------------------------------------------------
        function this = rigid2d(varargin)
            narginchk(0, 2);

            if nargin==0
                this.AffineTform = affine2d;
            else
                if nargin==1
                    T = varargin{1};
                    validateTransformationMatrix(T);
                else
                    rot = varargin{1};
                    trans = varargin{2};

                    validateRotationMatrix(rot);
                    validateTranslationVector(trans);

                    T = [rot zeros(2,1,'like',rot); [trans, 1]];
                end

                if ~this.isTransformationMatrixRigid(T)
                    coder.internal.error('images:geotrans:invalidRigidMatrix');
                end

                this.AffineTform = affine2d(T);
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

            this.T(1:2, 1:2) = rot;
        end

        %------------------------------------------------------------------
        function rot = get.Rotation(this)

            rot = this.T(1:2, 1:2);
        end

        %------------------------------------------------------------------
        function this = set.Translation(this, trans)

            validateTranslationVector(trans);

            this.T(3, 1:2) = trans;
        end

        %------------------------------------------------------------------
        function trans = get.Translation(this)

            trans = this.T(3, 1:2);
        end

        %------------------------------------------------------------------
        function Tinv = get.Tinv(this)
            
            % Inverted transformation can be constructed as:
            %
            %   Tinv = [  R'  0;
            %           -t*R' 1];

            rot   = this.T(1:2, 1:2)';
            trans = this.T(3, 1:2);

            Tinv = [rot [0;0]; [-trans * rot 1]];
        end

        %------------------------------------------------------------------
        function this = invert(this)
            %invert Invert rigid transformation
            %
            %   invTform = invert(tform) returns a rigid2d object
            %   corresponding to the inverse geometric transformation of
            %   tform.
            %
            %   Example
            %   -------
            %   % Create rigid transformation with translation of [5, 4]
            %   rot   = eye(2); % no rotation
            %   trans = [5, 4]; % translation
            %   tform = rigid2d(rot, trans);
            %
            %   % Invert transformation
            %   invTform = invert(tform);
            %
            %   disp(invTform.Translation)
            %
            %   See also rigid2d.

            this.T = this.Tinv;
        end

        %------------------------------------------------------------------
        function varargout = transformPointsForward(this, varargin)
            %transformPointsForward Apply forward rigid transformation
            %   [x, y] = transformPointsForward(tform, u, v) applies
            %   the forward transformation of tform to the input 2D point
            %   arrays u, v and returns point arrays x, y. The input
            %   point arrays u and v must be of the same size.
            %
            %   X = transformPointsForward(tform, U) applies the forward
            %   transformation of tform to the N-by-2 point matrix U and
            %   returns an N-by-2 point matrix X.
            %
            %   Example
            %   -------
            %   % Create a rigid transformation object
            %   theta = 45; % degrees
            %   rot   = [cosd(theta) sind(theta); ...
            %           -sind(theta) cosd(theta)];
            %   trans = [4 0];
            %
            %   tform = rigid2d(rot, trans)
            %
            %   % Define points to transform
            %   disp('Before transformation')
            %   U = [ 0 0; ...
            %        10 5]
            %
            %   % Apply forward transformation to points
            %   disp('After forward transformation')
            %   X = transformPointsForward(tform, U)
            %
            %   % Apply inverse transformation to points
            %   disp('After inverse transformation')
            %   U2 = transformPointsInverse(tform, X)
            %
            %   See also transformPointsInverse.

            [varargout{1:nargout}] = transformPointsForward(this.AffineTform, ...
                varargin{:});
        end

        %------------------------------------------------------------------
        function varargout = transformPointsInverse(this, varargin)
            %transformPointsInverse Apply inverse rigid transformation
            %   [u, v] = transformPointsInverse(tform, x, y) applies
            %   the inverse transformation of tform to the input 2D point
            %   arrays x, y and returns point arrays u, v. The input
            %   point arrays x and y must be of the same size.
            %
            %   U = transformPointsInverse(tform, X) applies the inverse
            %   transformation of tform to the N-by-2 point matrix X and
            %   returns an N-by-2 point matrix U.
            %
            %   Example
            %   -------
            %   % Create a rigid transformation object
            %   theta = 45;
            %   rot   = [cosd(theta) sind(theta); ...
            %           -sind(theta) cosd(theta)];
            %   trans = [4 0];
            %
            %   tform = rigid2d(rot, trans)
            %
            %   % Define points to transform
            %   disp('Before transformation')
            %   U = [ 0 0; ...
            %        10 5]
            %
            %   % Apply forward transformation to points
            %   disp('After forward transformation')
            %   X = transformPointsForward(tform, U)
            %
            %   % Apply inverse transformation to points
            %   disp('After inverse transformation')
            %   U2 = transformPointsInverse(tform, X)
            %
            %   See also transformPointsForward.

            [varargout{1:nargout}] = transformPointsInverse(this.AffineTform, ...
                varargin{:});
        end

        %------------------------------------------------------------------
        function varargout = outputLimits(this, varargin)
            %outputLimits Find output limits of geometric transformation
            %
            %   [xlimsOut,ylimsOut] = outputLimits(tform, xlimsIn,
            %   ylimsIn) estimates the output spatial limits
            %   corresponding to a given geometric transformation and a set
            %   of input spatial limits.
            %
            %   Example
            %   -------
            %   % Create a rigid transformation object
            %   rot   = eye(2);
            %   trans = [4 2];
            %   tform = rigid2d(rot, trans)
            %
            %   % Find output limits for square centered at origin
            %   xlimsIn = [-5 5];
            %   ylimsIn = [-5 5];
            %   [xlimsOut, ylimsOut] = outputLimits(tform, ...
            %       xlimsIn, ylimsIn)
            %
            %   See also rigid2d/transformPointsForward.

            [varargout{1:nargout}] = outputLimits(this.AffineTform, ...
                varargin{:});
        end

        %------------------------------------------------------------------
        function TF = isTranslation(self)
            %isTranslation Determine if transformation is pure translation
            %
            %   TF = isTranslation(tform) determines if the rigid
            %   transformation is a pure translation. TF is a scalar
            %   boolean that is true when tform defines only translation.
            %   Example
            %   -------
            %   % Create a rigid transformation object
            %   rot   = eye(2); % no rotation
            %   trans = [5, 4]; % translation
            %   tform = rigid2d(rot, trans)
            %
            %   % Check if tform is a pure translation
            %   TF = isTranslation(tform);
            %
            %   See also rigid2d.

            TF = isequal(self.T(1:self.Dimensionality,1:self.Dimensionality),...
                eye(self.Dimensionality));
        end
    end


    methods (Hidden)
        %------------------------------------------------------------------
        % saveobj is implemented to ensure compatibility across releases by
        % converting the class to a struct prior to saving. It also
        % contains a version number, which can be used to customize load in
        % case the interface is updated.
        %------------------------------------------------------------------
        function that = saveobj(this)

            % this - object
            % that - struct

            that.T       = this.T;
            that.Version = this.Version;
        end
    end

    methods (Static, Hidden)
        %------------------------------------------------------------------
        function this = loadobj(that)

            % this - object
            % that - struct

            this = rigid2d(that.T);
        end
    end

    methods (Static, Access = private)
        %------------------------------------------------------------------
        function isRigid = isTransformationMatrixRigid(T)

            rot = T(1:2,1:2);
            singularValues = svd(rot);

            isRigid = max(singularValues) - min(singularValues) < 1000*eps(max(singularValues(:)));
            isRigid = isRigid && abs(det(rot)-1) < 1000*eps(class(rot));
        end
    end
    
    methods (Access = protected)
        %------------------------------------------------------------------
        function group = getPropertyGroups(this)
            
            if isscalar(this)
                propList = struct(...
                    'Rotation',     this.Rotation, ...
                    'Translation',  this.Translation);
                
                group = matlab.mixin.util.PropertyGroup(propList);
            else
                group = getPropertyGroups@matlab.mixin.CustomDisplay(this);
            end
        end
    end
end

%--------------------------------------------------------------------------
function validateTransformationMatrix(T)

validateattributes(T, {'single', 'double'}, ...
    {'size', [3 3], 'finite', 'nonnan', 'real'}, 'rigid2d', 'T');

if ~isequal(T(:,3),[0 0 1]')
    coder.internal.error('images:geotrans:invalidRigidMatrix');
end

end

%--------------------------------------------------------------------------
function validateRotationMatrix(rot)

validateattributes(rot, {'single', 'double'}, ...
    {'size', [2 2], 'finite', 'real'}, 'rigid2d', 'rot');
end

%--------------------------------------------------------------------------
function validateTranslationVector(trans)

validateattributes(trans, {'single', 'double'}, ...
    {'size', [1 2], 'finite', 'real'}, 'rigid2d', 'trans');
end
