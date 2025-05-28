%geometricTransform3d 3-D Geometric Transformation object
%
%   A geometricTransform3d object defines a 3-D geometric transformation
%   using point-wise mapping functions
%
%   tform = geometricTransform3d(inverseFcn) creates a geometricTransform3d
%   object tform with the inverse mapping specified by function handle
%   inverseFcn. 
%
%   tform = geometricTransform3d(inverseFcn, forwardFcn) additionally
%   specifies forwardFcn, a function handle describing the forward mapping.
%
%   UVW = transformPointsInverse(tform, XYZ) maps points XYZ using the
%   inverse mapping function defined by tform.
%
%   [U, V, W] = transformPointsInverse(tform, X, Y, Z) maps points X, Y and
%   Z using the inverse mapping function defined by tform.
%
%   XYZ = transformPointsForward(tform, UVW) maps points UVW using the
%   forward mapping function defined by tform.
%
%   [X, Y, Z] = transformPointsForward(tform, U, V, W) maps points U, V and
%   W using the forward mapping function defined by tform.
%
%   geometricTransform3d properties:
%      InverseFcn - function handle for inverse mapping (required argument)
%      ForwardFcn - function handle for forward mapping (optional argument)
%
%   geometricTransform3d methods:
%      geometricTransform3d - construct 3-D geometricTransform object
%      transformPointsForward - Apply forward custom geometric transformation to points
%      transformPointsInverse - Apply inverse custom geometric transformation to points
%
%
%   Class Support
%   -------------
%   Points XYZ or UVW must be of size N-by-3 and of class single or double.
%   X, Y, Z, U, V or W are point arrays of class single or double. Output
%   points are of same size and class as input points.
%
%   Example 1
%   ---------
%   % This example apply inverse and forward geometric transform
%   % to input points
%   
%   % Input points
%   XYZ = [10 15 5;11 32 7;15 34 9]
%
%   % Construct a 3-D geometric transform object defined by a
%   % mathematical function
%   inversefn = @(c) [c(:,1)+c(:,2),c(:,1)-c(:,2),c(:,3).^2];
%
%   % Apply inverse geometric transform to input points
%   tform = geometricTransform3d(inversefn);
%   UVW = transformPointsInverse(tform,XYZ)
%
%   Example 2
%   ---------
%   % This example apply inverse and forward geometric transform
%   % to input points
%   
%   X = [10; 11; 9]
%   Y = [15; 32; 34]
%   Z = [5; 7; 9]
%
%   % Construct a 3-D geometric transform object defined by a
%   % mathematical function
%   inversefn = @(c) [c(:,1).^2, c(:,2).^2, c(:,3).^2];
%   forwardfn = @(c) [sqrt(c(:,1)), sqrt(c(:,2)), sqrt(c(:,3))];
%
%   % Apply inverse and forward geometric transform to input points
%   tform = geometricTransform3d(inversefn,forwardfn);
%   [U,V,W] = transformPointsInverse(tform,X,Y,Z)
%   [X,Y,Z] = transformPointsForward(tform,U,V,W)
%
%   Example 3
%   ---------
%   % Apply transformation to an MRI volume using the function
%   % imwarp
%   
%   % Load and visualize an MRI volume
%   s = load('mri');
%   mriVolume = squeeze(s.D);
%   figure, volshow(mriVolume)
%
%   % Construct a 3-D geometric transform object defined by a
%   % mathematical function
%   g = @(c)([-c(:,2),-c(:,1),-c(:,3)]);
%   tform = geometricTransform3d(g);
%
%   % Apply geometric transform object to 3D volume
%   mriVolumeTransformed = imwarp(mriVolume,tform);
%
%   % Visualize the transformed volume.
%   figure, volshow(mriVolumeTransformed)
%
%   See also affine3d, rigid3d, geometricTransform2d, affine2d, rigid2d,
%            projective2d, imwarp.

% Copyright 2018-2020 The MathWorks, Inc.


classdef geometricTransform3d < images.geotrans.internal.GeometricTransformation
    %% class file for geometricTransform
    properties(SetAccess = private)
        InverseFcn; %% function handle for inverse mapping
        ForwardFcn; %% function handle for forward mapping
    end
    
    properties (Hidden)
        IsBidirectional
    end
    
    properties (Constant)
        Dimensionality = 3
    end
    
    methods
        
        function obj = geometricTransform3d(varargin)
            %% constructor
            narginchk(0,2);
            obj.IsBidirectional = false;
            if nargin == 0
                obj.InverseFcn = function_handle.empty();
                obj.ForwardFcn = function_handle.empty();
            elseif nargin == 1
                obj.InverseFcn = varargin{1};
                obj.ForwardFcn = function_handle.empty();
            else
                obj.InverseFcn = varargin{1};
                obj.ForwardFcn = varargin{2};
            end
            
        end
        
        
        function varargout = transformPointsForward(obj,varargin)
            %% apply forward geometric transform
            packedPointsSpecified = (nargin==2);
            if packedPointsSpecified
                U = varargin{1};
                nargoutchk(0,1);
                if ~isequal(size(U,2),3)
                    error(message('images:geotrans:transformPointsPackedMatrixInvalidSize3d',...
                        'transformPointsForward','U'));
                end
                validateattributes(U,{'single','double'},{'2d','nonsparse'},'images:geometricTransform3d:transformPointsForward','U');
                varargout{1} = feval(obj.ForwardFcn,U);
                
            else
                
                narginchk(4,4);
                nargoutchk(0,3);
                u = varargin{1};
                v = varargin{2};
                w = varargin{3};
                
                if ~isequal(size(u),size(v)) || ~isequal(size(v),size(w))
                    error(message('images:geotrans:transformPointsSizeMismatch3d','transformPointsForward','U','V','W'));
                end
                
                validateattributes(u,{'single','double'},{'3d','nonsparse'},'images:geometricTransform3d:transformPointsForward','U');
                validateattributes(v,{'single','double'},{'3d','nonsparse'},'images:geometricTransform3d:transformPointsForward','V');
                validateattributes(w,{'single','double'},{'3d','nonsparse'},'images:geometricTransform3d:transformPointsForward','W');
                
                tempVal = feval(obj.ForwardFcn,[u(:),v(:),w(:)]);
                varargout{1} = reshape(tempVal(:,1),size(u));
                varargout{2} = reshape(tempVal(:,2),size(v));
                varargout{3} = reshape(tempVal(:,3),size(w));
                
            end
            
        end
        
        
        
        function varargout = transformPointsInverse(obj,varargin)
            %% apply inverse geometric transform
            packedPointsSpecified = (nargin==2);
            if packedPointsSpecified
                X = varargin{1};
                nargoutchk(0,1);
                if ~isequal(size(X,2),3)
                    error(message('images:geotrans:transformPointsPackedMatrixInvalidSize3d',...
                        'transformPointsInverse','X'));
                end
                validateattributes(X,{'single','double'},{'2d','nonsparse'},'images:geometricTransform3d:transformPointsInverse','X');
                varargout{1} = feval(obj.InverseFcn,X);
                
            else
                
                narginchk(4,4);
                nargoutchk(0,3);
                x = varargin{1};
                y = varargin{2};
                z = varargin{3};
                
                if ~isequal(size(x),size(y)) || ~isequal(size(y),size(z))
                    error(message('images:geotrans:transformPointsSizeMismatch3d','transformPointsInverse','X','Y','Z'));
                end
                
                validateattributes(x,{'single','double'},{'3d','nonsparse'},'images:geometricTransform3d:transformPointsInverse','X');
                validateattributes(y,{'single','double'},{'3d','nonsparse'},'images:geometricTransform3d:transformPointsInverse','Y');
                validateattributes(z,{'single','double'},{'3d','nonsparse'},'images:geometricTransform3d:transformPointsInverse','Z');
                
                tempVal = feval(obj.InverseFcn,[x(:),y(:),z(:)]);
                varargout{1} = reshape(tempVal(:,1),size(x));
                varargout{2} = reshape(tempVal(:,2),size(y));
                varargout{3} = reshape(tempVal(:,3),size(z));
                
            end
        end
        
        % Set methods
        function obj = set.ForwardFcn(obj,forwardfunction)
            % validate function
            validateattributes(forwardfunction,{'function_handle'},{},...
                'geometricTransform3d.set.ForwardFcn',...
                'ForwardFcn');
            
            obj.ForwardFcn = forwardfunction;
            if ~isempty(forwardfunction)
                obj = setBidirection(obj);
            end
            
        end
        
        function obj = set.InverseFcn(obj,inversefunction)
            % validate function
            validateattributes(inversefunction,{'function_handle'},{},...
                'geometricTransform3d.set.InverseFcn',...
                'InverseFcn');
            
            obj.InverseFcn = inversefunction;
            
        end
        
    end
    
    methods(Access='private')
        function obj = setBidirection(obj)
            obj.IsBidirectional = true;
        end
    end
    
end