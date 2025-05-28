function varargout = roipoly(varargin)

[xdata,ydata,num_rows,num_cols,xi,yi,placement_cancelled] = parse_inputs(varargin{:});

% return empty if user cancels operation
if placement_cancelled
    varargout = repmat({[]},nargout,1);
    return;
end

if length(xi)~=length(yi)
    error(message('images:roipoly:xiyiMustBeSameLength')); 
end

% Make sure polygon is closed.
if (~isempty(xi))
    if ( xi(1) ~= xi(end) || yi(1) ~= yi(end) )
        xi = [xi;xi(1)]; 
        yi = [yi;yi(1)];
    end
end
% Transform xi,yi into pixel coordinates.
roix = axes2pix(num_cols, xdata, xi);
roiy = axes2pix(num_rows, ydata, yi);

d = poly2mask(roix, roiy, num_rows, num_cols);

switch nargout
case 0
    figure
    imshow(d,'XData',xdata,'YData',ydata);
    
case 1
    varargout{1} = d;
    
case 2
    varargout{1} = d;
    varargout{2} = xi;
    
case 3
    varargout{1} = d;
    varargout{2} = xi;
    varargout{3} = yi;
    
case 4
    varargout{1} = xdata;
    varargout{2} = ydata;
    varargout{3} = d;
    varargout{4} = xi;
    
case 5
    varargout{1} = xdata;
    varargout{2} = ydata;
    varargout{3} = d;
    varargout{4} = xi;
    varargout{5} = yi;
    
otherwise
    error(message('images:roipoly:tooManyOutputArgs'));
    
end

end % roipoly

%%%
%%% parse_inputs
%%%

%--------------------------------------------------------
function [x,y,nrows,ncols,xi,yi,placement_cancelled] = parse_inputs(varargin)

% placement_cancelled only applies to interactive syntaxes. Assume placement_cancelled is false for initialization.
placement_cancelled = false;

cmenu_text = getString(message('images:roiContextMenuUIString:createMaskContextMenuLabel'));

switch nargin

case 0 
    % ROIPOLY
    
    % verify we have a target image
    hFig = get(0,'CurrentFigure');
    hAx  = get(hFig,'CurrentAxes');
    hIm = findobj(hAx, 'Type', 'image');
    if isempty(hIm)
        error(message('images:roipoly:noImage'))
    end
    
    %  Get information from the current figure
    [x,y,a,hasimage] = getimage;
    if ~hasimage
        error(message('images:roipoly:needImageInFigure'));
    end
    [xi,yi,placement_cancelled] = createWaitModePolygon(gca,cmenu_text);
    nrows = size(a,1);
    ncols = size(a,2);
    
case 1
    % ROIPOLY(A)
    a = varargin{1};
    nrows = size(a,1);
    ncols = size(a,2);
    x = [1 ncols];
    y = [1 nrows];
    imshow(a);
    [xi,yi,placement_cancelled] = createWaitModePolygon(gca,cmenu_text);
    
case 2
    % ROIPOLY(M,N)
    nrows = varargin{1};
    ncols = varargin{2};
    a = repmat(uint8(0), nrows, ncols);
    x = [1 ncols];
    y = [1 nrows];
    imshow(a);
    [xi,yi,placement_cancelled] = createWaitModePolygon(gca,cmenu_text);
    
case 3
    % SYNTAX: roipoly(A,xi,yi)
    a = varargin{1};
    nrows = size(a,1);
    ncols = size(a,2);
    xi = varargin{2}(:);
    yi = varargin{3}(:);
    x = [1 ncols]; y = [1 nrows];

case 4
    % SYNTAX: roipoly(m,n,xi,yi)
    nrows = varargin{1}; 
    ncols = varargin{2};
    xi = varargin{3}(:);
    yi = varargin{4}(:);
    x = [1 ncols]; y = [1 nrows];
    
case 5
    % SYNTAX: roipoly(x,y,A,xi,yi)
    x = varargin{1}; 
    y = varargin{2}; 
    a = varargin{3};
    xi = varargin{4}(:); 
    yi = varargin{5}(:);
    nrows = size(a,1);
    ncols = size(a,2);
    x = [x(1) x(end)];
    y = [y(1) y(end)];
    
case 6
    % SYNTAX: roipoly(x,y,m,n,xi,yi)
    x = varargin{1}; 
    y = varargin{2}; 
    nrows = varargin{3};
    ncols = varargin{4};
    xi = varargin{5}(:); 
    yi = varargin{6}(:);
    x = [x(1) x(end)];
    y = [y(1) y(end)];
    
    otherwise
    error(message('images:roipoly:invalidInputArgs'));

end

xi = cast_to_double(xi);
yi = cast_to_double(yi);
x = cast_to_double(x);
y = cast_to_double(y);
nrows= cast_to_double(nrows);
ncols = cast_to_double(ncols);

end % parse_inputs

%%%
% cast_to_double
%%%

%-----------------------------
function a = cast_to_double(a)
    matlab.images.internal.errorIfgpuArray(a);
    if ~isa(a,'double')
        a = double(a);
    end
end
    
%   Copyright 1993-2023 The MathWorks, Inc.
    
