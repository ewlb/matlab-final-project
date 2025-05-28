function [Label, Centers] = algkmeans(Inp,k,filename,varargin) 
%   Underlying core implementation that is used by imsegkmeans and
%   imsegkmeans3 to perform kmeans clustering based segmentation.
%   
%   FOR INTERNAL USE ONLY -- This function is intentionally undocumented
%   and is intended for use only within other toolbox classes and
%   functions. Its behavior may change, or the feature itself may be
%   removed in a future release.

%   Copyright 2018-2019 The MathWorks, Inc.

matlab.images.internal.errorIfgpuArray(Inp,k,filename,varargin{:});
args = matlab.images.internal.stringToChar(varargin);
[Inp,k,NormalizeInput, NumAttempts, MaxIterations, Threshold] = ParseInputs(filename,Inp,k,args{:});

% Casting input to single if non-floating datatype
classInp = class(Inp);
if ~isfloat(classInp)    
    Inp = single(Inp);
end

if strcmp(filename,'imsegkmeans')
    [m,n,c] = size(Inp);
    p = 1;
    X = reshape(Inp,m*n,[]);
    % Default Channel Average = 0 and StdDev = 1 when NormalizeInput is false

elseif strcmp(filename,'imsegkmeans3')
    [m,n,p,c] = size(Inp);
    X = reshape(Inp,m*n*p,[]);
    % Default Channel Average = 0 and StdDev = 1 when NormalizeInput is false
end
avgChn = zeros(1,c);
stdDevChn = ones(1,c);
if NormalizeInput
    [X, avgChn, stdDevChn] = normInp(X);
end

if size(X,1)<k
    error(message("images:validate:kTooLarge"))
end

if m==1 && n==1 && p == 1
    % Degenerate case with a single observation, workaround ocv bug
    Label = 1;
    NormCen = zeros(size(X),"like",X);
else
    [Label,NormCen] = images.internal.ocvkmeans(X,k,NumAttempts,MaxIterations,Threshold);
end
Centers = denormalizeCenters(NormCen, avgChn, stdDevChn);
Centers = cast(Centers,classInp);

if strcmp(filename,'imsegkmeans')
    Label = reshape(Label,m,n);
elseif strcmp(filename,'imsegkmeans3')
    Label = reshape(Label,m,n,p);
end

% Memory efficient Label matrix as it returns smallest numeric class
% necessary  depending upon the number of clusters.
if k <= intmax('uint8')
    dataType = 'uint8';
elseif k <= intmax('uint16')
    dataType = 'uint16';
elseif k <= intmax('uint32')
    dataType = 'uint32';
else
    dataType = 'double';
end
Label = cast(Label,dataType);


function [out, avgChn, stdDevChn] = normInp(X)
% normalize channels independently (each channel persists as a column in X).
avgChn = mean(X,1);
stdDevChn = std(X,0,1);
% EdgeCase Condition where standard Deviation is zero of any channel
% Modify channel's stdDev=1 as the channel is irrelevant from clustering perspective.
zeroLoc = stdDevChn==0;
stdDevChn(zeroLoc) = 1;
out = (X - avgChn)./stdDevChn;


function Centers = denormalizeCenters(NormCen, avgChn, stdDevChn)
% De-normalized centers to be returned in original user input space.
Centers = NormCen .* stdDevChn + avgChn ;

function [Inp,k,NormalizeInput, NumAttempts, MaxIterations, Threshold] = ParseInputs(filename, varargin)

narginchk(3,11);

p = inputParser;
p.PartialMatching = true;
p.CaseSensitive = false;
p.FunctionName = filename;
if strcmp(filename,'imsegkmeans')
    p.addRequired('Im',@validateImage);
else
    p.addRequired('V',@validateVolume);
end


p.addRequired('k',@validateNumClusters);
p.addParameter('NormalizeInput', true, @validateNormalizeInput);
p.addParameter('NumAttempts', 3, @validateNumAttempts);
p.addParameter('MaxIterations', 100, @validateMaxIterations);
p.addParameter('Threshold', 0.0001, @validateThreshold);
p.parse(varargin{:});
parsedInputs = p.Results;
if strcmp(filename,'imsegkmeans')
    Inp = parsedInputs.Im;
    if (ndims(Inp) > 3)
    error(message('images:validate:tooManyDimensions', 'Im', 3));
    end
else
    Inp = parsedInputs.V;
  if (ndims(Inp) > 4)
    error(message('images:validate:tooManyDimensions', 'V', 4));
  end
      
end

k = parsedInputs.k;
NormalizeInput =  parsedInputs.NormalizeInput;
NumAttempts = parsedInputs.NumAttempts;
MaxIterations = parsedInputs.MaxIterations;
Threshold = parsedInputs.Threshold;

function flag = validateImage(Im)
% Underlying openCV code does not handle Inf and NaN efficiently and
% crashed MATLAB and that is why 'finite' attribute is added here to
% prevent a crash from happening.
validateattributes(Im, { 'uint8' 'uint16' 'int8' 'int16' 'single'}, ...
    {'real','nonsparse','nonempty','finite'}, mfilename,'',1);
flag = true;

function flag = validateVolume(V)
% Underlying openCV code does not handle Inf and NaN efficiently and
% crashed MATLAB and that is why 'finite' attribute is added here to
% prevent a crash from happening.
validateattributes(V, { 'uint8' 'uint16' 'int8' 'int16' 'single'}, ...
    {'real','nonsparse','nonempty','finite'}, mfilename,'',1);
flag = true;

function flag = validateNumClusters(k)

validateattributes(k, {'numeric'}, ...
    {'scalar', 'nonsparse', 'nonempty', 'finite', 'integer' ,'positive'   }, ...
    mfilename, 'k',2);

flag = true;

function flag = validateNormalizeInput(inp)

validateattributes(inp, {'logical', 'numeric'}, {'binary','scalar'}, mfilename, 'NormalizeInput');

flag = true;

function flag = validateNumAttempts(inp)

validateattributes(inp, {'numeric'}, ...
    {'scalar',  'nonsparse', 'nonempty', 'finite',  'integer', 'positive' }, ...
    mfilename, 'NumAttempts');

flag = true;

function flag = validateMaxIterations(inp)

validateattributes(inp, {'numeric'}, ...
    {'scalar',  'nonsparse', 'nonempty', 'finite', 'integer', 'positive' }, ...
    mfilename, 'MaxIterations');

flag = true;

function flag = validateThreshold(inp)

validateattributes(inp, {'numeric'}, ...
    {'scalar', 'nonsparse', 'nonempty', 'finite', 'real', 'positive' }, ...
    mfilename, 'Threshold');

flag = true;
