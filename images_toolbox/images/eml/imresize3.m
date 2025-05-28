function Bout = imresize3(Ain, varargin) %#codegen

%IMRESIZE3 Resize image.

% Copyright 2023 The MathWorks, Inc.

%#ok<*EMCA>

narginchk(2,inf);

coder.internal.prefer_const(varargin);

% Validate Input Image
validateattributes(Ain, {'single', ...
    'double', ...
    'int8', ...
    'int16', ...
    'int32', ...
    'uint8', ...
    'uint16', ...
    'uint32',...
    'logical'}, ...
    {'nonsparse', ...
    'nonempty'}, ...
    mfilename, 'A', 1);
convertToUint8 = islogical(Ain);
if convertToUint8
    A = uint8(255) .* uint8(Ain);
else
    A = Ain;
end

coder.internal.errorIf(ndims(Ain) ~= 3,...
    'images:imresize3:incorrectDimensions');

% Rest of the inputs
scaleOrSize = [1 1 1];
resizeSpecSpecified     = false;
isResizeSpecScale       = false;
isResizeSpecScalarScale = true;
% Number of times the resize spec is specifed, possible max of 4, codegen
% only supports 1
numResizeSpecSpecification = 0;

antialiasing           = true;
antialiasingThroughPV  = false;

methodStrings = {'nearest', ...
    'linear',...
    'trilinear',...
    'cubic',...
    'bicubic',...
    'tricubic', ...
    'box',...
    'triangle',...
    'lanczos2',...
    'lanczos3',...
    };

arg = varargin{1};
if isnumeric(arg) && isscalar(arg)
    % Argument looks like a scale factor.
    validateattributes(arg, {'numeric'}, {'nonzero', 'real'}, mfilename, ...
        'SCALE', 2);


elseif isnumeric(arg) && isvector(arg) && (numel(arg) == 3)
    % Argument looks like output_size.
    validateattributes(arg, {'numeric'}, {'vector', 'real', 'positive'}, ...
        mfilename, '[NUMROWS NUMCOLS NUMPLANES]', 2);
end

switch numel(varargin)
    case 1
        if(ischar(varargin{1}))
            % imresize(A, method)
            % Fail later with missing scale message
            method = varargin{1};
        else
            % imresize(A, scaleOrSize)
            resizeSpecSpecified = true;
            if(isscalar(varargin{1}))
                scaleOrSize(1) = double(varargin{1});
                isResizeSpecScale = true;
            else
                coder.internal.errorIf(numel(varargin{1})~=3,...
                    'images:imresize3:badOutputSize');
                scaleOrSize = double(varargin{1});
            end

            method = 'cubic';
            numResizeSpecSpecification = numResizeSpecSpecification+1;
        end

    case 2
        if(ischar(varargin{1}))
            % imresize(A, P, V)
            [antialiasing, antialiasingThroughPV, scaleOrSize, resizeSpecSpecified, isResizeSpecScale, isResizeSpecScalarScale, method, numResizeSpecSpecification] = ...
                parsePV(1, antialiasing, antialiasingThroughPV, scaleOrSize, resizeSpecSpecified, isResizeSpecScale, isResizeSpecScalarScale, numResizeSpecSpecification, varargin{:});

        else
            % imresize(A, scaleOrSize, method)
            resizeSpecSpecified = true;
            if(isscalar(varargin{1}))
                scaleOrSize(1) = double(varargin{1});
                isResizeSpecScale = true;
            else
                coder.internal.errorIf(numel(varargin{1})~=3,...
                    'images:imresize3:badOutputSize');
                scaleOrSize = double(varargin{1});
            end

            coder.internal.errorIf(~coder.internal.isConst(varargin{2}), ...
                'MATLAB:images:validate:codegenInputNotConst', 'METHOD',...
                'IfNotConst','Fail');
            method = varargin{2};
            numResizeSpecSpecification = numResizeSpecSpecification+1;
        end

    otherwise
        % 3 additional args and up

        if(isnumeric(varargin{1}))
            % imresize(A, scaleSize,  ...)
            resizeSpecSpecified = true;
            numResizeSpecSpecification = numResizeSpecSpecification+1;
            if(isscalar(varargin{1}))
                scaleOrSize(1) = double(varargin{1});
                isResizeSpecScale = true;
            else
                coder.internal.errorIf(numel(varargin{1})~=3,...
                    'images:imresize3:badOutputSize');
                scaleOrSize = double(varargin{1});
            end

            if(isMethodString(varargin{2}))
                % imresize(A, scaleSize, method, {PVs, ...})
                method = varargin{2};
                coder.internal.errorIf(~coder.internal.isConst(varargin{2}), ...
                    'MATLAB:images:validate:codegenInputNotConst', 'METHOD',...
                    'IfNotConst','Fail');

                if(numel(varargin)>2)
                    % PV
                    [antialiasing, antialiasingThroughPV, scaleOrSize, resizeSpecSpecified, isResizeSpecScale,isResizeSpecScalarScale, ~, numResizeSpecSpecification] = ...
                        parsePV(3, antialiasing, antialiasingThroughPV, scaleOrSize, resizeSpecSpecified, isResizeSpecScale,isResizeSpecScalarScale, numResizeSpecSpecification,varargin{:});
                end
            else
                % imresize(A, scaleSize, {PVs,...})
                [antialiasing, antialiasingThroughPV, scaleOrSize, resizeSpecSpecified, isResizeSpecScale,isResizeSpecScalarScale, method, numResizeSpecSpecification] = ...
                    parsePV(2, antialiasing, antialiasingThroughPV, scaleOrSize, resizeSpecSpecified, isResizeSpecScale,isResizeSpecScalarScale,numResizeSpecSpecification, varargin{:});
            end
        else
            % imresize(A, PVs,...)
            [antialiasing, antialiasingThroughPV, scaleOrSize, resizeSpecSpecified, isResizeSpecScale,isResizeSpecScalarScale, method, numResizeSpecSpecification] = ...
                parsePV( 1, antialiasing, antialiasingThroughPV, scaleOrSize, resizeSpecSpecified, isResizeSpecScale, isResizeSpecScalarScale, numResizeSpecSpecification, varargin{:});
        end

end
coder.internal.errorIf(numResizeSpecSpecification>1,...
    'MATLAB:images:imresize:tooManyOutputSizeSpecificationsForCodegen');

% Convert method to function handle
method = validatestring(method, methodStrings, mfilename);

switch(method)
    case 'nearest'
        kernel = 'box';
        kwidth = 1.0;
        if(~antialiasingThroughPV)
            antialiasing = false;
        end
    case 'box'
        kernel = 'box';
        kwidth = 1.0;
        if(~antialiasingThroughPV)
            antialiasing = true;
        end
    case {'linear', 'triangle', 'trilinear'}
        kernel = 'tri';
        kwidth = 2.0;
        if(~antialiasingThroughPV)
            antialiasing = true;
        end
    case {'cubic', 'bicubic', 'tricubic'}
        kernel = 'cub';
        kwidth = 4.0;
        if(~antialiasingThroughPV)
            antialiasing = true;
        end
    case 'lanczos2'
        kernel = 'la2';
        kwidth = 4.0;
        if(~antialiasingThroughPV)
            antialiasing = true;
        end
    case 'lanczos3'
        kernel = 'la3';
        kwidth = 6.0;
        if(~antialiasingThroughPV)
            antialiasing = true;
        end
    otherwise
        assert(false, 'Unsupported method');
        kernel = 'cub';
        kwidth = 4.0;
        if(~antialiasingThroughPV)
            antialiasing = true;
        end
end

coder.internal.errorIf(~((isnumeric(antialiasing) || islogical(antialiasing)) && isscalar(antialiasing)),...
    'MATLAB:images:imresize:badAntialiasing');

% Find required scale
coder.internal.errorIf(resizeSpecSpecified == false,...
    'MATLAB:images:imresize:missingScaleAndSize');

coder.internal.prefer_const(scaleOrSize);

outputSize_ = size(A);
outputSize  = outputSize_(1:3);

if(isResizeSpecScale && isResizeSpecScalarScale)
    validateattributes(scaleOrSize(1), {'numeric'}, {'nonzero', 'positive','real'},...
        mfilename, 'SCALE');
    scale = [scaleOrSize(1), scaleOrSize(1),scaleOrSize(1)];
    outputSize = ceil(outputSize.*scale);
elseif(isResizeSpecScale && ~isResizeSpecScalarScale)
    scale = [scaleOrSize(1), scaleOrSize(2),scaleOrSize(3)];
    coder.internal.errorIf(~isnumeric(scale) || (isscalar(scale)) || ~all(scale(:)>0),...
        'images:imresize3:invalidScale');
    outputSize = ceil(outputSize.*scale);
else
    % Not scale, but output size
    coder.internal.errorIf(...
        ~isnumeric(scaleOrSize)|| numel(scaleOrSize)~=3 ...
        || all(isnan(scaleOrSize(:))) || any(scaleOrSize(:)<=0),...
        'images:imresize3:badOutputSize');


    coder.internal.errorIf(all(isnan(scaleOrSize(:))),...
        'images:imresize3:allNaN');

    % Convert output size to scale factor
    outputSize = scaleOrSize;
    if isnan(outputSize (1)) && isnan(outputSize (2))
        outputSize (1) = outputSize (3) * size(A, 1) / size(A, 3);
        outputSize (2) = outputSize (3) * size(A, 2) / size(A, 3);
        outputSize = ceil(outputSize);
        scale = [outputSize(3)/size(A,3), outputSize(3)/size(A,3), outputSize(3)/size(A,3)];
    elseif isnan(outputSize(1)) && isnan(outputSize (3))
        outputSize(1) = outputSize (2) * size(A, 1) / size(A, 2);
        outputSize (3) = outputSize (2) * size(A, 3) / size(A, 2);
        outputSize = ceil(outputSize);
        scale = [outputSize(2)/size(A,2), outputSize(2)/size(A,2), outputSize(2)/size(A,2)];
    elseif isnan(outputSize(2)) && isnan(outputSize (3))
        outputSize(2) = outputSize (1) * size(A, 2) / size(A, 1);
        outputSize (3) = outputSize (1) * size(A, 3) / size(A, 1);
        outputSize = ceil(outputSize);
        scale = [outputSize(1)/size(A,1), outputSize(1)/size(A,1), outputSize(1)/size(A,1)];
    elseif any(isnan(outputSize))
        coder.internal.errorIf(any(isnan(outputSize)),...
            'images:imresize3:invalidOutputSize');
        scale = outputSize(1:3)./([size(A,1), size(A,2), size(A,3)]);
    else
        outputSize = ceil(outputSize);
        scale = outputSize(1:3)./([size(A,1), size(A,2), size(A,3)]);
    end
end


coder.internal.prefer_const(scale);
coder.internal.prefer_const(outputSize);


% MLC implementation.
% Resize the smaller scale first. Split into if/else to ensure constant
% folding of output size.

if scale(1) <= scale(2) && scale(1) <= scale(3)
    %> Resize first dimension
    dim = 1;
    [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)), outputSize(dim), ...
        scale(dim), kernel, ...
        kwidth, antialiasing);
    APartialResize = resizeAlongDim(A, dim, weights, indices);

    if scale(2) <= scale(3)

        dim = 2;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        BPartialResize = resizeAlongDim(APartialResize, dim, weights, indices);

        dim = 3;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        B = resizeAlongDim(BPartialResize, dim, weights, indices);

    else
        dim = 3;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        BPartialResize = resizeAlongDim(APartialResize, dim, weights, indices);

        dim = 2;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        B = resizeAlongDim(BPartialResize, dim, weights, indices);
    end

elseif scale(2) <= scale(1) && scale(2) <= scale(3)
    dim = 2;
    [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)), outputSize(dim), ...
        scale(dim), kernel, ...
        kwidth, antialiasing);
    APartialResize = resizeAlongDim(A, dim, weights, indices);

    if scale(1) <= scale(3)
        dim = 1;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        BPartialResize = resizeAlongDim(APartialResize, dim, weights, indices);

        dim = 3;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        B = resizeAlongDim(BPartialResize, dim, weights, indices);

    else
        dim = 3;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        BPartialResize = resizeAlongDim(APartialResize, dim, weights, indices);

        dim = 1;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        B = resizeAlongDim(BPartialResize, dim, weights, indices);
    end
else
    dim = 3;
    [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)), outputSize(dim), ...
        scale(dim), kernel, ...
        kwidth, antialiasing);
    APartialResize = resizeAlongDim(A, dim, weights, indices);

    if scale(1) <= scale(2)
        dim = 1;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        BPartialResize = resizeAlongDim(APartialResize, dim, weights, indices);

        dim = 2;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        B = resizeAlongDim(BPartialResize, dim, weights, indices);

    else
        dim = 2;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        BPartialResize = resizeAlongDim(APartialResize, dim, weights, indices);

        dim = 1;
        [weights, indices] = contributions(coder.internal.indexInt(size(A, dim)),outputSize(dim),  ...
            scale(dim), kernel, ...
            kwidth, antialiasing);
        B = resizeAlongDim(BPartialResize, dim, weights, indices);
    end

end

if convertToUint8
    Bout = B > 128;
else
    Bout = B;
end

%==========================================================================
% This function resizes the images dimension wise
%==========================================================================
function outPut = resizeAlongDim(in_, dim, weights, indices)
% Resize along a specified dimension
%
% in           - input array to be resized
% dim          - dimension along which to resize
% weights      - weight matrix; row k is weights for k-th output pixel
% indices      - indices matrix; row k is indices for k-th output pixel

outLength = size(weights, 2);
coder.internal.prefer_const(outLength);

if dim == 3
    isThirdDimResize = true;
else
    isThirdDimResize = false;
end

if isThirdDimResize
    in = permuteLocal(in_);
    dim = 1;
else
    in = in_;
end

outSize = size(in);
outSize(dim) = outLength;
out = coder.nullcopy(zeros(outSize,'like', in));
out_ = resizeAlongDim2D(in, dim, weights, indices, outLength, out);

if isThirdDimResize
    outPut = permuteLocal(out_);
else
    outPut = out_;
end

%==========================================================================
function out = resizeAlongDim2D(in, dim, weights, indices, outLength, out)
coder.inline('always');
% The 'out' will be uint8 if 'in' is logical
% Otherwise 'out' datatype will be same as 'in' datatype

if(dim==1)

    parfor inCInd = 1:numel(in)/size(in,1) % input columns.
        inCol = in(:, inCInd);
        for outRInd = 1:outLength % output rows
            if(isreal(in)) %#ok<PFBNS>
                sumVal1 = 0.0;
            else
                sumVal1 = 0.0+0.0i;
            end
            linearInds = coder.internal.indexInt(sub2ind(size(weights),1, outRInd));
            %> Core - first dimension
            for k = 1:size(weights,1)
                sumVal1 = sumVal1 + weights(linearInds) * double(inCol(indices(linearInds))); %#ok<PFBNS>
                linearInds = coder.internal.indexPlus(linearInds,1);
            end

            out(outRInd, inCInd) = saturatingCast(sumVal1,class(in));
        end
    end

else

    for pInd = 1: size(in,3) % planes
        parfor inRInd = 1:size(in,1) % input rows.
            rowStart = sub2ind(size(in),inRInd,1, pInd);
            for outCInd = 1:outLength
                if(isreal(in))
                    sumVal1 = 0.0;
                else
                    sumVal1 = 0.0+0.0i;
                end

                %> Core - second dimension
                linearInds = coder.internal.indexInt(sub2ind(size(weights),1, outCInd));
                for k = 1:size(weights,1)
                    pixelIndex = coder.internal.indexPlus( rowStart,...
                        coder.internal.indexTimes(...
                        coder.internal.indexMinus(indices(linearInds),1),...
                        size(in,1))); %#ok<PFBNS>
                    pixelValue = in(pixelIndex);
                    sumVal1 = sumVal1 + weights(linearInds) * double(pixelValue);
                    linearInds = linearInds +1;
                end

                out(inRInd, outCInd, pInd) = saturatingCast(sumVal1,class(in));
            end
        end
    end
end

%==========================================================================
function [weights, indices] = contributions(inLength,outLength, ...
    scale, kernel, kernel_width, antialiasing)

coder.internal.prefer_const(outLength);

%> Contributions, using pixel indices

if (scale < 1) && (antialiasing)
    % Use a modified kernel to simultaneously interpolate and
    % antialias.
    kernel_width = kernel_width / scale;
end

% Output-space coordinates.
x = (1:outLength)';

% Input-space coordinates. Calculate the inverse mapping such that 0.5
% in output space maps to 0.5 in input space, and 0.5+scale in output
% space maps to 1.5 in input space.
u = x/scale + 0.5 * (1 - 1/scale);

% What is the left-most pixel that can be involved in the computation?
left = coder.internal.indexInt(floor(u - kernel_width/2));

% What is the maximum number of pixels that can be involved in the
% computation?  Note: it's OK to use an extra pixel here; if the
% corresponding weights are all zero, it will be eliminated at the end
% of this function.
P = coder.internal.indexInt(ceil(kernel_width) + 2);

% The indices of the input pixels involved in computing the k-th output
% pixel are in row k of the indices matrix.
indices = bsxfun(@coder.internal.indexPlus, left, 0:P-1);

% The weights used to compute the k-th output pixel are in row k of the
% weights matrix.
weights = kernelWrapper(bsxfun(@minus, u, double(indices)),kernel, scale, antialiasing);

% Normalize the weights matrix so that each row sums to 1.
weights = weights./sum(weights, 2);

% Mirror out-of-bounds indices; equivalent of doing symmetric padding

%> Create the auxiliary matrix:
% aux = [1:inLength,inLength:-1:1];

% inLength is assumed to be indexInt
auxLength = coder.internal.indexTimes(inLength,2);

% Allocate space without initializing
aux = coder.nullcopy(coder.internal.indexInt(zeros(1,auxLength)));

% Fill values
aux(1) = coder.internal.indexInt(1);
aux(inLength+1) = inLength;

for i = 2:inLength
    aux(i) = aux(i-1) + 1;
    aux(inLength+i) = aux(inLength+i-1) - 1;
end

%> Mirror the out-of-bounds indices using mod:
% tmp = mod(double(indices)-1,length(aux));
% indices = aux(coder.internal.indexPlus(tmp,1));

for i = 1:numel(indices)
    oldIdx = double(indices(i));
    % use mod only with two doubles. using indexInt will segv.
    k = mod(oldIdx-1,double(auxLength));
    indices(i) = aux(coder.internal.indexPlus(k,1));
end


% Alternatively, copy non-zero columns
copyCols = any(weights, 1);
weightsNonZeroCols = weights(:, copyCols);
indicesNonZeroCols = indices(:, copyCols);

% Transpose to allow for cache friendly access in the core resizer
weights = weightsNonZeroCols';
indices = indicesNonZeroCols';

%==========================================================================
function xout = kernelWrapper(xin, kernel, scale, antialiasing)

coder.inline('always');
coder.noImplicitExpansionInFunction; % for same-size operations on absx2 and x
% each call clearly has same-size operands

if (scale < 1) && (antialiasing)
    % Use a modified kernel to simultaneously interpolate and
    % antialias.
    x = scale * xin;
else
    x = xin;
end

switch kernel
    case 'cub'
        % See Keys, "Cubic Convolution Interpolation for Digital Image
        % Processing," IEEE Transactions on Acoustics, Speech, and Signal
        % Processing, Vol. ASSP-29, No. 6, December 1981, p. 1155.

        absx = abs(x);
        absx2 = absx.^2;
        absx3 = absx.^3;

        f = (1.5*absx3 - 2.5*absx2 + 1) .* (absx <= 1) + ...
            (-0.5*absx3 + 2.5*absx2 - 4*absx + 2) .* ...
            ((1 < absx) & (absx <= 2));
    case 'box'
        f = double((-0.5 <= x) & (x < 0.5));
    case 'tri'
        f = (x+1) .* ((-1 <= x) & (x < 0)) + (1-x) .* ((0 <= x) & (x <= 1));
    case 'la2'
        % See Graphics Gems, Andrew S. Glasser (ed), Morgan Kaufman, 1990,
        % pp. 156-157.
        f = (sin(pi*x) .* sin(pi*x/2) + eps) ./ ((pi^2 * x.^2 / 2) + eps);
        f = f .* (abs(x) < 2);
    case 'la3'
        % See Graphics Gems, Andrew S. Glasser (ed), Morgan Kaufman, 1990,
        % pp. 157-158.
        f = (sin(pi*x) .* sin(pi*x/3) + eps) ./ ((pi^2 * x.^2 / 3) + eps);
        f = f .* (abs(x) < 3);

    otherwise
        assert(false, 'Unsupported method');
        f=x;
end

if (scale < 1) && (antialiasing)
    % Use a modified kernel to simultaneously interpolate and
    % antialias.
    xout = scale * f;
else
    xout = f;
end

%==========================================================================
function [antialiasing, antialiasingThroughPV, scaleOrSize,resizeSpecSpecified, isResizeSpecScale, isResizeSpecScalarScale, method, numResizeSpecSpecification] = ...
    parsePV(startInd, antialiasing, antialiasingThroughPV, scaleOrSize, resizeSpecSpecified, isResizeSpecScale, isResizeSpecScalarScale, numResizeSpecSpecification, varargin)

coder.inline('always');
% Parse all PV's
coder.internal.errorIf(mod(numel(varargin)-startInd+1,2)~=0,...
    'images:imresize3:oddNumberArgs');

paramStrings = {...
    'Antialiasing',...
    'Method',...
    'OutputSize',...
    'Scale'};

methodStrings = {'nearest', ...
    'linear',...
    'trilinear',...
    'cubic',...
    'bicubic',...
    'tricubic',...
    'box',...
    'triangle',...
    'lanczos2',...
    'lanczos3'};
methodIdx = 0;
coder.unroll;
for ind=startInd:2:numel(varargin)
    coder.internal.errorIf(~coder.internal.isConst(varargin{ind}), ...
        'MATLAB:images:validate:codegenInputNotConst', 'PARAMETER',...
        'IfNotConst','Fail');

    paramString =  validatestring(varargin{ind}, paramStrings, mfilename);
    switch(paramString)
        case 'Antialiasing'
            coder.internal.errorIf(~coder.internal.isConst(varargin{ind+1}), ...
                'MATLAB:images:validate:codegenInputNotConst', 'ANTIALIASING',...
                'IfNotConst','Fail');
            antialiasingThroughPV = true;
            validateattributes(varargin{ind+1}, {'logical'}, {'scalar'},...
                mfilename, 'ANTIALIASING');
            antialiasing = varargin{ind+1};
        case 'Scale'
            coder.internal.errorIf(~coder.internal.isConst(varargin{ind+1}), ...
                'MATLAB:images:validate:codegenInputNotConst', 'SCALE',...
                'IfNotConst','Fail');
            % This value could be in the form [scalex, scaley, scalez]
            validateattributes(varargin{ind+1}, {'numeric'}, {'nonzero', 'real'},...
                mfilename, 'SCALE');
            resizeSpecSpecified = true;
            isResizeSpecScale = true;

            coder.internal.errorIf(~(isscalar(varargin{ind+1}) || numel(varargin{ind+1})==3),...
                'images:imresize3:invalidScale');

            if(isscalar(varargin{ind+1}))
                scaleOrSize(1) = double(varargin{ind+1});
                isResizeSpecScalarScale = true;
            else
                scaleOrSize = double(varargin{ind+1});
                isResizeSpecScalarScale = false;
            end
            numResizeSpecSpecification = numResizeSpecSpecification + 1;
        case 'OutputSize'
            coder.internal.errorIf(~coder.internal.isConst(varargin{ind+1}), ...
                'MATLAB:images:validate:codegenInputNotConst', 'OUTPUTSIZE',...
                'IfNotConst','Fail');
            coder.internal.prefer_const(varargin{ind+1});
            validateattributes(varargin{ind+1}, {'numeric'}, {'nonzero', 'real'},...
                mfilename, 'OUTPUTSIZE');
            coder.internal.errorIf(numel(varargin{ind+1})~=3,...
                'images:imresize3:badOutputSize');
            scaleOrSize = double(varargin{ind+1});
            coder.internal.errorIf(all(isnan(scaleOrSize(:))),...
                'images:imresize3:allNaN');
            resizeSpecSpecified = true;
            numResizeSpecSpecification = numResizeSpecSpecification + 1;
        case 'Method'
            coder.internal.errorIf(~coder.internal.isConst(varargin{ind+1}), ...
                'MATLAB:images:validate:codegenInputNotConst', 'METHOD',...
                'IfNotConst','Fail');
            % The method can be specified more than once,
            % but all method inputs must be validated.
            validatestring(varargin{ind+1}, methodStrings, mfilename);
            methodIdx = ind + 1;
        otherwise
            % numResizeSpecSpecification doesn't change
    end
end
if methodIdx >= 1
    method = validatestring(varargin{methodIdx}, methodStrings, mfilename);
else
    method = 'bicubic';
end

%==========================================================================
function tf = isMethodString(methodStr)
coder.inline('always');
tf = strncmpi(methodStr,'nearest', numel(methodStr))...
    ||strncmpi(methodStr,'linear',numel(methodStr))...
    ||strncmpi(methodStr,'cubic',numel(methodStr))...
    ||strncmpi(methodStr,'bicubic',numel(methodStr))...
    ||strncmpi(methodStr,'box',numel(methodStr))...
    ||strncmpi(methodStr,'triangle',numel(methodStr))...
    ||strncmpi(methodStr,'tricubic',numel(methodStr))...
    ||strncmpi(methodStr,'lanczos2',numel(methodStr))...
    ||strncmpi(methodStr,'lanczos3',numel(methodStr));

%==========================================================================
function y = saturatingCast(x,cls)
% Workaround g2532769. This is necessary currently to avoid overflow
% warnings from being issued when imresize is used in a function block
% context. This can be removed if/when geck is actioned.
coder.inline('always');
coder.internal.prefer_const(cls);

if coder.internal.isIntegerClass(cls) && isreal(x)
    if x > intmax(cls)
        y = intmax(cls);
    elseif x < intmin(cls)
        y = intmin(cls);
    else
        y = eml_cast(x,cls,'nearest','spill');
    end
else
    y = cast(x,cls);
end

%==========================================================================
% Local Permute Function to address the performance issue and uses array as
% an input Geck g3149468 is raised and assigned to coder team to look into
% the performance issue

function b = permuteLocal(inBuff)
coder.inline('always');
coder.internal.prefer_const(inBuff);
rows = size(inBuff,3);
cols = size(inBuff,2);
planes = size(inBuff,1);
b = coder.nullcopy(zeros(rows,cols,planes,'like',inBuff));
parfor i = 1:rows
    for j = 1:cols
        for k = 1:planes
            b(i,j,k) = inBuff(k,j,i);
        end
    end
end