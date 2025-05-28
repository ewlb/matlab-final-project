function varargout = edge(varargin) %#codegen
%EDGE Find edges in intensity image.

% Copyright 2013-2024 The MathWorks, Inc.

narginchk(1,5);
coder.internal.prefer_const(varargin);

% Shared library
singleThread = images.internal.coder.useSingleThread();
useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() && ...
    coder.const(~singleThread);

coder.internal.errorIf(nargout>4,'images:edge:tooManyOutputs');

in = varargin{1};
validateattributes(in,{'numeric','logical'},{'real','nonsparse','2d'},mfilename,'I',1); %#ok<*EMCA>

if nargin>1
    coder.internal.errorIf(~isa(varargin{2},'char'),...
        'images:edge:invalidSecondArgument');
    methodStr = validatestring(varargin{2},{'canny','approxcanny','sobel','prewitt','roberts','log','zerocross'},mfilename,'METHOD',2);
    coder.internal.errorIf(~any(strcmp(methodStr,{'sobel','roberts','prewitt'})) && (nargout>2),...
        'images:edge:tooManyOutputs');
    method = enumMethod(methodStr);
    if method==SOBEL || method==PREWITT || method==ROBERTS
        %this codepath does not need sigma or H.
        [direction,thinning,thresh,threshFlag] = parseGradientOperatorMethods(varargin{3:end});
        if direction==BOTH
            kx = 1; ky = 1;
        elseif direction==HORIZONTAL
            kx = 0; ky = 1;
        else%if direction==VERTICAL
            kx = 1; ky = 0;
        end
    elseif method==LOG
        %this codepath does not need direction,thinning or H.
        H = [];
        [thresh,threshFlag,sigma] = parseLaplacianOfGaussianMethod(varargin{3:end});
    elseif method==ZEROCROSS
        %this codepath does not need direction,thinning or sigma.
        sigma = 2;
        [thresh,threshFlag,H] = parseZeroCrossingMethod(varargin{3:end});
    elseif method==APPROXCANNY
        [thresh] = parseApproxCannyMethod(varargin{3:end});
    else%if method==CANNY
        %this codepath does not need direction,thinning or H.
        [thresh,threshFlag,sigma] = parseCannyMethod(varargin{3:end});
    end
else
    %these are the defaults.
    method     = SOBEL;
    thinning   = true;
    thresh     = 0;
    threshFlag = 0;
    H          = [];
    sigma      = 2;
    kx         = 1;
    ky         = 1;
end

% Transform to a double precision intensity image if necessary
isPrewittOrSobel = (method==SOBEL || method==PREWITT);

if method == CANNY && ~useSharedLibrary
    if ~isa(in,'single')
        a = im2single(in);
    else
        a = in;
    end
else
    % Row-major codegen uses shared library codepath only for Sobel and Prewitt
    useSharedLibrary = useSharedLibrary && ...
        (~(coder.isRowMajor && ~isPrewittOrSobel));
    if (~isPrewittOrSobel || ~useSharedLibrary) && ~isfloat(in) && ~strcmp(method,'approxcanny')
        a = im2single(in);
    elseif isequal(class(in), 'uint32') || isequal(class(in), 'uint64') || ...
            isequal(class(in), 'int64') || isequal(class(in), 'int32')
        a = single(in);
    else
        a = in;
    end
end

if isempty(a)
    varargout{1}  = false(size(a));
    if nargout > 2
        varargout{3} = [];
        varargout{4} = [];
    end
    if nargout >= 2
        if nargin == 2
            if method==CANNY
                varargout{2} = coder.internal.nan(1,2);
            else
                varargout{2} = coder.internal.nan(1);
            end
        else
            if method==CANNY
                varargout{2} = thresh;
            else
                varargout{2} = thresh(1);
            end
        end
    end
    return;
end

[m,n] = size(a);

if method == CANNY
    % Magic numbers
    PercentOfPixelsNotEdges = .7; % Used for selecting thresholds
    ThresholdRatio = .4;          % Low thresh is this fraction of the high.

    % Calculate gradients using a derivative of Gaussian filter
    [dx, dy] = smoothGradient(a, sigma);

    magGrad = coder.nullcopy((zeros(m,n,class(dx))));
    magGrad(1) = hypot(dx(1), dy(1));
    magmax = magGrad(1);

    parfor idx = 2 : numel(magGrad)
        magGrad(idx) = hypot(dx(idx), dy(idx));
        magmax = max(magGrad(idx), magmax);
    end

    if magmax > 0
        magGrad = magGrad / magmax;
    end

    % Determine Hysteresis Thresholds
    [lowThresh, highThresh] = selectThresholds(thresh, threshFlag, magGrad, PercentOfPixelsNotEdges, ThresholdRatio, mfilename);

    % Perform Non-Maximum Suppression Thining and Hysteresis Thresholding of Edge
    % Strength
    e = false(m,n);
    if ~isvector(e)
        e = thinAndThreshold(e, dx, dy, magGrad, lowThresh, highThresh, useSharedLibrary);
    end

    thresh(1) = lowThresh(1);
    thresh(2) = highThresh(1);
elseif method == APPROXCANNY
    e = computeapproxcanny(a, thresh);
elseif method == LOG || method == ZEROCROSS
    if isempty(H)
        fsize = ceil(sigma*3) * 2 + 1;  % choose an odd fsize > 6*sigma;
        op = fspecial('log',fsize,sigma);
    else
        op = H;
    end

    op = op - sum(op(:))/numel(op); % make the op to sum to zero
    b = imfilter(a,op,'replicate');

    if threshFlag==0
        thresh = [0.75 * sum(abs(b(:)),'double') / numel(b) 0];
    end

    e = false(m,n);
    rrmax = m-1;
    parfor cc = 2 : n-1
        for rr = 2 : rrmax
            b_up     = b(rr-1,cc  );
            b_down   = b(rr+1,cc  );
            b_left   = b(rr  ,cc-1);
            b_right  = b(rr  ,cc+1);
            b_center = b(rr  ,cc  );
            if b_center ~= 0
                % Look for the zero crossings:  +-, -+ and their transposes
                % We arbitrarily choose the edge to be the negative point
                zc1 = b_center<0 && b_right >0 && abs(b_center-b_right )>thresh(1);
                zc2 = b_left  >0 && b_center<0 && abs(b_left  -b_center)>thresh(1);
                zc3 = b_center<0 && b_down  >0 && abs(b_center-b_down  )>thresh(1);
                zc4 = b_up    >0 && b_center<0 && abs(b_up    -b_center)>thresh(1);
            else
                % Look for the zero crossings: +0-, -0+ and their transposes
                % The edge lies on the Zero point
                zc1 = b_up    <0 && b_down  >0 && abs(b_up    -b_down )>2*thresh(1);
                zc2 = b_up    >0 && b_down  <0 && abs(b_up    -b_down )>2*thresh(1);
                zc3 = b_left  <0 && b_right >0 && abs(b_left  -b_right)>2*thresh(1);
                zc4 = b_left  >0 && b_right <0 && abs(b_left  -b_right)>2*thresh(1);
            end
            e(rr,cc) = zc1 || zc2 || zc3 || zc4;
        end
    end

else%if method==SOBEL || method==PREWITT || method==ROBERTS
    if isPrewittOrSobel
        isSobel = (method == SOBEL);
        scale  = 4;
        offset = int8([0 0 0 0]);

        if(useSharedLibrary)
            [bx, by, b] = computeEdgeSobelPrewittLibrary(a,isSobel,kx,ky);
        else
            [bx, by, b] = computeEdgeSobelPrewittPortable(a,isSobel,kx,ky);
        end


    elseif method==ROBERTS
        x_mask = [1 0; 0 -1]/2; % Roberts approximation to diagonal derivative
        y_mask = [0 1;-1  0]/2;

        scale  = 6;
        offset = int8([-1 1 1 -1]);

        % compute the gradient in x and y direction
        if(useSharedLibrary)
            bx = imfilter(a,x_mask,'replicate');
            by = imfilter(a,y_mask,'replicate');
        else % portable code generation
            x_mask = rot90(x_mask,2); % convMode = 0
            y_mask = rot90(y_mask,2);
            coder.const(x_mask); coder.const(y_mask);
            a = padarray(a,[1 1],'replicate','post');
            bx = conv2(a,x_mask,'valid');
            by = conv2(a,y_mask,'valid');
        end
        % compute the magnitude
        b = kx*bx.*bx + ky*by.*by;
    end

    if (nargout > 2) % if gradients are requested
        varargout{3} = bx;
        varargout{4} = by;
    end


    % Determine the threshold; see page 514 of
    % "Digital Imaging Processing" by William K. Pratt
    if threshFlag==0 % Determine cutoff based on RMS estimate of noise
        % Mean of the magnitude squared image is a
        % value that's roughly proportional to SNR
        cutoff =  scale * sum(b(:),'double') / numel(b);
        thresh(1) = sqrt(cutoff);
    else
        % Use relative tolerance specified by the user
        cutoff = (thresh(1)).^2;
    end

    e = coder.nullcopy(false(m,n));

    if thinning
        if(useSharedLibrary)
            e = computeEdgesWithThinningLibrary(b,bx,by,kx,ky,offset,cutoff,e);
        else
            e = computeEdgesWithThinningPortable(b,bx,by,kx,ky,offset,cutoff,e);
        end
    else
        e = b > cutoff;
    end
end

varargout{1} = e;

if nargout>=2
    if method== CANNY || APPROXCANNY
        varargout{2} = thresh;
    else
        varargout{2} = thresh(1);
    end
end

%Parse input arguments for 'log'.
function [thresh,threshFlag,sigma] = parseLaplacianOfGaussianMethod(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);
narginchk(0,2);
if nargin==0
    %edge(im,method)
    thresh     = [0 0];
    threshFlag = 0;
    sigma      = 2;
elseif nargin==1
    %edge(im,method,thresh)
    validateattributes(varargin{1},...
        {'numeric','logical'},{},...
        mfilename,'THRESH',3);
    coder.internal.errorIf(numel(varargin{1}) > 1,...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    if isempty(varargin{1})
        thresh     = [0 0];
        threshFlag = 0;
    else
        thresh     = [varargin{1} 0];
        threshFlag = 1;
    end
    sigma      = 2;
else%if nargin==2
    %edge(im,method,thresh,sigma)
    validateattributes(varargin{1},...
        {'numeric','logical'},{},...
        mfilename,'THRESH',3);
    coder.internal.errorIf(numel(varargin{1}) > 1,...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    if isempty(varargin{1})
        thresh     = [0 0];
        threshFlag = 0;
    else
        thresh     = [varargin{1} 0];
        threshFlag = 1;
    end
    validateattributes(varargin{2},...
        {'numeric','logical'},{},...
        mfilename,'SIGMA',4);
    coder.internal.errorIf(numel(varargin{2}) ~= 1,...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    sigma  = varargin{2};
end

%Parse input arguments for 'sobel','prewitt' or 'roberts'.
function [direction,thinning,thresh,threshFlag] = parseGradientOperatorMethods(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);

if nargin==0
    %edge(im,method)
    direction  = BOTH;
    thinning   = true;
    thresh     = 0;
    threshFlag = 0;
elseif nargin==1
    if ischar(varargin{1})
        %edge(im,method,direction)
        %edge(im,method,thinning)
        thresh     = [0 0];
        threshFlag = 0;
        coder.internal.errorIf(~any(strcmp(varargin{1},{'both','horizontal','vertical','thinning','nothinning'})),...
            'images:edge:invalidInputArguments',...
            'IfNotConst','Fail');
        if strcmp(varargin{1},'both')
            direction = BOTH;
            thinning  = true;
        elseif strcmp(varargin{1},'horizontal')
            direction = HORIZONTAL;
            thinning  = true;
        elseif strcmp(varargin{1},'vertical')
            direction = VERTICAL;
            thinning  = true;
        elseif strcmp(varargin{1},'thinning')
            direction = BOTH;
            thinning  = true;
        else % strcmp(varargin{1},'nothinning')
            direction = BOTH;
            thinning  = false;
        end
    else
        %edge(im,method,thresh)
        validateattributes(varargin{1},...
            {'numeric','logical'},{},...
            mfilename,'THRESH',3);
        coder.internal.errorIf(numel(varargin{1}) > 1,...
            'images:edge:invalidInputArguments',...
            'IfNotConst','Fail');
        if isempty(varargin{1})
            thresh     = [0 0];
            threshFlag = 0;
        else
            thresh     = [varargin{1} 0];
            threshFlag = 1;
        end
        direction = BOTH;
        thinning  = true;
    end
elseif nargin==2
    if ischar(varargin{1})
        %edge(im,method,direction,__)
        thresh     = [0 0];
        threshFlag = 0;
        thinning   = true;
        coder.internal.errorIf(~any(strcmp(varargin{1},{'both','horizontal','vertical'})),...
            'images:edge:invalidInputArguments',...
            'IfNotConst','Fail');
        if strcmp(varargin{1},'both')
            direction = BOTH;
        elseif strcmp(varargin{1},'horizontal')
            direction = HORIZONTAL;
        else % strcmp(varargin{1},'vertical')
            direction = VERTICAL;
        end
    else
        %edge(im,method,thresh,__)
        validateattributes(varargin{1},...
            {'numeric','logical'},{},...
            mfilename,'THRESH',3);
        coder.internal.errorIf(numel(varargin{1}) > 1,...
            'images:edge:invalidInputArguments',...
            'IfNotConst','Fail');
        if isempty(varargin{1})
            thresh     = [0 0];
            threshFlag = 0;
        else
            thresh     = [varargin{1} 0];
            threshFlag = 1;
        end
        direction = BOTH;
    end

    coder.internal.errorIf(~isa(varargin{2},'char'),...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    if ischar(varargin{1})
        coder.internal.errorIf(~any(strcmp(varargin{2},{'thinning','nothinning'})),...
            'images:edge:invalidInputArguments',...
            'IfNotConst','Fail');
        %edge(im,method,direction,thinning)
        %direction has been specified, this can only be a thinning string.
        if strcmp(varargin{2},'thinning')
            thinning = true;
        else % strcmp(varargin{2},'nothinning')
            thinning = false;
        end
    else
        %direction has not been specified, so this can be a
        %direction/thinning string.
        %edge(im,method,thresh,direction)
        %edge(im,method,thresh,thinning)
        coder.internal.errorIf(~any(strcmp(varargin{2},{'horizontal','vertical','both','thinning','nothinning'})),...
            'images:edge:invalidInputArguments',...
            'IfNotConst','Fail');
        if strcmp(varargin{2},'horizontal')
            direction = HORIZONTAL;
            thinning  = true;
        elseif strcmp(varargin{2},'vertical')
            direction = VERTICAL;
            thinning  = true;
        elseif strcmp(varargin{2},'both')
            direction = BOTH;
            thinning  = true;
        elseif strcmp(varargin{2},'thinning')
            direction = BOTH;
            thinning  = true;
        else % strcmp(varargin{2},'nothinning')
            direction = BOTH;
            thinning  = false;
        end
    end

elseif nargin==3
    %has to be thresh,direction,thinning
    %edge(im,method,thresh,direction,thinning)
    validateattributes(varargin{1},...
        {'numeric','logical'},{},...
        mfilename,'THRESH',3);
    coder.internal.errorIf(numel(varargin{1}) > 1,...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    if isempty(varargin{1})
        thresh     = [0 0];
        threshFlag = 0;
    else
        thresh     = [varargin{1} 0];
        threshFlag = 1;
    end

    coder.internal.errorIf(~isa(varargin{2},'char'),...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    coder.internal.errorIf(~any(strcmp(varargin{2},{'horizontal','vertical','both'})),...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    if strcmp(varargin{2},'horizontal')
        direction = HORIZONTAL;
    elseif strcmp(varargin{2},'vertical')
        direction = VERTICAL;
    else % strcmp(varargin{2},'both')
        direction = BOTH;
    end

    coder.internal.errorIf(~isa(varargin{3},'char'),...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    coder.internal.errorIf(~any(strcmp(varargin{3},{'thinning','nothinning'})),...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    if strcmp(varargin{3},'thinning')
        thinning = true;
    else % strcmp(varargin{3},'nothinning')
        thinning = false;
    end
end

%Parse input arguments for 'zerocrossing'.
function [thresh,threshFlag,H] = parseZeroCrossingMethod(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);
narginchk(0,2);
if nargin==0
    %edge(im,nethod)
    thresh     = [0 0];
    threshFlag = 0;
    H      = [];
elseif nargin==1
    if numel(varargin{1})>1
        %edge(im,method,H)
        validateattributes(varargin{1},...
            {'numeric','logical'},{},...
            mfilename,'H',3);

        thresh     = [0 0];
        threshFlag = 0;
        H          = varargin{1};
    else
        %edge(im,method,thresh)
        validateattributes(varargin{1},...
            {'numeric','logical'},{},...
            mfilename,'THRESH',3);
        if isempty(varargin{1})
            thresh     = [0 0];
            threshFlag = 0;
        else
            thresh     = [varargin{1} 0];
            threshFlag = 1;
        end
        H      = [];
    end
elseif nargin==2
    %edge(im,method,thresh,H)
    validateattributes(varargin{1},...
        {'numeric','logical'},{},...
        mfilename,'THRESH',3);
    coder.internal.errorIf(numel(varargin{1}) > 1,...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    if isempty(varargin{1})
        thresh     = [0 0];
        threshFlag = 0;
    else
        thresh     = [varargin{1} 0];
        threshFlag = 1;
    end

    validateattributes(varargin{2},...
        {'numeric','logical'},{},...
        mfilename,'H',4);
    coder.internal.errorIf(numel(varargin{2}) <= 1,...
        'images:edge:invalidInputArguments');
    H = varargin{2};
end


%Parse input arguments for 'approxcanny'.
function [thresh] = parseApproxCannyMethod(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);
narginchk(0,1);
if nargin == 0
    %edge(im,method)
    thresh     = [];
elseif nargin == 1
    %edge(im,method,thresh)
    validateattributes(varargin{1},...
        {'numeric','logical'},{'real'},...
        mfilename,'THRESH',3);
    coder.internal.errorIf(numel(varargin{1}) > 2,...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    if isempty(varargin{1})
        thresh = [];
    elseif numel(varargin{1}) == 1
        threshone = varargin{1};
        coder.internal.errorIf(threshone>=1 || threshone < 0, ...
            'images:edge:singleThresholdOutOfRange');
        thresh = [0.4*varargin{1} varargin{1}];
    elseif numel(varargin{1}) == 2
        if ~isrow(varargin{1})
            threshCol = varargin{1};
            thresh    = [threshCol(1) threshCol(2)];
        else
            thresh     = varargin{1};
        end
        lowThresh = thresh(1);
        highThresh = thresh(2);
        coder.internal.errorIf((lowThresh >= highThresh) || highThresh >= 1 || lowThresh < 0,...
            'images:edge:thresholdOutOfRange');
    end
end

%Parse input arguments for 'canny'.
function [thresh,threshFlag,sigma] = parseCannyMethod(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);
narginchk(0,2);
if nargin==0
    %edge(im,method)
    thresh     = [0 0];
    threshFlag = 0;
    sigma      = sqrt(2);
elseif nargin==1
    %edge(im,method,thresh)
    validateattributes(varargin{1},...
        {'numeric','logical'},{},...
        mfilename,'THRESH',3);
    coder.internal.errorIf(numel(varargin{1}) > 2,...
        'images:edge:invalidInputArguments',...;
        'IfNotConst','Fail');
    if isempty(varargin{1})
        thresh     = [0 0];
        threshFlag = 0;
    elseif numel(varargin{1})==1
        thresh     = [varargin{1} 0];
        threshFlag = 1;
    elseif numel(varargin{1})==2
        if ~isrow(varargin{1})
            threshCol = varargin{1};
            thresh    = [threshCol(1) threshCol(2)];
        else
            thresh     = varargin{1};
        end
        threshFlag = 2;
    end
    sigma = sqrt(2);
elseif nargin==2
    %edge(im,method,thresh,sigma)
    validateattributes(varargin{1},...
        {'numeric','logical'},{},...
        mfilename,'THRESH',3);
    coder.internal.errorIf(numel(varargin{1}) > 2,...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    if isempty(varargin{1})
        thresh     = [0 0];
        threshFlag = 0;
    elseif numel(varargin{1})==1
        thresh     = [varargin{1} 0];
        threshFlag = 1;
    elseif numel(varargin{1})==2
        if ~isrow(varargin{1})
            threshCol = varargin{1};
            thresh    = [threshCol(1) threshCol(2)];
        else
            thresh     = varargin{1};
        end
        threshFlag = 2;
    end
    validateattributes(varargin{2},...
        {'numeric','logical'},{},...
        mfilename,'SIGMA',4);
    coder.internal.errorIf(numel(varargin{2}) ~= 1,...
        'images:edge:invalidInputArguments',...
        'IfNotConst','Fail');
    sigma  = varargin{2};
end

%Enumerate method strings.
function methodFlag = enumMethod(methodStr)
coder.inline('always');

if strcmp(methodStr,'canny')
    methodFlag = CANNY;
elseif strcmp(methodStr,'approxcanny')
    methodFlag = APPROXCANNY;
elseif strcmp(methodStr,'prewitt')
    methodFlag = PREWITT;
elseif strcmp(methodStr,'sobel')
    methodFlag = SOBEL;
elseif strcmp(methodStr,'log')
    methodFlag = LOG;
elseif strcmp(methodStr,'roberts')
    methodFlag = ROBERTS;
else %if strcmp(methodStr,'zerocross')
    methodFlag = ZEROCROSS;
end

%Enumeration functions for method strings and direction strings.
function methodFlag = CANNY()
coder.inline('always');
methodFlag = int8(1);

function methodFlag = PREWITT()
coder.inline('always');
methodFlag = int8(2);

function methodFlag = SOBEL()
coder.inline('always');
methodFlag = int8(3);

function methodFlag = LOG()
coder.inline('always');
methodFlag = int8(4);

function methodFlag = ROBERTS()
coder.inline('always');
methodFlag = int8(5);

function methodFlag = ZEROCROSS()
coder.inline('always');
methodFlag = int8(6);

function methodFlag = APPROXCANNY()
coder.inline('always');
methodFlag = int8(7);

function directionFlag = BOTH()
coder.inline('always');
directionFlag = int8(1);

function directionFlag = HORIZONTAL()
coder.inline('always');
directionFlag = int8(2);

function directionFlag = VERTICAL()
coder.inline('always');
directionFlag = int8(3);

%Method-specific sub-functions.
function [GX, GY] = smoothGradient(I, sigma)
coder.inline('always');
coder.internal.prefer_const(I,sigma);
% Create an even-length 1-D separable Derivative of Gaussian filter

% Determine filter length
filterExtent = ceil(4*sigma);

% Complete gaussian kernel is generated from the positive half utilizing the symmetric nature of the kernel
x = 0:filterExtent;

% Create positive half of 1-D gaussian kernel
c = 1/(sqrt(2*pi)*sigma);
gaussKernelTemp = c * exp(-(x.^2)/(2*sigma^2));

% Normalize to ensure kernel sums to one
gaussKernelTemp = gaussKernelTemp/(2*sum(gaussKernelTemp(2:end))+gaussKernelTemp(1));

% Append a symmetric mirror to create the complete kernel
gaussKernel = [fliplr(gaussKernelTemp) gaussKernelTemp(2:end)];

% Create 1-D Derivative of Gaussian Kernel
derivGaussKernelTemp = gradient(gaussKernel);

% Normalize to ensure kernel sums to one
derivGaussKernel = (derivGaussKernelTemp/sum(derivGaussKernelTemp(1:filterExtent+1)));
coder.internal.prefer_const(gaussKernel,derivGaussKernel);

% Compute smoothed numerical gradient of image I along x (horizontal)
% direction. GX corresponds to dG/dx, where G is the Gaussian Smoothed
% version of image I.
GX = imfilter(I, gaussKernel', 'conv', 'replicate');
GX = imfilter(GX, derivGaussKernel, 'conv', 'replicate');

% Compute smoothed numerical gradient of image I along y (vertical)
% direction. GY corresponds to dG/dy, where G is the Gaussian Smoothed
% version of image I.
GY = imfilter(I, gaussKernel, 'conv', 'replicate');
GY  = imfilter(GY, derivGaussKernel', 'conv', 'replicate');

function [lowThresh, highThresh] = selectThresholds(thresh, threshFlag, magGrad, PercentOfPixelsNotEdges, ThresholdRatio, ~)
coder.inline('always');
coder.internal.prefer_const(thresh, threshFlag, magGrad, PercentOfPixelsNotEdges, ThresholdRatio);
[m,n] = size(magGrad);

% Select the thresholds
if threshFlag==0
    counts = imhist(magGrad, 64);
    sum = 0;
    idx = ones('int8');

    while ~(sum > PercentOfPixelsNotEdges*m*n) && idx <= length (counts)
        sum = sum + counts(idx);
        idx = idx+1;
    end

    highThreshTemp = double((idx-1)) / length (counts);

    if idx > length (counts) && ~(sum > PercentOfPixelsNotEdges*m*n) % edge case : empty input
        highThresh = zeros(0,1,'like',highThreshTemp);
        lowThresh = zeros(0,1,'like',highThreshTemp);
    else
        highThresh = highThreshTemp;
        lowThresh  = ThresholdRatio*highThresh;
    end
elseif threshFlag==1
    highThresh = thresh(1);
    coder.internal.errorIf(thresh(1) >= 1,...
        'images:edge:singleThresholdOutOfRange');
    lowThresh  = ThresholdRatio*thresh(1);
else%if threshFlag==2
    lowThresh  = thresh(1);
    highThresh = thresh(2);
    coder.internal.errorIf(~(lowThresh(1)<highThresh(1) && highThresh(1)<1),...
        'images:edge:thresholdOutOfRange');
end

function H = thinAndThreshold(E, dx, dy, magGrad, lowThresh, highThresh, useSharedLibrary)

% Perform Non-Maximum Suppression Thinning and Hysteresis Thresholding of Edge
% Strength

% We will accrue indices which specify ON pixels in strong edgemap
% The array e will become the weak edge map.
coder.internal.prefer_const(useSharedLibrary);
[m, n] = size(E);
if(useSharedLibrary)
    E = cannyFindLocalMaximaLibrary(E,dx,dy,magGrad,[m, n],lowThresh(1)); % lowThresh(1) to ensure scalar double.
else
    E = cannyFindLocalMaximaPortable(E,dx,dy,magGrad,lowThresh);
end

marker = magGrad > highThresh(1);
H = imreconstruct(marker, E, 8);



function E = cannyFindLocalMaximaPortable(E,ix,iy,mag,lowThresh)
%
% This sub-function helps with the non-maximum suppression in the Canny
% edge detector.
%

[m,n] = size(mag);
if ~isempty(lowThresh)
    if coder.isColumnMajor
        rmax = m-1;
        parfor c = 2 : n-1
            for r = 2 : rmax
                gradmagval  = mag(r,c);
                if gradmagval>lowThresh(1)
                    ixval       = ix(r,c);
                    iyval       = iy(r,c);
                    if (iyval<=0 && ixval>-iyval) || (iyval>=0 && ixval<-iyval)
                        dval        = abs(iyval/ixval);
                        gradmagval1 = mag(r,c+1)*(1-dval) + mag(r-1,c+1)*dval;
                        gradmagval2 = mag(r,c-1)*(1-dval) + mag(r+1,c-1)*dval;
                        if gradmagval>=gradmagval1 && gradmagval>=gradmagval2
                            E(r,c) = true;
                        end
                    elseif (ixval>0 && -iyval>=ixval)  || (ixval<0 && -iyval<=ixval)
                        dval        = abs(ixval/iyval);
                        gradmagval1 = mag(r-1,c)*(1-dval) + mag(r-1,c+1)*dval;
                        gradmagval2 = mag(r+1,c)*(1-dval) + mag(r+1,c-1)*dval;
                        if gradmagval>=gradmagval1 && gradmagval>=gradmagval2
                            E(r,c) = true;
                        end
                    elseif (ixval<=0 && ixval>iyval) || (ixval>=0 && ixval<iyval)
                        dval        = abs(ixval/iyval);
                        gradmagval1 = mag(r-1,c)*(1-dval) + mag(r-1,c-1)*dval;
                        gradmagval2 = mag(r+1,c)*(1-dval) + mag(r+1,c+1)*dval;
                        if gradmagval>=gradmagval1 && gradmagval>=gradmagval2
                            E(r,c) = true;
                        end
                    elseif (iyval<0 && ixval<=iyval)  || (iyval>0 && ixval>=iyval)
                        dval        = abs(iyval/ixval);
                        gradmagval1 = mag(r,c-1)*(1-dval) + mag(r-1,c-1)*dval;
                        gradmagval2 = mag(r,c+1)*(1-dval) + mag(r+1,c+1)*dval;
                        if gradmagval>=gradmagval1 && gradmagval>=gradmagval2
                            E(r,c) = true;
                        end
                    end
                end
            end
        end
    else
        cmax = n-1;
        parfor  r = 2 : m-1
            for c = 2 : cmax
                gradmagval  = mag(r,c);
                if gradmagval>lowThresh(1)
                    ixval       = ix(r,c);
                    iyval       = iy(r,c);

                    if (iyval<=0 && ixval>-iyval) || (iyval>=0 && ixval<-iyval)
                        dval        = abs(iyval/ixval);
                        gradmagval1 = mag(r,c+1)*(1-dval) + mag(r-1,c+1)*dval;
                        gradmagval2 = mag(r,c-1)*(1-dval) + mag(r+1,c-1)*dval;
                        if gradmagval>=gradmagval1 && gradmagval>=gradmagval2
                            E(r,c) = true;
                        end
                    elseif (ixval>0 && -iyval>=ixval)  || (ixval<0 && -iyval<=ixval)
                        dval        = abs(ixval/iyval);
                        gradmagval1 = mag(r-1,c)*(1-dval) + mag(r-1,c+1)*dval;
                        gradmagval2 = mag(r+1,c)*(1-dval) + mag(r+1,c-1)*dval;
                        if gradmagval>=gradmagval1 && gradmagval>=gradmagval2
                            E(r,c) = true;
                        end
                    elseif (ixval<=0 && ixval>iyval) || (ixval>=0 && ixval<iyval)
                        dval        = abs(ixval/iyval);
                        gradmagval1 = mag(r-1,c)*(1-dval) + mag(r-1,c-1)*dval;
                        gradmagval2 = mag(r+1,c)*(1-dval) + mag(r+1,c+1)*dval;
                        if gradmagval>=gradmagval1 && gradmagval>=gradmagval2
                            E(r,c) = true;
                        end
                    elseif (iyval<0 && ixval<=iyval)  || (iyval>0 && ixval>=iyval)
                        dval        = abs(iyval/ixval);
                        gradmagval1 = mag(r,c-1)*(1-dval) + mag(r-1,c-1)*dval;
                        gradmagval2 = mag(r,c+1)*(1-dval) + mag(r+1,c+1)*dval;
                        if gradmagval>=gradmagval1 && gradmagval>=gradmagval2
                            E(r,c) = true;
                        end
                    end
                end
            end
        end
    end
end

function E = cannyFindLocalMaximaLibrary(E,ix,iy,mag,sz,lowThresh)
% This subfunction calculates local maxima using a shared
% library

coder.inline('always');
coder.internal.prefer_const(ix,iy,mag,lowThresh);

fcnName = ['cannythresholding_',images.internal.coder.getCtype(ix),'_tbb'];
E = images.internal.coder.buildable.CannyThresholdingTbbBuildable.cannythresholding_tbb(...
    fcnName,...
    ix,...
    iy,...
    mag,...
    sz,...
    lowThresh,...
    E);

function e = computeEdgesWithThinningPortable(b,bx,by,kx,ky,offset,cutoff,e)
% This subfunction computes edges using edge thinning for portable code

coder.inline('always');
coder.internal.prefer_const(b,bx,by,kx,ky,offset,cutoff,e);

bx = abs(bx);
by = abs(by);

m = size(e,1);
n = size(e,2);

offset = coder.internal.indexInt(offset);

% compute the output image
if coder.isColumnMajor
    mIndexInt = coder.internal.indexInt(m);
    parfor c=1:coder.internal.indexInt(n)
        for r=1:mIndexInt
            % make sure that we don't go beyond the border

            if (r+offset(1) < 1) || (r+offset(1) > m) || ((c-1) < 1)
                b1 = true;
            else
                b1 = (b(r+offset(1),c-1) <= b(r,c));
            end

            if (r+offset(2) < 1) || (r+offset(2) > m) || ((c+1) > n)
                b2 = true;
            else
                b2 = (b(r,c) > b(r+offset(2),c+1));
            end

            if (c+offset(3) < 1) || (c+offset(3) > n) || ((r-1) < 1)
                b3 = true;
            else
                b3 = (b(r-1,c+offset(3)) <= b(r,c));
            end

            if (c+offset(4) < 1) || (c+offset(4) > n) || ((r+1) > m)
                b4 = true;
            else
                b4 = (b(r,c) > b(r+1,c+offset(4)));
            end

            e(r,c) = (b(r,c)>cutoff) & ...
                (((bx(r,c) >= (kx*by(r,c)-eps*100)) & b1 & b2) | ...
                ((by(r,c) >= (ky*bx(r,c)-eps*100)) & b3 & b4 ));
        end
    end
else
    nIndexInt = coder.internal.indexInt(n);
    parfor r=1:coder.internal.indexInt(m)
        for c=1:nIndexInt
            % make sure that we don't go beyond the border

            if (r+offset(1) < 1) || (r+offset(1) > m) || ((c-1) < 1)
                b1 = true;
            else
                b1 = (b(r+offset(1),c-1) <= b(r,c));
            end

            if (r+offset(2) < 1) || (r+offset(2) > m) || ((c+1) > n)
                b2 = true;
            else
                b2 = (b(r,c) > b(r+offset(2),c+1));
            end

            if (c+offset(3) < 1) || (c+offset(3) > n) || ((r-1) < 1)
                b3 = true;
            else
                b3 = (b(r-1,c+offset(3)) <= b(r,c));
            end

            if (c+offset(4) < 1) || (c+offset(4) > n) || ((r+1) > m)
                b4 = true;
            else
                b4 = (b(r,c) > b(r+1,c+offset(4)));
            end

            e(r,c) = (b(r,c)>cutoff) & ...
                (((bx(r,c) >= (kx*by(r,c)-eps*100)) & b1 & b2) | ...
                ((by(r,c) >= (ky*bx(r,c)-eps*100)) & b3 & b4 ));
        end
    end
end

function e = computeEdgesWithThinningLibrary(b,bx,by,kx,ky,offset,cutoff,e)
% This subfunction computes edges using edge thinning using a shared
% library

coder.inline('always');
coder.internal.prefer_const(b,bx,by,kx,ky,offset,cutoff,e);

sz     = size(b);
epsval = 100*eps;

fcnName = ['edgethinning_',images.internal.coder.getCtype(b),'_tbb'];
e = images.internal.coder.buildable.EdgeThinningTbbBuildable.edgethinning_tbb(...
    fcnName,...
    b,...
    bx,...
    by,...
    kx,...
    ky,...
    offset,...
    epsval,...
    cutoff,...
    e,...
    sz);


function [bx, by, b] = computeEdgeSobelPrewittLibrary(a,isSobel,kx,ky)
% This subfunction computes sobel and prewitt edges using a shared
% library

coder.inline('always');

sz     = size(a);

if isfloat(a)
    bx = coder.nullcopy(zeros(sz,'like', a));
    by = coder.nullcopy(zeros(sz,'like', a));
    b  = coder.nullcopy(zeros(sz,'like', a));
else
    bx = coder.nullcopy(zeros(sz,'single'));
    by = coder.nullcopy(zeros(sz,'single'));
    b  = coder.nullcopy(zeros(sz,'single'));
end

fcnName = ['edgesobelprewitt_',images.internal.coder.getCtype(a),'_tbb'];
[bx, by, b] = images.internal.coder.buildable.EdgeSobelPrewittTbbBuildable.edgesobelprewitt_tbb(...
    fcnName,...
    a,...
    sz,...
    isSobel,...
    kx,...
    ky,...
    bx,...
    by,...
    b);


function [bx, by, b] = computeEdgeSobelPrewittPortable(a,isSobel,kx,ky)
% This subfunction computes sobel and prewitt edges which is used for
% portable code generation

coder.inline('always');

if isSobel
    op = fspecial('sobel')/8; % Sobel approximation to derivative
else
    op = fspecial('prewitt')/6; % Prewitt approximation to derivative
end
x_mask = op'; % gradient in the X direction
y_mask = op;
x_mask = rot90(x_mask,2); % convMode = 0
y_mask = rot90(y_mask,2);
coder.const(x_mask); coder.const(y_mask);

% obtain the build configurations passed by user
buildConfig = coder.internal.get_eml_option('CodegenBuildContext');
crl = coder.const(@feval,'getConfigProp',buildConfig, 'CodeReplacementLibrary');
% check if the CRL table is selected for Intel SIMD
isIntelSIMD = ~isempty(crl) && (contains(crl, 'Intel SSE') || contains(crl,'Intel AVX'));

% if (isIntelSIMD == True): use SIMD-enabled path
% if (isIntelSIMD == False): use conv2
if (isIntelSIMD && all(size(a)>=3,'all'))
    % compute the gradient in x and y direction (SIMD code path)
    [bx, by] = edgeSobelPrewittSIMD(a, x_mask, y_mask);
else
    % compute the gradient in x and y direction
    a = padarray(a,[1 1],'replicate','both');
    bx = conv2(a, x_mask, 'valid');
    by = conv2(a, y_mask, 'valid');
end
% compute the magnitude
b = kx*bx.*bx + ky*by.*by;

function [bx, by] = edgeSobelPrewittSIMD(a,x_mask, y_mask)
% SIMD-friendly implementation to perform separable filtering
% in order to compute the gradient in x and y directions
coder.inline('always');

[xCol,xRow]=separate2DKernel(x_mask);
xCol = flip(xCol);
xRow = flip(xRow);
coder.const(xRow); coder.const(xCol);
[yCol,yRow]=separate2DKernel(y_mask);
yCol = flip(yCol);
yRow = flip(yRow);
coder.const(yRow); coder.const(yCol);

if coder.isColumnMajor
    % compute the gradient in x and y direction
    bx = conv3x3SameRepl(a, xCol, xRow);
    by = conv3x3SameRepl(a, yCol, yRow);
else % rowMajor
    % compute the gradient in x and y direction
    bx = conv3x3SameRepl_rowMajor(a, xCol, xRow);
    by = conv3x3SameRepl_rowMajor(a, yCol, yRow);
end
% % % % %
% The above calls to 'conv3x3SameReplicate()' are equivalent to the following:
% a = padarray(a,[1 1],'replicate','both');
% bx = conv2(xCol, xRow, a, 'valid');
% by = conv2(yCol, yRow, a, 'valid');
% % % % %

function outImg = conv3x3SameRepl(inImg, hCol, hRow)
% This function implements 2-D convolution for an input image with the separable filter components (hCol, hRow)
% a 2-D convolution operation is separated into two 1-D filters
% padding method = 'Replicate', padding will be performed on the fly
% output size = 'same'
% This SIMD-friendly implementation is optimized for column major
coder.inline('always');

nRows=size(inImg,1);
nCols=size(inImg,2);

temp = coder.nullcopy(zeros(nRows,nCols,'like',inImg));
outImg = coder.nullcopy(zeros(nRows,nCols,'like',inImg));

% process hRow convolution
% process the first and last column
temp(:,1)= inImg(:,1)*hRow(1) + inImg(:,1)*hRow(2)+ inImg(:,1+1)*hRow(3);
temp(:,nCols)=inImg(:,nCols-1)*hRow(1) + inImg(:,nCols)*hRow(2)+ inImg(:,nCols)*hRow(3);
% process intermediate columns
for ix=2:nCols-1
    temp(:,ix)=inImg(:,ix-1)*hRow(1) + inImg(:,ix)*hRow(2)+ inImg(:,ix+1)*hRow(3);
end
% process hCol convolution
for ix=1:nCols
    % process element 'ix' in intermediate rows
    outImg(2:nRows-1,ix)=temp(1:nRows-2,ix)*hCol(1) + temp(2:nRows-1,ix)*hCol(2)+ temp(3:nRows,ix)*hCol(3);
    % process element 'ix' in the first row
    outImg(1,ix)=temp(1,ix)*hCol(1) + temp(1,ix)*hCol(2)+ temp(1+1,ix)*hCol(3);
    % process element 'ix' in the last row
    outImg(nRows,ix)=temp(nRows-1,ix)*hCol(1) + temp(nRows,ix)*hCol(2)+ temp(nRows,ix)*hCol(3);
end

function outImg = conv3x3SameRepl_rowMajor(inImg, hCol, hRow)
% This function implements 2-D convolution for an input image with the separable filter components (hCol, hRow)
% a 2-D convolution operation is separated into two 1-D filters
% padding method = 'Replicate', padding will be performed on the fly
% output size = 'same'
% This SIMD-friendly implementation is optimized for row major
coder.inline('always');

nRows=size(inImg,1);
nCols=size(inImg,2);

temp = coder.nullcopy(zeros(nRows,nCols,'like',inImg));
outImg = coder.nullcopy(zeros(nRows,nCols,'like',inImg));

% process hRow convolution
% process the first and last row
temp(1,:)= inImg(1,:)*hCol(1) + inImg(1,:)*hCol(2)+ inImg(1+1,:)*hCol(3);
temp(nRows,:)=inImg(nRows-1,:)*hCol(1) + inImg(nRows,:)*hCol(2)+ inImg(nRows,:)*hCol(3);
% process intermediate rows
for ix=2:nRows-1
    temp(ix,:)=inImg(ix-1,:)*hCol(1) + inImg(ix,:)*hCol(2)+ inImg(ix+1,:)*hCol(3);
end
% process hCol convolution
for ix=1:nRows
    % process element 'ix' in intermediate columns
    outImg(ix, 2:nCols-1) = temp(ix, 1:nCols-2)*hRow(1) + temp(ix, 2:nCols-1)*hRow(2)+ temp(ix, 3:nCols)*hRow(3);
    outImg(ix,1) = temp(ix,1)*hRow(1) + temp(ix,1)*hRow(2)+ temp(ix,1+1)*hRow(3);
    outImg(ix,nCols) = temp(ix,nCols-1)*hRow(1) + temp(ix,nCols)*hRow(2)+ temp(ix,nCols)*hRow(3);
end

function [hcol, hrow] = separate2DKernel(h)
% Extract the components of an input k x k separable filter
% A separable filter can be written as product of two simple filters.
% h: k x k separable filter
% hcol, hrow: two 1-D filters

[u,s,v] = svd(h);
s = diag(s);
hcol = u(:,1) * sqrt(s(1));
hrow = v(:,1)' * sqrt(s(1));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Local Function : computeapproxcanny
%
function e = computeapproxcanny(a, thresh)
a = im2uint8(a);
if isempty(a)
    e = logical([]);
else
    if isempty(thresh)
        e = images.internal.coder.buildable.ApproxCannyBuildable.canny_uint8_ocv(a,single(-1),single(-1));
    else
        if numel(thresh) == 1
            e = images.internal.coder.buildable.ApproxCannyBuildable.canny_uint8_ocv(a, 0.4*thresh, thresh);
        else
            e = images.internal.coder.buildable.ApproxCannyBuildable.canny_uint8_ocv(a, thresh(2), thresh(1));
        end
    end
    e = logical(e);
end
