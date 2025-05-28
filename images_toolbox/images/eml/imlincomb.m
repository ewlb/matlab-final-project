function Z = imlincomb(varargin) %#codegen
%IMLINCOMB Linear combination of images.

% Copyright 2013-2024 The MathWorks, Inc.

%#ok<*EMCA>

[imageStack,scalarStack, outputClass,lastIdx] = parseInputs(varargin{:});

numImages = numel(imageStack);
numScalars = numel(scalarStack);

Z = lincombGeneric(numImages,numScalars,outputClass,lastIdx,varargin{:});

%--------------------------------------------------------------------------
function [imageStack,scalarStack,outputClass,lastIdx] = parseInputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin{:});

narginchk(2,10);

% If the output_class input argument is used
if ischar(varargin{end})
    % Check that it is a compile-time constant
    eml_invariant(eml_is_const(varargin{end}), ...
        eml_message('MATLAB:images:validate:codegenInputNotConst','OUTPUT_CLASS'), ...
        'IfNotConst','Fail');
    % Validate its value
    validStrings = {'uint8','uint16','uint32','int8','int16','int32', ...
        'single','double'};
    outputClass = validatestring(varargin{end},validStrings,mfilename, ...
        'OUTPUT_CLASS',3);
    lastIdx = nargin-1;
else
    % Deduce the output class from the input class
    if islogical(varargin{2})
        outputClass = 'double';
    else
        outputClass = class(varargin{2});
    end
    lastIdx = nargin;
end

% Validate scalars
for p = 1:2:lastIdx
    validateattributes(varargin{p},{'double'}, ...
        {'real','nonsparse','scalar'},mfilename);
end

% Validate images
for p = 2:2:lastIdx
    validateattributes(varargin{p},{'logical','single','double','uint8', ...
        'uint16','uint32','int8','int16','int32'}, ...
        {'real','nonsparse'},mfilename);
end

% Assign images
imageStack = {varargin{2:2:lastIdx}};

coder.internal.errorIf(isempty(imageStack), ...
    'images:imlincomb:internalError','imageStack');

% Get input image class and size
inputClass = class(imageStack{1});
inputSize = size(imageStack{1});

% Number of images
numImages = numel(imageStack);

% Check if class of input images match
for p = coder.unroll(2:numImages)
    coder.internal.errorIf(~isa(imageStack{p},inputClass),...
        'images:imlincomb:mismatchedArrayClass');

    coder.internal.errorIf(~isequal(size(imageStack{p}),inputSize),...
        'images:imlincomb:mismatchedArraySize');
end

% Support up to 4 input images
coder.internal.errorIf(numImages > 4,...
    'images:imlincomb:codegenInvalidNumberOfImages');

% Assign scalars
scalarStack = {varargin{1:2:lastIdx}};
numScalars = numel(scalarStack);

% Make sure it is a vector
coder.internal.errorIf(~ismatrix(scalarStack) || ...
    (all(size(scalarStack)~=1) && any(size(scalarStack)~=0)),...
    'images:imlincomb:internalError','scalarStack');

% Check if number of images and scalars are consistent
coder.internal.errorIf((numScalars < numImages) || ...
    (numScalars > numImages+1),...
    'images:imlincombc:mismatchedLength')

%--------------------------------------------------------------------------
function Z = lincombGeneric(numImages,numScalars,outputClass,lastIdx,varargin)
% This is where we choose to use a shared library or go for portable code

coder.inline('always');
coder.internal.prefer_const(numImages,numScalars,outputClass,lastIdx,varargin{:});

% Use TBB for images over 500k pixels
GRAIN_SIZE = 500000;
numPixels = numel(varargin{2});
singleThread = images.internal.coder.useSingleThread();
useParallel = ~singleThread && (numPixels > GRAIN_SIZE);

% Use portable code if single-threaded
useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() ...
    && useParallel;

if useSharedLibrary
    Z = lincombSharedLibrary(numImages,numScalars,outputClass,lastIdx,varargin{:});
else
    Z = lincombPortableCode(numImages,numScalars,outputClass,varargin{:});
end

%--------------------------------------------------------------------------
function Z = lincombSharedLibrary(numImages,numScalars,outputClass,lastIdx,varargin)

coder.inline('always');
coder.internal.prefer_const(numImages,numScalars,outputClass,lastIdx,varargin{:});

% Convert the number of images to a string at compile-time
coder.extrinsic('eml_try_catch');
[errid,errmsg,numImagesStr] = eml_const(eml_try_catch('num2str',numImages));
eml_lib_assert(isempty(errmsg),errid,errmsg);

multipliers = coder.nullcopy(ones(numScalars,1));
for k = coder.unroll(0:numScalars-1)
    multipliers(k+1) = varargin{2*k+1};
end

switch outputClass
    case 'double'
        outputClassEnum = DOUBLE;
    case 'single'
        outputClassEnum = SINGLE;
    case 'int32'
        outputClassEnum = INT32;
    case 'uint32'
        outputClassEnum = UINT32;
    case 'int16'
        outputClassEnum = INT16;
    case 'uint16'
        outputClassEnum = UINT16;
    case 'int8'
        outputClassEnum = INT8;
    case 'uint8'
        outputClassEnum = UINT8;
    otherwise
        coder.internal.assert(false,'images:imlincomb:invalidOutputType');
end

% Create output buffer of type 'outputClass'.
% 'outputClass' and 'inputClass' must match
Z = coder.nullcopy(zeros(size(varargin{2}),outputClass));

% Number of pixels
numPixels = numel(varargin{2});

% Call the TBB library
lincombTBBCFun = ['imlincomb_tbb_' images.internal.coder.getCtype(varargin{2})];
fcnName = ['imlincomb_tbbCore_' numImagesStr];
Z = images.internal.coder.buildable.Imlincomb_tbbBuildable.(fcnName)(...
    lincombTBBCFun, multipliers, numScalars, Z, outputClassEnum, numPixels, numImages, varargin{2:2:lastIdx});

%--------------------------------------------------------------------------
function Z = lincombPortableCode(numImages,numScalars,outputClass,varargin)

coder.inline('always');
coder.internal.prefer_const(numImages,numScalars,outputClass,varargin{:});

% Get number of pixels from 1st input image
numPixels = numel(varargin{2});

% Get the offset from the last input argument
if numImages == numScalars
    offset = 0;
else
    offset = varargin{2*numScalars-1};
end

% Allocate space for the output function
Z = coder.nullcopy(zeros(size(varargin{2}),outputClass));

if coder.isColumnMajor() || (coder.isRowMajor() && numel(size(varargin{2}))>3)
    parfor k = 1:numPixels
        val = 0;
        % For each (coeff,image) pair
        for p = coder.unroll(0:numImages-1)
            lambda = varargin{2*p+1};
            % Do the computation in double precision
            val = val + lambda*double(varargin{2*p+2}(k));
        end
        % Add the offset
        val = val + offset;
        % Cast to the right output class
        Z(k) = images.internal.coder.convert2Type(val,outputClass);
    end
else % Row-major
    if numel(size(varargin{2})) == 2
        nRows = coder.internal.indexInt(size(varargin{2},1));
        nCols = coder.internal.indexInt(size(varargin{2},2));
        parfor i = 1:nRows
            for j = 1:nCols
                val = 0;
                % For each (coeff,image) pair
                for p = coder.unroll(0:numImages-1)
                    lambda = varargin{2*p+1};
                    % Do the computation in double precision
                    val = val + lambda*double(varargin{2*p+2}(i,j));
                end
                % Add the offset
                val = val + offset;
                % Cast to the right output class
                Z(i,j) = images.internal.coder.convert2Type(val,outputClass);
            end
        end
    else % numel(size(img)) == 3
                nRows = coder.internal.indexInt(size(varargin{2},1));
        nCols = coder.internal.indexInt(size(varargin{2},2));
        nPlanes = coder.internal.indexInt(size(varargin{2},3));
        parfor i = 1:nRows
            for j = 1:nCols
                for k = 1:nPlanes
                    val = 0;
                    % For each (coeff,image) pair
                    for p = coder.unroll(0:numImages-1)
                        lambda = varargin{2*p+1};
                        % Do the computation in double precision
                        val = val + lambda*double(varargin{2*p+2}(i,j,k));
                    end
                    % Add the offset
                    val = val + offset;
                    % Cast to the right output class
                    Z(i,j,k) = images.internal.coder.convert2Type(val,outputClass);
                end
            end
        end
    end
end

%--------------------------------------------------------------------------
function dataTypeEnum = DOUBLE()
coder.inline('always');
dataTypeEnum = int8(0);

function dataTypeEnum = SINGLE()
coder.inline('always');
dataTypeEnum = int8(1);

function dataTypeEnum = INT32()
coder.inline('always');
dataTypeEnum = int8(2);

function dataTypeEnum = UINT32()
coder.inline('always');
dataTypeEnum = int8(3);

function dataTypeEnum = INT16()
coder.inline('always');
dataTypeEnum = int8(4);

function dataTypeEnum = UINT16()
coder.inline('always');
dataTypeEnum = int8(5);

function dataTypeEnum = INT8()
coder.inline('always');
dataTypeEnum = int8(6);

function dataTypeEnum = UINT8()
coder.inline('always');
dataTypeEnum = int8(7);

% LocalWords:  nonsparse imlincombc TBB tbb
