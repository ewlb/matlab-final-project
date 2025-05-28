function B = rgb2lin(varargin)

[A,colorSpace,outputType] = parseInputs(varargin{:});

% Convert to floating point for the conversion
if ~isa(A,'double')
    A = im2single(A);
end

switch(lower(colorSpace))
    case "srgb"
        B = sRGBToLinearRGB(A);
    case "adobe-rgb-1998"
        B = adobeRGBToLinearRGB(A);
    case "prophoto-rgb"
        B = proPhotoRGBToLinearRGB(A);
    otherwise
        assert(false, "Invalid Colorspace");
end

% Convert to the desired output type
convert = str2func(['im2' outputType]);
B = convert(B);

%--------------------------------------------------------------------------
function y = sRGBToLinearRGB(x)
% Curve parameters
gamma = cast(2.4,'like',x);
a     = cast(1/1.055,'like',x);
b     = cast(0.055/1.055,'like',x);
c     = cast(1/12.92,'like',x);
d     = cast(0.04045,'like',x);

in_sign = -2 * (x < 0) + 1;
x = abs(x);

lin_range = (x < d);
gamma_range = ~lin_range;

y = zeros(size(x),'like',x);

y(gamma_range) = exp(gamma .* log(a * x(gamma_range) + b));
y(lin_range) = c * x(lin_range);

y = y .* in_sign;

%--------------------------------------------------------------------------
function y = adobeRGBToLinearRGB(x)
gamma = cast(2.19921875,'like',x);
y = x .^ gamma;

%--------------------------------------------------------------------------
function y = proPhotoRGBToLinearRGB(x)

    func = images.color.ProPhotoRGBEncoder.DecoderFunctionTable.(class(x));
    y = func(x);

%--------------------------------------------------------------------------
function [A,colorSpace,outputType] = parseInputs(varargin)

narginchk(1,5);

parser = inputParser();
parser.FunctionName = mfilename;

% A
validateImage = @(x) validateattributes(x, ...
    {'single','double','uint8','uint16'}, ...
    {'real','nonsparse','nonempty'}, ...
    mfilename,'A',1);
parser.addRequired('A', validateImage);

% NameValue 'ColorSpace': 'srgb' or 'adobe-rgb-1998'
defaultColorSpace = 'srgb';
validateChar = @(x) validateattributes(x, ...
    {'char','string'}, ...
    {'scalartext'}, ...
    mfilename, 'ColorSpace');
parser.addParameter('ColorSpace', ...
    defaultColorSpace, ...
    validateChar);

% NameValue 'OutputType': 'single', 'double', 'uint8', 'uint16'
defaultOutputType = -1;
parser.addParameter('OutputType', ...
    defaultOutputType, ...
    validateChar);

parser.parse(varargin{:});
inputs = parser.Results;
A = inputs.A;
colorSpace = inputs.ColorSpace;
outputType = inputs.OutputType;

if isequal(outputType, defaultOutputType)
    outputType = class(A);
end

% Additional validation
colorSpace = validatestring( ...
    colorSpace, ...
    {'srgb','adobe-rgb-1998','prophoto-rgb'}, ...
    mfilename, 'ColorSpace');

outputType = validatestring( ...
    outputType, ...
    {'single','double','uint8','uint16'}, ...
    mfilename, 'OutputType');

%   Copyright 2016-2022 The MathWorks, Inc.
