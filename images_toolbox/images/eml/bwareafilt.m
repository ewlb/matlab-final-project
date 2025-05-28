function bw2 = bwareafilt(varargin) %#codegen

% Copyright 2023 The MathWorks, Inc.

narginchk(2,4);

coder.inline('always');
coder.internal.prefer_const(varargin);

bw = varargin{1};
p = varargin{2};

validateattributes(bw, {'logical'}, {'nonnegative'}, mfilename, '', 1);
validateattributes(p, {'numeric'}, {'nonnegative'}, mfilename, '', 2);

if nargin == 2
    conn = conndef(ndims(bw), 'maximal');
    bw2 = bwpropfilt(bw, 'area', p, conn);
elseif nargin == 3
    if isnumeric(varargin{3})
        conn = varargin{3};
        bw2 = bwpropfilt(bw, 'area', p, conn);
    else
        direction = varargin{3};  % Let bwpropfilt validate it.
        conn = conndef(ndims(bw), 'maximal');
        bw2 = bwpropfilt(bw, 'area', p, direction, conn);
    end
else
    direction = varargin{3};
    conn = varargin{4};
    bw2 = bwpropfilt(bw, 'area', p, direction, conn);
end