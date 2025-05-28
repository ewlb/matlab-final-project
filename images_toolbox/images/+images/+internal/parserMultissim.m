function [I,Iref,numScales,scaleWeights,sigma,filtSize,C] = parserMultissim(inputVarName,fcnName,numSpatialDims,varargin)

%PARSERMULTISSIM Input parsing for multissim and multissim3.

% Copyright 2019-2020 The MathWorks, Inc.

% Validate input images
validImageTypes = {'uint8','uint16','int16','single','double','dlarray'};
inputImageAttributes = {'nonsparse','real','finite','nonempty'};

inputName = inputVarName;
inputRefName = inputVarName + "ref";

I = varargin{1};
validateattributes(I,...
    validImageTypes,inputImageAttributes,fcnName,inputName,1);

Iref = varargin{2};
validateattributes(Iref,...
    validImageTypes,inputImageAttributes,fcnName,inputRefName,2);

if ~isequal(underlyingType(I),underlyingType(Iref))
    error(message('images:validate:differentClassMatrices',inputName,inputRefName));
end

if ~isequal(size(I),size(Iref))
    error(message('images:validate:unequalSizeMatrices',inputName,inputRefName));
end

[numScales,scaleWeights,sigma,filtSize,dynmRange] = iParseNameValues(varargin,fcnName,I);

% Verify that the images can be downsampled numScales - 1 times
sizeReduced = size(I,1:min(numSpatialDims,ndims(I)));

for j = 1:(numScales-1)
    if any(sizeReduced == 1)
        error(message('images:validate:unableToDownsample',...
            sprintf('%s and %s',inputName,inputRefName),j-1,'NumScales',[num2str(j) ' or less']));
    end
    sizeReduced = ceil(sizeReduced/2);
end

% Calculate C1 and C2 as C = [C1 C2]: equation (4) [1]
C = double([(0.01*dynmRange).^2 (0.03*dynmRange).^2]);

% Int16 is the only allowed signed-integer type for I and Iref
if isa(I,'int16')
    % Add offset for signed-integer types to shift to the positive range
    I = single(I) - single(intmin('int16'));
    Iref = single(Iref) - single(intmin('int16'));
elseif isinteger(I)
    I = single(I);
    Iref = single(Iref);
end

end

function dynmRange = iGetDynamicRange(x)
if isa(x,'dlarray')
    x = extractdata(x([]));
end
dynmRange = diff(getrangefromclass(gather(x([]))));

end

function [numScales,scaleWeights,sigma,filtSize,dynmRange] = iParseNameValues(...
    inputValues,fcnName,I)

% Assign defaults
numScales = 5;
scaleWeights = fspecial('gaussian',[1,numScales],1);
sigma = 1.5;
dynmRange = iGetDynamicRange(I);

validStrings = {'NumScales','ScaleWeights','Sigma','DynamicRange'};

changedWeights = false;

% Validate name-value pairs
for k = 3:2:length(inputValues)
    if (ischar(inputValues{k}) || isstring(inputValues{k}))
        string = validatestring(inputValues{k},validStrings,...
            fcnName,'OPTION',k);
        switch string
            case {'NumScales'}
                validateattributes(inputValues{k+1},{'numeric'},...
                    {'real','nonempty','finite','scalar','nonzero',...
                    'nonnegative','integer','nonsparse'},...
                    fcnName,'NumScales');
                numScales = inputValues{k+1};
                
                if ~(changedWeights)
                    scaleWeights = fspecial('gaussian',...
                        [1,double(numScales)],1);
                end
            case {'ScaleWeights'}
                inputNumScaleWeights = k+1;
                validateattributes(inputValues{inputNumScaleWeights},...
                    {'numeric'},...
                    {'real','nonnegative','finite','nonempty',...
                    'nonsparse','vector'},fcnName,'ScaleWeights');
                scaleWeights = double(inputValues{inputNumScaleWeights});
                changedWeights = true;
            case {'DynamicRange'}
                validateattributes(inputValues{k+1},...
                    {'numeric'},...
                    {'real','nonempty','scalar','finite','positive'},...
                    fcnName,'DynamicRange');
                dynmRange = double(inputValues{k+1});
            case {'Sigma'}
                validateattributes(inputValues{k+1},...
                    {'numeric'},...
                    {'real','nonempty','scalar','finite','nonnegative',...
                    'nonsparse','nonzero'},fcnName,'Sigma');
                sigma = inputValues{k+1};
        end
    else
        error(message('images:validate:mustBeString'));
    end
end

% Verify that the length of scaleWeights is equal to numScales
if (numScales ~= length(scaleWeights))
    error(message('images:validate:badInputNumel',inputNumScaleWeights,...
        'ScaleWeights',numScales));
end

% Calculate radius with 3 standard deviations to include >99% of the area
filtRadius = ceil(sigma*3);
filtSize = 2 * filtRadius + 1;

% Normalize scaleWeights
totalWeights = sum(scaleWeights);

if (totalWeights ~= 1 && totalWeights ~= 0)
    scaleWeights = scaleWeights/sum(scaleWeights);
elseif (totalWeights == 0)
    error(message('images:validate:atLeastOneNonZeroElement',...
        'ScaleWeights'));
end

end

