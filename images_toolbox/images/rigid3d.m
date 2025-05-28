%rigid3d 3-D Rigid Geometric Transformation
%
%   A rigid3d object encapsulates a 3-D rigid transformation.
%
%   tform = rigid3d() creates a rigid3d object corresponding to an identity
%   transformation.
%
%   tform = rigid3d(T) creates a rigid3d object given a 4-by-4 matrix T
%   that specifies a valid rigid transformation matrix. T must be of the
%   form:
%
%   T = [r11 r12 r13 0; ...
%        r21 r22 r23 0; ...
%        r31 r32 r33 0; ...
%         tx  ty  tz 1];
%
%   tform = rigid3d(rot, trans) creates a rigid3d object given a 3-by-3
%   rotation matrix rot and 1-by-3 translation vector trans.
%
%   rigid3d properties:
%   T               - 4-by-4 matrix representing forward rigid transformation
%   Dimensionality  - Dimensionality of geometric transformation
%   Rotation        - 3-by-3 rotation matrix
%   Translation     - 1-by-3 translation vector
%
%   rigid3d methods:
%   invert                  - Invert geometric transformation
%   outputLimits            - Compute output spatial limits
%   transformPointsForward  - Apply forward 3-D geometric transformation to points
%   transformPointsInverse  - Apply inverse 3-D geometric transformation to points
%
%   Example
%   -------
%   % Construct a rigid3d object that defines translation and rotation
%   theta = 30; % degrees
%   rot = [ cosd(theta) sind(theta) 0; ...
%          -sind(theta) cosd(theta) 0; ...
%                    0           0  1];
%
%   trans = [2 3 4];
%
%   tform = rigid3d(rot, trans)
%
%   See also affine3d, rigid2d, geometricTransform3d.

% Copyright 2019-2021 The MathWorks, Inc.

%#codegen

classdef rigid3d < images.internal.rigid3dImpl &  images.internal.CustomDisplay
        
    properties (Constant, Access = private)
        %Version
        %   Version of the objects serialization/deserialization format.
        %   This is used to manage forward compatibility. Value is saved in
        %   a 'Version' field when an instance is serialized.
        Version = 1
    end
    
    methods
        %------------------------------------------------------------------
        %     Constructor
        %------------------------------------------------------------------
        function this = rigid3d(varargin)
            this = this@images.internal.rigid3dImpl(varargin{:});
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
            
            % that - struct
            % this - object
            
            this = rigid3d(that.T);
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

    methods(Access=public, Static, Hidden)
        %----------------------------------------------------------------------
        function name = matlabCodegenRedirect(~)
            name = 'images.internal.coder.rigid3d';
        end
    end
end

