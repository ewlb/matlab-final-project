function [h, theta, rho] = hough(varargin) %#codegen

%

% Copyright 2015-2020 The MathWorks, Inc.

%#ok<*EMCA>

% Supported syntax in code generation
% -----------------------------------
%     [H,theta,rho] = hough(BW)
%     [H,theta,rho] = hough(BW,ParameterName,ParameterValue)
%
% Input/output specs in code generation
% -------------------------------------
% BW:    2-D, real, nonsparse, nonempty
%        logical or numeric: uint8, uint16, uint32, uint64,
%                            int8, int16, int32, int64, single, double
%        anything that's not logical is converted first using
%           bw = BW ~= 0
%        Inf's ok, treated as 1
%        NaN's ok, treated as 1
%
% ParameterName can be 'RhoResolution' and 'Theta'
%
% ParameterValue for 'RhoResolution' must be a real, finite and
%        positive scalar of class double. The default is 1.
%
% ParameterValue for 'Theta' must be a real, finite, nonempty vector of
%        class double. Its default value is -90:89.
%
% H:     double matrix
%        size NRHO-by-NTHETA with
%        NRHO = (2*ceil(D/RhoResolution)) + 1, where
%        D = sqrt((numRowsInBW - 1)^2 + (numColsInBW - 1)^2).
%
% THETA: row vector
%        double
%        THETA values are within the range [-90, 90) degrees
%
% RHO:   row vector
%        double
%        RHO values range from -DIAGONAL to DIAGONAL where
%        DIAGONAL = RhoResolution*ceil(D/RhoResolution).

[bw, theta, rho, M, N] = parseInputs(varargin{:});

% If codegen solution needs to use single thread
singleThread = images.internal.coder.useSingleThread();

% For CPU targets OpenMP Library is used for parallelization if length(theta) is at least
% two and number of cores is greater than one
dontUseParfor = coder.internal.isInParallelRegion || coder.gpu.internal.isGpuEnabled || (length(theta)==1) || (singleThread);

if (dontUseParfor)
    % For GPU targets or when 'hough' is called inside a parallel region 
    h = standardHoughTransform(bw, theta, rho, M, N);
else
    % For multicore CPU targets, utilizes OpenMP Library 
    h = standardHoughTransformOptimized(bw, theta, rho, M, N);
end
end
%--------------------------------------------------------------------------
% Parse Input Parameters
function [BW, theta, rho, M, N] = parseInputs(varargin)

narginchk(1,5);

im = varargin{1};
validateattributes(im, {'numeric','logical'}, ...
                   {'real','2d','nonsparse','nonempty'}, ...
                   mfilename,'BW',1);

if ~islogical(im)
    BW = im~=0;
else
    BW = im;
end

% Useful below
[M,N] = size(BW);

% Process parameter-value pairs
[theta,rhoResolution] = parseOptionalInputs(varargin{2:end});

% Validate Theta
validateTheta(theta, mfilename);

% Validate RhoResolution
validateRhoResolution(M, N, rhoResolution, mfilename);

% Compute rho from rhoResolution
D = sqrt((M - 1)^2 + (N - 1)^2);
q = ceil(D/rhoResolution(1));
nrho = 2*q + 1;
rho = linspace(-q*rhoResolution(1), q*rhoResolution(1), nrho);
end

%--------------------------------------------------------------------------
function [theta,rhoResolution] = parseOptionalInputs(varargin)
% Parse optional PV pairs - 'Theta' and 'RhoResolution'
coder.inline('always');
coder.internal.prefer_const(varargin);

params = struct( ...
    'Theta',        uint32(0), ...
    'RhoResolution',uint32(0));

options = struct( ...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

optarg = eml_parse_parameter_inputs(params,options,varargin{:});

theta = eml_get_parameter_value( ...
    optarg.Theta, ...
    -90:89, ...
    varargin{:});

rhoResolution = eml_get_parameter_value( ...
    optarg.RhoResolution, ...
    1, ...
    varargin{:});
end

%--------------------------------------------------------------------------
% Validate 'RhoResolution' parameter
function validateRhoResolution(M, N, rhoResolution, fileName)

coder.inline('always');
coder.internal.prefer_const(M, N, rhoResolution, fileName);

inputStr = 'RhoResolution';

validateattributes(rhoResolution,{'double'}, ...
                   {'real','scalar','finite','positive'}, fileName, inputStr);

normSquared = N*N + M*M;

coder.internal.errorIf(rhoResolution(1)^2 >= normSquared, ...
                       'images:hough:invalidRhoRes',inputStr);
end

%--------------------------------------------------------------------------
% Validate 'Theta' parameter
function validateTheta(theta, fileName)

coder.inline('always');
coder.internal.prefer_const(theta, fileName);

inputStr = 'Theta';

validateattributes(theta, {'double'}, ...
                   {'nonempty','real','vector','finite'}, fileName, inputStr);

minTheta = min(theta(:));
maxTheta = max(theta(:));

coder.internal.errorIf(minTheta < -90, ...
                       'images:hough:invalidThetaMin', inputStr);

coder.internal.errorIf(maxTheta >= 90, ...
                       'images:hough:invalidThetaMax', inputStr);
end

%--------------------------------------------------------------------------
% Implementation of the Standard Hough Transform (SHT) algorithm
function H = standardHoughTransform(BW,theta,rho,numRow,numCol)

coder.inline('always');
coder.internal.prefer_const(BW,theta,rho,numRow,numCol);

rhoLength   = coder.internal.indexInt(length(rho));
thetaLength = coder.internal.indexInt(length(theta));

firstRho = rho(1);

% Allocate space for H and initialize to 0
% Gpu Enabled condition is added here
if (coder.gpu.internal.isGpuEnabled)
    H = zeros([rhoLength,thetaLength],'single');
else
    % 1. If Gpu is not Enabled
    H = zeros(rhoLength,thetaLength);
end

% Allocate space for cos/sin lookup tables
cost = coder.nullcopy(zeros(thetaLength,1));
sint = coder.nullcopy(zeros(thetaLength,1));

% Pre-compute the sin and cos tables
for i = 1:thetaLength
    % Theta is in radians
    cost(i) = cos(theta(i) * pi/180);
    sint(i) = sin(theta(i) * pi/180);
end

% Compute the factor for converting back to the rho matrix index
slope = double(rhoLength-1) / double(rho(rhoLength) - firstRho);

% Compute the Hough transform
if coder.isColumnMajor
    for n = 1:numCol
        for m = 1:numRow
            if BW(m,n) % if pixel is on
                coder.gpu.internal.noKernelRegion;
                for thetaIdx = 1:thetaLength
                    % rho = x*cos(theta) + y*sin(theta)
                    myRho = (n-1) * cost(thetaIdx) + (m-1) * sint(thetaIdx);
                    % convert to bin index
                    rhoIdx = roundAndCastInt(slope*(myRho - firstRho)) + 1;
                    % accumulate
                    % Gpu Enabled condition is added here
                    if (coder.gpu.internal.isGpuEnabled)
                        [H(rhoIdx,thetaIdx)] = gpucoder.atomicAdd(H(rhoIdx,thetaIdx),single(ones(1,1)));
                    else
                        H(rhoIdx,thetaIdx) = H(rhoIdx,thetaIdx)+1;
                    end
                end
            end
        end
    end
else
    for m = 1:numRow
        for n = 1:numCol
            if BW(m,n) % if pixel is on
                coder.gpu.internal.noKernelRegion;
                for thetaIdx = 1:thetaLength
                    % rho = x*cos(theta) + y*sin(theta)
                    myRho = (n-1) * cost(thetaIdx) + (m-1) * sint(thetaIdx);
                    % convert to bin index
                    rhoIdx = roundAndCastInt(slope*(myRho - firstRho)) + 1;
                    % accumulate
                    % Gpu Enabled condition is added here
                    if (coder.gpu.internal.isGpuEnabled)
                        [H(rhoIdx,thetaIdx)] = gpucoder.atomicAdd(H(rhoIdx,thetaIdx),single(ones(1,1)));
                    else
                        H(rhoIdx,thetaIdx) = H(rhoIdx,thetaIdx)+1;
                    end
                end
            end
        end
    end
end

% Gpu Enabled condition is added here
% Typecasting to double, because atomic operations are done in 'single'.
if (coder.gpu.internal.isGpuEnabled)
    H = cast(H, 'double');
else
    H = H;
end
end
%--------------------------------------------------------------------------
function H = standardHoughTransformOptimized(BW,theta,rho, numRow, numCol)
% For CPU targets 
% Computes the Standard Hough transform of all non-zero pixels for each
% value of theta independently. 
% Utilizes OpenMP Library in the generated code

coder.inline('always');
coder.internal.prefer_const(BW,theta,rho,numRow,numCol);

rhoLength   = coder.internal.indexInt(length(rho));
thetaLength = coder.internal.indexInt(length(theta));

firstRho = rho(1);

% Allocate space for H and initialize to 0

H = zeros(rhoLength,thetaLength);


% Allocate space for cos/sin lookup tables
cost = coder.nullcopy(zeros(thetaLength,1));
sint = coder.nullcopy(zeros(thetaLength,1));

% Pre-compute the sin and cos tables
for i = 1:thetaLength
    % Theta is in radians
    cost(i) = cos(theta(i) * pi/180);
    sint(i) = sin(theta(i) * pi/180);
end

% Compute the factor for converting back to the rho matrix index
slope = double(rhoLength-1) / double(rho(rhoLength) - firstRho);


[nonZeroPixelMatrix, numNonZeros] = findNonZero(BW,numRow,numCol);

%Compute Hough Transform
if coder.isColumnMajor
    parfor thetaIdx = 1:thetaLength
        rhoIdxVector = coder.internal.indexInt(zeros(rhoLength,1));
        for j = 1:numCol
            for i = 1 : numNonZeros(j)
                n = nonZeroPixelMatrix(i,j); % row index of non zero pixel
                myRho = (j-1) * cost(thetaIdx) + (double(n)-1) * sint(thetaIdx);
                rhoIdx = roundAndCastInt(slope*(myRho - firstRho)) + 1;
                rhoIdxVector(rhoIdx) = coder.internal.indexPlus(rhoIdxVector(rhoIdx),1); % temporary bin for rho indices
            end
        end
        H(:,thetaIdx) = rhoIdxVector;
    end
else
    parfor thetaIdx = 1:thetaLength
        rhoIdxVector = coder.internal.indexInt(zeros(rhoLength,1));
        for i = 1:numRow
            for j = 1 : numNonZeros(i)
                n = nonZeroPixelMatrix(i,j); % column index of non zeroelement
                myRho = (double(n)-1) * cost(thetaIdx) + (i-1) * sint(thetaIdx);
                rhoIdx = roundAndCastInt(slope*(myRho - firstRho)) + 1;
                rhoIdxVector(rhoIdx) = coder.internal.indexPlus(rhoIdxVector(rhoIdx),1); % temporary bin for rho indices
            end
        end
        H(:,thetaIdx) = rhoIdxVector;
    end
end
end


%--------------------------------------------------------------------------
function [nonZeroPixelMatrix, numNonZeros] = findNonZero(BW,numRow,numCol)

% If column major, X-coordinate of non-zero pixels in each column is stored in corresponding column of 'nonZeroPixelMatrix' and 
% y-coordinate for row-major.
% numNonZeros: number of non zero pixels in each column in case of column-major,
% and number of non-zero pixels in each row in case if row-major

coder.inline('always');
coder.internal.prefer_const(BW,numRow,numCol);

nonZeroPixelMatrix = coder.nullcopy(coder.internal.indexInt(zeros(size(BW))));

if coder.isColumnMajor
    % Store number of non-zero pixels in each column
    numNonZeros =  coder.internal.indexInt(zeros(numCol,1));
    
    parfor j = 1:numCol
        % Store x-coordinate of non-zero pixels in each column
        tempBin = coder.nullcopy((zeros(numRow,1)));
        % Count number of non-zero pixels in each column
        tempNum = 0;
        for i = 1:numRow
            if BW(i,j) > 0
                tempNum = tempNum + 1; % Number of non-zero pixels
                tempBin(tempNum) = i; % x
            end
        end
        numNonZeros(j) = tempNum;
        for k = 1:numRow
            if k>tempNum
                break;
            end
            nonZeroPixelMatrix(k,j) = tempBin(k); % Update x-values for each column
        end
    end

else
    
    % Get coordinates of non-zero pixels
    % Store number of non-zero pixels in each row
    numNonZeros =  coder.internal.indexInt(zeros(numRow,1));
    
    parfor j = 1:numRow
        % Store y-coordinate of non-zero pixels in each row
        tempBin = coder.nullcopy((zeros(numCol,1)));
        % Count number of non-zero pixels in each row
        tempNum = 0;
        for i = 1:numCol
            if BW(j,i) > 0
                tempNum = tempNum + 1; % Number of non-zero pixels
                tempBin(tempNum) = i; % y
            end
        end
        numNonZeros(j) = tempNum;
        for k = 1:numCol
            if k>tempNum
                break;
            end
            nonZeroPixelMatrix(j,k) = tempBin(k); % Update y-values for each row
        end
    end
end
end

%-----------------------------------------------------------------------------------------------
function y = roundAndCastInt(x)

coder.inline('always');
coder.internal.prefer_const(x);

% Only works if x >= 0
y = coder.internal.indexInt(x+0.5);
end
