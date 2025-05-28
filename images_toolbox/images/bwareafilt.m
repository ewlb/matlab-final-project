function bw2 = bwareafilt(varargin)

args = matlab.images.internal.stringToChar(varargin);
matlab.images.internal.errorIfgpuArray(varargin{:});
[bw, p, direction, conn] = parse_inputs(args{:});
bw2 = bwpropfilt(bw, 'area', p, direction, conn);

%--------------------------------------------------------------------------
function [bw, p, direction, conn] = parse_inputs(varargin)

narginchk(2,4)

bw = varargin{1};
p = varargin{2};
validateattributes(bw, {'logical'}, {'nonnegative'}, mfilename, '', 1)
validateattributes(p, {'numeric'}, {'nonnegative'}, mfilename, '', 2)

direction = '';
conn = conndef(ndims(bw),'maximal');

if (nargin == 3)
    
    if (isnumeric(varargin{3}))
        conn = varargin{3};
    else
        direction = varargin{3};  % Let bwpropfilt validate it.
    end
    
elseif (nargin == 4)
    
    direction = varargin{3};
    conn = varargin{4};
    
end

%   Copyright 2014-2022 The MathWorks, Inc.