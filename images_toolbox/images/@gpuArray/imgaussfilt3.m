function B = imgaussfilt3(varargin)
%IMGAUSSFILT3 3-D Gaussian filtering of 3-D images
%
%   B = imgaussfilt3(A) filters 3-D gpuArray image A with a 3-D Gaussian
%   smoothing kernel with standard deviation of 0.5.
%
%   B = imgaussfilt3(A,SIGMA) filters 3-D gpuArray image A with a 3-D
%   Gaussian smoothing kernel with standard deviation specified by SIGMA.
%   SIGMA can
%   be a scalar or a 3-element vector with positive values. If sigma is a
%   scalar, a cube Gaussian kernel is used.
%
%   B = imgaussfilt3(___,Name,Value,...) filters 3-D gpuArray image A with
%   a 3-D Gaussian smoothing kernel with Name-Value pairs used to control
%   aspects
%   of the filtering.
%
%   Parameters include:
%
%   'FilterSize'    -   Scalar or 3-element vector, of positive, odd
%                       integers that specifies the size of the Gaussian
%                       filter. If a scalar Q is specified, then a square
%                       Gaussian filter of size [Q Q Q] is used.
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
%   The input gpuArray image A must be a real, non-sparse matrix of 3
%   dimension of the following underlying classes: uint8, int8, uint16,
%   int16, uint32, int32, single or double.
%
%   Notes
%   -----
%   1. If the image A contains Infs or NaNs, the behavior of imgaussfilt3
%      for frequency domain filtering is undefined. This can happen when
%      the 'FilterDomain' parameter is set to 'frequency' or when it is set
%      to 'auto' and frequency domain filtering is used internally. To
%      restrict the propagation of Infs and NaNs in the output in a manner
%      similar to imfilter, consider setting the 'FilterDomain' parameter
%      to 'spatial'.
%
%   2. When 'FilterDomain' parameter is set to 'auto', an internal
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
%   This example smooths an MRI volume with a 3-D Gaussian filter.
%
%   vol = load('mri');
%   figure, montage(vol.D), title('Original image volume')
%
%   siz = vol.siz;
%   vol = gpuArray(squeeze(vol.D));   
%   sigma = 2;
%
%   volSmooth = imgaussfilt3(vol, sigma);
% 
%   figure, montage(reshape(gather(volSmooth),siz(1),siz(2),1,siz(3)))
%   title('Gaussian filtered image volume')
%
%   See also gpuArray/imgaussfilt, imfilter.

% Copyright 2014-2023 The MathWorks, Inc.

narginchk(1, Inf);

% Dispatch to CPU
if ~isgpuarray(varargin{1})
    [varargin{:}] = gather(varargin{:});
    B = imgaussfilt3(varargin{:});
    return;
end

args = matlab.images.internal.stringToChar(varargin);
[A, options] = parseInputs(args{:});

if isempty(A)
    B = A;
    return;
end

sigma       = options.Sigma;
hsize       = options.FilterSize;
padding     = options.Padding;
domain      = options.FilterDomain;

domain = chooseFilterImplementation(A, hsize, domain);

switch domain
    case 'spatial'
        B = spatialGaussianFilter(A, sigma, hsize, padding);
        
    case 'frequency'
        B = frequencyGaussianFilter(A, sigma, hsize, padding);
        
    otherwise
        assert(false, 'Internal Error: Unknown filter domain');
end

end

%--------------------------------------------------------------------------
% Spatial Domain Filtering
%--------------------------------------------------------------------------
function A = spatialGaussianFilter(A, sigma, hsize, padding)

dtype = underlyingType(A);

useConvPadding = isnumeric(padding) && padding==0;

if ~useConvPadding
    A = padImage(A, hsize, padding);
end

[hCol,hRow,hSlc] = createSeparableGaussianKernel(sigma, hsize);

switch underlyingType(A)
    case {'int32','uint32'}
        A = double(A);
    case {'uint8','int8','uint16','int16'}
        A = single(A);
    case {'single','double'}
        % No-op
    otherwise
        assert(false,'Unexpected datatype');     
end

if useConvPadding
    shape = 'same';
else
    shape = 'valid';
end

% 3-D Separable filtering
A = convn(A,hRow,shape);
A = convn(A,hCol,shape);
A = convn(A,hSlc,shape);

if ~isUnderlyingType(A,dtype)
    A = cast(A,dtype);
end
    
end

function [hcol,hrow,hslc] = createSeparableGaussianKernel(sigma, hsize)

isIsotropic = all(sigma==sigma(1)) && all(hsize==hsize(1));

hcol = images.internal.createGaussianKernel(sigma(1), hsize(1));

if isIsotropic
    hrow = hcol;
    hslc = hcol;
else
    hrow = images.internal.createGaussianKernel(sigma(2), hsize(2));
    hslc = images.internal.createGaussianKernel(sigma(3), hsize(3));
end

hrow = reshape(hrow, 1, hsize(2));
hslc = reshape(hslc, 1, 1, hsize(3));

end

%--------------------------------------------------------------------------
% Frequency Domain Filtering
%--------------------------------------------------------------------------
function A = frequencyGaussianFilter(A, sigma, hsize, padding)

sizeA = [size(A) ones(1,3-ndims(A))];
dtype = underlyingType(A);
outSize = sizeA;

A = padImage(A, hsize, padding);

h = gpuArray(images.internal.createGaussianKernel(sigma, hsize));

% cast to double to preserve precision unless single
if ~isfloat(A)
    A = double(A);
end

fftSize = size(A);
A = ifftn( fftn(A, fftSize) .* fftn(h, fftSize), 'symmetric' );

if ~isUnderlyingType(A,dtype)
    A = cast(A, dtype);
end

start = 1 + size(A)-outSize;
stop = start + outSize - 1;

A = A(start(1):stop(1), start(2):stop(2), start(3):stop(3));

end

%--------------------------------------------------------------------------
% Common Functions
%--------------------------------------------------------------------------
function domain = chooseFilterImplementation(A, hsize, domain)

if strcmp(domain, 'auto')
    domain = chooseFilterDomain3(A, hsize);
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

%--------------------------------------------------------------------------
% Input Parsing
%--------------------------------------------------------------------------
function [A, options] = parseInputs(varargin)

A = varargin{1};

supportedClasses = {'uint8','uint16','uint32','int8','int16','int32','single','double'};
supportedImageAttributes = {'real','3d','nonsparse'};
validateattributes(A, supportedClasses, supportedImageAttributes, mfilename, 'A');

% Default options
options = struct(...
        'Sigma',        [.5 .5 .5],...
        'FilterSize',   [3 3 3],...
        'Padding',      'replicate',...
        'FilterDomain', 'auto');

beginningOfNameVal = find(cellfun(@isstr,varargin),1);

if isempty(beginningOfNameVal) && length(varargin)==1
    %imgaussfilt3(A)
    return;
elseif beginningOfNameVal==2
    %imgaussfilt3(A,'Name',Value)
elseif (isempty(beginningOfNameVal) && length(varargin)==2) || (~isempty(beginningOfNameVal) && beginningOfNameVal==3)
    %imgaussfilt3(A,sigma,'Name',Value,...)
    %imgaussfilt3(A,sigma)
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
ValidateFcn = {@images.internal.validateThreeDFilterSize, @validatePadding, @validateFilterDomain};

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

validateattributes(sigma, {'numeric'}, {'real','positive','finite','nonempty'}, mfilename, 'Sigma');

if isscalar(sigma)
    sigma = [sigma sigma sigma];
end

if numel(sigma)~=3
    error(message('images:imgaussfilt:invalidLength3', 'Sigma'));
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
