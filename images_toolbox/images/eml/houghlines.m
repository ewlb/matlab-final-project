function lines = houghlines(varargin) %#codegen

% Copyright 2015-2021 The MathWorks, Inc.

%#ok<*EMCA>

% Supported syntax in code generation
% -----------------------------------
%     lines = houghlines(BW,theta,rho,peaks)
%     lines = houghlines(BW,theta,rho,peaks,ParameterName,ParameterValue)
%
% Input/output specs in code generation
% -------------------------------------
% BW:    2-D
%        real
%        non-sparse
%        non-empty
%        logical or numeric: uint8, uint16, uint32, uint64,
%                            int8, int16, int32, int64, single, double
%
% theta:    
%        realcd 
%        vector
%        finite
%        non-empty
%        non-sparse
%        class double only
%
% rho:
%        real
%        vector
%        finite
%        non-empty
%        non-sparse
%        class double only
%
% peaks:
%        real
%        2-D
%        size(peaks,2) must be 2
%        nonsparse
%        positive
%        integer
%        class double only
%
% ParameterName can be 'FillGap' and 'MinLength'
%
% ParameterValue for 'FillGap' must be:
%        scalar
%        real
%        finite
%        positive
%        class double only
%        default: 20.0
%
% ParameterValue for 'MinLength' must be:
%        scalar
%        real
%        finite
%        positive
%        class double only
%        default: 40.0
%
% lines:
%        structure array
%        length equals the number of merged line segments found
%        has these fields:
%             point1: 1x2 double vector; end point of the line segment
%             point2: 1x2 double vector; other end point of the line segment
%             theta:  double scalar; angle of the Hough transform bin (degree)
%             rho:    double scalar; rho-axis position of the bin
%

[BW,theta,rho,peaks,fillGap,minLength] = parseInputs(varargin{:});

% Gpu Enabled condition is added here.
if (coder.gpu.internal.isGpuEnabled)
    % gpu specific implementation for 'houghlines' is called here.
    lines = images.internal.coder.gpu.houghlinesGPUImpl(BW, theta, rho, peaks, fillGap, minLength);
    return;
end

% OpenMP enabled for images larger images.
% Threshold based on UPT test data.
parforThreshold = 2500;
useParfor = ~ coder.internal.isInParallelRegion() && numel(BW) > parforThreshold;

coder.internal.prefer_const(useParfor);

if (useParfor)
    [nonZeroPixelMatrix, tempNumsVector] = findNonZeroOmp(BW);
else
    [nonZeroPixelMatrix, tempNumsVector] = findNonZero(BW);
end

minLength2 = minLength^2;
numLines = coder.internal.indexInt(0);

% These variable size arrays store the output temporarily, because you
% can't grow a struct array in codegen.
coder.varsize('point1Array',[Inf,2],[1,0]);
point1Array = coder.internal.indexInt(zeros(0,2));

coder.varsize('point2Array',[Inf,2],[1,0]);
point2Array = coder.internal.indexInt(zeros(0,2));

coder.varsize('thetaArray',[Inf,1],[1,0]);
thetaArray = single(zeros(0,1));

coder.varsize('rhoArray',[Inf,1],[1,0]);
rhoArray = single(zeros(0,1));

firstRho = double(rho(1));
numRho = numel(rho);
lastRho = double(rho(numRho));
slope = double((numRho - 1)) / double(lastRho - firstRho);

% For all peaks
numPeaks = size(peaks,1);
for peakIdx = 1:numPeaks    
    % Coordinates of the current peak
    peak1 = coder.internal.indexInt(peaks(peakIdx,1));
    peak2 = coder.internal.indexInt(peaks(peakIdx,2));
    
    % Get all pixels associated with the Hough transform cell (peak1,peak2)
    if (useParfor)
        [numHoughPix,houghPix] = getHoughPixelsOmp(nonZeroPixelMatrix,theta,firstRho,slope,peak1,peak2,tempNumsVector);
    else
        [numHoughPix,houghPix] = getHoughPixels(nonZeroPixelMatrix,theta,firstRho,slope,peak1,peak2,tempNumsVector);
    end
    
    if (numHoughPix < 1)
        continue
    end
    
    % Find the gaps between points that are larger than the threshold
    indices = findGapsLargerThanThresh(houghPix, fillGap);
    
    % For each line, return it if it is longer than minLength
    for k = 1:numel(indices)-1
        % xy coordinates of the two ends of a line
        point1 = houghPix(indices(k)+1,:); % +1 is for 1-based indexing
        point2 = houghPix(indices(k+1),:); % don't offset by 1 this time
        
        lineLength2 = computeLineLength(point1,point2);
        if (lineLength2 >= minLength2)
            % Count the number of lines found
            numLines = numLines+1;
            % Add to the output
            point1Array = [point1Array; point1(2) point1(1)]; %#ok<*AGROW>
            point2Array = [point2Array; point2(2) point2(1)];
            thetaArray  = [thetaArray; single(theta(peak2))];
            rhoArray    = [rhoArray; single(rho(peak1))];
        end
    end
end

% Populate the output struct array
lines = convertToStructArray(numLines,point1Array,point2Array,thetaArray,rhoArray);

%--------------------------------------------------------------------------
function [nonZeroPixelMatrix, tempNumsVector] = findNonZero(BW)

% In case of Column Major, x-coordinate (row number) of all non-zero pixels
% in each column is stored in the corresponding column in
% 'nonZeroPixelMatrix'. The number of non-zero pixels in each column is
% stored in 'tempNumsVector'. 
% In case of row-major, y-coordinate (column number) of all non-zero pixels
% are stored similarly, in 'nonZeroPixelMatrix' and the number of non-zero
% pixels in each row is stored in 'tempNumsVector'.

coder.inline('always');
coder.internal.prefer_const(BW);

[numRow,numCol] = size(BW);

nonZeroPixelMatrix = coder.nullcopy(coder.internal.indexInt(zeros(size(BW))));

if coder.isColumnMajor
    % Get x-coordinates of non-zero pixels (0-based)
    % Store number of non-zero pixels in each column
    tempNumsVector =  coder.internal.indexInt(zeros(numCol,1));
    
    for j = 1:numCol
        % Count number of non-zero pixels in each column
        tempNum = 0;
        for i = 1:numRow
            if BW(i,j) > 0
                tempNum = tempNum + 1;
                % Store x-coordinate of non-zero pixels in each column
                nonZeroPixelMatrix(tempNum,j) = i-1; % x-coordinate, 0-based
            end
        end
        tempNumsVector(j) = tempNum; % Total num of non-zero pixels in each column
    end
else
    % Get y-coordinates of non-zero pixels (0-based)
    % Store number of non-zero pixels in each row
    tempNumsVector =  coder.internal.indexInt(zeros(numRow,1));
    
    for i = 1:numRow
        % Count number of non-zero pixels in each row
        tempNum = 0;
        for j = 1:numCol
            if BW(i,j) > 0
                tempNum = tempNum + 1;
                % Store y-coordinate of non-zero pixels in each row
                nonZeroPixelMatrix(i,tempNum) = j-1; % y-coordinate, 0-based
            end
        end
        tempNumsVector(i) = tempNum;
    end
end

%--------------------------------------------------------------------------
function [nonZeroPixelMatrix, tempNumsVector] = findNonZeroOmp(BW)
% Utilizes OpenMP library, in the generated code.
% In case of Column Major, x-coordinate (row number) of all non-zero pixels
% in each column is stored in the corresponding column in
% 'nonZeroPixelMatrix'. The number of non-zero pixels in each column is
% stored in 'tempNumsVector'. 
% In case of row-major, y-coordinate (column number) of all non-zero pixels
% are stored similarly, in 'nonZeroPixelMatrix' and the number of non-zero
% pixels in each row is stored in 'tempNumsVector'.

coder.inline('always');
coder.internal.prefer_const(BW);

[numRow,numCol] = size(BW);

nonZeroPixelMatrix = coder.nullcopy(coder.internal.indexInt(zeros(size(BW))));

if coder.isColumnMajor
    % Get x-coordinates of non-zero pixels (0-based)
    % Store number of non-zero pixels in each column
    tempNumsVector =  coder.internal.indexInt(zeros(numCol,1));
    
    parfor j = 1:numCol
        % Temporary bin to store x-coordinate of non-zero pixels in each column
        tempBin = coder.nullcopy((zeros(numRow,1)));
        % Count number of non-zero pixels in each column
        tempNum = 0;
        % Assignment loop split into two, with help of 'tempBin', to avoid
        % random indexing.
        for i = 1:numRow
            if BW(i,j) > 0
                tempNum = tempNum + 1; % Number of non-zero pixels
                tempBin(tempNum) = i-1; % x-coordinate, 0-based
            end
        end
        tempNumsVector(j) = tempNum;
        for i = 1:numRow
            if i > tempNum
                break;
            end
            nonZeroPixelMatrix(i,j) = tempBin(i); % Update x-values for each column
        end
    end
else
    % Get coordinates of non-zero pixels (0-based)
    % Store number of non-zero pixels in each row
    tempNumsVector =  coder.internal.indexInt(zeros(numRow,1));
    
    parfor i = 1:numRow
        % Temporary bin to store y-coordinate of non-zero pixels in each row
        tempBin = coder.nullcopy((zeros(numCol,1)));
        % Count number of non-zero pixels in each row
        tempNum = 0;
        % Assignment loop split into two, with help of 'tempBin', to avoid
        % random indexing.
        for j = 1:numCol
            if BW(i,j) > 0
                tempNum = tempNum + 1; % Number of non-zero pixels
                tempBin(tempNum) = j-1; % y-coordinate, 0-based
            end
        end
        tempNumsVector(i) = tempNum;
        for j = 1:numCol
            if j > tempNum
                break;
            end
            nonZeroPixelMatrix(i,j) = tempBin(j); % Update y-values for each row
        end
    end
end

%--------------------------------------------------------------------------
function y = roundAndCastInt(x)

coder.inline('always');
coder.internal.prefer_const(x);

% Only works for x >= 0, which is always the case here
y = coder.internal.indexInt(x+0.5);

%--------------------------------------------------------------------------
function [numHoughPix,houghPix] = getHoughPixels(nonZero,theta,firstRho,slope,peak1,peak2,tempNumsVector)
% Search over the non-zero pixels of the input image to find the points
% (Hough pixels) associated with the bin (theta,rho) corresponding to the current peak.

coder.inline('always');
[numRow,numCol] = size(nonZero);
coder.internal.prefer_const(nonZero,theta,firstRho,slope,peak1,peak2,numRow,numCol);

numHoughPix = coder.internal.indexInt(0); % store total number of hough pixels
thetaVal = double(theta(peak2)) * double(pi) / double(180);
cosTheta = cos(thetaVal);
sinTheta = sin(thetaVal);
rowMax = 0; % store maximum row value among hough pixels
rowMin = Inf; % store minimum row value among hough pixels
colMax = 0; % store maximum column value among hough pixels
colMin = Inf; % store minimum column value among hough pixels
% store coordinate of valid hough pixels
houghPixIdx = coder.nullcopy(coder.internal.indexInt(zeros(numel(nonZero),2)));

% For all non zero pixels, find pixels that satisfy the parametric
% equation corresponding to the current peak("Hough pixels"). Find the pixels with maximum
% and minimum coordinate values (possible endpoints of the line).

if coder.isColumnMajor
    for j = 1:numCol
        for i = 1:tempNumsVector(j)
            % y-coordinate of pixel is same as column index, and
            % x-coordinated is stored in 'nonZero' matrix.
            % (i,j) is a point on the line associated with the current peak if it
            % satisfies the equation rho = j * cos(theta) + i * sin(theta)
            rhoVal = double(j-1)* cosTheta + double(nonZero(i,j))  * sinTheta;
            rhoBinIdx = coder.internal.indexInt(roundAndCastInt(slope*(rhoVal - firstRho) + 1));
            % Check pixel aganist parametric equation
            if (rhoBinIdx == peak1)
                numHoughPix = numHoughPix + coder.internal.indexInt(1); % count of valid pixels.
                houghPixIdx(numHoughPix,1) = nonZero(i,j)+1; % r (1-based) = y (0-based)
                houghPixIdx(numHoughPix,2) = j; % c (1-based) = x (0-based)
                rowMax = max(rowMax,double(houghPixIdx(numHoughPix,1)));
                rowMin = min(rowMin,double(houghPixIdx(numHoughPix,1)));
                colMax = max(colMax,double(j));
                colMin = min(colMin,double(j));
            end
        end
    end
else
    for i = 1:numRow
        for j= 1:tempNumsVector(i)
            % x-coordinate of pixel is same as row index, and
            % y-coordinated is stored in 'nonZero' matrix.
            % (i,j) is a point on the line associated with the current peak if it
            % satisfies the equation rho = j * cos(theta) + i * sin(theta)           
            rhoVal = double(nonZero(i,j)) * cosTheta + double(i-1) * sinTheta;
            rhoBinIdx = coder.internal.indexInt(roundAndCastInt(slope*(rhoVal - firstRho) + 1));
            % Check pixel aganist parametric equation
            if (rhoBinIdx == peak1)
                numHoughPix = numHoughPix + coder.internal.indexInt(1); % count of valid pixels.
                houghPixIdx(numHoughPix,1) = i; % r (1-based) = y (0-based)
                houghPixIdx(numHoughPix,2) = nonZero(i,j)+1; % c (1-based) = x (0-based)
                rowMax = max(rowMax,double(i));
                rowMin = min(rowMin,double(i));
                colMax = max(colMax,double(houghPixIdx(numHoughPix,2)));
                colMin = min(colMin,double(houghPixIdx(numHoughPix,2)));
            end
        end
    end
end

if (numHoughPix < 1)
    houghPix = coder.internal.indexInt([]);
    return
end

% Sorting: make sure that r an c are in order along the line segment

% The max range determines along which direction to sort the indices
rowRange = rowMax - rowMin;
colRange = colMax - colMin;

if (rowRange > colRange)
    % Sort on r first, then on c
    sortingOrder = [1,2];
else
    % Sort on c first, then on r
    sortingOrder = [2,1];
end

% Sort the row-column pairs in ascending order
houghPix = sortrows(houghPixIdx(1:numHoughPix,:), sortingOrder);


%--------------------------------------------------------------------------
function [numHoughPix,houghPix] = getHoughPixelsOmp(nonZero,theta,firstRho,slope,peak1,peak2,tempNumsVector)
% Utilizes OpenMP library.
% Search over the non-zero pixels of the input image to find the points
% (Hough pixels) associated with the bin (theta,rho) corresponding to the current peak.

coder.inline('always');
[numRow,numCol] = size(nonZero);
coder.internal.prefer_const(nonZero,theta,firstRho,slope,peak1,peak2,numRow,numCol);

numHoughPix = coder.internal.indexInt(0); % store total number of hough pixels
thetaVal = double(theta(peak2)) * double(pi) / double(180);
cosTheta = cos(thetaVal);
sinTheta = sin(thetaVal);
rowMax = 0; % store maximum row value among hough pixels
rowMin = Inf; % store minimum row value among hough pixels
colMax = 0; % store maximum column value among hough pixels
colMin = Inf; % store minimum column value among hough pixels
% store coordinate of valid hough pixels
houghPixTemp = coder.nullcopy(coder.internal.indexInt(zeros(size(nonZero))));

% For all non zero pixels, find pixels that satisfy the parametric
% equation corresponding to the current peak("Hough pixels"). Find the pixels with maximum
% and minimum coordinate values (possible endpoints of the line).

if coder.isColumnMajor
    % Store number of hough pixels in each column.
    tempHoughPixNumsVector = coder.nullcopy(coder.internal.indexInt(zeros(numCol,1)));
    parfor k = 1:numCol
        % rho = x*cos(theta) + y*sin(theta)
        tempBin =  coder.nullcopy(coder.internal.indexInt(zeros(numRow,1)));
        tempNum = coder.internal.indexInt(0);
        
        for j= 1:tempNumsVector(k)
            % y-coordinate of pixel is same as column index, and
            % x-coordinated is stored in 'nonZero' matrix.
            rhoVal = double(k-1)* cosTheta + double(nonZero(j,k))  * sinTheta;
            rhoBinIdx = coder.internal.indexInt(roundAndCastInt(slope*(rhoVal - firstRho) + 1));
            % k is a point on the line associated with the current peak if it
            % satisfies the equation rho = x*cos(theta) + y*sin(theta)
            if (rhoBinIdx == peak1)
                tempNum = tempNum + coder.internal.indexInt(1); % count of valid pixels in each column.
                tempBin(tempNum) = nonZero(j,k)+1; % y-coordinate 1-based
            end
        end
        
        % Update count of hough pixels in current column
        tempHoughPixNumsVector(k) = coder.internal.indexInt(tempNum);
        % Update total count of hough pixels
        numHoughPix = numHoughPix + coder.internal.indexInt(tempNum);
        % Find maxima and minima (possible end points of line)
        if tempNum
            rowMax = max(rowMax,double(tempBin(tempNum)));
            rowMin = min(rowMin,double(tempBin(1)));
            colMax = max(colMax,double(k));
            colMin = min(colMin,double(k));
        end
        
        % Store y-coordinate of hough pixel
        for i = 1:numRow
            if i > tempNum
                break;
            end
            houghPixTemp(i,k) = tempBin(i); % 1-based
        end
    end
else
    % Store number of hough pixels in each row.
    tempHoughPixNumsVector = coder.nullcopy(coder.internal.indexInt(zeros(numRow,1)));
    parfor k = 1:numRow
        % rho = x*cos(theta) + y*sin(theta)
        tempBin =  coder.nullcopy(coder.internal.indexInt(zeros(numCol,1)));
        tempNum = coder.internal.indexInt(0);
        for j= 1:tempNumsVector(k)
            % x-coordinate of pixel is same as row index, and
            % y-coordinated is stored in 'nonZero' matrix.
            rhoVal = double(nonZero(k,j)) * cosTheta + double(k-1) * sinTheta;
            rhoBinIdx = coder.internal.indexInt(roundAndCastInt(slope*(rhoVal - firstRho) + 1));
            % Check pixel aganist parametric equation
            if (rhoBinIdx == peak1)
                tempNum = tempNum + coder.internal.indexInt(1);
                tempBin(tempNum) = nonZero(k,j)+1; % x-coordinate 1-based
            end
        end
        
        tempHoughPixNumsVector(k) = coder.internal.indexInt(tempNum); % num hough pixels in row
        numHoughPix = numHoughPix + coder.internal.indexInt(tempNum); % total num hough pixels
        
        if tempNum
            rowMax = max(rowMax,double(k));
            rowMin = min(rowMin,double(k));
            colMax = max(colMax,double(tempBin(tempNum)));
            colMin = min(colMin,double(tempBin(1)));
        end
        % Store x-coordinate of hough pixel
        for i = 1:numCol
            if i > tempNum
                break;
            end
            houghPixTemp(k,i) = tempBin(i); % 1-based
        end
    end
end

if (numHoughPix < 1)
    houghPix = coder.internal.indexInt([]);
    return
end

% Do a second pass to get the hough pixel coordinates
houghPixIdx = coder.nullcopy(coder.internal.indexInt(zeros(numel(nonZero),2)));
n = 0;
if coder.isColumnMajor
    for k = 1:numCol
        for j= 1:tempHoughPixNumsVector(k)
            n = n+1;
            houghPixIdx(n,1) = houghPixTemp(j,k); % r (1-based) = y (0-based)
            houghPixIdx(n,2) = k; % c (1-based) = x (0-based)
        end
    end
else
    for k = 1:numRow
        for j= 1:tempHoughPixNumsVector(k)
            n = n+1;
            houghPixIdx(n,1) = k; % r (1-based) = y (0-based)
            houghPixIdx(n,2) = houghPixTemp(k,j); % c (1-based) = x (0-based)
        end
    end
end
% Sorting: make sure that r an c are in order along the line segment

% The max range determines along which direction to sort the indices
rowRange = rowMax - rowMin;
colRange = colMax - colMin;

if (rowRange > colRange)
    % Sort on r first, then on c
    sortingOrder = [1,2];
else
    % Sort on c first, then on r
    sortingOrder = [2,1];
end

% Sort the row-column pairs in ascending order
houghPix = sortrows(houghPixIdx(1:numHoughPix,:), sortingOrder);

%--------------------------------------------------------------------------
function indices = findGapsLargerThanThresh(houghPix, fillGap)
% Points that are less than fillGap away from each other are considered to
% belong to the same line. They are "merged" into a single line.
% indices contains the indices (in houghPix) of the end points of these 
% lines.

coder.inline('always');

numHoughPix = size(houghPix,1);
fillGap2 = fillGap^2;
coder.internal.prefer_const(fillGap2);

% Compute the squared distances between the point pairs
distances2 = coder.nullcopy(zeros(numHoughPix-1,1));
numPairs = 0;
for k = 1:numHoughPix-1
    % d^2 = (y_k+1 - y_k)^2 + (x_k+1 - x_k)^2
    distances2(k) = (houghPix(k+1,1) - houghPix(k,1))^2 + ...
                    (houghPix(k+1,2) - houghPix(k,2))^2;
    % Count the number of pairs that satisfy the gap threshold
    if (distances2(k) > fillGap2)
        numPairs = numPairs+1;
    end
end

% Get the indices of the pairs that satisfy the gap threshold
indices      = coder.nullcopy(zeros(numPairs+2,1));
indices(1)   = 0;
indices(end) = numHoughPix;
n = 1;
for k = 1:numHoughPix-1
    if (distances2(k) > fillGap2)
        n = n+1;
        indices(n) = k;
    end
end

%--------------------------------------------------------------------------
function lineLength2 = computeLineLength(point1,point2)

coder.inline('always');
coder.internal.prefer_const(point1,point2);

% d^2 = (x2-x1)^2 + (y2-y1)^2
lineLength2 = (point2(1)-point1(1))^2 + (point2(2)-point1(2))^2;

%--------------------------------------------------------------------------
function lines = convertToStructArray(numLines,point1Array,point2Array,thetaArray,rhoArray)

coder.inline('always');
coder.internal.prefer_const(numLines,point1Array,point2Array,thetaArray,rhoArray);

% Initialize the output based on the number of lines found
lines = initializeStructArray(numLines);

% Populate the output struct array
for k = 1:numLines
    lines(k).point1 = double(point1Array(k,:));
    lines(k).point2 = double(point2Array(k,:));
    lines(k).theta  = double(thetaArray(k));
    lines(k).rho    = double(rhoArray(k));
end

%--------------------------------------------------------------------------
function lines = initializeStructArray(numLines)

coder.inline('always');
coder.internal.prefer_const(numLines);

tmp.point1 = [0,0];
tmp.point2 = [0,0];
tmp.theta  = 0;
tmp.rho    = 0;

lines = repmat(tmp,1,numLines);

%--------------------------------------------------------------------------
function [BW,theta,rho,peaks,fillGap,minLength] = parseInputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);

narginchk(4,8);

% Validate BW
BW = varargin{1};
validateattributes(BW, {'numeric','logical'}, ...
    {'real','2d','nonsparse','nonempty'}, ...
    mfilename,'BW',1);

% Validate theta
theta = varargin{2};
validateattributes(theta, {'double'}, ...
    {'real','vector','finite','nonsparse','nonempty'}, ...
    mfilename,'THETA',2);

% Validate rho
rho = varargin{3};
validateattributes(rho, {'double'}, ...
    {'real','vector','finite','nonsparse','nonempty'}, ...
    mfilename,'RHO',3);

% Validate peaks
peaks = varargin{4};
validateattributes(peaks, {'double'}, ...
    {'real','2d','nonsparse','positive', 'integer'}, ...
    mfilename,'PEAKS',4);

coder.internal.errorIf(size(peaks,2) ~= 2, ...
    'images:houghlines:invalidPEAKS');

% Set the defaults
fillGapDefault   = 20; 
minLengthDefault = 40; 

% Parse optional parameters
[fillGap_,minLength_] = parseNameValuePairs(fillGapDefault, ...
                                          minLengthDefault, ...
                                          varargin{5:end});
% Validate FillGap
validateattributes(fillGap_, {'double'}, ...
    {'finite','real','scalar','positive'}, ...
    mfilename,'FillGap');

% Validate MinLength
validateattributes(minLength_, {'double'}, ...
    {'finite','real','scalar','positive'}, ...
    mfilename,'MinLength');

fillGap = fillGap_(1);
minLength = minLength_(1);

%--------------------------------------------------------------------------
function [fillGap,minLength] = parseNameValuePairs(fillGapDefault, ...
                                                   minLengthDefault, ...
                                                   varargin)
                                               
coder.inline('always');
coder.internal.prefer_const(fillGapDefault,minLengthDefault,varargin);

params = struct( ...
    'FillGap', uint32(0), ...
    'MinLength', uint32(0));

options = struct( ...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

optarg = eml_parse_parameter_inputs(params,options,varargin{:});

fillGap = eml_get_parameter_value( ...
    optarg.FillGap, ...
    fillGapDefault, ...
    varargin{:});

minLength = eml_get_parameter_value( ...
    optarg.MinLength, ...
    minLengthDefault, ...
    varargin{:});
