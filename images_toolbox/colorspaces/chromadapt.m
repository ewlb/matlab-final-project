function B = chromadapt(varargin)

inputs = parseInputs(varargin{:});

% Normalize illuminant so that Y=1
% This prevents changing the overall brightness of the scene.
illuminant_xyz = rgb2xyz(inputs.illuminant, ...
    'ColorSpace', inputs.ColorSpace);
illuminant_xyz(illuminant_xyz == 0) = eps(class(illuminant_xyz));
illuminant_xyz = illuminant_xyz / illuminant_xyz(2);

if strcmp(inputs.Method, 'simple')
    % Scale in floating point
    if isa(inputs.A,'double')
        convert = @(x) x;
    else
        convert = @im2single;
    end
    B = convert(inputs.A);
    
    % Convert the normalized illuminant back to RGB
    illuminant = xyz2rgb(illuminant_xyz, ...
        'ColorSpace', inputs.ColorSpace, ...
        'OutputType', class(B));
    
    % Simple scaling of the RGB values
    % Note: if illuminant has a zero value, this is undefined
    illuminant = abs(illuminant);
    illuminant(illuminant == 0) = eps(class(illuminant));
    B = B ./ reshape(illuminant, [1 1 3]);
    
    % Convert back to the right type
    convert = str2func(['im2' class(inputs.A)]);
    B = convert(B);
else
    % Bradford and von Kries methods
    C = makecform('adapt', ...
        'WhiteStart', double(illuminant_xyz), ...
        'WhiteEnd', whitepoint('d65'), ...
        'AdaptModel', inputs.Method);
    
    A_XYZ = rgb2xyz(inputs.A, ...
        'WhitePoint', 'd65', ...
        'ColorSpace', inputs.ColorSpace);
    
    B_XYZ = applycform(double(A_XYZ), C); % only works in double
    
    B = xyz2rgb(B_XYZ, ...
        'WhitePoint', 'd65', ...
        'ColorSpace', inputs.ColorSpace, ...
        'OutputType', class(inputs.A));
end

%--------------------------------------------------------------------------
function inputs = parseInputs(varargin)

narginchk(2,6);
matlab.images.internal.errorIfgpuArray(varargin{1:2});
parser = inputParser();
parser.FunctionName = mfilename;

% A
validateImage = @(x) validateattributes(x, ...
    {'single','double','uint8','uint16'}, ...
    {'real','nonsparse','nonempty'}, ...
    mfilename,'A',1);
parser.addRequired('A', validateImage);

% illuminant
validateIlluminant = @(x) validateattributes(x, ...
    {'single','double','uint8','uint16'}, ...
    {'real','nonsparse','nonempty','nonnan','finite','vector','numel',3}, ...
    mfilename,'illuminant',2);
parser.addRequired('illuminant', validateIlluminant);

validateStringInput = @(x,name) validateattributes(x, ...
    {'char','string'}, ...
    {'scalartext'}, ...
    mfilename, name);

% NameValue 'ColorSpace': 'srgb', 'adobe-rgb-1998', 'linear-rgb' or
% 'prophoto-rgb'
validColorSpaces = {'srgb','adobe-rgb-1998','linear-rgb','prophoto-rgb'};
defaultColorSpace = validColorSpaces{1};
validateColorSpace = @(x) validateStringInput(x,'ColorSpace');
parser.addParameter('ColorSpace', ...
    defaultColorSpace, ...
    validateColorSpace);

% NameValue 'Method': 'bradford', 'vonkries' or 'simple'
validMethods = {'bradford','vonkries','simple'};
defaultMethod = validMethods{1};
validateMethod = @(x) validateStringInput(x,'Method');
parser.addParameter('Method', ...
    defaultMethod, ...
    validateMethod);

parser.parse(varargin{:});
inputs = parser.Results;

% shape illuminant as a row vector
inputs.illuminant = inputs.illuminant(:)';

% Additional validation

% A must be a MxNx3 RGB image
validColorImage = (ndims(inputs.A) == 3) && (size(inputs.A,3) == 3);
if ~validColorImage
    error(message('images:validate:invalidRGBImage','A'));
end

% illuminant cannot be black [0 0 0]
if isequal(inputs.illuminant, [0 0 0])
    error(message('images:awb:illuminantCannotBeBlack'));
end

inputs.ColorSpace = validatestring( ...
    inputs.ColorSpace, ...
    validColorSpaces, ...
    mfilename, 'ColorSpace');

inputs.Method = validatestring( ...
    inputs.Method, ...
    validMethods, ...
    mfilename, 'Method');

%   Copyright 2016-2022 The MathWorks, Inc.
