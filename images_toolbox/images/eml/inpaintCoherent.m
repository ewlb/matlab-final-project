function J = inpaintCoherent(I,mask,varargin)
%INPAINTCOHERENT Fill in specified region in image using coherent transport.
% 
%   J = inpaintCoherent(I,MASK) fills the regions in image I specified by
%   MASK. I must be a grayscale or an RGB image. MASK is a binary image
%   having same number of rows and columns as I. Non-zero pixels in MASK
%   designate the pixels of image I to fill.
%
%   J = inpaintCoherent(I,MASK,NAME,VALUE, ...) performs inpainting where
%   parameters control various aspects of the operation. Parameter names
%   can be abbreviated. Parameters include:
%
%     'SmoothingFactor'        Positive scalar value specifying the
%                              standard deviation of the Gaussian filter.
%
%     'Radius'                 Positive scalar value specifying the radius
%                              of the circular neighbor region around the
%                              pixel to be inpainted. 

% Copyright 2018-2020 The MathWorks, Inc.

%#codegen
%#ok<*EMCLS>
%#ok<*EMCA>


% Parse and validate input arguments.
narginchk(2,6);
validateattributes(I, {'single', 'double', 'int8','uint8', 'int16','uint16','int32','uint32'},...
                        {'nonempty','real','finite','nonsparse'}, mfilename, 'I', 1);
validateattributes(mask, {'logical'},{'real','2d','nonsparse'}, mfilename, 'mask', 2);

% img must be MxN or MxNx3
validColorImage = (ndims(I) == 3) && (size(I,3) == 3);
coder.internal.errorIf((~(ismatrix(I) || validColorImage)),...
        'images:validate:invalidImageFormat','I')
% validate size of I and mask
validateSize(I,mask);

[SmoothingFactor, radius] = parseInputsCodegen(varargin{:});

% call main algorithm
J = images.internal.coder.alginpaintCoherent(I,mask,radius,SmoothingFactor);
%--------------------------------------------------------------------------
function validateSize(I,mask)
% Make sure numbers of rows and cols are same for both I and MASK.
coder.internal.errorIf((~isequal(size(I,1), size(mask,1))...
    || ~isequal(size(I,2), size(mask,2))),'images:inpaint:mismatchDim')

%--------------------------------------------------------------------------
function [sigmaVal, radiusVal] = parseInputsCodegen(varargin)
% Get user-provided and default options.
% NameValue 'SmoothingFactor', 'Radius'
defaultSmoothingFactor = 2;
defaultRadius = 5;
params = struct(...
    'SmoothingFactor', uint32(0),...
    'Radius', uint32(0));
optionsParams = struct(...
    'CaseSensitivity',false, ...
    'StructExpand',   true, ...
    'PartialMatching',true);

parser = eml_parse_parameter_inputs(params,optionsParams, varargin{:});
SmoothingFactor = eml_get_parameter_value(parser.SmoothingFactor,defaultSmoothingFactor,...
            varargin{:});

Radius = eml_get_parameter_value(parser.Radius,defaultRadius,...
            varargin{:});
        
validateattributes(SmoothingFactor,{'double'}, ...
    {'nonempty','scalar','real','finite','nonsparse','nonnegative','nonzero','>=', 0.5}, ...
    mfilename,'SmoothingFactor');

 validateattributes(Radius,{'double'}, ...
    {'nonempty','scalar','real','integer','nonsparse','nonnegative','nonzero','>=', 1}, ...
    mfilename,'Radius');
sigmaVal = SmoothingFactor;
radiusVal = Radius;
        
