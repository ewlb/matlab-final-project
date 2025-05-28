function varargout = imcrop(varargin)
%gpuArray/IMCROP Crop image.
%
%   You can specify the cropping rectangle non-interactively, using
%   these syntaxes:
%
%      I2 = IMCROP(I,RECT)
%      X2 = IMCROP(X,MAP,RECT)
%
%   RECT is either a 4-element vector with the form [XMIN YMIN WIDTH HEIGHT];
%   or a images.spatialref.Rectangle object. These cropping values are 
%   specified in spatial coordinates. RECT can also be specified as an
%   object of type images.spatialref.Rectangle.
%
%   To use a non-default spatial coordinate system for the target image,
%   precede the other input arguments with two 2-element vectors specifying
%   the XData and YData:
%
%     [...] = IMCROP(X,Y,...)
%
%   [I2 RECT] = IMCROP(...) returns the cropping rectangle in addition to the
%   cropped image.
%
%   [X,Y,I2,RECT] = IMCROP(...) additionally returns the XData and YData of
%   the target image.
%
%   Remarks
%   -------
%   Because RECT is specified in terms of spatial coordinates, the WIDTH
%   and HEIGHT of RECT do not always correspond exactly with the size of
%   the output image. For example, suppose RECT is [20 20 40 30], using the
%   default spatial coordinate system. The upper left corner of the
%   specified rectangle is the center of the pixel (20,20) and the lower
%   right corner is the center of the pixel (50,60). The resulting output
%   image is 31-by-41, not 30-by-40, because the output image includes all
%   pixels in the input that are completely or partially enclosed by the
%   rectangle.
%
%   Class Support
%   -------------
%   If you specify RECT as an input argument, then the input image can be
%   logical, numeric, and must be real and nonsparse. RECT is either 
%   numeric or an object of type images.spatialref.Rectangle.
%
%   If you do not specify RECT as an input argument, then IMCROP calls
%   IMSHOW. IMSHOW expects I to be logical, uint8, uint16, int16, double,
%   or single. RGB can be uint8, int16, uint16, double, or single. X can be
%   logical, uint8, uint16, double, or single. The input image must be real
%   and nonsparse.
%
%   If you specify the image as an input argument, then the output image
%   has the same class as the input image.
%
%   Notes
%   ------
%   The gpuArray version of imcrop does not support interactive sytanx
%   The gpuArray version of imcrop does not support zero input argument.
%   The gpuArray version of imcrop does not support input image type as
%   categorical.
%
%   Example
%   -------
%   I = imread('circuit.tif');
%   I = gpuArray(I);
%   I2 = imcrop(I,[60 40 100 90]);
%   figure, imshow(I)
%   figure, imshow(I2)
%
%   See also zoom, drawrectangle.

%  Copyright 2020 The MathWorks, Inc.

[x,y,a,cm,spatial_rect,h_image,placement_cancelled] = images.internal.crop.parseInputsOverTwo(varargin{:});

outputNum = nargout;

switch outputNum
    case 0
        images.internal.crop.algimcrop(x,y,a,cm,spatial_rect,h_image,placement_cancelled,outputNum);
    case 1
        varargout{1} = ...
            images.internal.crop.algimcrop(x,y,a,cm,spatial_rect,h_image,placement_cancelled,outputNum);
    case 2
        [varargout{1},varargout{2}] = ...
            images.internal.crop.algimcrop(x,y,a,cm,spatial_rect,h_image,placement_cancelled,outputNum);
    case 4
        [varargout{1},varargout{2},varargout{3},varargout{4}] = ...
            images.internal.crop.algimcrop(x,y,a,cm,spatial_rect,h_image,placement_cancelled,outputNum);
    otherwise
        error(message('images:imcrop:tooManyOutputArguments'))
end

end
