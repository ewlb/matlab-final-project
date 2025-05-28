% This function parse input for imcrop, both cpu and gpu version, when the
% input number is larger or equal than 2. (not interactive sytanx)

% Copyright 2021 The MathWorks, Inc.

function [x,y,a,cm,spatial_rect,h_image,placement_cancelled] = parseInputsOverTwo(varargin)

x = [];
y = [];
a = [];
cm = [];
spatial_rect = [];
h_image = [];
placement_cancelled = false;

narginchk(2,5);

switch nargin
    
    case 2
        % IMCROP(X,MAP)
        a = varargin{1};
        x = [1 size(a,2)];
        y = [1 size(a,1)];
        
        images.internal.crop.checkForInvertedWorldCoordinateSystem(x,y);
        
        if isa(varargin{2}, 'images.spatialref.Rectangle')
            % IMCROP(I,RECT) , IMCROP(RGB,RECT)
            % RECT is a images.spatialref.Rectangle object
            checkCData(a);
            spatial_rect  = spatialRectObject2Rect(varargin{2});
            validateRectangle(spatial_rect,2);
        elseif size(varargin{2},2)==3 && (numel(varargin{2}) ~= 4) &&...
                ~isa(varargin{2}, 'images.spatialref.Rectangle')
            % IMCROP(X,MAP)
            if isgpuarray(varargin{1})
                error('interactive syntaxes not supported for gpuArray');
            end
            cm = varargin{2};
            if iscategorical(a)
                error(message('images:imcrop:categoricalUnsupportedSyntax'));
            end
            validateattributes(a,{'logical','single','double','uint16', 'uint8'}, ...
                {'real','nonsparse'},mfilename,'X',1);
            imshow(a,cm);
            [spatial_rect,h_image,placement_cancelled] = images.internal.crop.interactiveCrop(gcf);
                    
        else
            % IMCROP(I,RECT) , IMCROP(RGB,RECT)
            % RECT is in [X, Y, Width, Height] format
            checkCData(a);
            spatial_rect = varargin{2};
            validateRectangle(spatial_rect,2);
        end

    case 3
        if (size(varargin{3},3) == 3)
            % IMCROP(x,y,RGB)
            x = varargin{1};
            y = varargin{2};
            a = varargin{3};
            
            images.internal.crop.checkForInvertedWorldCoordinateSystem(x,y);
            
            validateattributes(a,{ 'int16','single','double','uint16', 'uint8'}, ...
                {'real','nonsparse'},mfilename,'RGB',1);
            imshow(a,'XData',x,'YData',y);
            [spatial_rect,h_image,placement_cancelled] = images.internal.crop.interactiveCrop(gcf);
        elseif isvector(varargin{3}) || isa(varargin{3},'images.spatialref.Rectangle')
            % This logic has some holes but it is less hole-ly than the previous
            % version. Furthermore, it is very unlikely that a user
            % would use IMCROP(x,y,I) if I was a vector.

            % IMCROP(X,MAP,RECT)
            a = varargin{1};
            checkCData(a);
            if iscategorical(a)
                error(message('images:imcrop:categoricalUnsupportedSyntax'));
            end
            cm = varargin{2};
            
            if(isa(varargin{3},'images.spatialref.Rectangle'))
                % RECT (3rd arg) is a images.spatialref.Rectanglr object
                % Convert to [x y width height] format.
                spatial_rect = spatialRectObject2Rect(varargin{3});
            else
                % RECT is in [x y width height] format.
                spatial_rect = varargin{3};
            end
            validateRectangle(spatial_rect,3);
            x = [1 size(a,2)];
            y = [1 size(a,1)];
        else
            % IMCROP(x,y,I)
            x = varargin{1};
            y = varargin{2};
            a = varargin{3};
            
            images.internal.crop.checkForInvertedWorldCoordinateSystem(x,y)
            
            validateattributes(a,{'int16','logical','single','double','uint16', 'uint8'}, ...
                {'real','nonsparse'},mfilename,'I',1);
            imshow(a,'XData',x,'YData',y);
            [spatial_rect,h_image,placement_cancelled] = images.internal.crop.interactiveCrop(gcf);
        end

    case 4
        % IMCROP(x,y,I,RECT) , IMCROP(x,y,RGB,RECT)
        x = varargin{1};
        y = varargin{2};
        a = varargin{3};
        checkCData(a);
        if(isa(varargin{4},'images.spatialref.Rectangle'))
            % RECT (4th arg) is a images.spatialref.Rectangle object
            % Convert to [x y width height] format.
            spatial_rect = spatialRectObject2Rect(varargin{4});
        else
            % RECT is in [x y width height] format.
            spatial_rect = varargin{4};
        end
        validateRectangle(spatial_rect,4);
    case 5
        % IMCROP(x,y,X,MAP,RECT)
        x = varargin{1};
        y = varargin{2};
        a = varargin{3};
        checkCData(a);
        if iscategorical(a)
            error(message('images:imcrop:categoricalUnsupportedSyntax'));
        end
        cm = varargin{4};
        if(isa(varargin{5},'images.spatialref.Rectangle'))
            % RECT (5th arg) is a images.spatialref.Rectanglr object
            % Convert to [x y width height] format.
            spatial_rect = spatialRectObject2Rect(varargin{5});
        else
            % RECT is in [x y width height] format.
            spatial_rect = varargin{5};
        end
        validateRectangle(spatial_rect,5);
end

images.internal.crop.checkForInvertedWorldCoordinateSystem(x,y);

end %parseInputs

%-------------------------
function checkCData(cdata)

right_type = (isnumeric(cdata) || islogical(cdata) || iscategorical(cdata)) &&...
    ~issparse(cdata);

if(~iscategorical(cdata))
    right_type = right_type && isreal(cdata);
elseif (iscategorical(cdata))
    % gpuArray not support input as categorical
    right_type = ~isgpuarray(cdata);
end

is_2d = ismatrix(cdata);
is_rgb = (ndims(cdata) == 3) && (size(cdata,3) == 3) && (~iscategorical(cdata));

if ~right_type || ~(is_2d || is_rgb)
    error(message('images:imcrop:invalidInputImage'));
end

end %checkCData

%-------------------------------
function validateRectangle(rect,inputNumber)

validateattributes(rect,{'numeric'},{'real','vector'}, ...
    mfilename,'RECT',inputNumber);

% rect must contain 4 elements: [x,y,w,h]
if(numel(rect) ~= 4)
    error(message('images:validate:badInputNumel',inputNumber,'RECT',4));
end

end %validateRectangle

function rect =  spatialRectObject2Rect(rectObj)
% Convert images.spatialref.Rectangle object to [ x y width height] format.

rectWidth = rectObj.XLimits(2)-rectObj.XLimits(1);
rectHeight = rectObj.YLimits(2)-rectObj.YLimits(1);

rect = [rectObj.XLimits(1) rectObj.YLimits(1) rectWidth rectHeight];
end