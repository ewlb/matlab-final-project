function B = imflatfield(varargin)
%IMFLATFIELD 2-D color and grayscale image flat-field correction.
%   B = IMFLATFIELD(A, SIGMA) applies flat-field correction to the
%   grayscale image A using Gaussian smoothing with a standard deviation of
%   SIGMA to approximate the shading component of A. SIGMA is specified as
%   a positive scalar or 2-element vector. The result, B, has the same size
%   and class as A.
%
%   B = IMFLATFIELD(RGB, SIGMA) applies flat-field correction to the
%   color image RGB using Gaussian smoothing with a standard deviation of
%   SIGMA to approximate the shading component of RGB. For RGB images, the
%   image is converted to HSV colorspace and flat-field correction is
%   applied to the Value channel. The result, B, is an RGB image with the
%   same size and class as A.
%
%   B = IMFLATFIELD(A, SIGMA, MASK) allows the user to specify a logical
%   mask that dictates what regions of the image flat-field correction is
%   applied to. The MASK input is a 2-D logical matrix where false values
%   are not included in the calculation. The regions of B where the logical
%   mask is true will be corrected regions of A, and the regions of B where
%   the logical mask is false are the corresponding unmodified regions of
%   A.
%
%   B = IMFLATFIELD(___, Name, Value) applies flat-field correction to an
%   image A with Name-Value pairs used to control aspects of filtering.
%
%   Parameters include:
%
%   'FilterSize'    -   Scalar or 2-element vector, of positive, odd
%                       integers that specifies the size of the Gaussian
%                       filter. If a scalar Q is specified, then a square
%                       Gaussian filter of size [Q Q] is used.
%
%                       Default value is 2*ceil(2*SIGMA)+1.
%
%
%   Class Support
%   -------------
%   The input image A must be a real, non-sparse matrix of dimension MxNx1
%   or MxNx3 and be of the following classes: uint8, uint16, int16, single
%   or double.
%
%   The input MASK must be a logical matrix.
%
%
%   Example 1
%   ---------
%   % Correct a grayscale image with a severe shading defect.
%       I = imread('printedtext.png');
%
%       figure;
%       subplot(2,1,1), imshow(I), title('Original Image');
%
%       Iflatfield = imflatfield(I, 30);
%       subplot(2,1,2), imshow(Iflatfield);
%       title('Flattened image, \sigma = 30')
%
%   Example 2
%   ---------
%   % Correct a color image with a vignetting defect.
%       I = imread('fabric.png');
%
%       figure;
%       subplot(2,1,1), imshow(I), title('Original Image');
%
%       Iflatfield = imflatfield(I, 20);
%       subplot(2,1,2), imshow(Iflatfield);
%       title('Flattened image, \sigma = 20')
%
%   Example 3
%   ---------
%   % Use a logical mask to apply shading correction to just the white
%   % background of a color image with a shading defect.
%       I = imread('hands1.jpg');
%       mask = ~imread('hands1-mask.png');
%
%       figure;
%       subplot(2,1,1), imshow(I), title('Original Image');
%
%       Iflatfield = imflatfield(I, 25, mask);
%       subplot(2,1,2), imshow(Iflatfield);
%       title('Flattened image, \sigma = 25')
%
%   See also imgaussfilt, imfilter

% Copyright 2017-2018 The MathWorks, Inc.

% Parse inputs
[A, classA, sigma, mask, filterSize] = parseInputs(varargin{:});

% Is a color image?
isRGB = size(A,3) == 3;

if(isRGB)
    % If color, process V channel of HSV color space
    Ihsv = rgb2hsv(A);
    A = Ihsv(:,:,3);
end

if(isempty(mask)) % Was a mask supplied as an input?
    % Non-mask mode
    shading = imgaussfilt(A, sigma,'Padding','symmetric','FilterSize',filterSize); % Calculate shading
    meanVal = mean(A(:),'omitnan');
else
    % Mask mode
    % Pad area around mask using dilation to reduce influence of
    % non-mask regions on inner-mask regions during estimation
    [Apadded, colPad, rowPad] = doMaskPadA(A,mask,sigma);
    shading = imgaussfilt(Apadded,sigma,'Padding','symmetric','FilterSize',filterSize); % Calculate shading
    shading = shading((colPad+1):(end-colPad),(rowPad+1):(end-rowPad),:);
    meanVal = mean(A(mask(:)),'omitnan');
end

B = A*meanVal./shading;

B(isnan(B)) = 0; % sometimes instances of 0/0 happen, making NaN values.
B(isinf(B)) = 0; % sometimes values are divided by 0, making Inf values.

if(~isempty(mask))
    % Keep only mask regions in output if a mask is supplied
    B(~mask) = A(~mask);
end

if(isRGB)
    % Put processed V channel back into HSV image, convert to RGB
    Ihsv(:,:,3) = B;
    B = hsv2rgb(Ihsv);
end

switch classA
    
    case 'int16'
        B = im2int16(B);
    case 'uint16'
        B = im2uint16(B);
    case 'uint8'
        B = im2uint8(B);
    otherwise
        % Single or double, don't do anything
        
end

end

function [A, classA, sigma, mask, filterSize] = parseInputs(varargin)

args = matlab.images.internal.stringToChar(varargin);
p = inputParser;

narginchk(2,5);

% Input image
A = args{1};

% Original class of input image
classA = class(A);

sigma = args{2};

defaultFilterSize = 2*ceil(2*sigma)+1;

p.FunctionName = 'imflatfield';
addRequired(p,'A',@(x) validateImage(x));
addRequired(p,'sigma', @(x) validateSigma(x));
addOptional(p,'mask',[],@(x) validateMask(x));
addParameter(p,'FilterSize',defaultFilterSize,@(x) validateFilterSize(x));
parse(p,args{:});

mask = logical(p.Results.mask);
filterSize = p.Results.FilterSize;

% Convert int16 to uint16 for calculations since signed inputs don't work for the algorithm
% if(isa(A,'int16'))
%     A = im2uint16(A);
% end

% Do shading correction in single precision if input is not double
if(~strcmpi(classA,'double'))
    A = im2single(A);
end

if ~isempty(mask) && (~(size(A,1) == size(mask,1)) || ~(size(A,2) == size(mask,2)) || ~(size(mask,3) == 1))
    error(message('images:imflatfield:imgMaskDifferentSize'));
end

end

function [paddedA,colPad,rowPad] = doMaskPadA(A,maskA,sigma)

% dilate the input image multiplied by the mask, expand beyond
% normal image size.
sigma = max(sigma);
dilatedA = imdilate(A,strel('disk',sigma),'full');

% This can introduce -inf values using 'full', but using 'same'
% causes output image edges to flare up. Get rid of the inf values.
dilatedA(isinf(dilatedA)) = 0;

% Smooth the dilated image. This is the "padding" to the mask area
dilatedA = imgaussfilt(dilatedA, sigma,'Padding','symmetric');

% How much did the image grow?
colPad = (size(dilatedA,1)-size(maskA,1))/2;
rowPad = (size(dilatedA,2)-size(maskA,2))/2;

% Pad A and the corresponding mask to match the dilated version of A
paddedA = padarray(A,[colPad,rowPad,0],0);
maskA = padarray(maskA,[colPad,rowPad,0],0);

% Replace only the values in A that are outside the mask with the
% corresponding value in dilated A. These values won't be used in the
% output because they are outside the mask, but they will be used when
% filtering pixels near the mask edge.
paddedA(~maskA) = dilatedA(~maskA);

end

function TF = validateImage(A)

validateattributes(A,{'uint8','uint16','int16','single','double'},...
    {'real','nonempty','nonsparse','finite','nonnan'});

if((~(size(A,3)==3) && size(A,3) ~= 1) || numel(size(A))>3)
    error(message('images:imflatfield:expectedColorOrGrayscaleInputImage'));
end

TF = true;

end

function TF = validateSigma(sigma)

if (numel(sigma) > 2)
    error(message('images:imflatfield:invalidSigma'));
end

validateattributes(sigma,{'numeric'},...
    {'real','nonnegative','nonzero','nonnan','finite','nonempty'});

TF = true;

end

function TF = validateMask(mask)

validateattributes(mask,{'numeric','logical'},{});

TF = true;

end

function TF = validateFilterSize(filterSize)

validateattributes(filterSize,{'numeric'},...
    {'finite','real','positive','integer','nonnan','odd'});

if(sum(size(filterSize))>3 || any(mod(filterSize,2) == 0))
    error(message('images:imflatfield:invalidFilterSize'));
end

TF = true;

end
