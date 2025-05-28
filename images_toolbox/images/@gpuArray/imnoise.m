function b = imnoise(varargin)
%IMNOISE Add noise to gpuArray image.
%   J = IMNOISE(I,TYPE,...) Add noise of a given TYPE to the gpuArray
%   intensity image I. TYPE is a string that can have one of these values:
%
%       'gaussian'       Gaussian white noise with constant
%                        mean and variance
%
%       'localvar'       Zero-mean Gaussian white noise
%                        with an intensity-dependent variance
%
%       'poisson'        Poisson noise
%
%       'salt & pepper'  "On and Off" pixels
%
%       'speckle'        Multiplicative noise
%
%   Depending on TYPE, you can specify additional parameters to IMNOISE.
%   All numerical parameters are normalized; they correspond to operations
%   with images with intensities ranging from 0 to 1.
%
%   J = IMNOISE(I,'gaussian',M,V) adds Gaussian white noise of mean M and
%   variance V to the gpuArray image I. When unspecified, M and V default
%   to 0 and 0.01 respectively.
%
%   J = imnoise(I,'localvar',V) adds zero-mean, Gaussian white noise of
%   local variance, V, to the gpuArray image I.  V is an array of the same
%   size as I.
%
%   J = imnoise(I,'localvar',IMAGE_INTENSITY,VAR) adds zero-mean, Gaussian
%   noise to a gpuArray image, I, where the local variance of the noise is
%   a function of the image intensity values in I.  IMAGE_INTENSITY and VAR
%   are vectors of the same size, and PLOT(IMAGE_INTENSITY,VAR) plots the
%   functional relationship between noise variance and image intensity.
%   IMAGE_INTENSITY must contain normalized intensity values ranging from 0
%   to 1.
%
%   J = IMNOISE(I,'poisson') generates Poisson noise from the data instead
%   of adding artificial noise to the data.  If I is double precision,
%   then input pixel values are interpreted as means of Poisson
%   distributions scaled up by 1e12.  For example, if an input pixel has
%   the value 5.5e-12, then the corresponding output pixel will be
%   generated from a Poisson distribution with mean of 5.5 and then scaled
%   back down by 1e12.  If I is single precision, the scale factor used is
%   1e6.  If I is uint8 or uint16, then input pixel values are used
%   directly without scaling.  For example, if a pixel in a uint8 input
%   has the value 10, then the corresponding output pixel will be
%   generated from a Poisson distribution with mean 10.
%
%   J = IMNOISE(I,'salt & pepper',D) adds "salt and pepper" noise to the
%   gpuArray image I, where D is the noise density.  This affects
%   approximately D*numel(I) pixels. The default for D is 0.05.
%
%   J = IMNOISE(I,'speckle',V) adds multiplicative noise to the gpuArray
%   image I, using the equation J = I + n*I, where n is uniformly
%   distributed random noise with mean 0 and variance V. The default for V
%   is 0.04.
%
%   Note
%   ----
%   The mean and variance parameters for 'gaussian', 'localvar', and
%   'speckle' noise types are always specified as if for a double gpuArray
%   image in the range [0, 1].  If the input image is of class uint8 or
%   uint16, the imnoise function converts the gpuArray image to double,
%   adds noise according to the specified type and parameters, and then
%   converts the noisy gpuArray image back to the same class as the input.
%
%   Class Support
%   -------------
%   For most noise types, input gpuArray I can have underlying class be
%   uint8, uint16, double, int16, or single. For Poisson noise, int16 is
%   not allowed. The output gpuArray image J has the same class as I.  If I
%   has more than two dimensions it is treated as a multidimensional
%   intensity image and not as an RGB gpuArray image.
%
%   Example
%   -------
%        I = gpuArray(imread('eight.tif'));
%        J = imnoise(I,'salt & pepper', 0.02);
%        figure, imshow(I), figure, imshow(J)
%
%   See also GPUARRAY/RAND, GPUARRAY/RANDN, GPUARRAY.

%   Copyright 2013-2023 The MathWorks, Inc.

% Check the input-array type.


[varargin{2:end}] = gather(varargin{2:end});
if ~isgpuarray(varargin{1})
    % CPU code path if the first input is not a gpuArray
    b = imnoise(varargin{:});
    return;
end

[a, code, classIn, classChanged, p3, p4] = ParseInputs(varargin{:});

sizeA = size(a);

switch code
    case 'gaussian' % Gaussian white noise
        %b = a + sqrt(p4)*randn(sizeA) + p3;
        p4 = sqrt(p4);
        r  = gpuArray.randn(sizeA);
        b  = arrayfun(@applyGaussian, a,r);
        
        b = images.internal.changeClass(classIn, b);
        
    case 'localvar_1' % Gaussian white noise with variance varying locally
        
        b = images.internal.algimnoise(a, code, classIn, classChanged, p3, p4);
        
    case 'localvar_2' % Gaussian white noise with variance varying locally
        
        b = images.internal.algimnoise(a, code, classIn, classChanged, p3, p4);
        
    case 'poisson' % Poisson noise
        
        b = images.internal.algimnoise(a, code, classIn, classChanged, p3, p4);
        
    case 'salt & pepper' % Salt & pepper noise
        
        r     = gpuArray.rand(sizeA);
        p3by2 = p3/2;
        b     = arrayfun(@applysnp, a, r);
        
        b = images.internal.changeClass(classIn, b);
        
    case 'speckle' % Speckle (multiplicative) noise
        p3factor = sqrt(12*p3);
        r        = gpuArray.rand(sizeA);
        b        = arrayfun(@applySpeckle, a, r);
        
        b = images.internal.changeClass(classIn, b);
end



    function pixout = applyGaussian(pixin, r)
        %b = a + sqrt(p4)*randn(sizeA) + p3;
        pixout = pixin + r*p4+p3;
        pixout = max(0, min(pixout,1));
    end

    function pixout = applysnp(pixin,r)
        %b(r < p3/2) = 0; % Minimum value
        %b(r >= p3/2 & r < p3) = 1; % Maximum (saturated) value
        pixout = (r>=p3by2)*( (r<p3) + pixin*(r>=p3));
        pixout = max(0, min(pixout,1));
    end

    function pixout = applySpeckle(pixin,r)
        %b = a + sqrt(12*p3)*a.*(rand(sizeA)-.5);
        pixout = pixin + p3factor*pixin*(r-0.5);
        pixout = max(0, min(pixout,1));
    end

end


%%%
%%% ParseInputs
%%%
function [a, code, classIn, classChanged, p3, p4, msg] = ParseInputs(varargin)

% Initialization
p3  = [];
p4  = [];
msg = '';

% Check the number of input arguments.

narginchk(1,4);

% Check the input-array type.
a = varargin{1};
validateattributes(a,...
    {'uint8','uint16','double','int16','single'}, ...
    {'nonsparse'},mfilename,'I',1);

% Change class to double
classIn      = underlyingType(a);
classChanged = 0;

if classIn ~= "double"
    a            = im2double(a);
    classChanged = 1;
else
    % Clip so a is between 0 and 1.
    a = max(min(a,1),0);
end

% Check the noise type.
if nargin > 1
    if ~matlab.internal.datatypes.isScalarText(varargin{2})
        error(message('images:imnoise:invalidNoiseType'))
    end
    
    % Preprocess noise type string to detect abbreviations.
    allStrings = ["gaussian", "salt & pepper", "speckle", "poisson", "localvar"];
    idx        = find(startsWith(allStrings, varargin{2}));
    
    switch length(idx)
        case 0
            error(message('images:imnoise:unknownNoiseType', varargin{2}))
        case 1
            code = allStrings(idx);
        otherwise
            error(message('images:imnoise:ambiguousNoiseType', varargin{2}))
    end
else
    code = "gaussian";  % default noise type
end


switch code
    case "poisson"
        if nargin > 2
            error(message('images:imnoise:tooManyPoissonInputs'))
        end
        if isa(a, 'int16')
            error(message('images:imnoise:badClassForPoisson'));
        end
        
    case "gaussian"
        p3 = 0;     % default mean
        p4 = 0.01;  % default variance
        
        if nargin > 2
            p3 = varargin{3};
            if ~isRealScalar(p3)
                error(message('images:imnoise:invalidMean'))
            end
        end
        
        if nargin > 3
            p4 = varargin{4};
            if ~isNonnegativeRealScalar(p4)
                error(message('images:imnoise:invalidVariance', 'gaussian'))
            end
        end
        
    case "salt & pepper"
        p3 = 0.05;   % default density
        
        if nargin > 2
            p3 = varargin{3};
            if ~isNonnegativeRealScalar(p3) || (p3 > 1)
                error(message('images:imnoise:invalidNoiseDensity'))
            end
            
            if nargin > 3
                error(message('images:imnoise:tooManySaltAndPepperInputs'))
            end
        end
        
    case "speckle"
        p3 = 0.05;    % default variance
        
        if nargin > 2
            p3 = varargin{3};
            if ~isNonnegativeRealScalar(p3)
                error(message('images:imnoise:invalidVariance', 'speckle'))
            end
        end
        
        if nargin > 3
            error(message('images:imnoise:tooManySpeckleInputs'))
        end
        
    case "localvar"
        if nargin < 3
            error(message('images:imnoise:toofewLocalVarInputs'))
            
        elseif nargin == 3
            % IMNOISE(a,'localvar',v)
            code = "localvar_1";
            p3 = varargin{3};
            if ~isNonnegativeReal(p3) || ~isequal(size(p3),size(a))
                error(message('images:imnoise:invalidLocalVarianceValueAndSize'))
            end
            
        elseif nargin == 4
            % IMNOISE(a,'localvar',IMAGE_INTENSITY,NOISE_VARIANCE)
            code = "localvar_2";
            p3 = varargin{3};
            p4 = varargin{4};
            
            if ~isNonnegativeRealVector(p3) || (any(p3 > 1))
                error(message('images:imnoise:invalidImageIntensity'))
            end
            
            if ~isNonnegativeRealVector(p4)
                error(message('images:imnoise:invalidLocalVariance'))
            end
            
            if ~isequal(size(p3),size(p4))
                error(message('images:imnoise:invalidSize'))
            end
            
            % Intensity values should be in increasing order for gpu
            [p3, sInds] = sort(p3);
            p4          = p4(sInds);
            
        else
            error(message('images:imnoise:tooManyLocalVarInputs'))
        end
        
end

end

%%%
%%% isReal
%%%
function t = isReal(P)
%   isReal(P) returns 1 if P contains only real
%   numbers and returns 0 otherwise.
%
t = isreal(P) && allfinite(P) && ~isempty(P);
end

%%%
%%% isNonnegativeReal
%%%
function t = isNonnegativeReal(P)
%   isNonnegativeReal(P) returns 1 if P contains only real
%   numbers greater than or equal to 0 and returns 0 otherwise.
%
t = isReal(P) && all(P>=0, "all");
end

%%%
%%% isRealScalar
%%%
function t = isRealScalar(P)
%   isRealScalar(P) returns 1 if P is a real,
%   scalar number and returns 0 otherwise.
%
t = isReal(P) && isscalar(P);
end

%%%
%%% isNonnegativeRealScalar
%%%
function t = isNonnegativeRealScalar(P)
%   isNonnegativeRealScalar(P) returns 1 if P is a real,
%   scalar number greater than 0 and returns 0 otherwise.
%
t = isReal(P) && isscalar(P) && P>=0;
end

%%%
%%% isVector
%%%
function t = isVector(P)
%   isVector(P) returns 1 if P is a vector and returns 0 otherwise.
%
t = ((numel(P) >= 2) && ((size(P,1) == 1) || (size(P,2) == 1)));
end

%%%
%%% isNonnegativeRealVector
%%%
function t = isNonnegativeRealVector(P)
%   isNonnegativeRealVector(P) returns 1 if P is a real,
%   vector greater than 0 and returns 0 otherwise.
%
t = isReal(P) && isVector(P) ...
    && all(P>=0); % No need to specify dim as P is known to be a vector
end
