function S = decorrstretch(varargin) %#codegen
%DECORRSTRETCH Apply decorrelation stretch to multichannel image.

% Copyright 2023 The MathWorks, Inc.

[aIn,mode,targetMeanInput,targetSigmaInput,tol,rowsubs,colsubs,...
    useDefaultSampleSubscripts] = parseInputs(varargin{:});

% Convert to double, if necessary.
inputClass = class(aIn);
if ~isa(aIn,'double')
    A = im2double(aIn);
    targetMean  = im2double(cast(targetMeanInput,inputClass));
    targetSigma = im2double(cast(targetSigmaInput,inputClass));
else
    A = aIn;
    targetMean = targetMeanInput;
    targetSigma = targetSigmaInput;
end

useCorr = mode == CORRELATION;

% Apply decorrelation stretch.
sDecorr = decorr(A,useCorr,targetMean,targetSigma,...
    rowsubs,colsubs,useDefaultSampleSubscripts);

% Apply optional contrast stretch.
if ~isempty(tol)
    lowHigh = stretchlim(sDecorr,tol);
    sAdjust = imadjustLocal(sDecorr,lowHigh);
else
    sAdjust = sDecorr;
end

% Restore input class.
S = images.internal.changeClass(inputClass,sAdjust);

%--------------------------------------------------------------------------
function S = decorr(A, useCorr, targetMean, targetSigma,...
    rowsubs, colsubs,useDefaultSampleSubscripts)
% Decorrelation stretch for a multiband image of class double.
coder.inline('always');
coder.internal.prefer_const(A, useCorr, targetMean, targetSigma,...
    rowsubs, colsubs,useDefaultSampleSubscripts);

sizeA = cast(size(A),'int32'); % Save the shape

nRows = sizeA(1);
nCols = sizeA(2);
if ~ismatrix(A)
    nbands = sizeA(3);
else
    nbands = int32(1);
end

npixels = nRows * nCols; % Number of pixels

reshapedA = reshape(A,[npixels nbands]);  % Reshape to numPixels-by-numBands

if useDefaultSampleSubscripts
    subSampledA = reshapedA;
else
    ind = sub2ind([nRows nCols], rowsubs, colsubs);
    subSampledA = reshapedA(ind,:);
end

meansubSampledA = mean(subSampledA,1);  % Mean pixel value in each spectral band
n = size(subSampledA,1);  % Equals npixels if rowsubs is empty
if n == 1
    cov = zeros(nbands);
else
    cov = (subSampledA'*subSampledA ...
        -(n*meansubSampledA')*meansubSampledA)/(n-1);  % Sample covariance matrix
end

% Call fitdecorrtrans
[decorrTransform,offset]  = fitdecorrtrans(meansubSampledA,...
    cov,useCorr,targetMean,targetSigma);

S = coder.nullcopy(zeros(size(A)));

% Loop Scheduler
schedule = coder.loop.Control;
if coder.isColumnMajor()
    schedule = schedule.parallelize('j');
else
    schedule = schedule.interchange('i','k').parallelize('i');
end

% Apply Loop Scheduler
schedule.apply
for k = 1:nbands
    for j = 1:nCols
        for i = 1:nRows
            idx = (j-1)*nRows + i;
            S(i,j,k) = reshapedA(idx,:)*decorrTransform(:,k)+offset(k);
        end
    end
end

% --------------------------------------------------------------------------
function out = imadjustLocal(img,lowHigh)
% A short, specialized version of IMADJUST that works with
% an arbitrary number of image planes.
coder.inline('always');
coder.internal.prefer_const(img,lowHigh)

low  = lowHigh(1,:);
high = lowHigh(2,:);
out = coder.nullcopy(zeros(size(img)));

% Loop Scheduler
schedule = coder.loop.Control;
if coder.isColumnMajor()
    schedule = schedule.parallelize('q');
else
    schedule = schedule.interchange('r','p').parallelize('p');
end

% Apply Loop Scheduler
schedule.apply

% Loop over image planes and perform transformation.
for r = 1:coder.internal.indexInt(size(img,3))
    for q = 1:coder.internal.indexInt(size(img,2))
        for p = 1:coder.internal.indexInt(size(img,1))
            % Make sure img is in the range [low,high].
            intensityValue =  max(low(r),min(high(r),img(p,q,r)));

            % Transform.
            intensityValue = (intensityValue-low(r))/(high(r)-low(r));

            if intensityValue < 0
                out(p,q,r) = 0;
            elseif intensityValue > 1
                out(p,q,r) = 1;
            else
                out(p,q,r) = intensityValue;
            end

        end
    end
end

%--------------------------------------------------------------------------
function [A, mode, targetMean, targetSigma, tolerance, rowsubs, colsubs,useDefaultSampleSubscripts] = ...
    parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);

narginchk(1, 12);

A = varargin{1};

% Validate the image array
validateImage(A);

validPropertyNames = ...
    {'Mode','TargetMean','TargetSigma','Tolerance','SampleSubscripts'};
for k = coder.unroll(2:2:nargin)
    validatestring(varargin{k},validPropertyNames,mfilename,'PARAM',k);
end

% Default Values
defaultMode = 'correlation';
defaultTargetMean = [];
defaultTargetSigma = [];
defaultTolerance = [];

% Define Parser Mapping Struct
params = struct(...
    'Mode',uint32(0), ...
    'TargetMean',uint32(0), ...
    'TargetSigma',uint32(0), ...
    'Tolerance',uint32(0), ...
    'SampleSubscripts',uint32(0));

% Specify parser options
poptions = struct( ...
    'CaseSensitivity',  false, ...
    'StructExpand',     true, ...
    'PartialMatching',  true);

% Parse param-value pairs
pstruct = coder.internal.parseParameterInputs(params,poptions,varargin{2:end});
modeStrIn = coder.internal.getParameterValue(pstruct.Mode,...
    defaultMode,varargin{2:end});
targetMeanIn = coder.internal.getParameterValue(pstruct.TargetMean,...
    defaultTargetMean,varargin{2:end});
targetSigmaIn = coder.internal.getParameterValue(pstruct.TargetSigma,...
    defaultTargetSigma ,varargin{2:end});
tol =  coder.internal.getParameterValue(pstruct.Tolerance,...
    defaultTolerance,varargin{2:end});

% Validate the property name-value pairs.
nbands = size(A,3);
modeStr = validatestring(modeStrIn,{'correlation','covariance'},...
    mfilename, 'mode');

mode = stringToModeEnum(modeStr);
if coder.const(pstruct.TargetMean ~= zeros('uint32'))
    targetMean = checkTargetMean(targetMeanIn,nbands);
else
    targetMean = defaultTargetMean;
end

if coder.const(pstruct.TargetSigma ~= zeros('uint32'))
    targetSigma = checkTargetSigma(targetSigmaIn,nbands);
else
    targetSigma = defaultTargetSigma;
end

if coder.const(pstruct.Tolerance ~= zeros('uint32'))
    tolerance = checkTolerance(tol);
else
    tolerance = defaultTolerance;
end

if coder.const(pstruct.SampleSubscripts == zeros('uint32'))
    useDefaultSampleSubscripts = true;
    rowsubs = [];
    colsubs = [];
else
    useDefaultSampleSubscripts = false;
    sampleSubScripts = coder.internal.getParameterValue(pstruct.SampleSubscripts,...
        [],  varargin{2:end});
    [rowsubs, colsubs] = checkSubs(sampleSubScripts, size(A,1), size(A,2));
end

%--------------------------------------------------------------------------
function validateImage(A)
coder.inline('always');
validateattributes(A, {'double','uint8','uint16','int16','single'},...
    {'nonempty','real','nonnan','finite'},...
    'decorrstretch', 'A', 1);

coder.internal.errorIf(numel(size(A))>3,'images:decorrstretch:expected2Dor3D');

%--------------------------------------------------------------------------
function tolerance = checkTolerance(tol)
coder.inline('always');

% Validate the linear-stretch tolerance.
validateattributes(tol, {'double'},...
    {'nonempty','real','nonnan','nonnegative','finite'},mfilename);

coder.internal.errorIf(any(tol < 0) || any(tol > 1), ...
    'images:decorrstretch:tolOutOfRange');

n = numel(tol);
coder.internal.errorIf(n > 2, ...
    'images:decorrstretch:tolHasTooManyElements');

coder.internal.errorIf((n == 2) && ~(tol(1) < tol(2)), ...
    'images:decorrstretch:tolNotIncreasing');

coder.internal.errorIf((n == 1) && (tol(1) >= 0.5), ...
    'images:decorrstretch:tolOutOfRangeScalar');

if n == 1
    tolerance = [tol 1-tol];
else
    tolerance = tol;
end

%--------------------------------------------------------------------------
function targetMean = checkTargetMean(targetMeanIn, nbands)
coder.inline('always');
coder.internal.prefer_const(targetMeanIn, nbands)

validateattributes(targetMeanIn, {'double'},...
    {'nonempty','real','nonnan','finite','vector'},...
    mfilename);

targetMean = targetMeanIn(:)';  % Make sure it's a row vector.

coder.internal.errorIf((numel(targetMean) > 1) && (size(targetMean,2) ~= nbands), ...
    'images:decorrstretch:targetMeanWrongSize', nbands)

%--------------------------------------------------------------------------
function targetSigma = checkTargetSigma(targetSigmaIn, nbands)
coder.inline('always');
coder.internal.prefer_const(targetSigmaIn, nbands);

validateattributes(targetSigmaIn, {'double'},...
    {'nonnegative','nonempty','real','nonnan','finite','vector'},...
    mfilename);
if ~isrow(targetSigmaIn)
    targetSigmaIn = targetSigmaIn';  % Make sure it's a row vector.
end

coder.internal.errorIf((numel(targetSigmaIn) > 1) && (size(targetSigmaIn,2) ~= nbands),...
    'images:decorrstretch:targetSigmaWrongSize', nbands);

% Convert to a diagonal matrix for convenient computation.
targetSigma = diag(targetSigmaIn);

%--------------------------------------------------------------------------
function [rowsubs, colsubs] = checkSubs(subscell, nrows, ncols)
coder.inline('always');
coder.internal.prefer_const(subscell, nrows, ncols);

coder.internal.errorIf(~iscell(subscell) || numel(subscell) ~= 2,...
    'images:decorrstretch:sampleSubsNotTwoElementCell');

rowsubs = subscell{1}(:);
colsubs = subscell{2}(:);

validateattributes(rowsubs, {'double'},{'nonempty','integer','positive'},...
    mfilename, 'ROWSUBS');

validateattributes(colsubs, {'double'},{'nonempty','integer','positive'},...
    mfilename, 'COLSUBS');

coder.internal.errorIf(any(rowsubs > nrows),...
    'images:decorrstretch:subscriptsOutOfRangeRows');

coder.internal.errorIf(any(colsubs > ncols),...
    'images:decorrstretch:subscriptsOutOfRangeColumns');

coder.internal.errorIf(numel(rowsubs) ~= numel(colsubs),...
    'images:decorrstretch:subscriptArraySizeMismatch');

%--------------------------------------------------------------------------
function modeFlag = CORRELATION
coder.inline('always');
modeFlag = int8(1);

%--------------------------------------------------------------------------
function modeFlag = COVARIANCE
coder.inline('always');
modeFlag = int8(2);

%--------------------------------------------------------------------------
function mode = stringToModeEnum(modeStr)
% Convert mode string to its corresponding enumeration
% Use strncmpi to allow case-insensitive, partial matches
coder.inline('always');
if strncmpi(modeStr,'correlation',numel(modeStr))
    mode = CORRELATION;
else % if strncmpi(modeStr,'covariance',numel(modeStr))
    mode = COVARIANCE;
end