function mask = circles2mask(varargin)%#codegen

[centers,radii,maskSize] = parseInputs(varargin{:});

numRadii = length(radii);
numCircles = coder.internal.indexInt(size(centers,1));

% If only one radius is specified, use that value for all the circles.
if(numRadii == 1)
    radiiOne = repmat(radii,numCircles,1);
else
    radiiOne = radii;
    coder.internal.errorIf(numRadii ~= numCircles,'images:circles2mask:sizeMismatch');
end

% Initialize the output mask.
mask = false(maskSize);
[rows,cols] = size(mask);

% Process each circle.
for k = 1:numCircles
    xc = centers(k,1);
    yc = centers(k,2);
    r = radiiOne(k);

    % Find the submatrix of mask that completely contains the portion
    % of this circle that lies within the bounds of the image. First,
    % find the smallest bounding box with integer coordinates that
    % contains the circe. The bounding box goes from x1 to x2
    % horizontally and from y1 to y2 vertically.
    xOne = floor(xc - r);
    xTwo = ceil(xc + r);
    yOne = floor(yc - r);
    yTwo = ceil(yc + r);

    % Next, clip the bounding box to the domain of the image.
    ixOne = max(xOne,1);
    ixTwo = min(xTwo,cols);
    iyOne = max(yOne,1);
    iyTwo = min(yTwo,rows);

    % Construct subscript values that can be used to extract and to
    % assign into a submatrix of mask.
    xx = ixOne:ixTwo;
    yy = (iyOne:iyTwo)';

    % For the submatrix defined by the indices xx and yy, compute which
    % pixels lie within (or on the perimeter of) the circle.

    submask = hypot(xx - xc, yy - yc) <= r;

    % Update the mask submatrix.
    mask(yy,xx) = mask(yy,xx) | submask;

end

end

function [centers, radii, maskSize] = parseInputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);

narginchk(3,3);

if isempty(varargin{1})
    centersTmp = varargin{1};
else
    centersTmp = varargin{1};
    validateattributes(centersTmp, {'numeric','loigcal'}, {'real','ncols',2},...
        mfilename,'CENTERS', 1);

end

if isempty(varargin{2})
    radiiTmp = varargin{2};
else
    radiiTmp = varargin{2};
    validateattributes(radiiTmp, {'numeric','logical'}, {'vector' 'real' 'nonnegative'},...
        mfilename,'RADII', 2);

end


maskSizeTmp = varargin{3};
validateattributes(maskSizeTmp, {'numeric','logical'}, {'integer' 'nonnegative','numel',2},...
    mfilename,'MASKSIZE', 3);
centers = double(centersTmp);
radii   = double(radiiTmp);
maskSize = double(maskSizeTmp);

end

% Copyright 2023 The MathWorks, Inc.