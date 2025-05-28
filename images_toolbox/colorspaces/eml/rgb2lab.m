function lab = rgb2lab(rgb,varargin) %#codegen
%rgb2lab Convert RGB to CIE 1976 L*a*b*

%   Copyright 2015-2022 The MathWorks, Inc.

%   Syntax
%   ------
%
%       lab = rgb2lab(rgb)
%       lab = rgb2lab(rgb,Name,Value)
%
%   Input Specs
%   -----------
%
%     RGB:
%       Px3 matrix of RGB triplets or MxNx3 RGB image or MxNx3xF image stack
%       must be real
%       can be single, double, uint8 or uint16
%
%     ColorSpace:
%       must be string
%       'srgb' (default), 'adobe-rgb-1998', 'linear-rgb' or 'prophoto-rgb'
%       must be a compile-time constant
%
%     WhitePoint:
%       can be string, single or double
%       'd65' (default), 'a', 'c', 'e', 'd50', 'd55', 'icc', or 1x3 vector
%       if string, must be a compile-time constant
%
%   OutputSpecs
%   -----------
%
%     Lab:
%       array the same shape as RGB
%       single if RGB is single, otherwise double
%
%   Summary
%   -------
%
%   This public interface function does the following:
%     - Parse and validate the inputs
%     - Allocate space for the output
%     - Dispatch to the right conversion pipeline
%     - Each conversion pipeline implements the following steps:
%         1. Decoding
%         2. Linearization
%         3. Conversion to unencoded XYZ
%         4. Chromatic adaptation to D65 illuminant (if necessary)
%         5. Conversion to unencoded L*a*b*

[inColorSpace,outputType,whitePoint,chromAdaptTform,isChromaAdaptReqd] = ...
    parseInputs(rgb,varargin{:});

% Compute the 3x3 transform from linear RGB to XYZ
if inColorSpace(1) == 'p'
    M = images.color.internal.proPhotoRGBToXYZTransform();
else
    % sRGB and Linear RGB use the same primaries.
    isUseSRGBPrimaries = inColorSpace(1) ~= 'a';
    M = images.color.internal.linearRGBToXYZTransform(isUseSRGBPrimaries);
end

coder.internal.prefer_const(inColorSpace,whitePoint,chromAdaptTform, ...
    isChromaAdaptReqd,M);

% Allocate space for output
% lab has the same size as rgb
lab = coder.nullcopy( cast(zeros(size(rgb)),outputType) );

if isStack(rgb)
    % rgb is MxNx3xF
    numFrames = size(rgb,4);
    numRows   = size(rgb,1);
    numCols   = size(rgb,2);
    
    % For each triplet, apply the pipeline
    for frame = 1:numFrames
        for col = 1:numCols
            for row = 1:numRows
                % Read R, G, and B from the input buffer
                R = rgb(row,col,1,frame);
                G = rgb(row,col,2,frame);
                B = rgb(row,col,3,frame);
                
                % Do the conversion
                [L,a,B] = convertRGBToLab( ...
                    R,G,B,inColorSpace,outputType,whitePoint, ...
                    chromAdaptTform,isChromaAdaptReqd,M);
                
                % Write L*, a*, b* to output buffer
                lab(row,col,1,frame) = L;
                lab(row,col,2,frame) = a;
                lab(row,col,3,frame) = B;
            end
        end
    end
else
    % rgb is Px3
    numTriplets = size(rgb,1);
    
    % For each triplet, apply the pipeline
    for k = 1:numTriplets
        % Read R, G, and B from the input buffer
        R = rgb(k,1);
        G = rgb(k,2);
        B = rgb(k,3);
        
        % Do the conversion
        [L,a,b] = convertRGBToLab( ...
            R,G,B,inColorSpace,outputType,whitePoint, ...
            chromAdaptTform,isChromaAdaptReqd,M);
        
        % Write L*, a*, and b* to output buffer
        lab(k,1) = L;
        lab(k,2) = a;
        lab(k,3) = b;
    end
end

%--------------------------------------------------------------------------
% Parse and validate the inputs.
%
%   inColorSpace
%     char vector - Holds the value of the colorspace of input RGB values
%
%   isStack:
%     boolean - true if rgb is MxNx3xF, false if rgb is Px3
%
%   whitePoint:
%     1x3 vector of class double
%
%   doChromAdapt:
%     boolean - false if whitePoint is D65, true otherwise
%
function [inColorSpace,outputType,whitePoint,chromAdaptTform,isChromaAdaptReqd] = parseInputs(rgb,varargin)

coder.internal.prefer_const(rgb,varargin{:});

narginchk(1,5);

% Validate RGB
validateattributes(rgb, ...
    {'single','double','uint8','uint16'}, ...
    {'real'},mfilename,'RGB',1)

% Validate the shape of RGB:
% throw error if it is not Px3 or MxNx3xF
coder.internal.errorIf( ...
    ~(ismatrix(rgb) && (size(rgb,2) == 3)) && ...
    ~((numel(size(rgb)) < 5) && (size(rgb,3) == 3)), ...
    'images:color:invalidShape','RGB');

% Parse optional parameters, if any
[colorSpaceStr,whitePointStr] = parsePVPairs(varargin{:});

% Validate ColorSpace string
validateattributes(colorSpaceStr,{'char'},{},mfilename,'ColorSpace');
inColorSpace = validatestring(colorSpaceStr, ...
    {'srgb','adobe-rgb-1998','linear-rgb','prophoto-rgb'}, ...
    mfilename);

% Determine the data type all computations are made in
% lab is single iff rgb is single, otherwise it is double
if isa(rgb,'single')
    outputType = coder.const('single');
else
    outputType = coder.const('double');
end

% Validate WhitePoint string and return a 1x3 vector
whitePoint = cast( ...
    images.color.internal.checkWhitePoint(whitePointStr), ...
    outputType);

% chromAdaptMat: used to adapt chromaticity to the desired reference white.
% ProPhoto RGB uses a d50 reference white. All other supported colorspaces
% use a d65 reference white.
if strcmp(inColorSpace(1), 'p')
    refWhitePoint = coder.const('d50');
else
    refWhitePoint = coder.const('d65');
end

if strcmp(whitePointStr,refWhitePoint)
    % Nothing to adapt if the whitepoint specified matches the reference
    % whitepoint of the ColorSpace
    chromAdaptTform = cast(eye(3),outputType);
    isChromaAdaptReqd = coder.const(false);
else
    chromAdaptTform = ...
        images.color.internal.coder.XYZChromaticAdaptationTransform( ...
        cast(whitepoint(refWhitePoint),outputType),whitePoint);
    isChromaAdaptReqd = coder.const(true);
end

%--------------------------------------------------------------------------
% Parse optional PV pairs - 'ColorSpace' and 'WhitePoint'
function [colorSpace,whitePoint] = parsePVPairs(varargin)

coder.internal.prefer_const(varargin{:});

% Default values
defaultColorSpace = 'srgb';
defaultWhitePoint = 'd65';

params = struct( ...
    'ColorSpace',uint32(0), ...
    'WhitePoint',uint32(0));

options = struct( ...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

optarg = eml_parse_parameter_inputs(params,options,varargin{:});

colorSpace = eml_get_parameter_value( ...
    optarg.ColorSpace, ...
    defaultColorSpace, ...
    varargin{:});

whitePoint = eml_get_parameter_value( ...
    optarg.WhitePoint, ...
    defaultWhitePoint, ...
    varargin{:});

%--------------------------------------------------------------------------
function TF = isStack(rgb)

if ismatrix(rgb) && (size(rgb,2) == 3)
    % Px3 vector of RGB triplets
    TF = false;
else
    % MxNx3xF stack of RGB images
    TF = true;
end

%--------------------------------------------------------------------------
% Conversion pipeline from encoded RGB arrays to unencoded L*a*b*
function [L,a,b] = convertRGBToLab(encodedR,encodedG,encodedB, ...
    inColorSpace,outputType,whitePoint,chromAdaptTform,isChromaAdaptReqd,M)

coder.internal.prefer_const(inColorSpace,outputType,whitePoint, ...
    chromAdaptTform,isChromaAdaptReqd,M);

% 1. Decode to outputType
[unencodedR,unencodedG,unencodedB] = images.color.internal.coder.decodeRGB( ...
    encodedR,encodedG,encodedB,outputType);

% This if/else branch should be constant-folded at compile time
isProPhoto = inColorSpace(1) == 'p';

if isProPhoto
    [linearR,linearG,linearB] = images.color.internal.coder.linearizeProPhotoRGB( ...
            unencodedR,unencodedG,unencodedB);
else
    isSRGB = inColorSpace(1) == 's';
    isLinear = inColorSpace(1) == 'l';
    if isSRGB
        % 2a. Linearize the unencoded sRGB triplet
        [linearR,linearG,linearB] = images.color.internal.coder.linearizeSRGB( ...
            unencodedR,unencodedG,unencodedB);
    elseif isLinear
        % 2c. Input is already delinearized sRGB
        linearR = unencodedR;
        linearG = unencodedG;
        linearB = unencodedB;
    else
        % 2b. Linearize the unencoded Adobe RGB triplet
        [linearR,linearG,linearB] = images.color.internal.coder.linearizeAdobeRGB( ...
            unencodedR,unencodedG,unencodedB);
    end
end

% 3a. or 3b. Convert to XYZ
[X,Y,Z] = matrixMultiply(M,linearR,linearG,linearB);

% 4. Adapt the chromaticity of XYZ if necessary
% This if/else branch should be constant-folded at compile time
if isChromaAdaptReqd
    [X,Y,Z] = images.color.internal.coder.adaptXYZ(X,Y,Z,chromAdaptTform);
end

% 5. Convert to L*a*b*
[L,a,b] = images.color.internal.coder.XYZToLAB(X,Y,Z,whitePoint);

%--------------------------------------------------------------------------
function [X,Y,Z] = matrixMultiply(M,R,G,B)

X = M(1,1)*R + M(1,2)*G + M(1,3)*B;
Y = M(2,1)*R + M(2,2)*G + M(2,3)*B;
Z = M(3,1)*R + M(3,2)*G + M(3,3)*B;
