function [Gx, Gy] = imgradientxy(varargin) %#codegen
%IMGRADIENTXY Find the directional gradients of an image.

% Copyright 2021 The MathWorks, Inc.

%  Syntax
%  ------
%
%  [Gx, Gy] = imgradientxy(I)
%  [Gx, Gy] = imgradientxy(I, Method)
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
%     string with values either 'sobel', 'prewitt', 'centraldifference' or
%     'intermediatedifference'
%     Default: 'sobel'
%
%  Output Specs
%  ------------
%
%  Gx:
%     single for input image of single datatype
%     double for other input datatypes
%     same size as I
%
%  Gy:
%     single for input image of single datatype
%     double for other input datatypes
%     same size as I


narginchk(1, 2);

validateattributes(varargin{1}, {'numeric','logical'},{'2d','nonsparse','real'}, ...
    mfilename,'I',1);

% Error out if input image has more than 2 dimensions
coder.internal.errorIf(numel(size(varargin{1})) > 2, ...
    'images:validate:tooManyDimensions', 'I', 2);

I = varargin{1};

if (nargin > 1)
    methodstrings = {'sobel', 'prewitt','centraldifference', ...
        'intermediatedifference'};
    
    method = validatestring(varargin{2}, methodstrings, ...
        mfilename, 'METHOD', 2);
else
    method = 'sobel'; % Default method
end

if isa(I,'single')
    classToCast = 'single';
else
    classToCast = 'double';
end

switch method
    case 'sobel'
        im = cast(I, classToCast);
        h = -fspecial('sobel'); % Align mask correctly along the x- and y- axes
        Gx = imfilter(im, h', 'replicate');
        if nargout > 1
            Gy = imfilter(im, h, 'replicate');
        end
        
    case 'prewitt'
        im = cast(I, classToCast);
        h = -fspecial('prewitt'); % Align mask correctly along the x- and y- axes
        Gx = imfilter(im, h', 'replicate');
        if nargout > 1
            Gy = imfilter(im, h, 'replicate');
        end
        
    case 'centraldifference'
        im = cast(I, classToCast);
        if isrow(im)
            Gx = gradient(im);
            if nargout > 1
                Gy = zeros(size(im), 'like', im);
            end
        elseif iscolumn(im)
            Gx = zeros(size(im), 'like', im);
            if nargout > 1
                Gy = gradient(im);
            end
        else
            [Gx, Gy] = gradient(im);
        end
        
    case 'intermediatedifference'
        Gx = cast(zeros(size(I)), classToCast);
        if nargout > 1
            Gy = cast(zeros(size(I)), classToCast);
        end
        
        if coder.isColumnMajor
            for j = 1:(size(I,2))
                for i = 1:(size(I,1))
                    if(j < size(I,2))
                        Gx(i,j) = cast(I(i, j+1), classToCast) -...
                            cast(I(i, j), classToCast);
                    end
                    if nargout > 1
                        if(i < size(I,1))
                            Gy(i,j) = cast(I(i+1, j), classToCast) -...
                                cast(I(i, j), classToCast);
                        end
                    end
                end
            end
        else % coder.isRowMajor
            for i = 1:(size(I,1))
                for j = 1:(size(I,2))
                    if(j < size(I,2))
                        Gx(i,j) = cast(I(i, j+1), classToCast) -...
                            cast(I(i, j), classToCast);
                    end
                    if nargout > 1
                        if(i < size(I,1))
                            Gy(i,j) = cast(I(i+1, j), classToCast) -...
                                cast(I(i, j), classToCast);
                        end
                    end
                end
            end
        end
        
        
    otherwise
        assert(false, 'Unsupported method.');
        
end