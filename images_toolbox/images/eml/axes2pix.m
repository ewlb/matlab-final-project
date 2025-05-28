function pixelx = axes2pix(varargin)%#codegen
%AXES2PIX Convert axes coordinate to pixel coordinate.
%
%  Syntax
%  ------
%
%  PIXELX = AXES2PIX(DIM, XDATA, AXESX)
%
%  Input Specs
%  ------------
%
%  DIM, XDATA, AXESX
%
%  single, double
%
%  Output Specs
%  ------------
%
%  PIXELX
%
%  single, double

%  Copyright 2023 The MathWorks, Inc.

%#ok<*EMCA>

% Parse inputs to verify valid function calling syntaxes and arguments
[dim,xdata,axesx] = parseInputs(varargin{:});

coder.internal.errorIf(max(size(dim)) ~= 1,...
    'images:axes2pix:firstArgNotScalar');

coder.internal.errorIf(min(size(xdata)) > 1,...
    'images:axes2pix:xdataMustBeVector');

xfirst = xdata(1);
xlast = xdata(max(size(xdata)));

if (dim == 1)
    pixelx = axesx - xfirst + 1;
    return;
end

delta = xlast - xfirst;

if delta == 0
    xslope = ones(size(dim),'like',dim);
else
    xslope = (dim - 1) / delta;
end

if ((xslope(1) == 1) && (xfirst(1) == 1))
    pixelx = axesx;
else
    pixelx = xslope * (axesx - xfirst) + 1;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  Function: parseInputs
function [dim,xdata,axesx] = parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);

narginchk(3,3);

dim = varargin{1};
xdata = varargin{2};
axesx = varargin{3};
coder.internal.errorIf(~isequal(class(dim),class(xdata),class(axesx)),...
    'images:validate:differentClassMatrices3', 'DIM', 'XDATA', 'AXESX');
validateattributes(dim, {'single','double'},...
    {'real','integer','nonnegative','scalar','nonsparse','nonempty'}, ...
    mfilename,'DIM',1);
validateattributes(xdata, {'single','double'}, ...
    {'real','vector','nonnan','finite','nonsparse','nonempty'},mfilename,'XDATA',2);
validateattributes(axesx, {'single','double'},...
    {'real','vector','nonnan','finite','nonsparse'},mfilename,'AXESX',3);