function out = adapthisteq(varargin) %#codegen
%ADAPTHISTEQ Contrast-limited Adaptive Histogram Equalization (CLAHE).

% Copyright 2020-2021 The MathWorks, Inc.

%   Syntax
%   ------
%
%   out = adapthisteq(I)
%   out = adapthisteq(I, Param,Value,...)
%
%   Input Specs
%   -----------
%
%   I:
%     real
%     non-sparse
%     2d
%     'uint8', 'uint16', 'double', 'int16', 'single'
%
%   'NumTiles':
%     Two-element vector of positive integers: [M N]
%     Default: [8 8]
%
%   'ClipLimit':
%     Real scalar from 0 to 1
%     Default: 0.01
%
%   'NBins':
%     Positive integer scalar
%     Default: 256
%
%   'Range':
%     string with values either 'original' or 'full'
%     Default: 'full'
%
%   'Distribution':
%     string with values either 'uniform' or 'rayleigh'or 'exponential'
%     Default: 'uniform'
%
%    'Alpha': (supplied when 'Dist' is either 'rayleigh' or 'exponential')
%     Nonnegative real scalar
%     Default: 0.4
%
%   Output Specs
%   ------------
%
%   out:
%     same class as I
%

[I, selectedRange, fullRange, numTiles, dimTile, clipLimit, numBins, ...
    noPadRectFlag, noPadRect, distribution, alpha, int16ClassChange] = parseInputs(varargin{:});

% If GPU is enabled, then calling GPU Codegen specific implementation for
% 'adapthisteq' here.
if coder.gpu.internal.isGpuEnabled
    claheI = adapthisteqGPUImpl(I, numTiles,dimTile, numBins, clipLimit,...
        selectedRange, fullRange, distribution, alpha);
else
    tileMappings = makeTileMappings(I, numTiles, dimTile, numBins, clipLimit, ...
        selectedRange, fullRange, distribution, alpha);

    %Synthesize the output image based on the individual tile mappings.
    claheI = makeClaheImage(I, tileMappings, numTiles, selectedRange, numBins,...
        dimTile);
end

if int16ClassChange
    % Change uint16 back to int16 so output has same class as input.
    out1 = uint16toint16(claheI);
else
    out1 = claheI;
end

if noPadRectFlag %do we need to remove padding?
    if coder.gpu.internal.isGpuEnabled
        % For removing padded values, rewritten equivalent code with for
        % loops for generating optimized code.
        I1 = size(varargin{1});
        out = coder.nullcopy(zeros(I1(1),I1(2),'like',varargin{1}));
        coder.gpu.kernel;
        for j = noPadRect.ulCol:noPadRect.lrCol
            coder.gpu.kernel;
            for i = noPadRect.ulRow:noPadRect.lrRow
                out(i-noPadRect.ulRow+1,j-noPadRect.ulCol+1) = out1(i,j);
            end
        end
    else
        out = out1(noPadRect.ulRow:noPadRect.lrRow, ...
            noPadRect.ulCol:noPadRect.lrCol);
    end
else
    out = out1;
end

%--------------------------------------------------------------------------
function [I, selectedRange, fullRange, numTiles, dimTile, clipLimit,...
    numBins, noPadRectFlag, noPadRect, distribution, alpha, ...
    int16ClassChange] = parseInputs(varargin)

narginchk(1,13);
coder.inline('always');
coder.internal.prefer_const(varargin);

I1 = varargin{1};
% validate Input Image
validateImage(I1);

% convert int16 to uint16
if isa(I1, 'int16')
    I2 = int16touint16(I1);
    int16ClassChange = true;
else
    int16ClassChange = false;
    I2 = I1;
end

if isa(I2, 'double') || isa(I2,'single')
    fullRange = [0 1];
else
    fullRange = double([intmin(class(I2)) intmax(class(I2))]); %will be clipped to min and max
end

[numTiles, normClipLimit, numBins, range, distribution, alpha, ...
    checkAlpha] = parseNameValuePairs(varargin{2:end});

% Pre-process the inputs
dimI = size(I2);
dimTile = dimI./numTiles;

%check if tile size is reasonable
coder.internal.errorIf(any(dimTile < 1), 'images:adapthisteq:inputImageTooSmallToSplit', ...
    sprintf('%g %g', numTiles(1), numTiles(2)));

coder.internal.errorIf(checkAlpha && coder.const(distribution == UNIFORM), ...
    'images:adapthisteq:alphaShouldNotBeSpecified', 'uniform');

if range == ORIGINAL
    selectedRange = double([min(I2(:)) max(I2(:))]);
else
    selectedRange = fullRange;
end

%check if the image needs to be padded; pad if necessary;
%padding occurs if any dimension of a single tile is an odd number
%and/or when image dimensions are not divisible by the selected
%number of tiles
rowDiv  = mod(dimI(1), numTiles(1)) == 0;
colDiv  = mod(dimI(2), numTiles(2)) == 0;
rowEven = mod(dimTile(1), 2) == 0;
colEven = mod(dimTile(2), 2) == 0;
if  ~(rowDiv && colDiv && rowEven && colEven)
    padRow = 0;
    padCol = 0;
    if ~rowDiv
        rowTileDim = floor(dimI(1)/numTiles(1)) + 1;
        padRow = rowTileDim*numTiles(1) - dimI(1);
    else
        rowTileDim = dimI(1)/numTiles(1);
    end

    if ~colDiv
        colTileDim = floor(dimI(2)/numTiles(2)) + 1;
        padCol = colTileDim*numTiles(2) - dimI(2);
    else
        colTileDim = dimI(2)/numTiles(2);
    end

    %check if tile dimensions are even numbers
    rowEven = mod(rowTileDim, 2) == 0;
    colEven = mod(colTileDim, 2) == 0;
    if ~rowEven
        padRow = padRow + numTiles(1);
    end

    if ~colEven
        padCol = padCol + numTiles(2);
    end

    padRowPre  = floor(padRow/2);
    padRowPost = ceil(padRow/2);
    padColPre  = floor(padCol/2);
    padColPost = ceil(padCol/2);
    I3 = padarray(I2, [padRowPre  padColPre], 'symmetric', 'pre');
    I = padarray(I3, [padRowPost padColPost], 'symmetric', 'post');

    %UL corner (Row, Col), LR corner (Row, Col)
    noPadRect.ulRow = padRowPre + 1;
    noPadRect.ulCol = padColPre + 1;
    noPadRect.lrRow = padRowPre + dimI(1);
    noPadRect.lrCol = padColPre + dimI(2);
    noPadRectFlag = true;
else
    noPadRectFlag = false;
    noPadRect = struct('ulRow', 0, 'ulCol', 0, ...
        'lrRow', 0, 'lrCol', 0) ;
    I = I2;
end

%redefine this variable to include the padding
dimI = size(I);

%size of the single tile
dimTile = dimI ./ numTiles;

%compute actual clip limit from the normalized value entered by the user
%maximum value of normClipLimit=1 results in standard AHE, i.e. no clipping;
%the minimum value minClipLimit would uniformly distribute the image pixels
%across the entire histogram, which would result in the lowest possible
%contrast value
numPixInTile = prod(dimTile);
minClipLimit = ceil(numPixInTile/numBins);
clipLimit = minClipLimit + round(normClipLimit*(numPixInTile - minClipLimit));

%--------------------------------------------------------------------------
% Parse the Name-Value pairs which are optional arguments
function [numTiles, normClipLimit, numBins, range, distribution, ...
    alpha, checkAlpha] = parseNameValuePairs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);

%default values
defaultNumTiles = [8 8];
defaultNormClipLimit = 0.01;
defaultNumBins = 256;
defaultRangeStr = 'full';
defaultDistribution = 'uniform';
defaultAlpha = 0.4;

% Define parser mapping struct
params = struct(...
    'NumTiles',     uint32(0), ...
    'ClipLimit',    uint32(0), ...
    'NBins',        uint32(0), ...
    'Range',        uint32(0), ...
    'Distribution', uint32(0), ...
    'Alpha',        uint32(0));

% Specify parser options
poptions = struct( ...
    'CaseSensitivity',  false, ...
    'StructExpand',     true, ...
    'PartialMatching',  true);

% Parse param-value pairs
pstruct = coder.internal.parseParameterInputs(params, poptions, varargin{:});
numTiles      =  coder.internal.getParameterValue(pstruct.NumTiles,     defaultNumTiles,      varargin{:});
normClipLimit =  coder.internal.getParameterValue(pstruct.ClipLimit,    defaultNormClipLimit, varargin{:});
numBins       =  coder.internal.getParameterValue(pstruct.NBins,        defaultNumBins ,      varargin{:});
rangeStr      =  coder.internal.getParameterValue(pstruct.Range,        defaultRangeStr,      varargin{:});
distributionStr  =  coder.internal.getParameterValue(pstruct.Distribution, defaultDistribution,  varargin{:});
alpha         =  coder.internal.getParameterValue(pstruct.Alpha,        defaultAlpha,         varargin{:});

% Validate Parse Options
validateNumTiles(numTiles);
validateClipLimit(normClipLimit);
validateNBins(numBins);
validateRange(rangeStr)
validateDistribution(distributionStr);
validateAlpha(alpha);

% Convert the strings to corresponding enumerations
range = stringToRange(rangeStr);
distribution = stringToDistribution(distributionStr);

if coder.const(pstruct.Alpha == zeros('uint32'))
    checkAlpha = false;
else
    checkAlpha = true;
end

%--------------------------------------------------------------------------
% Validate the input image
function validateImage(I)
coder.inline('always');
supportedClasses = {'uint8', 'uint16', 'double', 'int16', 'single'};
supportedAttribs = {'real', '2d', 'nonsparse', 'nonempty'};
validateattributes(I,supportedClasses,supportedAttribs, mfilename,'I', 1);
coder.internal.errorIf(any(size(I) < 2), 'images:adapthisteq:inputImageTooSmall');

%--------------------------------------------------------------------------
% Validate NumTiles
function validateNumTiles(numTiles)
coder.inline('always');
validateattributes(numTiles, {'double'}, {'real', 'vector', ...
    'integer', 'finite','positive'},...
    mfilename, 'NumTiles');
coder.internal.errorIf(any(size(numTiles) ~= [1,2]), 'images:adapthisteq:invalidNumTilesVector', 'NumTiles')
coder.internal.errorIf(any(numTiles < 2), 'images:adapthisteq:invalidNumTilesValue', 'NumTiles')

%--------------------------------------------------------------------------
% Validate ClipLimit
function validateClipLimit(normClipLimit)
coder.inline('always');
validateattributes(normClipLimit, {'double'}, ...
    {'scalar','real','nonnegative'},...
    mfilename, 'ClipLimit');
coder.internal.errorIf(normClipLimit > 1, 'images:adapthisteq:invalidClipLimit', 'ClipLimit')

%--------------------------------------------------------------------------
% Validate NBins
function validateNBins(numBins)
coder.inline('always');
validateattributes(numBins, {'double'}, {'scalar','real','integer',...
    'positive'}, mfilename, 'NBins');

%--------------------------------------------------------------------------
% Validate Range
function validateRange(rangeStr)
coder.inline('always');
validRangeStrings = {'original','full'};
validatestring(rangeStr, validRangeStrings, mfilename,...
    'Range');

%--------------------------------------------------------------------------
% Validate Distribution
function validateDistribution(distribution)
coder.inline('always');
validDist = {'rayleigh','exponential','uniform'};
validatestring(distribution, validDist, mfilename,...
    'Distribution');

%--------------------------------------------------------------------------
% Validate Alpha
function validateAlpha(alpha)
coder.inline('always');
validateattributes(alpha, {'double'},{'scalar','real',...
    'nonnan','positive','finite'},...
    mfilename, 'Alpha');

%--------------------------------------------------------------------------
function distribution = stringToDistribution(dStr)
% Convert method string to its corresponding enumeration
% Use strncmpi to allow case-insensitive, partial matches
if strncmpi(dStr, 'uniform',numel(dStr))
    distribution = UNIFORM;
elseif strncmpi(dStr,  'exponential',numel(dStr))
    distribution = EXPONENTIAL;
else % if strncmpi(dStr,'rayleigh',numel(dStr))
    distribution = RAYLEIGH;
end

%--------------------------------------------------------------------------
function range = stringToRange(rStr)
% Convert range string to its corresponding enumeration
% Use strncmpi to allow case-insensitive, partial matches
if strncmpi(rStr,'original',numel(rStr))
    range = ORIGINAL;
else % if strncmpi(rStr,'full',numel(rStr))
    range = FULL;
end

%--------------------------------------------------------------------------
function distributionFlag = UNIFORM()
coder.inline('always');
distributionFlag = int8(1);

%--------------------------------------------------------------------------
function distributionFlag = EXPONENTIAL()
coder.inline('always');
distributionFlag = int8(2);

%--------------------------------------------------------------------------
function distributionFlag = RAYLEIGH()
coder.inline('always');
distributionFlag = int8(3);

%--------------------------------------------------------------------------
function rangeFlag = ORIGINAL()
coder.inline('always');
rangeFlag = int8(4);

%--------------------------------------------------------------------------
function rangeFlag = FULL()
coder.inline('always');
rangeFlag = int8(5);

%--------------------------------------------------------------------------
function tileMappings = makeTileMappings(I, numTiles, dimTile, numBins, ...
    clipLimit, selectedRange, fullRange, distribution, alpha)
coder.inline('always');
coder.internal.prefer_const(I, numTiles, dimTile, numBins, clipLimit, ...
    selectedRange, fullRange, distribution, alpha);

numPixInTile = prod(dimTile);
tileMappings = coder.nullcopy(cell(numTiles));

% extract and process each tile
if coder.isColumnMajor()
    imgCol = 1;
    for col = 1:numTiles(2)
        imgRow = 1;
        for row = 1:numTiles(1)
            tile = I(imgRow:imgRow+dimTile(1)-1, imgCol:imgCol+dimTile(2)-1);
            tileHist = imhist(tile, numBins);
            tileHist = clipHistogram(tileHist, clipLimit, numBins);
            tileMapping = makeMapping(tileHist, selectedRange, fullRange, ...
                numPixInTile, distribution, alpha);

            % assemble individual tile mappings by storing them in a cell array;
            tileMappings{row, col} = tileMapping;
            imgRow = imgRow + dimTile(1);
        end
        imgCol = imgCol + dimTile(2); % move to the next column of tiles
    end
else % Row-major
    imgRow = 1;
    for row = 1:numTiles(1)
        imgCol = 1;
        for col = 1:numTiles(2)
            tile = I(imgRow:imgRow+dimTile(1)-1, imgCol:imgCol+dimTile(2)-1);
            tileHist = imhist(tile, numBins);
            tileHist = clipHistogram(tileHist, clipLimit, numBins);
            tileMapping = makeMapping(tileHist, selectedRange, fullRange, ...
                numPixInTile, distribution, alpha);

            % assemble individual tile mappings by storing them in a cell array;
            tileMappings{row, col} = tileMapping;
            imgCol = imgCol + dimTile(2);
        end
        imgRow = imgRow + dimTile(1); % move to the next row of tiles
    end
end

%--------------------------------------------------------------------------
function imgHist = clipHistogram(imgHist, clipLimit, numBins)
coder.inline('always');
coder.internal.prefer_const(clipLimit, numBins);

% total number of pixels overflowing clip limit in each bin
totalExcess = sum(max(imgHist - clipLimit, 0));

% clip the histogram and redistribute the excess pixels in each bin
avgBinIncr = floor(totalExcess/numBins);
upperLimit = clipLimit - avgBinIncr; % bins larger than this will be
% set to clipLimit
% this loop should speed up the operation by putting multiple pixels
% into the "obvious" places first
for k=1:numBins
    if imgHist(k) > clipLimit
        imgHist(k) = clipLimit;
    else
        if imgHist(k) > upperLimit % high bin count
            totalExcess = totalExcess - (clipLimit - imgHist(k));
            imgHist(k) = clipLimit;
        else
            totalExcess = totalExcess - avgBinIncr;
            imgHist(k) = imgHist(k) + avgBinIncr;
        end
    end
end
k=1;
% this loops redistributes the remaining pixels, one pixel at a time
while (totalExcess ~= 0)
    % keep increasing the step as fewer and fewer pixels remain for
    % the redistribution (spread them evenly)

    stepSize = max(floor(numBins/totalExcess), 1);
    for m = k:stepSize:numBins
        if imgHist(m) < clipLimit
            imgHist(m) = imgHist(m)+1;
            totalExcess = totalExcess - 1; %reduce excess
            if totalExcess == 0
                break;
            end
        end
    end
    k = k+1; % prevent from always placing the pixels in bin #1
    if k > numBins % start over if numBins was reached
        k = 1;
    end
end

%--------------------------------------------------------------------------
function mapping = makeMapping(imgHist, selectedRange, fullRange, ...
    numPixInTile, distribution, alpha)
coder.inline('always');
coder.internal.prefer_const(imgHist, selectedRange, fullRange, ...
    numPixInTile, distribution, alpha);

histSum = cumsum(imgHist);
valSpread  = selectedRange(2) - selectedRange(1);
mapping = 0;
switch distribution
    case UNIFORM
        scale =  valSpread/numPixInTile;
        mapping = (min(selectedRange(1) + histSum*scale, selectedRange(2))) ; %limit to max

    case RAYLEIGH % suitable for underwater imagery
        % pdf = (t./alpha^2).*exp(-t.^2/(2*alpha^2))*U(t)
        % cdf = 1-exp(-t.^2./(2*alpha^2))
        hconst = 2*alpha^2;
        vmax = 1 - exp(-1/hconst);
        val = vmax*(histSum/numPixInTile);
        val(val>=1) = 1 - eps; % avoid log(0)
        temp = sqrt(-hconst*log(1-val));
        mapping = min(selectedRange(1)+temp*valSpread, selectedRange(2)); %limit to max

    case EXPONENTIAL
        % pdf = alpha*exp(-alpha*t)*U(t)
        % cdf = 1-exp(-alpha*t)
        vmax = 1 - exp(-alpha);
        val = (vmax*histSum/numPixInTile);
        val(val>=1) = 1-eps;
        temp = -1/alpha*log(1-val);
        mapping = min(selectedRange(1)+temp*valSpread, selectedRange(2));

    otherwise
        coder.internal.errorIf(true, 'images:adapthisteq:distributionType') %should never get here

end

%rescale the result to be between 0 and 1 for later use by the GRAYXFORMMEX
%private mex function
mapping = mapping/fullRange(2);

%--------------------------------------------------------------------------
function claheI = makeClaheImage(I, tileMappings, numTiles, selectedRange,...
    numBins, dimTile)
coder.inline('always');
coder.internal.prefer_const(I, tileMappings, numTiles, selectedRange,...
    numBins, dimTile);

%initialize the output image to zeros (preserve the class of the input image)
claheI = I;
claheI(:) = 0;

%compute the LUT for looking up original image values in the tile mappings,
%which we created earlier
if ~(isa(I,'double') || isa(I,'single'))
    k = selectedRange(1)+1 : selectedRange(2)+1;
    aLut = zeros(selectedRange(2)+1,1);
    aLut(k) = (k-1) - selectedRange(1);
    aLut = aLut/(selectedRange(2)-selectedRange(1));
else
    % remap from 0..1 to 0..numBins-1
    if numBins ~= 1
        binStep = 1/(numBins-1);
        start = ceil(selectedRange(1)/binStep);
        stop  = floor(selectedRange(2)/binStep);
        k = start+1:stop+1;
        aLut = zeros(stop+1,1);
        aLut(k) = 0:1/(length(k)-1):1;

    else
        aLut = 0;
        aLut(1) = 0; %in case someone specifies numBins = 1, which is just silly
    end
end

if coder.isColumnMajor()
    imgTileCol=1;
    for k = 1:numTiles(2)+1
        if k == 1 % special case: left column
            imgTileNumCols = dimTile(2)/2;
            mapTileCols = [1, 1];
        else
            if k == numTiles(2)+1 % special case: right column
                imgTileNumCols = dimTile(2)/2;
                mapTileCols = [numTiles(2), numTiles(2)];
            else % default values
                imgTileNumCols = dimTile(2);
                mapTileCols = [k-1, k]; % right left
            end
        end

        % loop over rows of the tileMappings cell array
        imgTileRow=1;
        for l=1:numTiles(1)+1
            if l == 1  % special case: top row
                imgTileNumRows = dimTile(1)/2; %always divisible by 2 because of padding
                mapTileRows = [1 1];
            else
                if l == numTiles(1)+1 % special case: bottom row
                    imgTileNumRows = dimTile(1)/2;
                    mapTileRows = [numTiles(1) numTiles(1)];
                else % default values
                    imgTileNumRows = dimTile(1);
                    mapTileRows = [l-1, l]; % [upperRow lowerRow]
                end
            end

            % get clahe image in each tile
            claheI(imgTileRow : imgTileRow+imgTileNumRows-1, imgTileCol:imgTileCol + imgTileNumCols - 1) ...
                = makeClaheImageFromEachTile(I, tileMappings, aLut, imgTileRow, imgTileCol, ...
                imgTileNumRows, imgTileNumCols, mapTileRows, mapTileCols);

            imgTileRow = imgTileRow + imgTileNumRows;
        end % over tile rows
        imgTileCol = imgTileCol + imgTileNumCols;
    end % over tile cols
else % Row-Major
    imgTileRow=1;
    for k = 1:numTiles(1)+1
        if k == 1  % special case: top row
            imgTileNumRows = dimTile(1)/2; % always divisible by 2 because of padding
            mapTileRows = [1 1];
        else
            if k == numTiles(1)+1 % special case: bottom row
                imgTileNumRows = dimTile(1)/2;
                mapTileRows = [numTiles(1) numTiles(1)];
            else % default values
                imgTileNumRows = dimTile(1);
                mapTileRows = [k-1, k]; % [upperRow lowerRow]
            end
        end

        % loop over columns of the tileMappings cell array
        imgTileCol=1;
        for l=1:numTiles(2)+1
            if l == 1 % special case: left column
                imgTileNumCols = dimTile(2)/2;
                mapTileCols = [1, 1];
            else
                if l == numTiles(2)+1 % special case: right column
                    imgTileNumCols = dimTile(2)/2;
                    mapTileCols = [numTiles(2), numTiles(2)];
                else % default values
                    imgTileNumCols = dimTile(2);
                    mapTileCols = [l-1, l]; % right left
                end
            end

            % get clahe image in each tile
            claheI(imgTileRow : imgTileRow + imgTileNumRows - 1, imgTileCol:imgTileCol+imgTileNumCols-1) ...
                = makeClaheImageFromEachTile(I, tileMappings, aLut, imgTileRow, imgTileCol, ...
                imgTileNumRows, imgTileNumCols, mapTileRows, mapTileCols);

            imgTileCol = imgTileCol + imgTileNumCols;
        end % over tile cols
        imgTileRow = imgTileRow + imgTileNumRows;
    end % over tile rows
end

%--------------------------------------------------------------------------
function claheImageEachTile = makeClaheImageFromEachTile(I, tileMappings, aLut, ...
    imgTileRow, imgTileCol, imgTileNumRows, imgTileNumCols, mapTileRows, mapTileCols)
coder.inline('always');
coder.internal.prefer_const(I, tileMappings, aLut, imgTileRow, imgTileCol, ...
    imgTileNumRows, imgTileNumCols, mapTileRows, mapTileCols);

% Extract four tile mappings
ulMapTile = tileMappings{mapTileRows(1), mapTileCols(1)};
urMapTile = tileMappings{mapTileRows(1), mapTileCols(2)};
blMapTile = tileMappings{mapTileRows(2), mapTileCols(1)};
brMapTile = tileMappings{mapTileRows(2), mapTileCols(2)};

% Calculate the new greylevel assignments of pixels
% within a submatrix of the image specified by imgTileIdx. This
% is done by a bilinear interpolation between four different mappings
% in order to eliminate boundary artifacts.
normFactor = imgTileNumRows * imgTileNumCols; %normalization factor

imgTileIdx = {imgTileRow : imgTileRow + imgTileNumRows - 1, ...
    imgTileCol:imgTileCol+imgTileNumCols-1};

imgPixVals = grayxform(I(imgTileIdx{1}, imgTileIdx{2}), aLut);

% calculate the weights used for linear interpolation between the
% four mappings
rowW = repmat((0:imgTileNumRows-1)', 1, imgTileNumCols);
colW = repmat(0:imgTileNumCols-1, imgTileNumRows, 1);
rowRevW = repmat((imgTileNumRows:-1:1)', 1, imgTileNumCols);
colRevW = repmat(imgTileNumCols:-1:1, imgTileNumRows, 1);

claheImageEachTile = ...
    (rowRevW .* (colRevW .* double(grayxform(imgPixVals, ulMapTile)) + ...
    colW    .* double(grayxform(imgPixVals, urMapTile)))+ ...
    rowW    .* (colRevW .* double(grayxform(imgPixVals, blMapTile)) + ...
    colW    .* double(grayxform(imgPixVals, brMapTile))))...
    /normFactor;

%-----------------------------------------------------------------------------
function claheI = adapthisteqGPUImpl(I, numTiles, dimTile, numBins, clipLimit, ...
    selectedRange, fullRange, distribution, alpha)
%adapthisteqGPUImpl is GPU specific implementation for adapthisteq.
%   claheI = adapthisteqGPUImpl(I, numTiles, dimTile, numBins, clipLimit,
%   selectedRange, fullRange, distribution, alpha) performs the
%   contrast-limited adaptive histogram equalization on input image and
%   produces the contrast enhanced image.
%
%   Input and output arguments information is given below:
%   Input Arguments:
%   I:                      Input image
%   numTiles:               Number of tiles
%   dimTile:                Dimension of tile
%   numBins:                Number of histogram bins
%   clipLimit:              Contrast enhancement limit
%   selectedRange:          selected range of input
%   fullRange:              Range of output data
%   distribution:           Desired histogram shape
%   alpha:                  Distribution parameter
%
%   Output Arguments:
%   claheI:                 Contrast enhanced image
%
%   Class Support
%   -------------
%   The input image I must be of one of the following classes: uint8,
%   uint16, int16, single, or double. Contrast enhanced image claheI,
%   returned as a 2-D matrix of the same data type as the input image I.
%

% GPU Coder pragma
coder.gpu.kernelfun;

% Total number of pixels in each tile
numPixInTile = prod(dimTile);

% Allocate size for starting and ending points of tile.
imgRow =  zeros(numTiles(1)+1,1);
imgCol =  zeros(numTiles(2)+1,1);
% Compute each tile starting and ending points.
imgRow(1) = 1;
imgCol(1) = 1;
for row = 1:numTiles(1)
    imgRow(row+1) = imgRow(row) + dimTile(1);
end
for col = 1:numTiles(2)
    imgCol(col+1) = imgCol(col) + dimTile(2);
end

% Allocate size for tile mappings
tileMappings =coder.nullcopy(zeros(numTiles(1),numTiles(2),numBins));
% Compute tile mappings for each tile
for col = 1:numTiles(2)
    for row = 1:numTiles(1)
        % Extract the tile from input
        tile = I(imgRow(row):imgRow(row+1)-1, imgCol(col):imgCol(col+1)-1);
        % For each tile calculate the histogram
        tileHist = imhist(tile, numBins);
        % Clip the histograms and redistribute the clipped part to all histograms
        tileClipHist = clipHistogram(tileHist, clipLimit, numBins);
        % Calculate the transform function for mapping
        tileMappings(row,col,:) = makeMapping(tileClipHist,...
            selectedRange, fullRange, ...
            numPixInTile, distribution, alpha);
    end
end


% Compute the LUT for looking up original image values in the tile mappings,
% which we created earlier
if ~(isa(I,'double') || isa(I,'single'))
    k = selectedRange(1)+1 : selectedRange(2)+1;
    aLut = zeros(selectedRange(2)+1,1);
    aLut(k) = (k-1) - selectedRange(1);
    aLut = aLut/(selectedRange(2)-selectedRange(1));
else
    % remap from 0..1 to 0..numBins-1
    if numBins ~= 1
        binStep = 1/(numBins-1);
        start = ceil(selectedRange(1)/binStep);
        stop  = floor(selectedRange(2)/binStep);
        k = start+1:stop+1;
        aLut = zeros(stop+1,1);
        aLut(k) = 0:1/(length(k)-1):1;
    else
        aLut = 0;
        aLut(1) = 0; %in case someone specifies numBins = 1
    end
end


% Compute starting and ending columns of each submatrix.
% Compute corresponding tileMappings for each submatrix.
imgTileNumCols =zeros(numTiles(2)+2,1);
mapTileCols = coder.nullcopy(zeros(numTiles(2)+1,2));
imgTileNumCols(1) = 1;
for k = 1:numTiles(2)+1
    if k == 1 % special case: left column
        imgTileNumCols(k+1) = imgTileNumCols(k)+dimTile(2)/2;
        mapTileCols(k,1) = 1;
        mapTileCols(k,2) = 1;
    else
        if k == numTiles(2)+1 % special case: right column
            imgTileNumCols(k+1) = imgTileNumCols(k)+dimTile(2)/2;
            mapTileCols(k,1) = numTiles(2);
            mapTileCols(k,2) = numTiles(2);

        else % default values
            imgTileNumCols(k+1) = imgTileNumCols(k)+dimTile(2);
            mapTileCols(k,1) = k-1;
            mapTileCols(k,2) = k;
        end
    end
end


% Compute starting and ending rows of each submatrix.
% Compute corresponding tileMappings for each submatrix.
imgTileNumRows =zeros(numTiles(1)+2,1);
mapTileRows = coder.nullcopy(zeros(numTiles(1)+1,2));
imgTileNumRows(1) = 1;
for l=1:numTiles(1)+1
    if l == 1  % special case: top row
        imgTileNumRows(l+1) = imgTileNumRows(l)+dimTile(1)/2;
        mapTileRows(l,1) = 1;
        mapTileRows(l,2) = 1;
    else
        if l == numTiles(1)+1 % special case: bottom row
            imgTileNumRows(l+1) = imgTileNumRows(l)+dimTile(1)/2;
            mapTileRows(l,1) = numTiles(1);
            mapTileRows(l,2) = numTiles(1);
        else % default values
            imgTileNumRows(l+1) = imgTileNumRows(l)+dimTile(1);
            mapTileRows(l,1) = l-1;
            mapTileRows(l,2) = l;
        end
    end
end


% Allocate size for clahe Image.
claheI = coder.nullcopy(zeros(size(I,1),size(I,2),'like',I));
for k = 1:numTiles(2)+1
    for l=1:numTiles(1)+1

        % Calculate the new greylevel assignments of pixels
        % within a submatrix of the image. This
        % is done by a bilinear interpolation between four different
        % mappings in order to eliminate boundary artifacts.
        imgPixVals = grayxform(I(imgTileNumRows(l) : imgTileNumRows(l+1)...
            - 1, imgTileNumCols(k):imgTileNumCols(k+1)-1), aLut);
        ulMapTile = double(grayxform(imgPixVals, ...
            tileMappings(mapTileRows(l,1), mapTileCols(k,1),:)));
        urMapTile = double(grayxform(imgPixVals, ...
            tileMappings(mapTileRows(l,1), mapTileCols(k,2),:)));
        blMapTile = double(grayxform(imgPixVals, ...
            tileMappings(mapTileRows(l,2), mapTileCols(k,1),:)));
        brMapTile = double(grayxform(imgPixVals, ...
            tileMappings(mapTileRows(l,2), mapTileCols(k,2),:)));
        normFactor = (imgTileNumRows(l+1)-imgTileNumRows(l)) * ...
            (imgTileNumCols(k+1)-imgTileNumCols(k));

        % Compute clahe image from each tile
        coder.gpu.kernel;
        for j = imgTileNumCols(k):imgTileNumCols(k+1)-1
            coder.gpu.kernel;
            for i = imgTileNumRows(l):imgTileNumRows(l+1)-1
                claheI(i,j)=((imgTileNumRows(l+1)-i)*...
                    ((imgTileNumCols(k+1)-j)*ulMapTile(i-...
                    imgTileNumRows(l)+1,j-imgTileNumCols(k)+1)...
                    +(j-imgTileNumCols(k))*urMapTile(i-imgTileNumRows(l)...
                    +1,j-imgTileNumCols(k)+1))+(i-imgTileNumRows(l))*...
                    ((imgTileNumCols(k+1)-j)*blMapTile(i-...
                    imgTileNumRows(l)+1,j-imgTileNumCols(k)+1)+...
                    (j-imgTileNumCols(k))*brMapTile(i-imgTileNumRows(l)...
                    +1,j-imgTileNumCols(k)+1)))/normFactor;
            end
        end

    end
end

%-----------------------------------------------------------------------------