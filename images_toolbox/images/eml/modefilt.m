function B = modefilt(varargin) %#codegen
%Copyright 2019 The MathWorks, Inc.

%#ok<*EMCA>
[A, kernelSize, padOpt] = parseInputs(varargin{:});

if(isempty(A))
    B = A;
    return;
end
B = coder.nullcopy(A);

if padOpt == ZEROS
    np = images.internal.coder.NeighborhoodProcessor(size(A), true(kernelSize),coder.const('NeighborhoodCenter'),...
        coder.const(images.internal.coder.NeighborhoodProcessor.NEIGHBORHOODCENTER.TOPLEFT),...
        coder.const('Padding'),coder.const(images.internal.coder.NeighborhoodProcessor.PADDING.CONSTANT),...
        coder.const('PadValue'), coder.const(0));
    
elseif padOpt == SYMMETRIC
    np = images.internal.coder.NeighborhoodProcessor(size(A), true(kernelSize),coder.const('NeighborhoodCenter'),...
        coder.const(images.internal.coder.NeighborhoodProcessor.NEIGHBORHOODCENTER.TOPLEFT),...
        coder.const('Padding'),coder.const(images.internal.coder.NeighborhoodProcessor.PADDING.SYMMETRIC));
else
    np = images.internal.coder.NeighborhoodProcessor(size(A), true(kernelSize),...
        coder.const('NeighborhoodCenter'), coder.const(images.internal.coder.NeighborhoodProcessor.NEIGHBORHOODCENTER.TOPLEFT),...
        coder.const('Padding'),coder.const(images.internal.coder.NeighborhoodProcessor.PADDING.REPLICATE));
end

% B = coder.nullcopy(A);
B = np.process(A,@modefilt2Algo,B);

end

function out = modefilt2Algo(window,~)
coder.inline('always');
% Find mode of pixels in the neighborhood. If the center pixel is one of
% the modes, it gets the preference, else the lowest value pixel is used
% for tie-breaking

windowSize = size(window);
center = ceil(windowSize/2);
centerValue = window(center(1),center(2));

tempOut = mode(window(:));

% Count value for center pixel in the window
centerValueCount = nnz(window(:) == centerValue);
modeCount = nnz(window(:) == tempOut);

if centerValueCount == modeCount
    out = centerValue;
else
    out = tempOut;
end

end


function [A,filterSize,padOpt] = parseInputs(varargin)

coder.internal.prefer_const(varargin);

narginchk(1,3);

A = varargin{1};
ndimsA = ndims(A);

if ndimsA > 3
    coder.internal.errorIf(true,'images:modefilt:invalidInputSize');
end

validateattributes(A,...
    {'uint8','uint16','uint32','int8','int16','int32','single','double','logical'},...
    {'nonsparse','real'},mfilename,'A',1);

if nargin == 1
    filterSize = defaultFilterSize(ndimsA);
    padOpt = SYMMETRIC;    

elseif nargin == 2
    
    if ischar(varargin{2}) || isstring(varargin{2})
        filterSize = defaultFilterSize(ndimsA);
        padOpt = parsePadOpt(varargin{2},2);
        
    else
        filterSize = parseFilterSize(varargin{2},ndimsA,2);
        padOpt = SYMMETRIC;
    end

elseif nargin == 3
    filterSize = parseFilterSize(varargin{2},ndimsA,2);
    padOpt = parsePadOpt(varargin{3},3);
else
    filterSize = [];
    padOpt = SYMMETRIC;
end

end

function padopt = parsePadOpt(padOptIn,k)

coder.inline('always');
coder.internal.prefer_const(padOptIn,k);

padOptions = {'zeros','replicate','symmetric'};

eml_invariant(eml_is_const(padOptIn),...
              eml_message('MATLAB:images:validate:codegenInputNotConst','PADOPT'),...
              'IfNotConst','Fail');

padoptStr = validatestring(padOptIn, padOptions, mfilename, 'PADOPT', k);

if strcmp(padoptStr,'zeros')
    padopt = ZEROS;
elseif strcmp(padoptStr,'replicate')
    padopt = REPLICATE;
elseif strcmp(padoptStr,'symmetric')
    padopt = SYMMETRIC;
end
end

function padoptFlag = ZEROS()
coder.inline('always');
padoptFlag = int8(1);
end

function padoptFlag = SYMMETRIC()
coder.inline('always');
padoptFlag = int8(2);
end

function padoptFlag = REPLICATE()
coder.inline('always');
padoptFlag = int8(3);
end

function filterSize = defaultFilterSize(ndimsA)

coder.inline('always');
coder.internal.prefer_const(ndimsA);
if ndimsA <= 2
    filterSize = [3 3];
elseif ndimsA == 3
    filterSize = [3 3 3];
end
end

function filterSize = parseFilterSize(filtSizeIn,ndimsA,k)

coder.inline('always');
coder.internal.prefer_const(filtSizeIn,ndimsA,k);

validateattributes(filtSizeIn,{'numeric'},...
            {'real','finite','positive','integer','odd','nonempty','nonsparse','vector','numel',ndimsA},...
            mfilename,'FILTSIZE',k);
        
filterSize = filtSizeIn;

end