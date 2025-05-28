function b = dct2(varargin) %#codegen
%DCT2 2-D discrete cosine transform.
%  Syntax
%  ------
%
%  B = DCT2(I)
%  B = DCT2(I,[M N])
%  B = DCT2(I,M N)
%
%  Input Specs
%  ------------
%
%  I
%  Numeric or logical
%
%  M,N
%  Positive Integer
%
%  Output Specs
%  ------------
%
%  B
%
%  double

% Copyright 2023 The MathWorks, Inc.

[argOne, mrows,ncols,m,n] = parseInputs(varargin{:});

% Basic algorithm.
if (nargin == 1)
    if (m > 1) && (n > 1)
        dctOne = dct(argOne).';
        b = dct(dctOne).';
        return;
    end
end

% Padding for vector input.
mpad = mrows;
npad = ncols;

if m == 1 && mpad > m
    a = zeros(2,n);
    a(1,:) = argOne;
    m = 2;
elseif n == 1 && npad > n
    a = zeros(m,2);
    a(:,1) = argOne;
    n = 2;
else
    a = argOne;
end

if m == 1
    mpad = npad;
    npad = 1;
end   % For row vector.

% Transform.
bOut = dct(a, mpad);
if m > 1 && n > 1
    b = dct(bOut.', npad).';
else
    b = bOut;
end
end

%%parse input arguments
%==========================================================================
function [argOne, mrows,ncols,m,n] = parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);

narginchk(1,3);

validateattributes(varargin{1},{'logical','numeric'},{'nonempty','nonsparse'}, ...
    mfilename, 'ARG1',1);

argOne = varargin{1};

[m, n] = size(argOne);

if nargin == 1
    mrows = m;
    ncols = n;
elseif nargin == 2
    array = varargin{2};
    validateArray(array,'ARRAY',2)
    mrows = array(1);
    ncols = array(2);
else
    mrows = varargin{2};
    ncols = varargin{3};
    validateRowsCols(mrows,'ROWS',2);
    validateRowsCols(ncols,'COLS',3);
end
end

%%validate input arguments
%==========================================================================
function validateRowsCols(in,strIn,n)
validateattributes(in,{'uint8' 'uint16' 'double' 'int16','single'},...
    {'real','integer','nonnegative','scalar','nonsparse','nonempty'},...
    mfilename,strIn,n);
end

%==========================================================================
function validateArray(in,strIn,n)
validateattributes(in,{'uint8' 'uint16' 'double' 'int16','single'},...
    {'real','integer','nonnegative','nonempty','vector',...
    'nonnan','finite','nonsparse'},mfilename,strIn,n);
end