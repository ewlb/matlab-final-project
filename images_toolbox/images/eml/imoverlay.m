function B = imoverlay(A_,BW_,varargin) %#codegen
%IMOVERLAY Burn binary mask into a 2-D image - C-to-MATLAB code generation.

%   Copyright 2015-2022 The MathWorks, Inc.

% Parse and validate inputs
[A,BW,color] = parseInputs(A_,BW_,varargin{:});

% Copy over A to B and fill with color
B = coder.nullcopy(zeros(size(A),'like',A));
d = size(B,3); % This will have a value 3 always
c = size(B,2);
r = size(B,1);

% Loop Scheduler
schedule = coder.loop.Control;
if coder.isColumnMajor()
    schedule = schedule.parallelize('col');
else
    schedule = schedule.interchange('row','p').parallelize('row');
end
% Apply Loop Scheduler
schedule.apply
for p = 1:d
    for col = 1:c
        for row = 1:r
            if BW(row,col)
                B(row,col,p) = color(p);
            else
                B(row,col,p) = A(row,col,p);
            end
        end
    end
end


%--------------------------------------------------------------------------
function [A,BW,color] = parseInputs(A_,BW_,varargin)

narginchk(2,3);

numericTypes = images.internal.iptnumerictypes();

% Validate A
validateattributes(A_, ...
    {'logical','uint8','uint16','int16','single','double'}, ...
    {'nonsparse','real'},mfilename,'A');

% A is either 2D grayscale or 3D RGB
validColorImage = (ndims(A_) == 3) && (size(A_,3) == 3);
coder.internal.errorIf(~ismatrix(A_) && ~validColorImage, ...
    'images:validate:invalidImageFormat','A');

% Validate BW
validateattributes(BW_,{'logical',numericTypes{:}}, ...
    {'nonsparse','real','2d'},mfilename,'BW');

% A and BW must have the same number of pixels
coder.internal.errorIf( ...
    (size(A_,1) ~= size(BW_,1)) || (size(A_,2) ~= size(BW_,2)), ...
    'images:validate:unequalNumberOfRowsAndCols','A','BW');

% Convert A to RGB uint8
if validColorImage
    A = im2uint8(A_);
else
    A = im2uint8(repmat(A_,[1,1,3]));
end

% Convert BW to logical
if isempty(BW_)
    BW = logical(BW_);
elseif islogical(BW_)
    BW = BW_;
else
    [m,n] = size(BW_);
    BW = coder.nullcopy(false(m,n));
    if coder.isColumnMajor
        parfor j=1:n
            for i=1:m
                BW(i,j) = BW_(i,j)~=0; % handle NaN's as 1's
            end
        end
    else
        parfor i=1:m
            for j=1:n
                BW(i,j) = BW_(i,j)~=0;
            end
        end
    end
end

if (nargin < 3)
    color = getColorValue('yellow');
else
    color = validateColorSpec(varargin{1});
end

%--------------------------------------------------------------------------
function rgb = validateColorSpec(color)

coder.internal.prefer_const(color);

if ischar(color) || isstring(color)
    coder.internal.errorIf(~coder.internal.isConst(color), ...
        'images:imoverlay:colorStringMustBeConstant');
    colorStr = validatestring(color,validColorStrings(),mfilename,'Color');
    rgb = getColorValue(colorStr);
else
    % color must be a vector of length 3
    % color must be in [0,1]
    validateattributes(color,{'single','double'}, ...
        {'real','vector','numel',3,'>=',0,'<=',1},mfilename,'Color');
    rgb = im2uint8(color);
end

%--------------------------------------------------------------------------
function list = validColorStrings()

% These are exactly the fields in the struct
% matlab.graphics.datatype.ColorTable.

list = {'b','bl','blue','black','k','cyan','g', ...
    'green','magenta','red','w','white','yellow'};

%--------------------------------------------------------------------------
function color = getColorValue(colorString)

coder.internal.prefer_const(colorString)

% The switch/case below is straight from the
% matlab.graphics.datatype.ColorTable struct.

switch colorString
    case {'b','bl','blue'}
        color = uint8([0,0,255]);
    case {'black','k'}
        color = uint8([0,0,0]);
    case 'cyan'
        color = uint8([0,255,255]);
    case {'g','green'}
        color = uint8([0,255,0]);
    case 'magenta'
        color = uint8([255,0,255]);
    case 'red'
        color = uint8([255,0,0]);
    case {'w','white'}
        color = uint8([255,255,255]);
    case 'yellow'
        color = uint8([255,255,0]);
end

% LocalWords:  nonsparse grayscale BW
