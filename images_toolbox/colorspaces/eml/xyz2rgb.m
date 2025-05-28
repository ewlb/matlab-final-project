function rgb = xyz2rgb(xyz,varargin) %#codegen
%xyz2rgb Convert CIE 1931 XYZ to RGB

%   Copyright 2024 The MathWorks, Inc.

%   Syntax
%   ------
%       rgb = xyz2rgb(xyz)
%       rgb = xyz2rgb(xyz,Name,Value)
%
%   Input Specs
%   -----------
%
%     xyz:
%       Px3 matrix of XYZ triplets or MxNx3 XYZ image or MxNx3xF image stack
%       must be real
%       can be single or double
%
%     ColorSpace:
%       character vector
%       'srgb' (default), 'adobe-rgb-1998', 'linear-rgb' or 'prophoto-rgb'
%       must be a compile-time constant
%
%     WhitePoint:
%       can be character vector, single or double
%       'd65' (default), 'a', 'c', 'e', 'd50', 'd55', 'icc', or 1x3 vector
%       if character vector, must be a compile-time constant
%
%     OutputType:
%       character vector with values: 'double', 'single', 'uint8', 'uint16'
%       default: the same type as the input (single or double)
%       must be a compile-time constant
%
%   OutputSpecs
%   -----------
%
%     RGB:
%       array the same shape as xyz
%       type specified by OutputType
%
%   Summary
%   -------
%
%   This public interface function does the following:
%     - Parse and validate the inputs
%     - Allocate space for the output
%     - Dispatch to the right conversion pipeline
%     - Each conversion pipeline implements the following steps:
%         1. Chromatic adaptation to D65 illuminant (if necessary)
%         2. Conversion to linear RGB
%         3. Conversion to sRGB or Adobe RGB 1998
%         4. Encoding

[outColorSpace,outputType,whitePoint,chromAdaptTform,isChromaAdaptReqd] = ...
    parseInputs(xyz,varargin{:});

% Compute the 3x3 transform from XYZ to linear RGB
if outColorSpace(1) == 'p'
    M = images.color.internal.proPhotoRGBToXYZTransform();
else
    isUseRGBPrimaries = outColorSpace(1) ~= 'a';
    M = images.color.internal.linearRGBToXYZTransform(isUseRGBPrimaries);
end
M = M \ eye(3);

coder.internal.prefer_const(outColorSpace,outputType,whitePoint, ...
    chromAdaptTform,isChromaAdaptReqd,M);

% Allocate space for output
% rgb has the same size as xyz
rgb = coder.nullcopy( cast(zeros(size(xyz)),outputType) );
% rgb = cast(zeros(size(xyz)),outputType);

if isStack(xyz)
    % xyz is MxNx3xF
    numFrames = size(xyz,4);
    numRows   = size(xyz,1);
    numCols   = size(xyz,2);

    % For each triplet, apply the pipeline
    for frame = 1:numFrames
        for col = 1:numCols
            for row = 1:numRows
                % Read L*, a*, and b* from the input buffer
                x = xyz(row,col,1,frame);
                y = xyz(row,col,2,frame);
                z = xyz(row,col,3,frame);

                % Do the conversion
                [R,G,B] = convertXYZToRGB( ...
                    x,y,z,outColorSpace,outputType,whitePoint, ...
                    chromAdaptTform,isChromaAdaptReqd,M);

                % Write R, G, B to output buffer
                rgb(row,col,1,frame) = R;
                rgb(row,col,2,frame) = G;
                rgb(row,col,3,frame) = B;
            end
        end
    end
else
    % xyz is Px3
    numTriplets = size(xyz,1);

    % For each triplet, apply the pipeline
    for k = 1:numTriplets
        % Read L*, a*, and b* from the input buffer
        x = xyz(k,1);
        y = xyz(k,2);
        z = xyz(k,3);

        % Do the conversion
        [R,G,B] = convertXYZToRGB( ...
            x,y,z,outColorSpace,outputType,whitePoint, ...
            chromAdaptTform,isChromaAdaptReqd,M);

        % Write R, G, and B to output buffer
        rgb(k,1) = R;
        rgb(k,2) = G;
        rgb(k,3) = B;
    end
end

%--------------------------------------------------------------------------
function [outColorSpace,outputType,whitePoint,chromAdaptTform,isChromaAdaptReqd] = parseInputs(xyz,varargin)
% Parse and validate the inputs.
%
%   isSRGB:
%     boolean - true if ColorSpace is sRGB, false if it is Adobe RGB 1998
%
%   isLinear:
%     boolean - true if ColorSpace is Linear RGB (linearized sRGB)
%
%   outputType:
%     character vector - encoding type for the RGB values returned by xyz2rgb
%
%   whitePoint:
%     1x3 vector of the same class as xyz
%
%   chromAdaptTform:
%     3x3 matrix to do chromatic adaptation of the same type as xyz
%

coder.internal.prefer_const(xyz,varargin{:});

narginchk(1,7);

% Validate xyz
validateattributes(xyz,{'single','double'},{'real'},mfilename,'XYZ',1)

% Validate the shape of xyz:
% throw error if it is not Px3 or MxNx3xF
coder.internal.errorIf( ...
    ~(ismatrix(xyz) && (size(xyz,2) == 3)) && ...
    ~((numel(size(xyz)) < 5) && (size(xyz,3) == 3)), ...
    'images:color:invalidShape','XYZ');

% Parse optional parameters, if any
[colorSpaceStr,whitePointStr,outputTypeStr] = parsePVPairs(xyz,varargin{:});

% Validate ColorSpace string
validateattributes(colorSpaceStr,{'char'},{},mfilename,'ColorSpace');
outColorSpace = validatestring(colorSpaceStr, ...
    {'srgb','adobe-rgb-1998','linear-rgb','prophoto-rgb'}, ...
    mfilename);

% Validate WhitePoint string and return a 1x3 vector
whitePoint = cast( ...
    images.color.internal.checkWhitePoint(whitePointStr), ...
    'like',xyz);

% Validate OutputType string
outputType = coder.const(validatestring(outputTypeStr, ...
    {'single','double','uint8','uint16'},mfilename));

% chromAdaptMat: used to adapt chromaticity to the desired reference white
% ProPhoto RGB uses a d50 reference white. All other supported colorspaces
% use a d65 reference white.
colorSpaceTmp = coder.const('p');
if outColorSpace(1) == colorSpaceTmp
    refWhitePoint = coder.const('d50');
else
    refWhitePoint = coder.const('d65');
end

if whitePointStr == refWhitePoint %strcmp(whitePointStr,refWhitePoint)
    % Nothing to adapt if the whitepoint specified matches the reference
    % whitepoint of the output colorspace
    chromAdaptTform = cast(eye(3),'like',xyz);
    isChromaAdaptReqd = coder.const(false);
else
    chromAdaptTform = ...
        images.color.internal.coder.XYZChromaticAdaptationTransform( ...
        whitePoint,cast(whitepoint(refWhitePoint),'like',xyz));
    isChromaAdaptReqd = coder.const(true);
end

%--------------------------------------------------------------------------
% Parse optional PV pairs - 'ColorSpace', 'WhitePoint' and 'OutputType'
function [colorSpace,whitePoint,outputType] = parsePVPairs(xyz,varargin)

coder.internal.prefer_const(xyz,varargin{:});

% Default values
defaultColorSpace = 'srgb';
defaultWhitePoint = 'd65';
defaultOutputType = class(xyz);

params = struct( ...
    'ColorSpace',uint32(0), ...
    'WhitePoint',uint32(0), ...
    'OutputType',uint32(0));

options = struct( ...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

optarg = coder.internal.parseParameterInputs(params,options,varargin{:});

colorSpace = coder.internal.getParameterValue( ...
    optarg.ColorSpace, ...
    defaultColorSpace, ...
    varargin{:});

whitePoint = coder.internal.getParameterValue( ...
    optarg.WhitePoint, ...
    defaultWhitePoint, ...
    varargin{:});

outputType = coder.internal.getParameterValue( ...
    optarg.OutputType, ...
    defaultOutputType, ...
    varargin{:});

%--------------------------------------------------------------------------
function TF = isStack(xyz)

if ismatrix(xyz) && (size(xyz,2) == 3)
    % Px3 vector of x*y*z* triplets
    TF = false;
else
    % MxNx3xF stack of x*y*z* images
    TF = true;
end

%--------------------------------------------------------------------------
% Conversion pipeline from unencoded L*a*b* arrays to encoded RGB
function [encodedR,encodedG,encodedB] = convertXYZToRGB(X,Y,Z,outColorSpace,...
    outputType,whitePoint,chromAdaptTform,isChromaAdaptReqd,M)

coder.internal.prefer_const(outColorSpace,outputType,whitePoint, ...
    chromAdaptTform,isChromaAdaptReqd,M);

% 1. Adapt the chromaticity of XYZ if necessary
% This if/else branch should be constant-folded at compile time
if isChromaAdaptReqd
    [X,Y,Z] = images.color.internal.coder.adaptXYZ(X,Y,Z,chromAdaptTform);
end

% 2a. or 2b. Convert to linear RGB
[linearR,linearG,linearB] = matrixMultiply(M,X,Y,Z);

% This if/else branch should be constant-folded at compile time
coloSpaceP = coder.const('p');
coloSpaceS = coder.const('s');
coloSpaceL = coder.const('l');
isProPhoto = outColorSpace(1) == coloSpaceP;
if isProPhoto
    [R,G,B] = images.color.internal.coder.delinearizeProPhotoRGB( ...
        linearR,linearG,linearB );
else
    isSRGB = outColorSpace(1) == coloSpaceS;
    isLinear = outColorSpace(1) == coloSpaceL;
    if isSRGB
        % 3a. Delinearize to sRGB
        [R,G,B] = images.color.internal.coder.delinearizeSRGB( ...
            linearR,linearG,linearB);
    elseif isLinear
        % 3c. Return linear RGB values
        R = linearR;
        G = linearG;
        B = linearB;
    else
        % 3b. Delinearize to Adobe RGB 1998
        [R,G,B] = images.color.internal.coder.delinearizeAdobeRGB( ...
            linearR,linearG,linearB);
    end
end

% 4. Encode to outputType
[encodedR,encodedG,encodedB] = images.color.internal.coder.encodeRGB( ...
    R,G,B,outputType);

%--------------------------------------------------------------------------
function [R,G,B] = matrixMultiply(M,X,Y,Z)

R = M(1,1)*X + M(1,2)*Y + M(1,3)*Z;
G = M(2,1)*X + M(2,2)*Y + M(2,3)*Z;
B = M(3,1)*X + M(3,2)*Y + M(3,3)*Z;
