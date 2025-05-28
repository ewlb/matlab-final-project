function J = inpaintExemplar(I, mask, varargin)
%INPAINTEXEMPLAR Exemplar based image inpainting
%   J = inpaintExemplar(I,MASK) fills the regions in image I specified by
%   MASK. I must be a grayscale or an RGB image. MASK is a binary image
%   having same size as I. Non-zero pixels in MASK designate the pixels of
%   image I to fill.
%
%   J = inpaintExemplar(I,MASK,NAME,VALUE, ...) performs inpainting where
%   parameters control various aspects of the operation. Parameter names
%   can be abbreviated. Parameters include:
%
%     'FillOrder'         FillOrder determines the order while filling the
%                         selected region. Possible values are 'gradient'
%                         and 'tensor'. 'gradient' term boosts the priority
%                         of a patch in direction normal to gradient.
%                         'tensor' term boosts the priority to dominant
%                         tensor gradient direction.
%
%                         Default: 'gradient'
%
%
%     'PatchSize'         'PatchSize' specifies the size of the patch used
%                         for the best patch selection. 'PatchSize' can be
%                         a vector specifying the number of rows and
%                         columns of patch or a scalar, in case of a square
%                         patch. A lower PatchSize increases the time
%                         complexity. Minimum value for 'PatchSize' is 3.
%
%                         Default: [9 9]
%
%
%   Class Support
%   -------------
%   The input image I must be a M-by-N or M-by-N-by-3 array of one of the
%   following classes: single, double, uint8, uint16, uint32, int8, int16,
%   int32. The output image J has the same class and size as I. MASK must
%   be a logical array of size M-by-N. PatchSize must be less than the size
%   of the input image.
%
%   Notes
%   -----
%   [1] INPAINTEXEMPLAR determines the best matching patch from a known
%   neighborhood by using the sum of squared difference (SSD). The target
%   patch to be inpainted is replaced with the best matching patch.
%   [2] INPAINTEXEMPLAR works well when inpainting regions are highly
%   textured but is computationally expensive. Refer inpaintCoherent to
%   inpaint less textured regions.
%   [3] drawassisted, drawfreehand functions and imageSegmenter app can be
%   used for generating the MASK.
%   [4] INPAINTEXEMPLAR uses a local search region around the target region
%   for performance improvement.
%
%   Example 1: Removal of text from the image
%   ----------
%     I = imread('cameraman.tif');
%     mask = imread('text.png');
%     I = imoverlay(I, mask,'green');
%     J = inpaintExemplar(I, mask);
%     imshowpair(I,J,'montage')
%
%   Example 2: Removal of object from the image with user selected mask
%   ----------
%     I = imread('greens.jpg');
%     imshow(I);
%     h = drawassisted;
%     mask = createMask(h);
%     J = inpaintExemplar(I, mask);
%     imshowpair(I,J,'montage')
%
%   References
%   ---------
%   [1] A. Criminisi, P. Perez, K. Toyama, "Region filling and object
%   removal by exemplar-based image inpainting", IEEE Trans. on Image
%   Processing, Vol. 13, No. 9, pp. 1200-1212, 2004.
%   [2] Olivier Le Meur, Mounira Ebdelli, Christine Guillemot,
%   "Hierarchical super-resolution-based inpainting", IEEE Trans. on Image
%   Processing, Vol. 22, No. 10, pp. 3779-3790, 2013.
%
%   See also inpaintCoherent, regionfill, imfill, roifilt2.

%   Copyright 2019 The MathWorks, Inc.


% Parse and validate input arguments.
narginchk(2,6);
validateattributes(I, {'single', 'double', 'int8','uint8', 'int16','uint16','int32','uint32'},...
                        {'nonempty','real','finite','nonsparse'}, mfilename, 'I', 1);
validateattributes(mask, {'logical'},{'real','2d','nonsparse'}, mfilename, 'mask', 2);

% I must be MxN or MxNx3
validColorImage = (ndims(I) == 3) && (size(I,3) == 3);
if ~(ismatrix(I) || validColorImage)
    error(message('images:validate:invalidImageFormat','I'));
end

varargin = matlab.images.internal.stringToChar(varargin);
options = parseArgs(varargin{:});
dataTermUsed = options.FillOrder;
patchSize = options.PatchSize;
% validate size of I, mask and patchsize
validateSize(I,mask,options);
numPixel = size(I,1)*size(I,2);
pointToInpaint = sum(mask(:)); % total no. of pixels to be inpaint
if pointToInpaint ~= 0 && pointToInpaint ~= numPixel
    I = padarray(I,[2 2],'replicate');
    mask = padarray(mask,[2 2]);
    tempJ = images.internal.alginpaintExemplar(I,mask,dataTermUsed,patchSize);
    I = tempJ(3:end-2,3:end-2,:);
end
J = I;


%--------------------------------------------------------------------------
function validateSize(I,mask,options)
% Make sure numbers of rows and cols are same for both I and MASK.
if ~isequal(size(I,1), size(mask,1)) || ~isequal(size(I,2), size(mask,2))
    error(message('images:inpaint:mismatchDim'))
end

minDimension = min(size(I,1),size(I,2));
% Make sure patch size is less than image size
if (max(options.PatchSize)> minDimension )
    error(message('images:inpaint:minPatchSize'))
end


%--------------------------------------------------------------------------
function options = parseArgs(varargin)
% Get user-provided and default options.

parser = inputParser();
parser.FunctionName = mfilename;
parser.CaseSensitive = false;
parser.PartialMatching = true;

% NameValue 'FillOrder'
defaultFillOrder = 'gradient';
validFillOrder = {'gradient', 'tensor'};
validateFillOrder = @(x) validateattributes(x, ...
    {'char','string'}, ...
    {}, ...
    mfilename,'FillOrder');
parser.addParameter('FillOrder', ...
    defaultFillOrder, ...
    validateFillOrder);

defaultPatchSize = [9, 9];
validatePatchSize = @(x) validateattributes(x, ...
    {'double'}, ...
    {'nonempty','row','real','finite','nonsparse','nonnegative','>=', 3}, ...
    mfilename,'PatchSize');
parser.addParameter('PatchSize', ...
    defaultPatchSize, ...
    validatePatchSize);

parser.parse(varargin{:});
options = parser.Results;

if numel(options.PatchSize)>2
    error(message('images:inpaint:patchDim'))
end

options.FillOrder = validatestring( ...
    options.FillOrder, ...
    validFillOrder, ...
    mfilename,'FillOrder');



