function xyz = rgb2xyz(rgb,varargin)

matlab.images.internal.errorIfgpuArray(rgb, varargin{:});
validateattributes(rgb, ...
    {'single','double','uint8','uint16'}, ...
    {'real'},mfilename,'RGB',1)

args = matlab.images.internal.stringToChar(varargin);
options = parseInputs(args{:});

switch options.ColorSpace
    case 'adobe-rgb-1998'
        converter = images.color.adobeRGBToXYZConverter(options.WhitePoint);
    case 'srgb'
        converter = images.color.sRGBToXYZConverter(options.WhitePoint);
    case 'prophoto-rgb'
        converter = images.color.proPhotoRGBToXYZConverter(options.WhitePoint);
    otherwise
        converter = images.color.linearRGBToXYZConverter(options.WhitePoint);
end

converter.OutputType = 'float';
xyz = converter(rgb);

function options = parseInputs(varargin)

narginchk(0,4);

parser = inputParser();
parser.FunctionName = mfilename;

% 'ColorSpace'
defaultColorSpace = 'srgb';
validColorSpaces = {defaultColorSpace, 'adobe-rgb-1998', 'prophoto-rgb', 'linear-rgb'};
validateColorSpace = @(x) validateattributes(x, ...
    {'char'}, ...
    {}, ...
    mfilename,'ColorSpace');
parser.addParameter('ColorSpace', ...
    defaultColorSpace, ...
    validateColorSpace);

% 'WhitePoint'
defaultWhitePoint = 'd65';
parser.addParameter('WhitePoint', ...
    defaultWhitePoint, ...
    @(~) true);

parser.parse(varargin{:});
options = parser.Results;

% InputParser doesn't work with validatestring, so use it after parsing.
options.ColorSpace = validatestring( ...
    options.ColorSpace, ...
    validColorSpaces, ...
    mfilename,'ColorSpace');

% Use checkWhitePoint to validate the white point
options.WhitePoint = ...
    images.color.internal.checkWhitePoint(options.WhitePoint);

%   Copyright 2014-2022 The MathWorks, Inc.
