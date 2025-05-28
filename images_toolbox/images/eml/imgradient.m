function [Gmag, Gdir] = imgradient(varargin) %#codegen
%IMGRADIENT Find the gradient magnitude and direction of an image.

% Copyright 2021 The MathWorks, Inc.

%  Syntax
%  ------
%
%  [Gmag, Gdir] = imgradient(I)
%  [Gmag, Gdir] = imgradient(I, Method)
%  [Gmag, Gdir] = imgradient(Gx, Gy)
%
%  Input Specs
%  ------------
%
%  I:
%     real
%     2D grayscale or 2D binary image
%     'single', 'double', 'int8', 'int32', 'uint8', 'uint16', 'uint32',
%     'logical'
%
%   Method:
%     string with values either 'sobel', 'prewitt', 'centraldifference',
%     'intermediatedifference' or 'roberts'
%     Default: 'sobel'
%
%   Gx, Gy:
%     real, numeric or logical
%     2D
%
%
%  Output Specs
%  ------------
%
%  Gmag:
%     single if input image I and the one or both of input directional
%     gradients of single datatype, otherwise, double for all cases
%     same size as I
%
%  Gdir:
%     single if input image I and the one or both of input directional
%     gradients of single datatype, otherwise, double for all cases
%     same size as I

narginchk(1, 2);

if nargin == 1
    I = varargin{1};
    validateattributes(I, {'numeric','logical'},{'2d','nonsparse','real'}, ...
        mfilename,'I',1);
    
    % Error out if input image has more than 2 dimensions
    coder.internal.errorIf(numel(size(I)) > 2,...
        'images:validate:tooManyDimensions', 'I', 2);
    
    method = 'sobel';
    
    % Compute Gx and Gy
    [Gx, Gy] = computeGxGy(I, method);
    
else % nargin == 2
    if ischar(varargin{2}) || isstring(varargin{2})
        I = varargin{1};
        validateattributes(I, {'numeric','logical'},{'2d','nonsparse','real'}, ...
            mfilename,'I',1);
        
        % Error out if input image has more than 2 dimensions
        coder.internal.errorIf(numel(size(I)) > 2, ...
            'images:validate:tooManyDimensions', 'I', 2);
        
        methodstrings = {'sobel', 'prewitt', 'roberts', 'centraldifference', ...
            'intermediatedifference'};
        method = validatestring(varargin{2}, methodstrings, ...
            mfilename, 'METHOD', 2);
        
        % Gx and Gy are not given, use IMGRADIENTXY to compute Gx and Gy for
        % except roberts method
        [Gx, Gy] = computeGxGy(I, method);
        
    else
        GxIn = varargin{1};
        GyIn = varargin{2};
        
        method = 'sobel';
        
        validateattributes(GxIn, {'numeric','logical'}, {'2d','nonsparse', ...
            'real'}, mfilename, 'Gx', 1);
        validateattributes(GyIn, {'numeric','logical'}, {'2d','nonsparse', ...
            'real'}, mfilename, 'Gy', 2);
        
        coder.internal.errorIf(~isequal(size(GxIn),size(GyIn)),...
            'images:validate:unequalSizeMatrices', 'Gx', 'Gy');
        
        coder.internal.errorIf(~isequal(class(GxIn),class(GyIn)),...
            'images:validate:differentClassMatrices', 'Gx', 'Gy');
        
        if isa(GxIn,'single')
            classToCast = 'single';
        else
            classToCast = 'double';
        end
        
        Gx = cast(GxIn, classToCast);
        
        if isa(GyIn,'single')
            classToCast = 'single';
        else
            classToCast = 'double';
        end
        
        Gy = cast(GyIn, classToCast);
    end
end

% Compute gradient magnitude
Gmag = sqrt(Gx.^2 + Gy.^2);

% Compute gradient direction
if (nargout > 1)
    if (strcmpi(method,'roberts'))
        Gdir = coder.nullcopy(zeros(size(Gx)));
    else
        Gdir = coder.nullcopy(zeros(size(Gx), 'like', Gx));
    end
    
    if coder.isRowMajor
        coder.internal.treatAsParfor;
        for i = 1:size(Gdir,1)
            for j = 1:size(Gdir,2)
                Gdir(i,j) = computeGdir(Gx(i,j), Gy(i,j), method);
            end
        end
    else
        coder.internal.treatAsParfor;
        for j = 1:size(Gdir,2)
            for i = 1:size(Gdir,1)
                Gdir(i,j) = computeGdir(Gx(i,j), Gy(i,j), method);
            end
        end
    end
end
end

%--------------------------------------------------------------------------
function [Gx, Gy] = computeGxGy(I, method)
coder.inline('always');
coder.internal.prefer_const(I, method)

if (strcmpi(method, 'roberts'))
    if isa(I, 'single')
        classToCast = 'single';
    else
        classToCast = 'double';
    end
    Iin = cast(I, classToCast);
    Gx = imfilter(Iin, [1 0; 0 -1], 'replicate');
    Gy = imfilter(Iin, [0 1; -1 0], 'replicate');
else
    [Gx, Gy] = imgradientxy(I, method);
end
end

%--------------------------------------------------------------------------
function Gdir = computeGdir(Gx,Gy, method)
coder.inline('always');
coder.internal.prefer_const(Gx,Gy, method);

if (strcmpi(method,'roberts'))
    % For pixels with zero gradient (both Gx and Gy zero), Gdir is set
    % to 0. Compute direction only for pixels with non-zero gradient.
    
    if ~(Gx == 0 && Gy == 0)
        theta = cast(atan2(Gy,-Gx) - (pi/4), 'double');
        if theta < -pi
            theta =  theta + 2*pi;
        end
        Gdir = theta*(180/pi);
    else
        Gdir = 0;
    end
else
    Gdir = atan2(-Gy, Gx)*180/pi; % Radians to degrees
end
end