function J = inpaintCoherent(I, mask, varargin)
%INPAINTCOHERENT Coherent transport based image inpainting.
%
%   J = inpaintCoherent(I, MASK) fills the regions in image I specified by
%   MASK. I must be a grayscale or an RGB image. MASK is a binary image
%   having same number of rows and columns as I. Non-zero pixels in MASK
%   designate the pixels of image I to fill.
%
%   J = inpaintCoherent(I, MASK, NAME, VALUE, ...) performs inpainting where
%   parameters control various aspects of the operation. Parameter names
%   can be abbreviated. Parameters include:
%
%     'SmoothingFactor'        Positive scalar value specifying the
%                              standard deviation of the Gaussian filter.
%                              Gaussian filtering is used as a pre- and
%                              post-smoothing of image while inpainting. A
%                              high value of 'SmoothingFactor' corresponds
%                              to more smoothing. Specified value must be
%                              greater than or equal to 0.5.
%
%                              Default: 2
%
%     'Radius'                 Positive scalar integer value specifying the
%                              radius of the circular neighbor region
%                              around the pixel to be inpainted. A larger
%                              value of 'Radius' leads to the small amount
%                              of blur around the inpainting region.
%                              Specified value must be greater than or
%                              equal to 1.
%
%                              Default: 5
%
%
%   Class Support
%   -------------
%   The input image I must be a M-by-N or M-by-N-by-3 array of one of the
%   following classes: single, double, uint8, uint16, uint32, int8, int16,
%   int32. The output image J has the same class and size as I. MASK must
%   be a logical array of size M-by-N.
%
%   Notes
%   -----
%   [1] INPAINTCOHERENT uses the fast-marching method for image inpainting.
%   The function traverses the inpainting domain non-iteratively and fills
%   image values along the coherence direction. The coherence direction is
%   estimated by using a structure tensor.
%   [2] INPAINTCOHERENT is a local non-texture image inpainting method.
%   [3] drawassisted, drawfreehand functions and imageSegmenter app can be
%   used for generating the MASK.
%
%   References
%   ---------
%   [1] F. Bornemann, T. Marz, "Fast Image Inpainting Based on Coherence
%   Transport", Journal of Mathematical Imaging and Vision, 28, 259-278,
%   2007.
%
%   Example 1: Removal of overlay text from the image
%   ----------
%     I = imread('cameraman.tif');
%     mask = imread('text.png');
%     I = imoverlay(I, mask, 'green');
%     J = inpaintCoherent(I, mask);
%     imshowpair(I,J,'montage')
%
%   Example 2: Removal of object from the image with user selected mask
%   ----------
%     I = imread('greens.jpg');
%     imshow(I);
%     h = drawassisted;
%     mask = createMask(h);
%     J = inpaintCoherent(I, mask);
%     imshowpair(I,J,'montage')
%
%   See also inpaintExemplar, regionfill, imfill, roifilt2.

%   Copyright 2018-2020 The MathWorks, Inc.

% Parse and validate input arguments.
narginchk(2,6)
validateattributes(I, {'single', 'double', 'int8','uint8', 'int16','uint16','int32','uint32'},...
                        {'nonempty','real','finite','nonsparse'}, mfilename, 'I', 1);
validateattributes(mask, {'logical'},{'real','2d','nonsparse'}, mfilename, 'mask', 2);

% I must be MxN or MxNx3
validColorImage = (ndims(I) == 3) && (size(I,3) == 3);
if ~(ismatrix(I) || validColorImage)
    error(message('images:validate:invalidImageFormat','I'));
end
% validate size of I and mask
validateSize(I,mask);

varargin = matlab.images.internal.stringToChar(varargin);
options = parseArgs(varargin{:});
SmoothingFactor = options.SmoothingFactor;
rho = 1.5*SmoothingFactor;
radius = options.Radius;

% Set kernels
kernelS = max(round(2*SmoothingFactor),1);
kernelR = max(round(2*rho),1);
lenKernel1 = 2*kernelS+1;
lenKernel2 = 2*kernelR+1;
kernel1 = zeros(1,lenKernel1);
kernel2 = zeros(1,lenKernel2);
for ind = 0:lenKernel1-1
    kernel1(ind+1) = exp((-1*(ind-kernelS)*(ind-kernelS))/(2*SmoothingFactor*SmoothingFactor));
end
for ind = 0:lenKernel2-1
    kernel2(ind+1) = exp((-1*(ind-kernelR)*(ind-kernelR))/(2*rho*rho));
end

padval = max([radius,kernelR])+1;
classToUse = class(I);
[I,mask] = padMatrix(double(I),mask,padval);

invMask = ~mask;
numPointsToInpaint = sum(mask(:));

% call main algorithm
I = double(I).*double(invMask);
[smoothI,smoothInvMask] = smoothImage(I,invMask,kernel1);
imageOut = images.internal.builtins.inpaintCoherent(I,smoothI,mask,smoothInvMask,...
                              numPointsToInpaint,radius,lenKernel1,...
                              kernel1,lenKernel2,kernel2,padval);
imageOut = imageOut(padval+1:end-padval,padval+1:end-padval,:);
J = cast(imageOut,classToUse);
%--------------------------------------------------------------------------
function [smoothI,smoothInvMask] = smoothImage(I,invMask,kernel1)
% smooth image
kernel = kernel1'*kernel1;
smoothI = imfilter(I,kernel,'same');
smoothInvMask = conv2(invMask,kernel,'same');

%--------------------------------------------------------------------------
function [image,mask] = padMatrix(I,mask,padval)
[rows,cols,channels] = size(I);
maskBorder = [mask(1,:) mask(rows,:) mask(:,1)' mask(:,cols)'];
ind = find((maskBorder==1));
imageBorder = zeros(size(I,3),numel(maskBorder));
for ch = 1:size(I,3)
    imageBorder(ch,:) = [I(1,:,ch) I(rows,:,ch) I(:,1,ch)' I(:,cols,ch)'];
end
imageBorder(:,ind) = NaN;
indLength = 1:numel(maskBorder);
if numel(ind) < 2*(rows+cols)-1
    for ch = 1:channels
        tempBorder = imageBorder(ch,:);
        tempBorder(isnan(tempBorder)) = interp1(indLength(~isnan(tempBorder)),...
            tempBorder(~isnan(tempBorder)),indLength(isnan(tempBorder)),...
            'nearest','extrap');
        imageBorder(ch,:) = tempBorder;
    end
end
for ch = 1:channels
    I(1,:,ch) = imageBorder(ch,1:cols);
    I(rows,:,ch) = imageBorder(ch,cols+1:2*cols);
    I(:,1,ch) = imageBorder(ch,2*cols+1:end-rows)';
    I(:,cols,ch) = imageBorder(ch,end-rows+1:end)';
end
image = double(padarray(I,[padval,padval],'replicate'));
mask = padarray(mask,[padval,padval]);

%--------------------------------------------------------------------------
function validateSize(I,mask)
% Make sure numbers of rows and cols are same for both I and MASK.

if ~isequal(size(I,1), size(mask,1)) || ~isequal(size(I,2), size(mask,2))
    error(message('images:inpaint:mismatchDim'))
end

%--------------------------------------------------------------------------
function options = parseArgs(varargin)
% Get user-provided and default options.
parser = inputParser();
parser.FunctionName = mfilename;
parser.CaseSensitive = false;
parser.PartialMatching = true;

% NameValue 'SmoothingFactor'
defaultSmoothingFactor = 2;
validateSmoothingFactor = @(x) validateattributes(x, ...
    {'double'}, ...
    {'nonempty','scalar','real','finite','nonsparse','nonnegative','nonzero','>=', 0.5}, ...
    mfilename,'SmoothingFactor');
parser.addParameter('SmoothingFactor', ...
    defaultSmoothingFactor, ...
    validateSmoothingFactor);

% NameValue 'Radius'
defaultRadius = 5;
validateRadius = @(x) validateattributes(x, ...
    {'double'}, ...
    {'nonempty','scalar','real','integer','nonsparse','nonnegative','nonzero','>=', 1}, ...
    mfilename,'Radius');
parser.addParameter('Radius', ...
    defaultRadius, ...
    validateRadius);

parser.parse(varargin{:});
options = parser.Results;

