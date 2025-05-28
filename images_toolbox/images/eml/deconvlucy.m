function J = deconvlucy(varargin)%#codegen
%DECONVLUCY Deblur image using Lucy-Richardson method.

% Copyright 2022-2024 The MathWorks, Inc.

% Parse inputs to verify valid function calling syntaxes and arguments
[J1,J4,psf,numIt,damper,readOut,weight,subSmpl,sizeI,numNSdim]=...
    parseInputs(varargin{:});

sizeOTF = sizeI;
numNSdimLen = coder.internal.indexInt(numel(numNSdim));
for i = 1:numNSdimLen
    sizeOTF(numNSdim(i)) = subSmpl*sizeI(numNSdim(i));
end

H = psf2otf(psf,sizeOTF);

% 2. Prepare parameters for iterations
% Create indexes for image according to the sampling rate
idxLen = zeros(1,length(sizeI));
for i = 1:numNSdimLen
    k = numNSdim(i);
    idxLen(k) = k;
end

% imgLen gives whether the given image is 2D or 3D
imgLen = coder.internal.indexInt(numel(sizeI));
if imgLen == 3
    if idxLen(1) == 1
        idx1 = reshape(repmat(1:sizeI(1),[subSmpl 1]),[subSmpl*sizeI(1) 1]);
    else
        idx1 =  reshape(repmat(1:sizeI(1),[1 1]),[sizeI(1) 1]);
    end
    if idxLen(2) == 2
        idx2 = reshape(repmat(1:sizeI(2),[subSmpl 1]),[subSmpl * sizeI(2) 1]);
    else
        idx2 =  reshape(repmat(1:sizeI(2),[1 1]),[sizeI(2) 1]);
    end
    if idxLen(3) == 3
        idx3 = reshape(repmat(1:sizeI(3),[subSmpl 1]),[subSmpl*sizeI(3) 1]);
    else
        idx3 =  reshape(repmat(1:sizeI(3),[1 1]),[sizeI(3) 1]);
    end

    idx={idx1,idx2,idx3};
else
    if idxLen(1) == 1
        idx1 = reshape(repmat(1:sizeI(1),[subSmpl 1]),[subSmpl*sizeI(1) 1]);
    else
        idx1 =  reshape(repmat(1:sizeI(1),[1 1]),[sizeI(1) 1]);
    end
    if idxLen(2) == 2
        idx2 = reshape(repmat(1:sizeI(2),[subSmpl 1]),[subSmpl*sizeI(2) 1]);
    else
        idx2 =  reshape(repmat(1:sizeI(2),[1 1]),[sizeI(2) 1]);
    end
    idx = {idx1,idx2};
end

wI = max(weight.*(readOut + J1),0); % at this point  - positivity constraint
J2 = J1(idx{:});
J3 = zeros(size(J2));
scale = real(ifftn(conj(H).*fftn(weight(idx{:})))) + sqrt(eps);
damperTwo = (damper.^2)/2;

coder.internal.prefer_const(subSmpl);
% prepare vector of dimensions to facilitate the reshaping based on SubSmpl
if subSmpl ~= 1  
    vecLen = coder.internal.indexTimes(2, length(sizeI));
    vec = zeros(1,vecLen,'like',sizeI);
    count = coder.internal.indexInt(1);
    for i = 2:2:vecLen
        vec(i) = sizeI(count);
        count = count+1;
    end
    for i = 1:coder.internal.indexInt(length(numNSdim))
        m = numNSdim(i);
        vec(2*m-1) = -1;
    end
    vecModLen = coder.internal.indexInt(length(find(vec)));
    vecMod = zeros(1,vecModLen,'like',vec);
    n = coder.internal.indexInt(1);  
    for i = 1:vecLen
        if(vec(i) ~= 0)
            vecMod(n) = vec(i);
            n = n+1;
        end
    end

    vecTwo = find(vecMod == -1);
    num = fliplr(vecTwo);
    numLen = coder.internal.indexInt(length(num));
    for i = 1:numLen
        k = num(i);
        vecMod(k) = subSmpl;
    end
else
    vecMod= [];
    num = [];
end

% 3. L_R Iterations
lambda = 0;
for k = 1:coder.internal.indexInt(numIt)    
    % 3.a Make an image predictions for the next iteration
    if k > 2
        lambda = (J4(:,1).'*J4(:,2))/(J4(:,2).'*J4(:,2) +eps);
        lambda = max(min(lambda,1),0);% stability enforcement
    end
    Y = max(J2 + lambda*(J2 - J3),0);% plus positivity constraint
    
    % 3.b  Make core for the LR estimation
    CC = corelucy(Y,H,damperTwo,wI,readOut,subSmpl,idx,vecMod,num);
    
    % 3.c Determine next iteration image & apply positivity constraint
    J3 = J2;
    J2 = max(Y.*real(ifftn(conj(H).*CC))./scale,0);
    J4 = [J2(:)-Y(:) J4(:,1)];
end

% convert result input image class
if ~isa(varargin{1},'double')
    J = images.internal.changeClass(class(varargin{1}),J2);
else
    J = J2;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  Function: parseInputs
function [J1,J4,psf,numIt,dampar,readOut,weight,subSmpl,sizeI,numNSdim] = ...
    parseInputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);
narginchk(2,7);

coder.internal.errorIf(iscell(varargin{1}),...
    'images:deconvlucy:inputImageMustNotBeCellArray');

coder.internal.errorIf(numel(size(varargin{1}))>3,...
    'images:deconvlucy:incorrectInputImageDims');

validateattributes(varargin{1},{'uint8' 'uint16' 'double' 'int16','single'},...
    {'real' 'nonempty' 'finite'},mfilename,'I',1); 

coder.internal.errorIf(length(varargin{1})<2,...
    'images:deconvlucy:inputImagesMustHaveAtLeast2Elements');

if ~isa(varargin{1},'double')
    J1 = im2double(varargin{1});
else
    J1 = varargin{1};
end

% Second, Assign the rest of the inputs:
coder.internal.errorIf(numel(size(varargin{2}))>3,...
    'images:deconvlucy:incorrectInputPSFDims');
% deconvlucy(I,PSF)
psf = varargin{2};     

% Number of  iterations, usually produces good
% result by 10.
numItD = 10;

% No damping is default
damparD = 0;

% Zero readout noise or any other
% back/fore/ground noise associated with CCD camera.
% Or the Image is corrected already for this noise by user.
readOutD= 0;

% Image and PSF are given at equal resolution,
% no over/under sampling at all.
subSmplD= 1;

% PSF array
[sizeI, sizePSF] = padlength(size(J1), size(psf));

numNSdim = find(sizePSF ~= 1);

if nargin == 3         
    % deconvlucy(I,PSF,NUMIT)
    numItOne = varargin{3};
elseif nargin == 4          
    % deconvlucy(I,PSF,NUMIT,DAMPAR)
    numItOne = varargin{3};
    damparOne = varargin{4};
elseif nargin == 5
    % deconvlucy(I,PSF,NUMIT,DAMPAR,WEIGHT)
    numItOne = varargin{3};
    damparOne = varargin{4};
    weightOne = varargin{5};
elseif nargin == 6          
    % deconvlucy(I,PSF,NUMIT,DAMPAR,WEIGHT,READOUT)
    numItOne = varargin{3};
    damparOne = varargin{4};
    weightOne = varargin{5};
    readOutOne = varargin{6};
elseif nargin == 7          
    % deconvlucy(I,PSF,NUMIT,DAMPAR,WEIGHT,READOUT,SUBSMPL)
    numItOne = varargin{3};
    damparOne = varargin{4};
    weightOne = varargin{5};
    readOutOne = varargin{6};
    subSmplOne = varargin{7};
end

% Third, Check validity of the input parameters:
% NUMIT check number of iterations
if ((nargin >= 3 && isempty(varargin{3}) || nargin < 3))
    numIt = numItD;
else
    numIt=numItOne;
    validateattributes(numIt,{'double'},{'scalar' 'positive' 'finite'},...
        mfilename,'NUMIT',3);
end

% SUBSMPL check sub-sampling rate
if ((nargin == 7 && isempty(varargin{7}) || nargin < 7))
    subSmpl = subSmplD;
else
    subSmpl = subSmplOne;
    validateattributes(subSmpl,{'double'},{'scalar' 'positive' 'finite'},...
        mfilename,'SUBSMPL',7);
end

coder.internal.assert(coder.internal.isConst(subSmpl), ...
        'MATLAB:images:validate:codegenInputNotConst','SUBSMPL');

coder.internal.errorIf(prod(sizePSF)<2,...
    'images:deconvlucy:psfMustHaveAtLeast2Elements');
coder.internal.errorIf(all(psf(:)==0),...
    'images:deconvlucy:psfMustNotBeZeroEverywhere');
coder.internal.errorIf(any(sizePSF(numNSdim)/subSmpl > sizeI(numNSdim)),...
    'images:deconvlucy:psfMustBeSmallerThanImage');

nRows = coder.internal.indexInt(prod(sizeI)*subSmpl^length(numNSdim));
J4 = zeros(nRows,2); % assign the 4-th element of input cell now

% DAMPAR check damping parameter
if ((nargin >= 4 && isempty(varargin{4}) || nargin < 4))
    dampar = damparD;
else
    coder.internal.errorIf(numel(damparOne) ~= 1 && ~isequal(size(damparOne),sizeI),...
        'images:deconvlucy:damparMustBeSameSizeAsImage');
    coder.internal.errorIf(~isa(damparOne,class(varargin{1})),...
        'images:deconvlucy:damparMustBeSameClassAsInputImage');
    if ~isa(varargin{1},'double')
        dampar = im2double(damparOne);
    else
        dampar = damparOne;
    end
end
validateattributes(dampar,{'double'},{'finite'},mfilename,'DAMPAR',4);

% READOUT check read-out noise
if ((nargin >= 6 && isempty(varargin{6}) || nargin < 6))
    readOut = readOutD;
else
    coder.internal.errorIf((numel(readOutOne) ~= 1) && ...
        ~isequal(size(readOutOne),sizeI), ...
        'images:deconvlucy:readoutMustBeSameSizeAsImage');
    coder.internal.errorIf(~isa(readOutOne,class(varargin{1})),...
        'images:deconvlucy:readoutMustBeSameClassAsInputImage');
    if ~isa(varargin{1},'double')
        readOut = im2double(readOutOne);
    else
        readOut = readOutOne;
    end
end

validateattributes(readOut,{'double'},{'finite'},mfilename,'READOUT',6);

% WEIGHT check weighting
if ((nargin >= 5 && isempty(varargin{5}) || nargin < 5))
    % All pixels are of equal quality, flat-field is one
    weight = ones(sizeI);
else
    validateattributes(weightOne,{'double'},{'finite'},mfilename,'WEIGHT',5);
    coder.internal.errorIf((numel(weightOne)~=1) && ~isequal(size(weightOne),sizeI),...
        'images:deconvlucy:weightMustBeSameSizeAsImage');
    if isscalar(weightOne)
        weight = repmat(weightOne,sizeI);
    else
        weight = weightOne;
    end
end