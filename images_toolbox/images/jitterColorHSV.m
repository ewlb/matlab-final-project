function B = jitterColorHSV(A,varargin)
% jitterColorHSV Randomly augment color of each pixel
%
%   B = jitterColorHSV(A,Name,Value,___) augments the color of each pixel
%   in the RGB input image A using Name/Value pairs to control specifics of
%   how color content in A is altered.
%
%   Name/Value Pairs include:
%
%   'Hue'               A numeric scalar or two-element numeric vector.
%                       When specified as a scalar, the input image is
%                       converted to HSV colorspace and the hue channel is
%                       modified by adding a random offset selected from
%                       the uniform random range [-Hue,Hue]. The value
%                       provided must be in the range [0.0,1.0].
%                       When specified as a vector, the input is used
%                       directly as a range in the form [minRange,maxRange].
%
%                       Default: 0.0
%
%   'Saturation'        A numeric scalar or two-element numeric vector.
%                       When specified as a scalar, the input image is
%                       converted to HSV colorspace and the saturation
%                       channel is modified by adding a random offset
%                       selected from the uniform random range
%                       [-Saturation,Saturation]. The value provided must
%                       be in the range [0.0,1.0]. When specified as a
%                       vector, the input is used directly as a range in
%                       the form [minRange,maxRange].
%
%                       Default: 0.0
%
%   'Brightness'        A numeric scalar or two-element numeric vector.
%                       When specified as a scalar, the input image is
%                       converted to HSV colorspace and the brightness
%                       (value) channel is modified by adding a random
%                       offset selected from the uniform random range
%                       [-Brightness,Brightness]. The value provided must
%                       be in the range [0.0,1.0]. When specified as a vector, 
%                       the input is used directly as a range in the form
%                       [minRange,maxRange].
%
%                       Default: 0.0
%
%   'Contrast'          A numeric scalar or two-element numeric vector. When
%                       specified as a scalar, the input image is converted
%                       to HSV colorspace. The brightness (value) channel
%                       is scaled by a random factor selected from the
%                       range [max(0,1-Contrast),1+Contrast]. The value
%                       must be positive. When specified as a vector, the 
%                       input is used directly as a range of scale factors 
%                       in the form [minRange,maxRange].
%
%                       Default: 0.0
%
%   Class Support
%   -------------
%   The input RGB image can be of class uint8, uint16, single,
%   or double. The output image is of the same type as the input.
%
%   Example
%   ---------
%   % Randomly augment color content of input image
%   A = imread('kobi.png');
%   B = jitterColorHSV(A,'Contrast',0.4,'Hue',0.1,'Saturation',0.2,'Brightness',0.3);
%   figure
%   imshow(B)
%
%   See also randomAffine2d, randomCropWindow2d, centerCropWindow2d

% Copyright 2019 The MathWorks, Inc.

narginchk(1,inf);

matlab.images.internal.errorIfgpuArray(A, varargin{:});

validateattributes(A,{'uint8','uint16','single','double'},...
    {'real','nonsparse','ndims',3,'size',[NaN NaN 3]},'jitterColorHSV','A');

classIn = class(A);

[inputs,defaults] = parseInputs(varargin{:});

hsv = rgb2hsv(A);

if ~defaults.DefaultHue
    hsv(:,:,1) = adjustHue(hsv(:,:,1),uniformRandomValInRange(inputs.Hue));
end

if ~defaults.DefaultSaturation
    hsv(:,:,2) = adjustSaturation(hsv(:,:,2),uniformRandomValInRange(inputs.Saturation));
end

if ~defaults.DefaultBrightness
    hsv(:,:,3) = adjustBrightness(hsv(:,:,3),uniformRandomValInRange(inputs.Brightness));
end

if ~defaults.DefaultContrast
    hsv(:,:,3) = adjustContrast(hsv(:,:,3),uniformRandomValInRange(inputs.Contrast));
end

B = images.internal.changeClass(classIn,hsv2rgb(hsv));

end

function hueOut = adjustHue(hueIn,offset)
hueOut = hueIn + offset;
hueOut = mod(hueOut,1.0); % Hue wraps circularly in range [0,1].
end


function saturationOut = adjustSaturation(saturationIn,offset)
saturationOut = saturationIn + offset;
saturationOut = saturate(saturationOut);
end

function brightnessOut = adjustBrightness(brightnessIn,offset)
brightnessOut = brightnessIn + offset;
brightnessOut = saturate(brightnessOut);
end

function brightnessOut = adjustContrast(brightnessIn,scale)
meanBrightness = mean2(brightnessIn);
brightnessOut = saturate((brightnessIn-meanBrightness)*scale + meanBrightness);
end

function B = saturate(A)
B = min(max(0.0,A),1.0);
end

function [inputs,defaultsStruct] = parseInputs(varargin)

parser = inputParser();
parser.addParameter('Hue',0,@(val) validateFactor(val,'Hue'));
parser.addParameter('Saturation',0,@(val) validateFactor(val,'Saturation'));
parser.addParameter('Brightness',0,@(val) validateFactor(val,'Brightness'));
parser.addParameter('Contrast',0,@validateContrast);

parse(parser,varargin{:});
inputs = parser.Results;
inputs.Hue = convertScalarToRange(inputs.Hue);
inputs.Saturation = convertScalarToRange(inputs.Saturation);
inputs.Brightness = convertScalarToRange(inputs.Brightness);
inputs.Contrast = convertScalarContrastToRange(inputs.Contrast);

usingDefaults = string(parser.UsingDefaults);
defaultsStruct.DefaultHue = any(usingDefaults == "Hue");
defaultsStruct.DefaultSaturation = any(usingDefaults == "Saturation");
defaultsStruct.DefaultBrightness = any(usingDefaults == "Brightness");
defaultsStruct.DefaultContrast = any(usingDefaults == "Contrast");

end

function TF = validateContrast(val)

if isscalar(val)
    validateattributes(val,{'numeric'},{'real','finite','nonnegative'},...
        'jitterColorHSV','Contrast');
else
    validateattributes(val,{'numeric'},{'real','vector','numel',2,'nondecreasing','positive'},...
        'jitterColorHSV','Contrast');
end

TF = true;

end

function TF = validateFactor(factor,name)

if isscalar(factor)
    validateattributes(factor,{'numeric'},{'real','>=',0,'<=',1.0},...
        'jitterColorHSV',name);
else
    validateattributes(factor,{'numeric'},{'real','vector','numel',2,'nondecreasing','>=',-1.0,'<=',1.0},...
        'jitterColorHSV',name);
end

TF = true;
end

function range = convertScalarToRange(val)

if isscalar(val)
    range = double([-val,val]);
else
    range = double(val);
end
end

function range = convertScalarContrastToRange(val)
if isscalar(val)
    range = double([max(0,1-val),1+val]);
else
    range = double(val);
end
end

function valOut = uniformRandomValInRange(range)
valOut = rand*diff(range) + range(1);
end



