function J = entropyfilt(varargin) %#codegen
%ENTROPYFILT Local entropy of intensity image.

% Copyright 2022 The MathWorks, Inc.

narginchk(1,2);

[Iin,H] = parseInputs(varargin{:});

% Convert to uint8 if not logical and set number of bins for the class.
if islogical(Iin) 
    I = Iin;
    nbins = 2;
else
    I = im2uint8(Iin);
    nbins = 256;
end

% Capture original size before padding.
origSize = size(I);

% Pad array.
padSize = (size(H) - 1) / 2;
Ipad = padarray(I,padSize,'symmetric','both');

% Calculate local entropy using MEX-file.
entropyOut = entropyfiltAlgo(Ipad,H,nbins);

% Append zeros to padSize so that it has the same number of dimensions as the
% padded image.
numDims = coder.internal.indexInt(ndims(I));
padSize = [padSize zeros(1,numDims-coder.internal.indexInt(ndims(padSize)))];

% Extract the "middle" of the result; it should be the same size as
% the input image.
idx = coder.nullcopy(cell(1,numDims));
for k = 1: numDims
    s = size(entropyOut,k) - (2*padSize(k));
    first = padSize(k) + 1;
    last = first + s - 1;
    idx{k} = first:last;
end

J = entropyOut(idx{:});

% Should never get here
coder.internal.assert(isequal(size(J),origSize), ...
    'images:entropyfilt:internalError');
end

%---------------------------------------------------------------------------
% Entropyfilt Algorithm Portable Version
function J = entropyfiltAlgo(I,nhood,nbins)
coder.inline('always');
coder.internal.prefer_const(I,nhood);

% Allocate Memory
J = coder.nullcopy(zeros(size(I),'double'));

% Assign Neighbourhood Parameters
nhParams.nbins = nbins;
nhParams.histCount = zeros(nbins,1);
nhParams.numNeighbors = sum(nhood(:));
nhParams.entropyCalcValue = log(2);

% Calculate Entropy
np = images.internal.coder.NeighborhoodProcessor(size(I),nhood);
J = np.process(I,@localEntropy,J,nhParams);
end

%--------------------------------------------------------------------------
% Process each pixel and its neighborhood
function out = localEntropy(imnh,nhParams)
coder.inline('always');
coder.internal.prefer_const(imnh,nhParams);

out = 0;
numNonZeroPixels = coder.internal.indexInt(numel(imnh));

if(nhParams.nbins == 2) % logical image
    sum = 0;
    for pixelInd = 1:numNonZeroPixels
        sum = sum + double(imnh(pixelInd));
    end
    nhParams.histCount(1) = uint32(nhParams.numNeighbors - sum);
    nhParams.histCount(2) = uint32(sum);
else % uint8 image
    for pixelInd = 1:numNonZeroPixels
        idx = coder.internal.indexPlus(coder.internal.indexInt(imnh(pixelInd)),1);
        nhParams.histCount(idx) = nhParams.histCount(idx) + 1;
    end
end

% Calculate Entropy based on normalized histogram counts
% (sum should equal one).
for k = 1:nhParams.nbins
    if nhParams.histCount(k)
        temp = double(nhParams.histCount(k)/nhParams.numNeighbors);
        entropy = temp*(log(temp)/nhParams.entropyCalcValue);

        % log base 2 (temp) = log(temp) / log(2)
        out = out - entropy;

        % re-initialize for next neighborhood
        nhParams.histCount(k) = 0;
    end
end
end

%--------------------------------------------------------------------------
% ParseInputs
function [I,H] = parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin)

% Validate input image I
validateattributes(varargin{1},{'uint8','uint16','double','single','logical'},...
    {'real','nonempty','nonsparse'},mfilename,'I',1);

I = varargin{1};

if nargin == 1
    H = true(9);  % Default Value
else
    % Validate H
    validateattributes(varargin{2},{'logical','numeric'},{'nonempty','nonsparse'}, ...
        mfilename,'NHOOD',2);
    Hin = varargin{2};

    % H must contain zeros and or ones.
    badElements = (Hin ~= 0) & (Hin ~= 1);
    coder.internal.errorIf(any(badElements(:)),...
        'images:entropyfilt:invalidNeighborhoodValue');

    % H's size must be odd (a factor of 2n-1).
    sizeH = size(Hin);
    coder.internal.errorIf(any(floor(sizeH/2) == (sizeH/2)),...
        'images:entropyfilt:invalidNeighborhoodSize');

    % Convert H to a logical array.
    if ~islogical(Hin)
        H = Hin ~= 0;
    else
        H = Hin;
    end
end
end