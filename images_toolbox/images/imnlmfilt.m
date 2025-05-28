function varargout = imnlmfilt(varargin)
%IMNLMFILT Non-Local Means based filtering of images
%
%  B = imnlmfilt(A) applies a non-local means based filter to the input
%  grayscale (MxN matrix) image or color (MxNx3) image A. A must be equal
%  to or greater than 21-by-21 in size.
%
%  [B, DegreeOfSmoothing] = imnlmfilt(A, ...) also returns the value of
%  DegreeOfSmoothing which corresponds to the standard deviation of the
%  Gaussian noise present in the image.
%
%  [__] = imnlmfilt(__,Name,Value,...) filters the image A using name-value
%  pairs to control aspects of non-local means filtering. Parameter names
%  can be abbreviated. Parameters include:
%
%  'DegreeOfSmoothing'   - Positive scalar value that controls the amount
%                          of smoothing in the output image. It is the
%                          estimate of the standard deviation of Gaussian
%                          noise present in the image. Higher value leads to
%                          higher smoothing. If the DegreeOfSmoothing value
%                          is not provided, it is estimated before
%                          performing filtering.
%
%  'SearchWindowSize'    - Scalar odd valued positive integer (P) which
%                          specifies the size of the square neighbourhood
%                          (PxP) to which the search for similar pixels is
%                          limited. SearchWindowSize affects the performance
%                          linearly in terms of time. Specified value
%                          should not be larger than the size of the image.
%                          Default value is 21.
%
%  'ComparisonWindowSize'- Scalar odd valued positive integer (Q) which
%                          specifies the size of the square window (QxQ)
%                          surrounding the pixel which is used to compute
%                          weights based on similarity of the pixels.
%                          Specified Value cannot be larger than the
%                          'SearchWindowSize' value.
%                          Default value is 5.
%
%  Class Support
%  -------------
%  The input array A must be of one of the following classes: uint8, int8,
%  uint16, int16, uint32, int32, single or double. It must be nonsparse and
%  non empty. Output image B is an array of the same size and type as A.
%
%  Notes
%  -----
%  1. Non-local means filtering works best for Gaussian noise. The
%  'DegreeOfSmoothing' estimation step also assumes Gaussian noise.
%
%  2. The parameter 'DegreeOfSmoothing' corresponds to the standard
%  deviation of Gaussian noise present in the image. If not provided, it is
%  estimated using convolution of the image with a 3x3 matrix which is not
%  sensitive to the Laplacian of an image, since structures like edges have
%  strong second order differential components. In case of three channel
%  images, the DegreeOfSmoothing is taken as the mean of standard
%  deviations of noise estimated across the channels[2]. This value can be
%  optionally accessed as an output.
%
%  3. The proposed method by A. Buades et. al. [1] suggests convolution of
%  the Euclidean distance between two comparison patches with a Gaussian
%  kernel of the same size as the comparison window. In this
%  implementation, an ideal low pass filter (box blur) is used instead for
%  computational efficiency.
%
%  4. The calculation of weights uses Euclidean distance of the pixel value
%  from the values of other pixels in the search window. For colored images,
%  the distance calculation is done across all the channels. Convert an RGB
%  image to the CIE L*a*b space using RGB2LAB before applying the filter to
%  smoothen perceptually closer colors. Convert the result back to RGB
%  using LAB2RGB for viewing the results.
%
%  5. The computations take place in single precision unless the input
%  datatype is double.
%
%  Example 1
%  ---------
%  % This example performs denoising of an image with Gaussian white noise
%  % with non-local means filter.
%
%  % Import a Gray scale image
%  I = imread('cameraman.tif');
%  % Add Gaussian noise with zero mean and 0.0015 variance
%  noisyImage = imnoise(I, 'gaussian', 0, 0.0015);
%  % Apply NLM filter
%  [filteredImage, estDoS] = imnlmfilt(noisyImage);
%  % Display the noisy image and filtered image side-by-side
%  montage({noisyImage, filteredImage});
%
%  Example 2
%  ---------
%  % This example performs non-local means filtering on a colored image.
%
%  im = imread('peppers.png');
%  imn = imnoise(im, 'gaussian', 0, 0.0015);
%  iml = rgb2lab(imn);
%
%  % Pick a region using the RGB image that contains noise (part of the
%  % background)
%  rect = [210, 24, 52, 41];
%  imcl = imcrop(iml, rect);
%
%  % Compute the standard deviation of this patch
%  edist = imcl.^2;
%  edist = sqrt(sum(edist,3)); % Euclidean distance from origin
%  patchSigma = sqrt(var(edist(:)));
%
%  % Set the DegreeOfSmoothing to be higher than the standard deviation
%  % of the patch that needs to be smoothed.
%  imls = imnlmfilt(iml,'DegreeOfSmoothing', 1.5*patchSigma);
%  ims = lab2rgb(imls,'Out','uint8');
%  montage({imn, ims});
%
%  References:
%  -----------
%  [1] Antoni Buades, Bartomeu Coll, and Jean-Michel Morel, A Non-Local
%      Algorithm for Image Denoising, Computer Vision and Pattern
%      Recognition 2005. CVPR 2005, Volume 2, (2005), pp. 60-65.
%  [2] John Immerkaer, Fast Noise Variance Estimation, Computer Vision and
%      Image Understanding, Volume 64, Issue 2, (1996), pp. 300-302
%
%  See also imguidedfilter, imbilatfilt, locallapfilt, imdiffusefilt

%  Copyright 2018-2021 The MathWorks, Inc.

nargoutchk(0,2);
inputs = parseInputs(varargin{:});

dtype = class(inputs.A);

if ~isa(inputs.A, 'double')
   inputs.A = single(inputs.A);
end

% Applying fast non-local means filter to the image
B = images.internal.builtins.nlm_halide( inputs.A, inputs.ComparisonWindowSize, ...
                inputs.SearchWindowSize, inputs.DegreeOfSmoothing);

% Converting the image back to input datatype
B = cast(B,dtype);
varargout{1}  = B;
if (nargout == 2)
    varargout{2} = inputs.DegreeOfSmoothing;
end
end

function inputs = parseInputs(varargin)

narginchk(1, 7);
args = matlab.images.internal.stringToChar(varargin);

parser = inputParser;
parser.CaseSensitive = false;
parser.PartialMatching = true;
parser.FunctionName = mfilename;

parser.addRequired('A', ...
    @(A) validateattributes(...
    A, {'uint8','uint16','int16','single','double', 'uint32', 'int32','int8'}, ...
    {'nonsparse','nonempty', 'real'},...
    mfilename, 'A'));
parser.addParameter('DegreeOfSmoothing', [],...
    @(fp) validateattributes(...
    fp, {'numeric'},...
    {'scalar','finite','real', 'positive', 'nonsparse'},...
    mfilename, 'DegreeOfSmoothing'));
parser.addParameter('SearchWindowSize', [],...
    @(sw) validateattributes(...
    sw, {'numeric'},...
    {'scalar', 'finite', 'real', 'nonempty','positive','integer' , 'odd', 'nonsparse'},...
    mfilename, 'SearchWindowSize'));
parser.addParameter('ComparisonWindowSize', [],...
    @(cw) validateattributes(...
    cw, {'numeric'},...
    {'scalar', 'finite', 'real', 'nonempty','positive','integer' , 'odd', 'nonsparse'},...
    mfilename, 'ComparisonWindowSize'));

parser.parse(args{:});
inputs = parser.Results;
[M,N,C] = size(inputs.A);

if ismatrix(inputs.A)
    % numeric grayscale
    validateattributes(...
        inputs.A, {'numeric'}, ...
        {'nonsparse','nonempty', 'real','ndims',2},...
        mfilename, 'A')
else
    %  3 channel color
    validateattributes(...
        inputs.A, {'numeric'}, ...
        {'nonsparse','nonempty', 'real','ndims',3},...
        mfilename, 'A')
    if C~=3
        error(message('images:validate:invalidImageFormat', 'A'));
    end
end

%  Input Image size limits
if (any([M, N]<21))
    error(message('images:imnlmfilt:incorrectImageSize'));
end

% default value for ComparisonWindowSize
if any(strcmp(parser.UsingDefaults,'ComparisonWindowSize'))
    inputs.ComparisonWindowSize = 5;
end

% default value for SearchWindowSize
if any(strcmp(parser.UsingDefaults,'SearchWindowSize'))
   inputs.SearchWindowSize = 21;
end

% default value for DegreeOfSmoothing
if any(strcmp(parser.UsingDefaults,'DegreeOfSmoothing'))
   inputs.DegreeOfSmoothing = estimateDegreeOfSmoothing(inputs.A);
end

 % ComparisonWindowSize limits
 if (inputs.ComparisonWindowSize>inputs.SearchWindowSize)
    error(message('images:imnlmfilt:invalidWindowSize'));
 end

 %  SearchWindowSize limits
 if (inputs.SearchWindowSize>min(M, N))
   error(message('images:imnlmfilt:imageNotMinSize'));
 end

end

function DegreeofSmoothing = estimateDegreeOfSmoothing(I)
[H, W, S] = size(I);
I = single(I);
kernel=[1 -2 1; -2 4 -2; 1 -2 1];
res = zeros(1,S);
for i = 1:S
    res(i) = sum(sum(abs(conv2(I(:,:,i), kernel))));
    res(i) = (res(i)*sqrt(0.5*pi)./(6*(W-2)*(H-2)));
end
DegreeofSmoothing = mean(res);
if DegreeofSmoothing == 0
     DegreeofSmoothing = single(eps);
end
end
