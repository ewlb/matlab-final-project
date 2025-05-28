function rgb = xyz2rgb(xyz,varargin)

validateattributes(xyz,{'single','double'},{'real'},mfilename,'XYZ',1)

args = matlab.images.internal.stringToChar(varargin);
options = parseInputs(args{:});

switch options.ColorSpace
    case 'adobe-rgb-1998'
        converter = images.color.xyzToAdobeRGBConverter(options.WhitePoint);
    case 'srgb'
        converter = images.color.xyzToSRGBConverter(options.WhitePoint);
    case 'prophoto-rgb'
        converter = images.color.xyzToProPhotoRGBConverter(options.WhitePoint);
    otherwise
        converter = images.color.xyzToLinearRGBConverter(options.WhitePoint);
end

if isempty(options.OutputType)
    converter.OutputType = 'float';
else
    converter.OutputType = options.OutputType;
end

rgb = converter(xyz);

function options = parseInputs(varargin)

narginchk(0,6);

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

% 'OutputType'
defaultOutputType = [];
validOutputTypes = {'double', 'single', 'uint8', 'uint16'};
validateOutputType = @(x) validateattributes(x, ...
    {'char'}, ...
    {}, ...
    mfilename,'OutputType');
parser.addParameter('OutputType', ...
    defaultOutputType, ...
    validateOutputType);

parser.parse(varargin{:});
options = parser.Results;

% InputParser doesn't work with validatestring, so use it after parsing.
options.ColorSpace = validatestring( ...
    options.ColorSpace, ...
    validColorSpaces, ...
    mfilename,'ColorSpace');

if ~isequal(options.OutputType, defaultOutputType)
    options.OutputType = validatestring( ...
        options.OutputType, ...
        validOutputTypes, ...
        mfilename,'OutputType');
end

% Use checkWhitePoint to validate the white point
options.WhitePoint = ...
    images.color.internal.checkWhitePoint(options.WhitePoint);

%    Copyright 2014-2022 The MathWorks, Inc.
