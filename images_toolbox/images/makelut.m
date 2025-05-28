function lut = makelut(varargin)
%

%   Copyright 1993-2012 The MathWorks, Inc.

% Obsolete syntax:
%   LUT = MAKELUT(FUN,N,P1,P2,...) passes the additional parameters P1, P2,
%   ..., to FUN.
%

narginchk(2,inf);
varargin = matlab.images.internal.stringToChar(varargin);
fun = varargin{1};
n = varargin{2};
params = varargin(3:end);
fun = fcnchk(fun, length(params));

if (n == 2)
    lut = zeros(16,1);
    for k = 1:16
        a = reshape(fliplr(dec2bin(k-1,4) == '1'), 2, 2);
        lut(k) = feval(fun, a, params{:});
    end
    
elseif (n == 3)
    lut = zeros(512,1);
    for k = 1:512
        a = reshape(fliplr(dec2bin(k-1,9) == '1'), 3, 3);
        lut(k) = feval(fun, a, params{:});
    end
    
else
    error(message('images:makelut:invalidN'))
end
