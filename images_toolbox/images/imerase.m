function outputImage = imerase(A,win,params)
%imerase Remove image pixels within a region of interest.
%   B = imerase(A,win) remove pixels of image, A, within a rectangular region
%   defined by win. win is a 1-by-4 vector of the form [x,y,width,height]
%   or an images.spatialref.Rectangle object defining the erasing window.
%   The image can be grayscale or truecolor. The transformed image is
%   returned as B.
%
%   B = imerase(A,win,'FillValues',fillValue) also specifies the fill values 
%   of pixels in the erased region. fillValue can be a numeric scalar,
%   a row numeric vector, or a numeric array whose size matches the
%   size of the erased region. For a scalar or row vector, the function 
%   replaces all erased pixels with the specified grayscale or RGB value
%   respectively. The specified value must be of same datatype as of input
%   image. Some possibilities for fillValue include:                     
%       0                               - fill with black
%       [0,0,0]                         - also fill with black
%       255                             - fill with white
%       [255,255,255]                   - also fill with white
%       [0,0,255]                       - fill with blue
%       [255,255,0]                     - fill with yellow
%       randi([1,255],[win(4) win(3)])  - fill with random values.       
%
%       Default: 0
%
%   Example: Apply random erasing augmentation.
%   -------------------------------------------
%
%   % Read image.
%   I = imread('peppers.png');
%
%   % Apply random erase function on an image.
%   win = randomWindow2d(size(I),'Scale',[0.02,0.13],'DimensionRatio',[1,1;1,1]);
%   J = imerase(I,win,'FillValues',0);
%
%   % Display the original and augmented images.
%   figure, montage({I,J})
%
%   See also imwarp, imref2d, randomWindow2d, affineOutputView.
   
%   Copyright 2020 The MathWorks, Inc.

    arguments
        A (:,:,:) {mustBeNumeric,mustBeFinite,mustBeReal,mustBeNonnegative,mustBeNonsparse,mustBeNonempty}
        win {mustBeNumericOrObject(win),mustBeSize(win),mustBeValidDatatype(win)}
        params.FillValues {mustBeNonempty,mustBeNumeric,mustBeReal,mustBeFinite,mustBeNonsparse} = 0
    end
        
    params.c = size(A,3);
    
    % Cutting out the patch from image.
    outputImage = iApplyCutout(A,win,params);
    
    % cast the output image to datatype of input image.
    outputImage = cast(outputImage,class(A));

end

%% Supporting function.

function Tout = iApplyCutout(inp,coord,params)
% Apply cutout on Image.

    if(isa(coord,'images.spatialref.Rectangle'))
        coord = icomputeCoordinates([coord.XLimits(1),coord.YLimits(1),coord.XLimits(2),coord.YLimits(2)]);
    end
    
    % Check valid Size of FillValues
    iValidValueArgument(params.FillValues,coord,params.c);

    %Check Bounding box
    iCheckBoundingBox(coord,inp);
    Tout = inp;
    
    % Cast FillValues to data type of input image
    params.FillValues = cast(params.FillValues, 'like', inp);
    valueSize = size(params.FillValues);
    
    % Adding +1 to coord(4),coord(3) to compute the number of pixels that 
    % needs to be filled with new values.
    fillValueMatchesSpatialDims = isequal(valueSize(1:2),[coord(4)+1,coord(3)+1]);

    if any(valueSize(1:2) == 1)
        params.FillValues = isScalarChannel(params);
        for i=1:params.c
            Tout(coord(2):coord(2)+coord(4),coord(1):coord(1)+coord(3),i)=params.FillValues(i);
        end
    elseif fillValueMatchesSpatialDims
        params.FillValues = isScalarChannel(params);
        Tout(coord(2):coord(2)+coord(4),coord(1):coord(1)+coord(3),:)=params.FillValues;
    else
        assert(false,"Unexpected fill value spatial dim size");
    end
end

function boxes = ixywhToX1Y1X2Y2(boxes)
    % Convert [x y w h] box to [x1 y1 x2 y2]. Input and output
    % boxes are in pixel coordinates. boxes is an M-by-4
    % matrix.
    boxes(:,3) = boxes(:,1) + boxes(:,3);
    boxes(:,4) = boxes(:,2) + boxes(:,4);
end

function fillValues = isScalarChannel(params)
if(size(params.FillValues,3)==1)
    fillValues = repmat(params.FillValues,[1,1,params.c]);
else
    fillValues = params.FillValues;
end
end

function boxes = icomputeCoordinates(boxes)
    % Convert images.spatialref.Rectangle limits to [x y w h] format. 
    % Input and output boxes are in pixel coordinates. boxes is an M-by-4
    % matrix.
    boxes(:,3) = boxes(:,3) - boxes(:,1);
    boxes(:,4) = boxes(:,4) - boxes(:,2);
end

function mustBeNumericOrObject(args)
    % Check the argument is either numeric or
    % images.spatialref.Rectangle Object.
    if~(isa(args,'numeric') || isa(args,'images.spatialref.Rectangle'))
        error(message('images:imerase:InvalidDataType'))
    end
    
    if(isa(args,'images.spatialref.Rectangle'))
        validateattributes(args,{'images.spatialref.Rectangle'},...
        {'size',[1,1]},mfilename,'win',2);
    end

end

function mustBeValidDatatype(args)
    % Check the argument is positive and Integer.
    if(isa(args,'numeric'))
        mustBeInteger(args);
        mustBePositive(args);
    end
end

function mustBeSize(args)
    % Verify the size of argument must be 1x4.
    if(isa(args,'numeric') && ~isequal(size(args),[1,4]))
        error(message('images:imerase:InvalidSize'))
    end
end

function iCheckBoundingBox(coord,img)
    % Check Bounding box does not exceed image dimension.
    coord = ixywhToX1Y1X2Y2(coord);
    if(any(coord([1,3])>size(img,2)) || any(coord([2,4])>size(img,1)))
        error(message('images:imerase:InvalidBoxDimension'))
    end
end

function iValidValueArgument(value,win,channel)
    % validate size of DimensionRatio NVP.
    targetSize = [win(4)+1 win(3)+1];
    valueSize = size(value);
    valueSize = valueSize(1:2);
    if ~((isequal(valueSize,targetSize) && (size(value,3)==1 || size(value,3)==channel)) ...
            || isequal(valueSize,[1,channel]) || isequal(valueSize,[1,1]))
        error(message('images:imerase:Value'))
    end
end