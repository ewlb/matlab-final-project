function lab = rgb2lab(rgb,varargin)

matlab.images.internal.errorIfgpuArray(rgb, varargin{:});
validateattributes(rgb, ...
    {'single','double','uint8','uint16'}, ...
    {'real'},mfilename,'RGB',1)

args = matlab.images.internal.stringToChar(varargin);
options = parseInputs(args{:});

converter2 = images.color.xyzToLABConverter(options.WhitePoint);

switch options.ColorSpace
    case 'adobe-rgb-1998'
        converter1 = images.color.adobeRGBToXYZConverter(options.WhitePoint);
        converter = images.color.ColorConverter({converter1, converter2});

    case 'srgb'
        converter1 = images.color.sRGBToXYZConverter(options.WhitePoint);
        converter = images.color.ColorConverter({converter1, converter2});
        converter.InputEncoder = images.color.sRGBLinearEncoder;

    case 'prophoto-rgb'
        converter1 = images.color.proPhotoRGBToXYZConverter(options.WhitePoint);
        converter = images.color.ColorConverter({converter1, converter2});
        converter.InputSpace = converter1.InputSpace;
        converter.OutputSpace = converter2.OutputSpace;
        converter.InputEncoder = converter1.InputEncoder;
        converter.OutputEncoder = converter2.OutputEncoder;
        
    otherwise
        converter1 = images.color.linearRGBToXYZConverter(options.WhitePoint);
        converter = images.color.ColorConverter({converter1, converter2});
end

% Specify the output is double for all non-single inputs and single for
% single-valued inputs.
converter.OutputType = 'float';
lab = converter(rgb);

function options = parseInputs(varargin)

narginchk(0,4);

parser = inputParser();
parser.FunctionName = mfilename;

% 'ColorSpace'
defaultColorSpace = 'srgb';
validColorSpaces = {defaultColorSpace, 'adobe-rgb-1998', 'linear-rgb', 'prophoto-rgb'};
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
