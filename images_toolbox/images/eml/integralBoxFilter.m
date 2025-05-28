function out = integralBoxFilter(intA, varargin) %#codegen
%INTEGRALBOXFILTER 2-D box filtering of integral images

%   Copyright 2015-2021 The MathWorks, Inc.

narginchk(1,4);

validateattributes(intA,{'double'}, ...
    {'real','nonsparse','nonempty'},mfilename,'Integral Image',1);

coder.internal.errorIf(any([size(intA,1),size(intA,2)] < 2), ...
    'images:integralBoxFilter:intImageTooSmall');

[normFactor,filterSize] = parseInputs(varargin{:});

% OutSize of Image = size(integralImage) - size(filter)
outSize = size(intA) - [filterSize(1:2),zeros(1,numel(size(intA))-2)];

out = coder.nullcopy(zeros(outSize,'like',intA));

nPlanes = coder.internal.prodsize(out,'above',2);

if coder.isColumnMajor()
    outSize1IndexInt = coder.internal.indexInt( outSize(1));
    outSize2IndexInt = coder.internal.indexInt( outSize(2));
    parfor p = 1:coder.internal.indexInt(nPlanes)
        for n = 1:outSize2IndexInt
            sC = n;
            eC = coder.internal.indexPlus(sC, coder.internal.indexInt(filterSize(2))); %#ok<PFBNS>
            for m = 1:outSize1IndexInt
                sR = m;
                eR = coder.internal.indexPlus(sR, coder.internal.indexInt(filterSize(1)));

                firstTerm  = intA(eR,eC,p); %#ok<PFBNS>
                secondTerm = intA(sR,sC,p);
                thirdTerm  = intA(sR,eC,p);
                fourthTerm = intA(eR,sC,p);

                regionSum = firstTerm + secondTerm - thirdTerm - fourthTerm;

                out(m,n,p) = normFactor * regionSum;
            end
        end
    end
else
    outSize2IndexInt = coder.internal.indexInt( outSize(2));
    nPlanesIndexInt = coder.internal.indexInt(nPlanes);
    parfor m = 1:coder.internal.indexInt(outSize(1))
        sR = m;
        eR = coder.internal.indexPlus(sR, coder.internal.indexInt(filterSize(1))); %#ok<PFBNS>
        for n = 1:outSize2IndexInt
            sC = n;
            eC = coder.internal.indexPlus(sC, coder.internal.indexInt(filterSize(2)));
            for p = 1:nPlanesIndexInt
                firstTerm  = intA(eR,eC,p); %#ok<PFBNS>
                secondTerm = intA(sR,sC,p);
                thirdTerm  = intA(sR,eC,p);
                fourthTerm = intA(eR,sC,p);

                regionSum = firstTerm + secondTerm - thirdTerm - fourthTerm;

                out(m,n,p) = normFactor * regionSum;
            end
        end
    end
end
end

%--------------------------------------------------------------------------
function [normalizationFactor, filterSize] = parseInputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);

% Default values
filterSizeDefault = [3,3];
normalizationFactorDefault = 1/9;

if nargin > 0
    % If first input is FilterSize
    if ~ischar(varargin{1})
        % Validate FilterSize
        filterSize = images.internal.validateTwoDFilterSize(varargin{1});
        % compute Norm factor
        normalizationFactorDefault = 1/prod(filterSize);
        beginNVIdx = 2;
    else
        % The first input is NV pair
        filterSize = filterSizeDefault;
        beginNVIdx = 1;
    end

    % Parse the VN pair for NormalizationFactor
    normFactor = parseNameValuePairs( ...
        normalizationFactorDefault, ...
        varargin{beginNVIdx:end});
    normalizationFactor = validateNormalizationFactor(normFactor);

else
    % No input params given use the default filter values
    filterSize = filterSizeDefault;
    normalizationFactor = normalizationFactorDefault;
end
end

%--------------------------------------------------------------------------
function normalizationFactor = parseNameValuePairs(normFactorDefault,varargin)

coder.inline('always');
coder.internal.prefer_const(normFactorDefault,varargin);

params = struct('normalizationFactor',uint32(0));

options = struct( ...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

optarg = eml_parse_parameter_inputs(params,options,varargin{:});

normalizationFactor = eml_get_parameter_value( ...
    optarg.normalizationFactor, ...
    normFactorDefault, ...
    varargin{:});
end

%--------------------------------------------------------------------------
function normalize = validateNormalizationFactor(normalizeIn)

coder.inline('always');
coder.internal.prefer_const(normalizeIn);

validateattributes(normalizeIn,{'numeric'}, ...
    {'real','scalar','nonsparse'}, ...
    mfilename,'normalizationFactor');

normalize = double(normalizeIn);
end
