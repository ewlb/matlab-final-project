function peaks = houghpeaks(varargin) %#codegen

% Copyright 2015-2021 The MathWorks, Inc.

%#ok<*EMCA>

% Supported syntax in code generation
% -----------------------------------
%     peaks = houghpeaks(H,numpeaks)
%     peaks = houghpeaks(H,numpeaks,ParameterName,ParameterValue)
%
% Input/output specs in code generation
% -------------------------------------
% H:     2-D
%        real
%        nonsparse
%        nonempty
%        finite
%        integer-valued
%        class double
%
% numpeaks:
%        scalar
%        real
%        positive
%        nonempty
%        integer-valued
%        class double
%        optional input with default value 1
%
% ParameterName can be 'Threshold', 'NHoodSize'  and 'Theta'
%
% ParameterValue for 'Threshold' must be:
%        scalar
%        real
%        non-NaN
%        non-negative
%        default: 0.5*max(H(:))
%
% ParameterValue for 'NHoodSize' must be:
%        row vector of size [1,2]
%        real
%        finite
%        positive
%        odd
%        integer-valued
%        default: size(H)/50
%
% ParameterValue for 'Theta' must be:
%        vector
%        real
%        finite
%        integer-valued
%        default: -90:89
%
% peaks:
%        Q-by-2 matrix with 0 <= Q <= numpeaks
%        double
%

[H, maxNumPeaks, threshold, nhoodSize, theta] = parseInputs(varargin{:});

% If either input is empty, return empty
if (numel(H) < 1 || numel(maxNumPeaks) < 1 || numel(threshold) < 1 || numel(nhoodSize) < 2)
    peaks = [];
    return;
end

numRowH = coder.internal.indexInt(size(H,1));
numColH = coder.internal.indexInt(size(H,2));

% Initialize the loop variables
isDone = false;
hnew = H;

nhoodCenter_i = coder.internal.indexInt((nhoodSize(1)-1)/2);
nhoodCenter_j = coder.internal.indexInt((nhoodSize(2)-1)/2);

% Allocate enough memory for the maximum number of peaks
% without using runtime memory alloc
if coder.internal.isConst(maxNumPeaks)
    peakCoordinates = coder.nullcopy(zeros(maxNumPeaks,2));
else
    peakCoordinates = coder.nullcopy(zeros(numel(H),2));
end

% Counter on the number of peaks that we found
peakIdx = coder.internal.indexInt(0);

minTheta = min(theta);
maxTheta = max(theta);
thetaResolution = abs(maxTheta - minTheta) / (numel(theta)-1);
isThetaAntisymmetric = abs(minTheta+thetaResolution*nhoodSize(2)) <= maxTheta;

%  Gpu Enabled condition is added here.
if (coder.gpu.internal.isGpuEnabled)
    % gpu specific implementation for 'houghpeaks' is called here.
    peaks =  images.internal.coder.gpu.houghpeaksGPUImpl(hnew, maxNumPeaks, threshold, nhoodSize,isThetaAntisymmetric);
    return;
end

while ~isDone
    % [iPeak,jPeak] : Coordinates of the peak   
    % numRowH       : number of rows in Hough matrix (H)
    
    if numRowH < 1200 && coder.isColumnMajor
        % With numRowH less than ~1000 (240p images), indexing is faster
        % with CRL set to Intel AVX.
        % Tested on Intel(R) Xeon(R) CPU E5-1650 v4 @ 3.60GHz
        [~,idx] = max(hnew(:));
        [iPeak,jPeak] = ind2sub(size(hnew),idx);
        iPeak = coder.internal.indexInt(iPeak);
        jPeak = coder.internal.indexInt(jPeak);
    else
        % All other input sizes
        [iPeak,jPeak] = getLocationOfMax(hnew);
    end

    if hnew(iPeak,jPeak) >= threshold(1)
        % Add the peak to the list
        peakIdx = peakIdx + 1;
        peakCoordinates(peakIdx,1) = iPeak;
        peakCoordinates(peakIdx,2) = jPeak;
        
        % Set this maximum and its close neighbors to 0.
        % The neighborhood is within [rhoMin,rhoMax] and [thetaMin,thetaMax]
        
        % rho axis = vertical direction = i
        rhoMin = iPeak - nhoodCenter_i;
        rhoMax = iPeak + nhoodCenter_i;
        
        % theta axis = horizontal direction = j
        thetaMin = jPeak - nhoodCenter_j;
        thetaMax = jPeak + nhoodCenter_j;
        
        % Throw away neighbor coordinates that are out of bounds in
        % the rho direction (first dimension) by clamping.
        
        % p1 <- max(p1,1)
        if (rhoMin < coder.internal.indexInt(1))
            rhoMin = coder.internal.indexInt(1);
        end
        
        % p2 <- min(p2,M)
        if (rhoMax > coder.internal.indexInt(numRowH))
            rhoMax = coder.internal.indexInt(numRowH);
        end
        
        for theta = thetaMin:thetaMax
            for rho = rhoMin:rhoMax
                % Coordinates to set to 0
                rhoToRemove = rho;
                thetaToRemove = theta;
                
                % For coordinates that are out of bounds in the theta
                % direction, we want to consider that H is antisymmetric
                % along the rho axis for theta = +/- 90 degrees.
                if isThetaAntisymmetric
                    % Wrap theta coordinates around by antisymmetry
                    if (thetaToRemove > numColH)
                        rhoToRemove = numRowH - rhoToRemove + 1;
                        thetaToRemove = thetaToRemove - numColH;
                    elseif (thetaToRemove < 1)
                        rhoToRemove = numRowH - rhoToRemove + 1;
                        thetaToRemove = thetaToRemove + numColH;
                    end
                end
                
                % Skip coordinates that are out of bounds in the theta
                % direction.
                if (thetaToRemove > numColH) || (thetaToRemove < 1)
                    continue;
                end
                
                % Set to 0
                hnew(rhoToRemove,thetaToRemove) = 0;
            end
        end        
        isDone = (peakIdx == coder.internal.indexInt(maxNumPeaks));
    else
        isDone = true;
    end
end

% Return double([]) just like in simulation in case no peaks are found
if (peakIdx == coder.internal.indexInt(0))
    peaks = [];
else
    % If we found fewer peaks than the max number,
    % return a truncated array of the right size
    peaks = peakCoordinates(1:peakIdx,:);
end

%--------------------------------------------------------------------------
function [iMax,jMax] = getLocationOfMax(A)

coder.inline('always');
coder.internal.prefer_const(A);

% Coordinates of the max value
iMax = coder.internal.indexInt(0);
jMax = coder.internal.indexInt(0);

N = coder.internal.indexInt(size(A,1));
M = coder.internal.indexInt(size(A,2));

if coder.isColumnMajor
    % Arrays to store max value in each column and its index
    maxarray = zeros(M,1);
    indarray = zeros(M,1);
    
    parfor i = 1:M
        tempmax = A(1,i);
        tempidx = coder.internal.indexInt(1);
        for j = 2:N
            temp = A(j,i);
            if temp > tempmax
                tempmax = temp;
                tempidx = j;
            end
        end
        maxarray(i) = tempmax;
        indarray(i) = tempidx;
    end
    
    % A is supposed to be >= 0 so -1 is ok
    maxVal = cast(-1,'like',A);
    
    for i = 1:M
        if maxarray(i) > maxVal
            maxVal = maxarray(i);
            jMax = i;
            iMax = coder.internal.indexInt(indarray(i));
        end
    end
    
else
    maxarray = zeros(N,1);
    indarray = zeros(N,1);
    
    parfor i = 1:N
        tempmax = A(i,1);
        tempidx = coder.internal.indexInt(1);
        for j = 2:M
            if A(i,j) > tempmax
                tempmax = A(i,j);
                tempidx = j;
            end
        end
        maxarray(i) = tempmax;
        indarray(i) = tempidx;
    end
    
    maxVal = cast(-1,'like',A);
    
    for i = 1:N
        if maxarray(i) > maxVal
            maxVal = maxarray(i);
            iMax = i;
            jMax = coder.internal.indexInt(indarray(i));
        end
    end
end

%--------------------------------------------------------------------------
function [H, maxNumPeaks, threshold, nhoodSize, theta] = parseInputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);

narginchk(1,8);

H = varargin{1};
validateattributes(H,{'double'}, ...
    {'real','2d','nonsparse','nonempty','finite','integer'}, ...
    mfilename,'H',1);

% Set default value for numpeaks
maxNumPeaks = coder.internal.indexInt(1);

% Set default value for Threshold
thresholdDefault = computeDefaultThreshold(H);

% Set default value for NHoodSize
nhoodSizeDefault = computeDefaultNhoodSize(H);

% Set default value for Theta
thetaDefault = -90:89;

% Parse optional input arguments

if nargin > 1
    % If second input is numpeaks
    if ~ischar(varargin{2})
        % Validate numpeaks
        maxNumPeaksIn = varargin{2};
        validateattributes(maxNumPeaksIn,{'double'}, ...
            {'real','scalar','integer','positive','nonempty'}, ...
            mfilename,'NUMPEAKS',2);
        % Cast to an integer for the rest of the code
        maxNumPeaks = coder.internal.indexInt(maxNumPeaksIn(1));
        beginIdx = 3;
    else
        beginIdx = 2;
    end
    [threshold,nhoodSize,theta] = parseNameValuePairs(thresholdDefault, ...
        nhoodSizeDefault, ...
        thetaDefault, ...
        varargin{beginIdx:end});
else
    threshold = thresholdDefault;
    nhoodSize = nhoodSizeDefault;
    theta = thetaDefault;
end

% Validate threshold
validateThreshold(threshold,mfilename);

% Validate nhoodSize,
% And continue with the enforced size of [1 2] done by validateNHoodSize.
nhoodSize = validateNHoodSize(nhoodSize,mfilename,H);

% Validate Theta
validateTheta(theta,mfilename);

%--------------------------------------------------------------------------
function [threshold,nhoodSize,theta] = parseNameValuePairs(thresholdDefault, ...
    nhoodSizeDefault, ...
    thetaDefault, ...
    varargin)
% Parse optional PV pairs - 'Threshold', 'NHoodSize' and 'Theta'
coder.inline('always');
coder.internal.prefer_const(varargin);

params = struct( ...
    'Threshold', uint32(0), ...
    'NHoodSize', uint32(0), ...
    'Theta', uint32(0));

options = struct( ...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

optarg = eml_parse_parameter_inputs(params,options,varargin{:});

threshold = eml_get_parameter_value( ...
    optarg.Threshold, ...
    thresholdDefault, ...
    varargin{:});

nhoodSize = eml_get_parameter_value( ...
    optarg.NHoodSize, ...
    nhoodSizeDefault, ...
    varargin{:});

thetaVal = eml_get_parameter_value( ...
    optarg.Theta, ...
    thetaDefault, ...
    varargin{:});

if iscolumn(thetaVal)
    theta = thetaVal';
else
    theta = thetaVal;
end

%--------------------------------------------------------------------------
function thresholdDefault = computeDefaultThreshold(H)

coder.inline('always');
coder.internal.prefer_const(H);

maxVal = 0;

if coder.isColumnMajor
    numElems = numel(H);

    for k = 1:numElems
        val = H(k);
        if (val > maxVal)
            maxVal = val;
        end
    end
else
    for p = 1:size(H,1)
        for q = 1:size(H,2)
            val = H(p,q);
            if (val > maxVal)
                maxVal = val;
            end
        end
    end
end
thresholdDefault = 0.5 * maxVal;

%--------------------------------------------------------------------------
function nhoodSizeDefault = computeDefaultNhoodSize(H)

coder.inline('always');
coder.internal.prefer_const(H);

[M,N] = size(H);

nhoodSizeDefault = [M,N] / 50;

% Make sure the nhood size is odd
nhoodSizeDefault = max(2*ceil(nhoodSizeDefault/2) + 1, 1);

% Edge case where the input transform is smaller than the smallest default
% neighborhood size of 3-by-3
if M < 3
    nhoodSizeDefault(1) = 1;
end
if N < 3
    nhoodSizeDefault(2) = 1;
end

%--------------------------------------------------------------------------
function validateThreshold(threshold,fileName)

coder.inline('always');
coder.internal.prefer_const(threshold,fileName);

inputStr = 'Threshold';

validateattributes(threshold,{'double'}, ...
    {'real','scalar','nonnan','nonnegative'}, ...
    fileName, inputStr);

%--------------------------------------------------------------------------
function nhoodSize = validateNHoodSize(nhoodSize,fileName,H)

coder.inline('always');
coder.internal.prefer_const(nhoodSize,fileName);

inputStr = 'NHoodSize';

validateattributes(nhoodSize,{'double'}, ...
    {'real','vector','finite','integer','positive','odd'}, ...
    fileName, inputStr);

[M,N] = size(nhoodSize);

% NHoodSize should be a 1-by-2 vector
coder.internal.errorIf(any([M,N] ~= [1,2]), ...
    'images:houghpeaks:invalidNHoodSize', inputStr);

% Now that it's 1x2, inform inference
nhoodSize = [nhoodSize(1) nhoodSize(2)];

% The neighborhood cannot be larger than the Hough transform
coder.internal.errorIf(any(nhoodSize > size(H)), ...
    'images:houghpeaks:tooBigNHoodSize', inputStr);
%--------------------------------------------------------------------------
function validateTheta(theta,fileName)

coder.inline('always');
coder.internal.prefer_const(theta,fileName);

inputStr = 'Theta';

validateattributes(theta, {'double'}, {'nonempty', 'real',...
    'vector','finite'}, mfilename, inputStr);

coder.internal.errorIf(min(theta) < -90,...
    'images:houghpeaks:invalidThetaMin', inputStr);

coder.internal.errorIf(max(theta) >= 90,...
    'images:houghpeaks:invalidThetaMax', inputStr)

% Theta vector must be evenly spaced.
thetaInterval = diff(theta);
coder.internal.errorIf(abs(sum(diff(thetaInterval))) > sqrt(eps),...
    'images:houghpeaks:invalidThetaVectorSpacing');
