function varargout = roipoly(varargin)%#codegen
%ROIPOLY Select polygonal region of interest.
%
%  Syntax
%  ------
%
%  BW = ROIPOLY(I,xi,yi)
%  BW = ROIPOLY(m,n,xi,yi)
%  BW = ROIPOLY(x,y,I,xi,yi)
%  [BW,xi] = ROIPOLY(...)
%  [BW,xi,yi] = ROIPOLY(...)
%  [x,y, BW,xi] = ROIPOLY(...)
%  [x,y,BW,xi,yi] = ROIPOLY(...)
%
%  Input Specs
%  ------------
%
%  I
%
%  uint8, uint16, int16, double or single
%
%  xi,yi,m,n,x,y
%
%  double
%
%  Output Specs
%  ------------
%
%  BW
%
%  logical
%
%  x,y,xi,yi
%
%  double

%   Copyright 2023 The MathWorks, Inc.

%#ok<*EMCA>

[xData,yData,nRows,nCols,xi,yi] = parseInputs(varargin{:});

coder.internal.errorIf(length(xi)~=length(yi),...
    'images:roipoly:xiyiMustBeSameLength');

% Make sure polygon is closed.
if (~isempty(xi))
    if ( xi(1) ~= xi(end) || yi(1) ~= yi(end) )
        xii = [xi;xi(1)];
        yii = [yi;yi(1)];
    else
        xii = xi;
        yii = yi;
    end
else
    xii = xi;
    yii = yi;
end

% Transform xi,yi into pixel coordinates.
roiX = axes2pix(nCols, xData, xii);
roiY = axes2pix(nRows, yData, yii);

BW = poly2mask(roiX, roiY, nRows, nCols);

nargoutchk(1,5)

if nargout == 1
    varargout{1} = BW;
elseif nargout == 2
    varargout{1} = BW;
    varargout{2} = xii;
elseif nargout == 3
    varargout{1} = BW;
    varargout{2} = xii;
    varargout{3} = yii;
elseif nargout == 4
    varargout{1} = xData;
    varargout{2} = yData;
    varargout{3} = BW;
    varargout{4} = xii;
else
    varargout{1} = xData;
    varargout{2} = yData;
    varargout{3} = BW;
    varargout{4} = xii;
    varargout{5} = yii;
end

end % roipoly

%%%
%%% parse_inputs
%%%

%--------------------------------------------------------
function [x,y,nRows,nCols,xi,yi] = parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);

narginchk(3,6)

if nargin == 3
    % SYNTAX: roipoly(I,xi,yi)
    I = varargin{1};
    validateInImage(varargin{1},'I',1);
    nRowsOne = size(I,1);
    nColsOne = size(I,2);
    xiOne = varargin{2}(:);
    yiOne = varargin{3}(:);
    validateVectorsXiYi(varargin{2},'XI',2);
    validateVectorsXiYi(varargin{3},'YI',3);
    xOne = [1 nColsOne]; yOne = [1 nRowsOne];
elseif nargin == 4
    % SYNTAX: roipoly(m,n,xi,yi)
    nRowsOne = varargin{1};
    nColsOne = varargin{2};
    validateRowCols(varargin{1},'ROWS',1);
    validateRowCols(varargin{2},'COLS',2);
    xiOne = varargin{3}(:);
    yiOne = varargin{4}(:);
    validateVectorsXiYi(varargin{3},'XI',3);
    validateVectorsXiYi(varargin{4},'YI',4);
    xOne = [1 nColsOne]; yOne = [1 nRowsOne];
elseif nargin == 5
    % SYNTAX: roipoly(x,y,I,xi,yi)
    x = varargin{1};
    y = varargin{2};
    validateVectorsXY(varargin{1},'X',1);
    validateVectorsXY(varargin{2},'Y',2);
    I = varargin{3};
    validateInImage(varargin{3},'I',3);
    xiOne = varargin{4}(:);
    yiOne = varargin{5}(:);
    validateVectorsXiYi(varargin{4},'XI',4);
    validateVectorsXiYi(varargin{5},'YI',5);
    nRowsOne = size(I,1);
    nColsOne = size(I,2);
    xOne = [x(1) x(end)];
    yOne = [y(1) y(end)];
else
    % SYNTAX: roipoly(x,y,m,n,xi,yi)
    x = varargin{1};
    y = varargin{2};
    validateVectorsXY(varargin{1},'X',4);
    validateVectorsXY(varargin{2},'Y',4);
    nRowsOne = varargin{3};
    nColsOne = varargin{4};
    validateRowCols(varargin{3},'ROWS',3);
    validateRowCols(varargin{4},'COLS',4);
    xiOne = varargin{5}(:);
    yiOne = varargin{6}(:);
    validateVectorsXiYi(varargin{5},'XI',5);
    validateVectorsXiYi(varargin{6},'XI',6);
    xOne = [x(1) x(end)];
    yOne = [y(1) y(end)];
end

xi = castToDouble(xiOne);
yi = castToDouble(yiOne);
x = castToDouble(xOne);
y = castToDouble(yOne);
nRows= castToDouble(nRowsOne);
nCols = castToDouble(nColsOne);
end

%%%
% cast_to_double
%%%
%-----------------------------
function bOut = castToDouble(aIn)
if ~isa(aIn,'double')
    bOut = double(aIn);
else
    bOut = aIn;
end
end

%==========================================================================
function validateInImage(in,inString,n)
validateattributes(in, ...
    {'uint8' 'uint16' 'double' 'int16','single'}, ...
    {'real' 'nonempty' 'finite'},mfilename,inString,n);
end

%==========================================================================
function validateVectorsXiYi(in,inString,n)
validateattributes(in, ...
    {'uint8' 'uint16' 'double' 'int16','single'},...
    {'real','nonnan','finite','nonsparse'},mfilename,inString,n);
end

%==========================================================================
function validateVectorsXY(in,inString,n)
validateattributes(in, ...
    {'uint8' 'uint16' 'double' 'int16','single'},...
    {'real','nonempty','vector','nonnan','finite','nonsparse'}, ...
    mfilename,inString,n);
end

%==========================================================================
function validateRowCols(in,inString,n)
validateattributes(in, {'uint8' 'uint16' 'double' 'int16','single'},...
    {'real','integer','nonnegative','scalar','nonsparse','nonempty'}, ...
    mfilename,inString,n);
end