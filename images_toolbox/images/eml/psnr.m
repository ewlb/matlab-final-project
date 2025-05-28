function [peaksnr,snr] = psnr(A,ref,varargin) %#codegen

% Copyright 2015-2020 The MathWorks, Inc.

%#ok<*EMCA>

narginchk(2,5);

checkImages(A,ref);

if (nargin < 3)
    peakval = diff(getrangefromclass(A));
    format = parsePVPairs(numel(size(A)),varargin{2:end});
elseif ~isnumeric(varargin{1})
    peakval = diff(getrangefromclass(A));
    format = parsePVPairs(numel(size(A)),varargin{:});
else
    checkPeakval(varargin{1},A);
    peakval = double(varargin{1});
    format = parsePVPairs(numel(size(A)),varargin{2:end});
end

[validChars, validCounts] = images.internal.qualitymetric.isValidDataFormat(format);
coder.internal.errorIf(~validChars,'images:qualitymetric:InvalidDimLabel');
coder.internal.errorIf(~validCounts,'images:qualitymetric:RepeatedDimLabels');

perm = images.internal.qualitymetric.permuteFormattedDims(A,format);
hasBatchDim = ~isempty(find(format == 'B',1));

needToPermute = ~isequal(perm,1:ndims(A));

if ~hasBatchDim
   dimsToReduce = 'all'; 
else
   dimsToReduce = 1:length(size(A))-1;
end

if isa(ref,'single')
    % if the input is single, return a single
    classToUse = 'single';
else
    % otherwise, do the computation in double precision
    classToUse = 'double';
end

if isempty(A) % If A is empty, ref must also be empty
    peaksnr = cast([],classToUse);
    snr     = cast([],classToUse);
    return;
end

if nargout > 1 && ~hasBatchDim
    % for better performance, do only one pass through the data and compute
    % the MSE and the mean square simultaneously, instead of calling immse
    meanSquareError = cast(0,classToUse);
    meanSquare = cast(0,classToUse);
    
    numElems = numel(A);
    if coder.isColumnMajor
        for i = 1:numElems
            % pixel values in input images
            val    = cast(A(i),classToUse);
            refVal = cast(ref(i),classToUse);
            % compute the mean square error between A and the reference image
            meanSquareError = meanSquareError + (val-refVal)*(val-refVal);
            % compute mean square of the reference image
            meanSquare = meanSquare + refVal*refVal;
        end
    else % Row-major
        if numel(size(A)) == 2
            for i = 1:size(A,1)
                for j = 1:size(A,2)
                    % pixel values in input images
                    val    = cast(A(i,j),classToUse);
                    refVal = cast(ref(i,j),classToUse);
                    % compute the mean square error between A and the reference image
                    meanSquareError = meanSquareError + (val-refVal)*(val-refVal);
                    % compute mean square of the reference image
                    meanSquare = meanSquare + refVal*refVal;
                end
            end
        elseif numel(size(A)) == 3
            for i = 1:size(A,1)
                for j = 1:size(A,2)
                    for k = 1:size(A,3)
                        % pixel values in input images
                        val    = cast(A(i,j,k),classToUse);
                        refVal = cast(ref(i,j,k),classToUse);
                        % compute the mean square error between A and the reference image
                        meanSquareError = meanSquareError + (val-refVal)*(val-refVal);
                        % compute mean square of the reference image
                        meanSquare = meanSquare + refVal*refVal;
                    end
                end
            end
        else
            for i = 1:numElems
                % pixel values in input images
                val    = cast(A(i),classToUse);
                refVal = cast(ref(i),classToUse);
                % compute the mean square error between A and the reference image
                meanSquareError = meanSquareError + (val-refVal)*(val-refVal);
                % compute mean square of the reference image
                meanSquare = meanSquare + refVal*refVal;
            end
        end
    end
    meanSquareError = meanSquareError / cast(numElems,classToUse);
    meanSquare      = meanSquare / cast(numElems,classToUse);
    
    snr = 10*log10(meanSquare/meanSquareError);
else    
    
    % Only this codepath is used for calls with batch dim, so only manage
    % permutation in this branch of conditional for now to avoid paying for
    % for the [a,b] = psnr(___); syntax without batch DataFormat.
    
    if needToPermute
        A_p = permute(A,perm);
        ref_p = permute(ref,perm);
    else
        A_p = A;
        ref_p = ref;
    end
    
    if isinteger(A_p)
        A_f = double(A_p);
        ref_f = double(ref_p);
    else
        A_f = A_p;
        ref_f = ref_p;
    end
    
    sizeA = size(A);
    
    if hasBatchDim
        numElements = prod(sizeA(dimsToReduce));
    else
        numElements = prod(sizeA);
    end
    
    meanSquareError = sum((A_f-ref_f).^2,dimsToReduce) ./ numElements;
    
    if nargout > 1
        tempSNR = 10*log10(mean(ref_f.^2,dimsToReduce)./meanSquareError);
        if needToPermute
            snr = ipermute(tempSNR,perm);
        else
            snr = tempSNR;
        end
    end    
end

tempPSNR = 10*log10( (peakval*peakval) ./ meanSquareError);
if needToPermute
    peaksnr = ipermute(tempPSNR,perm);
else
    peaksnr = tempPSNR;
end

end

function checkImages(A, ref)

validImageTypes = {'uint8','uint16','int16','single','double'};

validateattributes(A,validImageTypes,{'nonsparse','real'},mfilename,'A',1);
validateattributes(ref,validImageTypes,{'nonsparse','real'},mfilename,'REF',2);

% A and ref must be of the same class
coder.internal.errorIf(~isa(A,class(ref)),'images:validate:differentClassMatrices','A','REF');

% A and ref must have the same size
coder.internal.errorIf(~isequal(size(A),size(ref)),'images:validate:unequalSizeMatrices','A','REF');

end

function checkPeakval(peakval, A)

validateattributes(peakval,{'numeric'},{'nonnan', 'real', ...
    'nonnegative','nonsparse','nonempty','scalar'}, mfilename, ...
    'PEAKVAL',3);

if isinteger(A) && (peakval > diff(getrangefromclass(A)))
    coder.internal.warning('images:psnr:peakvalTooLarge','A','REF');
end

end

function format = parsePVPairs(numInputDims,varargin)

coder.internal.prefer_const(varargin{:});

% Default values
defaultFormat = repmat('S',1,numInputDims);

params = struct( ...
    'DataFormat',uint32(0));

options = struct( ...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

optarg = eml_parse_parameter_inputs(params,options,varargin{:});

format = eml_get_parameter_value( ...
    optarg.DataFormat, ...
    defaultFormat, ...
    varargin{:});

end