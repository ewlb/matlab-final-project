function rgb = lab2rgb(lab,varargin)

validateattributes(lab,{'single','double'},{'real'},mfilename,'LAB',1)

args = matlab.images.internal.stringToChar(varargin);
options = parseInputs(args{:});

converter1 = images.color.labToXYZConverter(options.WhitePoint);

switch options.ColorSpace
    case 'adobe-rgb-1998'
        converter2 = images.color.xyzToAdobeRGBConverter(options.WhitePoint);
        converter = images.color.ColorConverter({converter1, converter2});
    case 'srgb'
        converter2 = images.color.xyzToSRGBConverter(options.WhitePoint);
        converter = images.color.ColorConverter({converter1, converter2});
    case 'prophoto-rgb'
        converter2 = images.color.xyzToProPhotoRGBConverter(options.WhitePoint);
        converter = images.color.ColorConverter({converter1, converter2});

        % Configure the Input/OutputEncoder to ensure appropriate transfer
        % functions are applied during the colour conversion process
        converter.InputSpace = converter1.InputSpace;
        converter.OutputSpace = converter2.OutputSpace;
        converter.InputEncoder = converter1.InputEncoder;
        converter.OutputEncoder = converter2.OutputEncoder;
        
    otherwise
        converter2 = images.color.xyzToLinearRGBConverter(options.WhitePoint);
        converter = images.color.ColorConverter({converter1, converter2});
end
converter.OutputType = options.OutputType;
rgb = converter(lab);

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
defaultOutputType = 'float';
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

%   Copyright 2014-2022 The MathWorks, Inc.
