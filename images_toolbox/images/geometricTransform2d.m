%geometricTransform2d 2-D Geometric Transformation object
%   A geometricTransform2d object defines a 2-D geometric transformation
%   using point-wise mapping functions
%
%   tform = geometricTransform2d(inverseFcn) creates a geometricTransform2d
%   object tform with the inverse mapping specified by function handle
%   inverseFcn. 
%
%   tform = geometricTransform2d(inverseFcn, forwardFcn) additionally
%   specifies forwardFcn, a function handle describing the forward mapping.
% 
%   UV = transformPointsInverse(tform, XY) maps points XY using the inverse
%   mapping function defined by tform.
%
%   [U, V] = transformPointsInverse(tform, X, Y) maps points X and Y using
%   the inverse mapping function defined by tform.
%
%   XY = transformPointsForward(tform, UV) maps points UV using the forward
%   mapping function defined by tform.
%
%   [X, Y] = transformPointsForward(tform, U, V) maps points U and V using
%   the forward mapping function defined by tform.
%
%   geometricTransform2d properties:
%      InverseFcn - function handle for inverse mapping (required argument)
%      ForwardFcn - function handle for forward mapping (optional argument)
%
%   geometricTransform2d methods:
%      geometricTransform2d - construct 2-D geometricTransform object
%      transformPointsForward - Apply forward custom geometric transformation to points
%      transformPointsInverse - Apply inverse custom geometric transformation to points
%
%
%   Class Support
%   -------------
%   Points XY or UV must be of size N-by-2 and of class single or double.
%   X, Y, U or V are point arrays of class single or double. Output points
%   are of same size and class as input points.
%
%   Example 1
%   ----------
%   % This example apply inverse geometric transform to input
%   % points
%
%   % Input points
%   XY = [10 15;11 32;15 34]
%
%   % Construct a 2-D geometric transform object defined by a
%   % mathematical function
%   inversefn = @(c) [c(:,1)+c(:,2),c(:,1)-c(:,2)];
%   tform = geometricTransform2d(inversefn);
%
%   % Apply inverse geometric transform to input points
%   UV = transformPointsInverse(tform,XY)
%
%   Example 2
%   ---------
%   % This example apply inverse geometric transform to input
%   % points
%   
%   % Input points
%   X = [10; 11; 15]
%   Y = [15; 32; 34]
%
%   % Construct a 2-D geometric transform object defined by a
%   % mathematical function
%   inversefn = @(c) [c(:,1).^2, sqrt(c(:,2))];
%   forwardfn = @(c) [sqrt(c(:,1)),(c(:,2).^2)];
%   tform = geometricTransform2d(inversefn,forwardfn);
%
%   % Apply inverse and forward geometric transform to input points
%   [U,V] = transformPointsInverse(tform,X,Y)
%   [X,Y] = transformPointsForward(tform,U,V)
%
%   Example 3 
%   ---------
%   % This example swaps the horizontal and vertical coordinates.
%   
%   % Construct a 2-D geometric transform object defined by a
%   % mathematical function
%   
%   f = @(c) fliplr(c);
%   tform = geometricTransform2d(f);
%
%   % Input image to be transformed
%   Inp = imread('cameraman.tif');
%   figure, imshow(Inp)
%
%   % Apply inverse geometric transform to input image
%   out = imwarp(Inp,tform);
%   figure, imshow(out)
%
%   Example 4
%   ---------
%   % This example uses the square of the polar radial component.
%   
%   % Construct a 2-D geometric transform object defined by a
%   % mathematical function
%   r = @(c) sqrt(c(:,1).^2 + c(:,2).^2);
%   w = @(c) atan2(c(:,2), c(:,1));
%   f = @(c) [r(c).^2 .* cos(w(c)), r(c).^2 .* sin(w(c))];
%   g = @(c) f(c);
%   tform = geometricTransform2d(g);
%
%   % Input image to be transformed
%   Inp = imread('peppers.png');
%   figure, imshow(Inp)
%
%   % Create an imref2d object, specifying the size and world limits of
%   % the input and output image.
%   Rin = imref2d([384 512],[-1 1],[-1 1]);
%   Rout = imref2d([384 512],[-1 1],[-1 1]);
%
%   % Apply inverse geometric transform to input image
%   out = imwarp(Inp,Rin,tform,'OutputView',Rout);
%   figure, imshow(out)
%
%   See also affine2d, rigid2d, projective2d, affine3d, geometricTransform3d, imwarp.

% Copyright 2018-2020 The MathWorks, Inc.

classdef geometricTransform2d < images.geotrans.internal.GeometricTransformation
    %% class file for geometricTransform
    properties(SetAccess = private)
        InverseFcn; %% function handle for inverse mapping
        ForwardFcn; %% function handle for forward mapping
    end
    
    properties (Hidden)
        IsBidirectional
    end
    
    properties (Constant)
        Dimensionality = 2
    end
    
    methods
        
        function obj = geometricTransform2d(varargin)
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
                if ~isequal(size(U,2),2)
                    error(message('images:geotrans:transformPointsPackedMatrixInvalidSize',...
                        'transformPointsForward','U'));
                end
                validateattributes(U,{'single','double'},{'2d','nonsparse'},'images:geometricTransform2d:transformPointsForward','U');
                varargout{1} = feval(obj.ForwardFcn,U);
                
            else
                
                narginchk(3,3);
                nargoutchk(0,2);
                u = varargin{1};
                v = varargin{2};
                
                if ~isequal(size(u),size(v))
                    error(message('images:geotrans:transformPointsSizeMismatch','transformPointsForward','U','V'));
                end
                
                validateattributes(u,{'single','double'},{'2d','nonsparse'},'images:geometricTransform2d:transformPointsForward','U');
                validateattributes(v,{'single','double'},{'2d','nonsparse'},'images:geometricTransform2d:transformPointsForward','V');
                
                tempVal = feval(obj.ForwardFcn,[u(:),v(:)]);
                varargout{1} = reshape(tempVal(:,1),size(u));
                varargout{2} = reshape(tempVal(:,2),size(v));
                
            end
            
        end
        
        
        function varargout = transformPointsInverse(obj,varargin)
            %% apply inverse geometric transform
            packedPointsSpecified = (nargin==2);
            if packedPointsSpecified
                X = varargin{1};
                nargoutchk(0,1);
                if ~isequal(size(X,2),2)
                    error(message('images:geotrans:transformPointsPackedMatrixInvalidSize',...
                        'transformPointsInverse','X'));
                end
                validateattributes(X,{'single','double'},{'2d','nonsparse'},'images:geometricTransform2d:transformPointsInverse','X');
                varargout{1} = feval(obj.InverseFcn,X);
                
            else
                
                narginchk(3,3);
                nargoutchk(0,2);
                x = varargin{1};
                y = varargin{2};
                
                if ~isequal(size(x),size(y))
                    error(message('images:geotrans:transformPointsSizeMismatch','transformPointsInverse','X','Y'));
                end
                validateattributes(x,{'single','double'},{'2d','nonsparse'},'images:geometricTransform2d:transformPointsInverse','X');
                validateattributes(y,{'single','double'},{'2d','nonsparse'},'images:geometricTransform2d:transformPointsInverse','Y');
                
                tempVal = feval(obj.InverseFcn,[x(:),y(:)]);
                varargout{1} = reshape(tempVal(:,1),size(x));
                varargout{2} = reshape(tempVal(:,2),size(y));
                
            end
        end
        
        % Set methods
        function obj = set.ForwardFcn(obj,forwardfunction)
            validateattributes(forwardfunction,{'function_handle'},{},...
                'geometricTransform2d.set.ForwardFcn',...
                'ForwardFcn');
            obj.ForwardFcn = forwardfunction;
            if ~isempty(forwardfunction)
                obj = setBidirection(obj);
            end
            
        end
        
        function obj = set.InverseFcn(obj,inversefunction)
            % validate function
            validateattributes(inversefunction,{'function_handle'},{},...
                'geometricTransform2d.set.InverseFcn',...
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