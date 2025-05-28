function out = integralBoxFilter3(intA, varargin) %#codegen
%INTEGRALBOXFILTER 2-D box filtering of integral images

%   Copyright 2021 The MathWorks, Inc.

narginchk(1,4);

validateattributes(intA,{'double'}, ...
    {'real','nonsparse','nonempty'},mfilename,'Integral Image',1);

coder.internal.errorIf(any([size(intA) ones(3-ndims(intA))] < 2), ...
    'images:integralBoxFilter:intImage3TooSmall');

[normFactor,filterSize] = parseInputs(varargin{:});

outSize = [size(intA) ones(1,3-ndims(intA))] - [filterSize zeros(1,3-numel(filterSize))];

out = coder.nullcopy(zeros(outSize,'like',intA));

if coder.isColumnMajor()
    outSize1IndexInt = coder.internal.indexInt( outSize(1));
    outSize2IndexInt = coder.internal.indexInt( outSize(2));
    parfor p = 1:coder.internal.indexInt(outSize(3))
        sP = p;
        eP = coder.internal.indexPlus(sP, coder.internal.indexInt(filterSize(3))); %#ok<PFBNS>
        for n = 1:outSize2IndexInt
            sC = n;
            eC = coder.internal.indexPlus(sC, coder.internal.indexInt(filterSize(2)));
            for m = 1:outSize1IndexInt
                sR = m;
                eR = coder.internal.indexPlus(sR, coder.internal.indexInt(filterSize(1)));

                term_A = intA(sR,eC,eP); %#ok<PFBNS>
                term_B = intA(sR,sC,eP);
                term_C = intA(sR,eC,sP);
                term_D = intA(sR,sC,sP);

                term_E = intA(eR,eC,eP);
                term_F = intA(eR,sC,eP);
                term_G = intA(eR,eC,sP);
                term_H = intA(eR,sC,sP);


                regionSum = term_E - term_A - term_F - term_G + term_B + term_C + term_H - term_D;

                out(m,n,p) = normFactor * regionSum;
            end
        end
    end
else
    outSize2IndexInt = coder.internal.indexInt( outSize(2));
    outSize3IndexInt = coder.internal.indexInt( outSize(3));
    parfor m = 1:coder.internal.indexInt(outSize(1))
        sR = m;
        eR = coder.internal.indexPlus(sR, coder.internal.indexInt(filterSize(1))); %#ok<PFBNS>
        for n = 1:outSize2IndexInt
            sC = n;
            eC = coder.internal.indexPlus(sC, coder.internal.indexInt(filterSize(2)));
            for p = 1:outSize3IndexInt
                sP = p;
                eP = coder.internal.indexPlus(sP, coder.internal.indexInt(filterSize(3)));

                term_A = intA(sR,eC,eP); %#ok<PFBNS>
                term_B = intA(sR,sC,eP);
                term_C = intA(sR,eC,sP);
                term_D = intA(sR,sC,sP);

                term_E = intA(eR,eC,eP);
                term_F = intA(eR,sC,eP);
                term_G = intA(eR,eC,sP);
                term_H = intA(eR,sC,sP);

                regionSum = term_E - term_A - term_F - term_G + term_B + term_C + term_H - term_D;

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
filterSizeDefault = [3,3,3];
normalizationFactorDefault = 1/27;

if nargin > 0
    % If first input is FilterSize
    if ~ischar(varargin{1})
        % Validate FilterSize
        filterSize = images.internal.validateThreeDFilterSize(varargin{1});
        % compute Norm factor
        normalizationFactorDefault = 1/prod(filterSize);
        beginNVIdx = 2;
    else
        % The first input is NV pair
        filterSize = FilterSizeDefault;
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
