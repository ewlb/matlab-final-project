function Iout = imblend(fimg, bimg, mask, pvpairs)

arguments
    fimg {validateInputImages};
    bimg {validateInputImages};
    mask {validateMask} = true;
    pvpairs.Mode (1, 1) {validateMode, string} = "Alpha";
    pvpairs.Location {validateLocation} = [1, 1]
    pvpairs.ForegroundOpacity {validateOpacity}
    pvpairs.FilterSize  {validateFilterSize}
end

mode = pvpairs.Mode;
location = pvpairs.Location;
fgMask = mask;


if isfield(pvpairs,"ForegroundOpacity")
    if mode~="Alpha"
        error(message("images:imblend:UnusedparameterForegroundOpacity"));
    else
        fgopacity = pvpairs.ForegroundOpacity;
    end
else
    if mode=="Alpha"
        fgopacity = 0.7;
    end
end

if isfield(pvpairs,"FilterSize")
    if mode~="Guided"
        error(message("images:imblend:UnusedparameterFilterSize"));
    else
        filterSize = pvpairs.FilterSize;
    end
else
    if mode=="Guided"
        filterSize = 3;
    end
end

if ~isscalar(fgMask) & size(fgMask, 1:2) ~= size(fimg, 1:2)
    error(message("images:imblend:badsizeMask"));
end

if isscalar(fgMask) && mode=="Guided"
    error(message("images:imblend:MandatoryMask"));
end
originalClass = class(bimg);


[fimg, bimg] = updateInputs(fimg, bimg, location);

sizebimg = size(bimg);
classbimg = class(bimg);
location = location - [1,1];

% Adjust the spatial location of foreground image and mask as per the location input
[fimg, mask] = adjustForeground(fimg, fgMask, sizebimg, classbimg, location);

switch mode
    case "Alpha"
        Mout = mask*fgopacity;
        Iout = bimg + (fimg-bimg).*Mout;
    case "Guided"
        Mout = imguidedfilter(mask, fimg, "NeighborhoodSize", filterSize);
        Iout = fimg.*Mout+bimg.*(1-Mout);
    case "Min"
        Iout = min(fimg, bimg).*mask + bimg.*(1-mask);
    case "Max"
        Iout = max(fimg, bimg).*mask + bimg.*(1-mask);
    case "Overlay"
        hi = bimg > 0.5;
        hicmpl = ~hi;
        Iout = ((1-2*(1-bimg).*(1-fimg)).*hi + (2*fimg.*bimg).*hicmpl).*(mask) + (1-mask).*bimg ;
    case "Average"
        Iout = ((fimg + bimg)./2).*mask + bimg.*(1-mask);
    otherwise
        assert(false,"Unknown blend mode");
end

Iout = convertToOriginalClass(Iout,originalClass);

end
%----------------------------------------------------
function [fimg, bimg] = updateInputs(fimg, bimg, location)

if ~isfloat(fimg)
    % The algorithm assumes the input image is in [0,1]
        fimg = im2single(fimg);
end

if ~isfloat(bimg)
    % The algorithm assumes the input image is in [0,1]
        bimg = im2single(bimg);
end
if size(fimg, 3) > size(bimg, 3)
    bimg = cat(3, bimg, bimg, bimg);
elseif size(fimg, 3) < size(bimg, 3)
    fimg = cat(3, fimg, fimg, fimg);
end

if ((location(1) > size(bimg,2) || location(2) > size(bimg,1)) ...
        || (location(1)+size(fimg,2) <=0) || (location(2)+size(fimg,1) <=0))
    warning(message("images:imblend:badLocation"));
end
end

%----------------------------------------------------
function validateInputImages(img)

supportedImageClasses = {'uint8','uint16','int16', 'single','double'};
supportedImageAttributes = {"real", "finite","nonempty", "nonsparse", "3d"};

validateattributes(img,supportedImageClasses,supportedImageAttributes,...
    mfilename);
hasInvalidNumberOfDimensions = @(im) ((size(im,3)~=3) && (size(im,3) ~= 1)) ...
    || ndims(im) > 3;
if hasInvalidNumberOfDimensions(img)
    error(message("images:validate:invalidImageFormat","input image"));
end
end
%----------------------------------------------------
function  validateMask(M)

validateattributes(M, ...
    "logical", ...
    {"real","nonsparse","nonempty","2d","nonnan"}, ...
    mfilename,"Mask");
end
%----------------------------------------------------
function filterSize = validateFilterSize(filterSize_)
validateattributes(filterSize_,"numeric", ...
    {"real","nonsparse","nonempty","nonzero","integer", "positive","odd","2d"}, ...
    mfilename,"filterSize");

if isscalar(filterSize_)
    filterSize = [double(filterSize_),double(filterSize_)];
else
    coder.internal.errorIf(numel(filterSize_) ~= 2, ...
        "images:validate:badVectorLength","filterSize",2);
    
    filterSize = [double(filterSize_(1)),double(filterSize_(2))];
end
end
%----------------------------------------------------
function mode = validateMode(mode)
mode = validatestring(mode,{'Alpha', 'Guided', 'Max', 'Min', ...
'Average', 'Overlay'},mfilename,"Mode");
end
%----------------------------------------------------
function TF = validateLocation(loc)
validPosTypes = "numeric";
attributes = {"real","nonnan","finite", "nonsparse", "nonempty","nrows",1, "numel", 2};
validateattributes(loc, validPosTypes, attributes, mfilename,"Location");
TF = true;
end
%----------------------------------------------------
function validateOpacity(opacity)
validateattributes(opacity, {'single', 'double'}, {"real", "scalar","nonnan","nonzero",">",0,"<=",1});
end
%----------------------------------------------------
function [fimgout, maskOut] = adjustForeground(fimg, mask, sizebimg, classbimg, location)
if isscalar(mask)
    mask = true(size(fimg,1:2));
end

fimgTranslated = imtranslate(fimg, location,"nearest", "OutputView","full");
maskTranslated = imtranslate(mask, location,"nearest", "OutputView","full");
[nrowsfimg, ncolsfimg]=size(fimgTranslated, 1:2);
nrowsbimg= sizebimg(1);
ncolsbimg= sizebimg(2);

nRows = min(nrowsfimg, nrowsbimg);
nCols = min(ncolsfimg, ncolsbimg);

fimgout = zeros(sizebimg, classbimg);
maskOut = false(sizebimg(1:2));
if location(1) < 0
    x = round(abs(location(1)));
    if x < 1
        x = 1;
    end
    cols = min(x+ nCols - 1, ncolsfimg);
else
    x = 1;
    cols = nCols;
end
if location(2) < 0
    y = round(abs(location(2)));
    if y < 1
        y = 1;
    end
    rows = min(y+ nRows-1, nrowsfimg);
else
    y = 1;
    rows = nRows;
end

fimgout(1:rows-y+1, 1:cols-x+1, :) = fimgTranslated(y:rows, x:cols, :);
maskOut(1:rows-y+1, 1:cols-x+1) = maskTranslated(y:rows, x:cols);
end
%----------------------------------------------------
function B = convertToOriginalClass(B, OriginalClass)

if strcmp(OriginalClass, "uint8")
    B = im2uint8(B);
elseif strcmp(OriginalClass, "uint16")
    B = im2uint16(B);
    elseif strcmp(OriginalClass, "int16")
    B = im2int16(B);
else
    B = clip(B, 0.0, 1.0);
end
end

% Copyright 2024 The MathWorks, Inc.