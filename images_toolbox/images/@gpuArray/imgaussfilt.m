function B = imgaussfilt(varargin)
%IMGAUSSFILT 2-D Gaussian filtering of images
%
%   B = imgaussfilt(A) filters gpuArray image A with a 2-D Gaussian
%   smoothing kernel with standard deviation of 0.5. A can have any number
%   of dimensions.
%
%   B = imgaussfilt(A,SIGMA) filters gpuArray image A with a 2-D Gaussian
%   smoothing kernel with standard deviation specified by SIGMA. SIGMA can
%   be a scalar or a 2-element vector with positive values. If sigma is a
%   scalar, a square Gaussian kernel is used.
%
%   B = imgaussfilt(___,Name,Value,...) filters gpuArray image A with a 2-D
%   Gaussian smoothing kernel with Name-Value pairs used to control aspects
%   of the filtering. 
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
%   'Padding'       -   String or character vector or numeric scalar that
%                       specifies padding to be used on image before
%                       filtering.
%
%                       If a scalar (X) is specified, input image values
%                       outside the bounds of the image are implicitly
%                       assumed to have the value X. 
%
%                       If a string or character vector is specified, it
%                       can be 'replicate', 'circular' or 'symmetric'.
%                       These options are analogous to the padding options
%                       provided by imfilter. 
%
%                       'replicate'
%                       Input image values outside the bounds of the image
%                       are assumed equal to the nearest image border
%                       value.
%
%                       'circular'
%                       Input image values outside the bounds of the image
%                       are computed by implicitly assuming the input image
%                       is periodic.
%
%                       'symmetric'
%                       Input image values outside the bounds of the image
%                       are computed by mirror-reflecting the array across
%                       the array border. 
%
%                       Default value is 'replicate'.
%
%   'FilterDomain'  -   String or character vector that specifies domain in
%                       which filtering is performed. It can be 'spatial',
%                       'frequency' or 'auto'. For 'spatial', convolution
%                       is performed in the spatial domain, for 'frequency',
%                       convolution is performed in the frequency domain
%                       and for 'auto', convolution may be performed in
%                       spatial or frequency domain based on internal
%                       heuristics.
%
%                       Default value is 'auto'.
%
%
%   Class Support
%   -------------
%   The input gpuArray image A must be a real matrix of any dimension of
%   the following underlying classes: uint8, int8, uint16, int16, uint32,
%   int32, single or double.
%
%
%   Notes
%   -----
%   1. If the image A contains Infs or NaNs, the behavior of imgaussfilt
%      for frequency domain filtering is undefined. This can happen when
%      the 'FilterDomain' parameter is set to 'frequency' or when it is set
%      to 'auto' and frequency domain filtering is used internally. To
%      restrict the propagation of Infs and NaNs in the output in a manner
%      similar to imfilter, consider setting the 'FilterDomain' parameter
%      to 'spatial'.
%
%   2.  When 'FilterDomain' parameter is set to 'auto', an internal
%      heuristic is used to determine whether spatial or frequency domain
%      filtering is faster. This heuristic is machine dependent and may
%      vary for different configurations. For optimal performance, consider
%      comparing 'spatial' and 'frequency' to determine the best filtering
%      domain for your image and kernel size.
%
%   3. When the 'Padding' parameter is not specified, 'replicate' padding 
%      is used as the default, which is different from the default used in
%      imfilter.
%
%
%   Example 1
%   ---------
%   This example smooths an image with Gaussian filters of increasing
%   standard deviations.
%
%   I = gpuArray(imread('cameraman.tif'));
%
%   subplot(2,2,1), imshow(I), title('Original Image');
%
%   Iblur = imgaussfilt(I, 2);
%   subplot(2,2,2), imshow(Iblur)
%   title('Gaussian filtered image, \sigma = 2')
%
%   Iblur = imgaussfilt(I, 4);
%   subplot(2,2,3), imshow(Iblur)
%   title('Gaussian filtered image, \sigma = 4')
%
%   Iblur = imgaussfilt(I, 6);
%   subplot(2,2,4), imshow(Iblur)
%   title('Gaussian filtered image, \sigma = 6')
%
%   See also gpuArray/imgaussfilt3, gpuArray/imfilter, fspecial.

% Copyright 2014-2023 The MathWorks, Inc.

narginchk(1, Inf);

% Dispatch to CPU
if ~isgpuarray(varargin{1})
    [varargin{:}] = gather(varargin{:});
    B = imgaussfilt(varargin{:});
    return;
end

args = matlab.images.internal.stringToChar(varargin);
[A, options] = parseInputs(args{:});

sigma       = options.Sigma;
hsize       = options.FilterSize;
padding     = options.Padding;
domain      = options.FilterDomain;

if isempty(A)
    B = A;
    return;
end

[domain, separableFlag] = chooseFilterImplementation(A, hsize, domain);

switch domain
    case 'spatial'
        B = spatialGaussianFilter(A, sigma, hsize, padding, separableFlag);
        
    case 'frequency'
        B = frequencyGaussianFilter(A, sigma, hsize, padding);
        
    otherwise
        assert(false, 'Internal Error: Unknown filter domain');
end

end

%--------------------------------------------------------------------------
% Spatial Domain Filtering
%--------------------------------------------------------------------------
function A = spatialGaussianFilter(A, sigma, hsize, padding, separableFlag)

outSize = size(A);
dtype = underlyingType(A);

% We use the implicit zero-padding provided by conv2 when possible to avoid
% unnecessary memory copies.
useConvPadding = isnumeric(padding) && padding==0 && ismatrix(A);

switch dtype
    case {'int32','uint32'}
        A = double(A);
    case {'uint8','int8','uint16','int16'}
        A = single(A);
    case {'single','double'}
        % No-op
    otherwise
        assert(false,'Unexpected datatype');
end

if ~useConvPadding
    A = padImage(A, hsize, padding);
end

if separableFlag

    [hCol,hRow] = createSeparableGaussianKernel(sigma, hsize);
    

    
    % When using zero-padding provided by conv2, 'same' output is requested
    % to maintain input image size at the output.
    if useConvPadding
        A = conv2(hCol, hRow, A, 'same');
        
        % Make sure CONV didn't change the type
        if ~isUnderlyingType(A, dtype)
            A = cast(A,dtype);
        end
        
        return;
    end
    
    % When the image is 2-D, we can directly invoke conv2.
    if ismatrix(A)
        A = conv2(hCol, hRow, A, 'valid');
        
        % Make sure CONV didn't change the type
        if ~isUnderlyingType(A, dtype)
            A = cast(A,dtype);
        end
        
        return;
    end
    
    % For filtering an image-stack, conserve memory by processing one page
    % at a time.
    B = gpuArray.zeros(outSize, dtype);
    [~,~,numPages] = size(A);
    for dim = 1:numPages
       B(:,:,dim) = cast(conv2(hCol, hRow, A(:,:,dim), 'valid'), dtype);
    end
    A = B;
    
else
    
    h = images.internal.createGaussianKernel(sigma, hsize);
        
    if useConvPadding
        A = convn(A, h, 'same');
    else
        A = convn(A, h, 'valid');
    end
    
    % Make sure CONV didn't change the type
    if ~isUnderlyingType(A, dtype)
        A = cast(A, dtype);
    end

end
                    
end

function TF = useSeparableFiltering(A, hsize)

isKernel1D = any(hsize==1);

minKernelElems = getSeparableFilterThreshold(underlyingType(A));

TF = ~isKernel1D && prod(hsize) >= minKernelElems;

end

function [hcol,hrow] = createSeparableGaussianKernel(sigma, hsize)

isIsotropic = sigma(1)==sigma(2) && hsize(1)==hsize(2);

hcol = images.internal.createGaussianKernel(sigma(1), hsize(1));

if isIsotropic
    hrow = hcol;
else
    hrow = images.internal.createGaussianKernel(sigma(2), hsize(2));
end

hrow = reshape(hrow, 1, hsize(2));

end

%--------------------------------------------------------------------------
% Frequency Domain Filtering
%--------------------------------------------------------------------------
function A = frequencyGaussianFilter(A, sigma, hsize, padding)

sizeA = size(A);
dtype = underlyingType(A);
outSize = sizeA;

A = padImage(A, hsize, padding);

h = gpuArray(images.internal.createGaussianKernel(sigma, hsize));

% cast to double to preserve precision unless single
if ~isfloat(A)
    A = double(A);
end

fftSize = size(A);
if ismatrix(A)
    A = ifft2( fft2(A) .* fft2(h, fftSize(1), fftSize(2)), 'symmetric' );
else
    fftH = fft2(h, fftSize(1), fftSize(2));
    
    dims3toEnd = prod(fftSize(3):fftSize(end));
    
    %Stack behavior
    for dim = 1 : dims3toEnd
        A(:,:,dim) = ifft2( fft2(A(:,:,dim), fftSize(1), fftSize(2)) .* fftH, 'symmetric' );
    end
end

% cast back to input type
if ~isUnderlyingType(A, dtype)
    A = cast(A, dtype);
end

A = unpadImage(A, outSize);

end

%--------------------------------------------------------------------------
% Common Functions
%--------------------------------------------------------------------------
function [domain, separableFlag] = chooseFilterImplementation(A, hsize, domain)

separableFlag = useSeparableFiltering(A, hsize);

if strcmp(domain, 'auto')
    domain = chooseFilterDomain(A, hsize);
end

end

function [A, padSize] = padImage(A, hsize, padding)

padSize = computePadSize(size(A), hsize);

if ischar(padding)
    method = padding;
    padVal = [];
else
    method = 'constant';
    padVal = padding;
end

A = padarray_algo(A, padSize, method, padVal, 'both');

end

function padSize = computePadSize(sizeA, sizeH)

rankA = numel(sizeA);
rankH = numel(sizeH);

sizeH = [sizeH ones(1,rankA-rankH)];

padSize = floor(sizeH/2);

end

function A = unpadImage(A, outSize)

start = 1 + size(A) - outSize;
stop  = start + outSize - 1;

subCrop.type = '()';
subCrop.subs = {start(1):stop(1), start(2):stop(2)};

for dims = 3 : ndims(A)
    subCrop.subs{dims} = matlab.internal.ColonDescriptor(start(dims),stop(dims));
end

A = subsref(A, subCrop);

end

%--------------------------------------------------------------------------
% Input Parsing
%--------------------------------------------------------------------------
function [A, options] = parseInputs(varargin)

A = varargin{1};

supportedClasses = {'uint8','uint16','uint32','int8','int16','int32','single','double'};
supportedImageAttributes = {'real','nonsparse'};
validateattributes(A, supportedClasses, supportedImageAttributes, mfilename, 'A');

% Default options
options = struct(...
        'Sigma',        [.5 .5],...
        'FilterSize',   [3 3],...
        'Padding',      'replicate',...
        'FilterDomain', 'auto');
    
beginningOfNameVal = find(cellfun(@isstr,varargin),1);

if isempty(beginningOfNameVal) && length(varargin)==1
    %imgaussfilt(A)
    return;
elseif beginningOfNameVal==2
    %imgaussfilt(A,'Name',Value)
elseif (isempty(beginningOfNameVal) && length(varargin)==2) || (~isempty(beginningOfNameVal) && beginningOfNameVal==3)
    %imgaussfilt(A,sigma,'Name',Value,...)
    %imgaussfilt(A,sigma)
    options.Sigma = validateSigma(varargin{2});
    options.FilterSize = computeFilterSizeFromSigma(options.Sigma);
else
    error(message('images:imgaussfilt:tooManyOptionalArgs'));
end

numPVArgs = length(varargin) - beginningOfNameVal + 1;
if mod(numPVArgs,2)~=0
    error(message('images:imgaussfilt:invalidNameValue'));
end

ParamNames = {'FilterSize', 'Padding', 'FilterDomain'};
ValidateFcn = {@images.internal.validateTwoDFilterSize, @validatePadding, @validateFilterDomain};

for p = beginningOfNameVal : 2 : length(varargin)-1
    
    Name = varargin{p};
    Value = varargin{p+1};
    
    idx = strncmpi(Name, ParamNames, numel(Name));
    
    if ~any(idx)
        error(message('images:imgaussfilt:unknownParamName', Name));
    elseif numel(find(idx))>1
        error(message('images:imgaussfilt:ambiguousParamName', Name));
    end
    
    validate = ValidateFcn{idx};
    options.(ParamNames{idx}) = validate(Value);
    
end

end

function sigma = validateSigma(sigma)

validateattributes(sigma, {'numeric'}, {'real','nonsparse','positive','finite','nonempty'}, mfilename, 'Sigma');

if numel(sigma)>2
    error(message('images:imgaussfilt:invalidLength', 'Sigma'));
end

if isscalar(sigma)
    sigma = [sigma sigma];
end

sigma = double(sigma);

end

function filterSize = computeFilterSizeFromSigma(sigma)

filterSize = 2*ceil(2*sigma) + 1;

end

function padding = validatePadding(padding)

if ~ischar(padding)
    validateattributes(padding, {'numeric','logical'}, {'real','scalar','nonsparse'}, mfilename, 'Padding');
else
    padding = validatestring(padding, {'replicate','circular','symmetric'}, mfilename, 'Padding');
end

end

function filterDomain = validateFilterDomain(filterDomain)

filterDomain = validatestring(filterDomain, {'spatial','frequency','auto'}, mfilename, 'FilterDomain');

end
