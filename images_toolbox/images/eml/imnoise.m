function b = imnoise(varargin) %#codegen
%   Syntax
%   ------
%
%   J = imnoise(I,TYPE,...)
%
%   Input Specs
%   -----------
%
%   I:
%    Grayscale image
%    'single', 'double', 'int16', 'uint8', 'uint16'
%
%
%   Type
%   'gaussian', 'localvar', 'poisson', 'salt & pepper', 'speckle'
%    Default: 'gaussian'
%
%   J = imnoise(I, 'gaussian', m, var_gauss)
%   m: numeric scalar
%   -Default: 0
%   var_gauss: numeric scalar
%   -Default: 0.01
%
%   J = imnoise(I, 'localvar', var_local)
%   var_local: numeric matrix, same size of I
%
%   J = imnoise(I, 'localvar', intensity_map, var_local)
%   intensity_map: numeric vector
%   var_local: A numeric vector the same length of intensity_map
%
%   J = imnoise(I, 'poisson')
%   Images of datatype int16 is not allowed
%
%   J = imnoise(I,'salt & pepper' ,d)
%   d: numeric scalar % -Default: 0.05
%
%   J = imnoise(I, 'speckle', var_speckle)
%   var_speckle: numeric scalar
%   -Default: 0.05
%
%   Output Specs:
%   ------------
%   J : Noisy image, returned as a numeric matrix of the same data type as input image I

%   Copyright 2021 The MathWorks, Inc.

[a, code, classIn, classChanged, p3, p4] = parseInputs(varargin{:});

b = algimnoise(a, code, classIn, classChanged, p3, p4);


%--------------------------------------------------------------------------
% parse the inputs
function [a, code, classIn, classChanged, p3, p4] = parseInputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);

% Check the number of input arguments.

narginchk(1,4);

% Check the input-array type.
aIn = varargin{1};
validateattributes(aIn, {'uint8','uint16','double','int16','single'}, {}, mfilename, ...
              'I', 1);

% Change class to double
classIn = class(aIn);
classChanged = 0;
if ~isa(aIn, 'double')
  a = im2double(aIn);
  classChanged = 1;
else
  % Clip so a is between 0 and 1.
  a = max(min(aIn,1),0);
end

% Check the noise type.
if nargin > 1
  coder.internal.errorIf(((~ischar(varargin{2})) && (~isstring(varargin{2}))), ...
      'images:imnoise:invalidNoiseType');
  validNoiseTypes = {'gaussian', 'localvar', 'poisson', 'salt & pepper', 'speckle'};
  noiseType = validatestring(varargin{2}, validNoiseTypes, mfilename);

  % Preprocess noise type string to detect abbreviations.
  code = stringToNoiseType(noiseType);
else
  code = GAUSSIAN;  % default noise type
end

switch code
 case POISSON
  p3 = [];
  p4 = [];
  coder.internal.errorIf(nargin > 2, 'images:imnoise:tooManyPoissonInputs');
  coder.internal.errorIf(isequal(classIn, 'int16'), 'images:imnoise:badClassForPoisson');

 case GAUSSIAN
  % default mean
  p3 = 0;
  p4 = 0.01;

  if nargin > 2
    p3 = varargin{3};
    coder.internal.errorIf(~images.internal.imnoise.isRealScalar(p3), 'images:imnoise:invalidMean');
  end

  if nargin > 3
    p4 = varargin{4};
    coder.internal.errorIf(~images.internal.imnoise.isNonnegativeRealScalar(p4), ...
        'images:imnoise:invalidVariance', 'gaussian');
  end

 case SALTANDPEPPER
  % default density
  p3 = 0.05;
  p4 = [];

  if nargin > 2
    p3 = varargin{3};
    coder.internal.errorIf((~images.internal.imnoise.isNonnegativeRealScalar(p3) || (p3(1) > 1)), ...
          'images:imnoise:invalidNoiseDensity');
    coder.internal.errorIf(nargin > 3, 'images:imnoise:tooManySaltAndPepperInputs');
  end

 case SPECKLE
  % default variance
  p3 = 0.05;
  p4 = [];

  if nargin > 2
    p3 = varargin{3};
    coder.internal.errorIf(~images.internal.imnoise.isNonnegativeRealScalar(p3), ...
          'images:imnoise:invalidVariance', 'speckle');
  end
  coder.internal.errorIf(nargin > 3,'images:imnoise:tooManySpeckleInputs')

 case LOCALVAR
  coder.internal.errorIf(nargin < 3, 'images:imnoise:toofewLocalVarInputs');
  coder.internal.errorIf(nargin > 4, 'images:imnoise:tooManyLocalVarInputs');
  if nargin == 3
    % IMNOISE(a,'localvar',v)
    code = LOCALVAR_1;
    p3 = varargin{3};
    p4 = [];
    coder.internal.errorIf(( ~images.internal.imnoise.isNonnegativeReal(p3) || ~isequal(size(p3),size(a))),...
          'images:imnoise:invalidLocalVarianceValueAndSize');

  elseif nargin == 4
    % IMNOISE(a,'localvar',IMAGE_INTENSITY,NOISE_VARIANCE)
    code = LOCALVAR_2;
    p3 = varargin{3};
    p4 = varargin{4};

    coder.internal.errorIf(( ~images.internal.imnoise.isNonnegativeRealVector(p3) || any(all(p3(:) > 1))),...
          'images:imnoise:invalidImageIntensity');

    coder.internal.errorIf(~images.internal.imnoise.isNonnegativeRealVector(p4),...
          'images:imnoise:invalidLocalVariance');

    coder.internal.errorIf(~isequal(size(p3),size(p4)),...
          'images:imnoise:invalidSize');
  end
end

% -------------------------------------------------------------------------
% convert string noise type to int
function noiseType = stringToNoiseType(noiseStr)
%   stringToNoiseType(noiseStr) returns the constant int noiseType
%   by parsing the string input
%
coder.inline('always');
if (strncmpi(noiseStr,'gaussian',numel(noiseStr)))
    noiseType =  GAUSSIAN;
elseif (strncmpi(noiseStr,'salt & pepper',numel(noiseStr)))
    noiseType =  SALTANDPEPPER;
elseif (strncmpi(noiseStr,'speckle',numel(noiseStr)))
    noiseType =  SPECKLE;
elseif (strncmpi(noiseStr,'poisson',numel(noiseStr)))
    noiseType =  POISSON;
elseif (strncmpi(noiseStr,'localvar',numel(noiseStr)))
    noiseType =  LOCALVAR;
end

% -------------------------------------------------------------------------
% Defining enum for each noise TYPE
function noiseType = GAUSSIAN()
coder.inline('always');
noiseType = int8(1);

function noiseType = SALTANDPEPPER()
coder.inline('always');
noiseType = int8(2);

function noiseType = SPECKLE()
coder.inline('always');
noiseType = int8(3);

function noiseType = POISSON()
coder.inline('always');
noiseType = int8(4);

function noiseType = LOCALVAR()
coder.inline('always');
noiseType = int8(5);

function noiseType = LOCALVAR_1()
coder.inline('always');
noiseType = int8(6);

function noiseType = LOCALVAR_2()
coder.inline('always');
noiseType = int8(7);

% -------------------------------------------------------------------------
% algimnoise
function cb = algimnoise(a, code, classIn, classChanged, p3, p4)
% Main algorithm used by imnoise function

% No input validation is done in this function.
  coder.inline('always');
  coder.internal.prefer_const(a, code, classIn, classChanged, p3, p4);
  sizeA = size(a);
  b = coder.nullcopy(a);
  na = numel(a);

  switch code
   case GAUSSIAN
    % Gaussian white noise
    sqrtp4 = sqrt(p4);
    temp = coder.sameSizeBinaryOp(@plus, a, sqrtp4*randn(sizeA));
    b = coder.internal.ixfun('imnoise', @plus, temp, p3(1));

   case LOCALVAR_1 
    % Gaussian white noise with variance varying locally
    % imnoise(a,'localvar',v)
    % v is local variance array

    rNoise = randn(sizeA);  % Random noise to be added
    parfor i=1:na
        b(i) = a(i)+sqrt(p3(i))*rNoise(i);
    end

   case LOCALVAR_2 
    % Gaussian white noise with variance varying locally
    % Use an empirical intensity-variance relation
    intensity = p3(:);
    var       = p4(:);
    minI  = min(intensity);
    maxI  = max(intensity);
    rNoise = randn(sizeA);    % Random noise to be added
    parfor i=1:na
        b(i)     = min(max(a(i),minI),maxI);
        b(i)     = interp1(intensity,var,b(i));
        b(i)     = a(i) + sqrt(b(i))*rNoise(i);
    end

   case POISSON
    % Poisson noise
    switch classIn
     case 'uint8'
      a = round(a*255);
     case 'uint16'
      a = round(a*65535);
     case 'single'
      % Recalibration
      a = a * 1e6;
     case 'double'
      % Recalibration
      a = a * 1e12;
    end

    a = a(:);

    %  (Monte-Carlo Rejection Method) Ref. Numerical
    %  Recipes in C, 2nd Edition, Press, Teukolsky,
    %  Vetterling, Flannery (Cambridge Press)

    b = zeros(size(a),'like', a);
    % Cases where pixel intensities are less than 50 units
    idx1 = find(a<50);
    if (~isempty(idx1))
      g = exp(-a(idx1));
      em = -ones(size(g));
      t = ones(size(g));
      idx2 = (1:length(idx1))';
      while ~isempty(idx2)
        em(idx2) = em(idx2) + 1;
        t(idx2) = coder.internal.ixfun('imnoise', @times, t(idx2), rand(size(idx2)));
        idx2 = idx2(t(idx2) > g(idx2));
      end
      b(idx1) = em;
    end

    % For large pixel intensities the Poisson pdf becomes 
    % very similar to a Gaussian pdf of mean and of variance
    % equal to the local pixel intensities. Ref. Mathematical Methods
    % of Physics, 2nd Edition, Mathews, Walker (Addison Wesley)
    idx1 = find(a >= 50); % Cases where pixel intensities are at least 50 units
    if (~isempty(idx1))
      temp = coder.sameSizeBinaryOp(@times, sqrt(a(idx1)), randn(size(idx1)));
      b(idx1) = round(coder.sameSizeBinaryOp(@plus, a(idx1), temp));
    end

    b = reshape(b,sizeA);

   case SALTANDPEPPER
    % Salt & pepper noise
    b = a;
    coder.varsize('x');
    x = rand(sizeA);
    k = p3(1)/2;
    parfor i=1:na
        if (x(i) < k)
            % Minimum value
            b(i) = 0;
        else
            if (x(i) < p3)
                % Maximum (saturated) value
                b(i) =  1;
            end
        end
    end

   case SPECKLE
    % Speckle (multiplicative) noise
    sqp3 = sqrt(12*p3(1))*a;
    e = 0.5;
    rNoise = coder.internal.ixfun('imnoise', @minus, rand(sizeA), e);
    temp = coder.sameSizeBinaryOp(@times, sqp3, rNoise);
    b = coder.sameSizeBinaryOp(@plus, a, temp);
  end

  % Truncate the output array data if necessary

  if (code == POISSON)
    switch classIn
     case 'uint8'
      % assigning the result of type conversion to different variable
      tb = uint8(b);
     case 'uint16'
      tb = uint16(b);
     case 'single'
      tb = max(0, min(b / 1e6, 1));
     case 'double'
      tb = max(0, min(b / 1e12, 1));
    end
  else    
    b = max(0,min(b,1));
  end

  % The output class should be the same as the input class
  if classChanged
      if (code == POISSON)
        cb = images.internal.changeClass(classIn, tb);
      else
        cb = images.internal.changeClass(classIn, b);
      end
  else
      if (code == POISSON)
        cb = tb;
      else
        cb = b;
      end
  end