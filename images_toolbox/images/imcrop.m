function varargout = imcrop(varargin)
%IMCROP Crop image.
%   I = IMCROP creates an interactive image cropping tool, associated with
%   the image displayed in the current figure, called the target image. The
%   tool is a moveable, resizable rectangle that is interactively placed
%   and manipulated using the mouse.  After positioning the tool, the user
%   crops the target image by either double clicking on the tool or
%   choosing 'Crop Image' from the tool's context menu.  The cropped image,
%   I, is returned.  The cropping tool can be deleted by pressing
%   backspace, escape, or delete, or via the 'Cancel' option from the
%   context menu.  If the tool is deleted, all return values are set to
%   empty.
%
%   I2 = IMCROP(I) displays the image I in a figure window and creates a
%   cropping tool associated with that image.  I can be a grayscale image,
%   an RGB image, or a logical array.  The cropped image returned, I2, is
%   of the same type as I.
%
%   X2 = IMCROP(X,MAP) displays the indexed image [X,MAP] in a figure
%   window and creates a cropping tool associated with that image.
%
%   I = IMCROP(H) creates a cropping tool associated with the image
%   specified by handle H.  H may be an image, axes, uipanel, or figure
%   handle.  If H is an axes, uipanel, or figure handle, the cropping tool
%   acts on the first image found in the container object.
%
%   The cropping tool blocks the MATLAB command line until the operation is
%   completed.
%
%   You can also specify the cropping rectangle non-interactively, using
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
%   C2 = IMCROP(C, RECT) crops a categorical input C based on the crop
%   window specified by RECT and  returns a cropped categorical image C2.
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
%   logical, numeric or categorical, and must be real and nonsparse. RECT is 
%   either numeric or an object of type images.spatialref.Rectangle.
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
%   If you don't specify the image as an input argument, i.e., you call
%   IMCROP with 0 input arguments or a handle, then the output image has
%   the same class as the target image except for the int16 or single data
%   type. The output image is double if the input image is int16 or single.
%
%   Example
%   -------
%   I = imread('circuit.tif');
%   I2 = imcrop(I,[60 40 100 90]);
%   figure, imshow(I)
%   figure, imshow(I2)
%
%   See also zoom, drawrectangle.

%  Copyright 1993-2021 The MathWorks, Inc.

if nargin < 2
    % if interactive sytanx
    [x,y,a,cm,spatial_rect,h_image,placement_cancelled] = parseInputs(varargin{:});
else
    [x,y,a,cm,spatial_rect,h_image,placement_cancelled] = ...
        images.internal.crop.parseInputsOverTwo(varargin{:});
end

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

function [x,y,a,cm,spatial_rect,h_image,placement_cancelled] = parseInputs(varargin)

x = [];
y = [];
a = [];
cm = [];
spatial_rect = [];
h_image = [];
placement_cancelled = false;

narginchk(0,1);

switch nargin
    case 0
        % IMCROP()

        % verify we have a target image
        hFig = get(0,'CurrentFigure');
        hAx  = get(hFig,'CurrentAxes');
        hIm = findobj(hAx, 'Type', 'image');
        if isempty(hIm)
            error(message('images:imcrop:noImage'))
        end

        [x,y,a,~,cm] = validateTargetHandle(hIm);
        
        images.internal.crop.checkForInvertedWorldCoordinateSystem(x,y)
        
        [spatial_rect,h_image,placement_cancelled] = images.internal.crop.interactiveCrop(hIm);

    case 1
        a = varargin{1};
        if isscalar(a) && ishghandle(a)
            % IMCROP(H)
            h = a;
            [x,y,a,~,cm] = validateTargetHandle(h);
            
            images.internal.crop.checkForInvertedWorldCoordinateSystem(x,y);
            
            [spatial_rect,h_image,placement_cancelled] = images.internal.crop.interactiveCrop(h);
        else
            % IMCROP(I) , IMCROP(RGB)
            x = [1 size(a,2)];
            y = [1 size(a,1)];
            
            images.internal.crop.checkForInvertedWorldCoordinateSystem(x,y);
            
            if iscategorical(a)
                error(message('images:imcrop:categoricalUnsupportedSyntax'));
            end
            validateattributes(a,{'logical','int16','single','double','uint16',...
                'uint8'},{'real','nonsparse'},mfilename,'I, RGB, or H',1);
            imshow(a);
            [spatial_rect,h_image,placement_cancelled] = images.internal.crop.interactiveCrop(gcf);
        end
end

images.internal.crop.checkForInvertedWorldCoordinateSystem(x,y);

end

%-----------------------------------------------------------------------

function [x,y,a,flag,cm] = validateTargetHandle(h)

[x,y,a,flag] = getimage(h);
if (flag == 0)
    error(message('images:imcrop:noImageFoundInCurrentAxes'));
end
if (flag == 1)
    % input image is indexed; get its colormap
    cm = colormap(ancestor(h,'axes'));
else
    cm = [];
end

end

