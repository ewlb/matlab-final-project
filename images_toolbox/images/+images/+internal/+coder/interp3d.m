function outputImage = interp3d(inputImage,X,Y,Z,method,fillValue,varargin) %#codegen

% Copyright 2023 The MathWorks, Inc.

coder.inline('always');
coder.internal.prefer_const(inputImage,X,Y,Z,method,fillValue,varargin);

narginchk(6,7);

if(nargin==6)
    % If not specified, default to smoothing edges
    smoothEdges = true;
else
    smoothEdges = varargin{1};
end

validateattributes(inputImage,{'numeric','logical'},{'nonsparse'},mfilename,'inputImage');

validateattributes(X,{'single','double'},{'nonsparse','real'},mfilename,'X');

validateattributes(Y,{'single','double'},{'nonsparse','real'},mfilename,'Y');

validateattributes(Z,{'single','double'},{'nonsparse','real'},mfilename,'Z');

validateattributes(fillValue,{'numeric','logical'},{'nonsparse'},mfilename,'fillValue');
fillValue = cast(fillValue, 'like', real(inputImage));

if(smoothEdges)
    [paddedImage,X,Y,Z] = padImage(inputImage,X,Y,Z,fillValue);
else
    paddedImage = inputImage;
end

% For now we only have an optimized codepath for interp3 for the linear
% interpolation case for all datatypes except logical.
if strcmp(method,'linear') && ~isa(paddedImage,'logical')
    if isa(paddedImage, 'single')
        Xpad = single(X); Ypad= single(Y); Zpad = single(Z);
    else
        Xpad = double(X); Ypad = double(Y); Zpad = double(Z);
    end

    if isreal(paddedImage)
        outputImage = images.internal.coder.interp3dImpl(paddedImage,Xpad,Ypad,Zpad,fillValue);
    else
        outputImage = complex(images.internal.coder.interp3dImpl(real(paddedImage),Xpad,Ypad,Zpad,fillValue),...
            images.internal.coder.interp3dImpl(imag(paddedImage),Xpad,Ypad,Zpad,fillValue));
    end
else
    if ~isa(paddedImage,'double')
        paddedImageDouble = double(paddedImage);
    else
        paddedImageDouble = paddedImage;
    end
    fillValue = double(fillValue);
    outputImage = interp3(paddedImageDouble,X,Y,Z,method,fillValue);
end


function [paddedImage,X,Y,Z] = padImage(inputImage,X,Y,Z,fillValue)
% We achieve the 'fill' pad behavior from makeresampler by prepadding our
% image with the fillValue and translating our X,Y locations to the
% corresponding locations in the padded image.
coder.inline('always');
pad = 3;
paddedImage = padarray(inputImage,[pad pad,pad],fillValue);
X = X+pad;
Y = Y+pad;
Z = Z+pad;