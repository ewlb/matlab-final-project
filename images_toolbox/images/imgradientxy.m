function [Gx, Gy] = imgradientxy(varargin)
%IMGRADIENTXY Find the directional gradients of an image.
%   [Gx, Gy] = IMGRADIENTXY(I) takes a grayscale or binary image I as input
%   and returns the gradient along the X axis, Gx, and the Y axis, Gy.
%   X axis points in the direction of increasing column subscripts and
%   Y axis points in the direction of increasing row subscripts. Gx and Gy
%   are the same size as the input image I.
%
%   [Gx, Gy] = IMGRADIENTXY(I, METHOD) calculates the directional gradients
%   of the image I using the specified METHOD. Supported METHODs are:
%
%       'sobel'                 : Sobel gradient operator (default)
%
%       'prewitt'               : Prewitt gradient operator
%
%       'central'               : Central difference gradient dI/dx = (I(x+1)- I(x-1))/ 2
%
%       'intermediate'          : Intermediate difference gradient dI/dx = I(x+1) - I(x)
%
%   Class Support 
%   ------------- 
%   The input image I can be numeric or logical two-dimensional matrix, and
%   it must be nonsparse. Both Gx and Gy are of class double, unless the
%   input image I is of class single, in which case Gx and Gy will be of
%   class single.
%
%   Notes
%   -----
%   1. When applying the gradient operator at the boundaries of the image,
%      values outside the bounds of the image are assumed to equal the
%      nearest image border value. This is similar to the 'replicate'
%      boundary option in IMFILTER.
%
%
%   Example 1
%   ---------
%   % Compute and display the directional gradients of the image using
%   % Prewitt's gradient operator.
%       I = imread('coins.png');
%       imshow(I)
%   
%       [Gx, Gy] = imgradientxy(I,'prewitt');
% 
%       figure, imshow(Gx, []), title('Directional gradient: X axis')
%       figure, imshow(Gy, []), title('Directional gradient: Y axis')
%
%   Example 2
%   ---------
%   % Compute and display both the directional gradients and the gradient
%   % magnitude and gradient direction for the image
%       I = imread('coins.png');
%       imshow(I)
%   
%       [Gx, Gy] = imgradientxy(I);
%       [Gmag, Gdir] = imgradient(Gx, Gy);
% 
%       figure, imshow(Gmag, []), title('Gradient magnitude')
%       figure, imshow(Gdir, []), title('Gradient direction')
%       figure, imshow(Gx, []), title('Directional gradient: X axis')
%       figure, imshow(Gy, []), title('Directional gradient: Y axis')
%
%   See also EDGE, FSPECIAL, IMGRADIENT.

% Copyright 2012-2018 The MathWorks, Inc.

narginchk(1,2);

[I, method] = parse_inputs(varargin{:});

if ~isfloat(I)
    I = double(I);
end

switch method
    case 'sobel'
        h = -fspecial('sobel'); % Align mask correctly along the x- and y- axes
        Gx = imfilter(I,h','replicate');
        if nargout > 1
            Gy = imfilter(I,h,'replicate');
        end
        
    case 'prewitt'
        h = -fspecial('prewitt'); % Align mask correctly along the x- and y- axes
        Gx = imfilter(I,h','replicate');
        if nargout > 1
            Gy = imfilter(I,h,'replicate');
        end        
        
    case 'centraldifference' 
        if isrow(I)            
            Gx = gradient(I);
            if nargout > 1
                Gy = zeros(size(I),'like',I);
            end            
        elseif iscolumn(I)            
            Gx = zeros(size(I),'like',I);
            if nargout > 1
                Gy = gradient(I);
            end                
        else            
            [Gx, Gy] = gradient(I);
        end
   
    case 'intermediatedifference' 
        Gx = zeros(size(I),'like',I);
        if (size(I,2) > 1)        
            Gx(:,1:end-1) = diff(I,1,2);
        end
            
        if nargout > 1
            Gy = zeros(size(I),'like',I);
            if (size(I,1) > 1)
                Gy(1:end-1,:) = diff(I,1,1);
            end
        end
        
end

end
%======================================================================
function [I, method] = parse_inputs(varargin)

I = varargin{1};

validateattributes(I,{'numeric','logical'},{'2d','nonsparse','real'}, ...
                   mfilename,'I',1);

method = 'sobel'; % Default method
if (nargin > 1)
    methodstrings = {'sobel','prewitt','centraldifference', ...
        'intermediatedifference'};
    validateattributes(varargin{2},{'char','string'}, ...
        {'scalartext'},mfilename,'METHOD',2);
    method = validatestring(varargin{2}, methodstrings, ...
        mfilename, 'METHOD', 2);
end

end
%----------------------------------------------------------------------
