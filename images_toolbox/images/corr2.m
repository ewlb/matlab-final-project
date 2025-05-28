function r = corr2(varargin)%#codegen
%CORR2 2-D correlation coefficient.
%   R = CORR2(A,B) computes the correlation coefficient between A
%   and B, where A and B are matrices or vectors of the same size.
%
%   Class Support
%   -------------
%   A and B can be numeric or logical.
%   R is a scalar double.
%
%   Example
%   -------
%   I = imread('pout.tif');
%   J = medfilt2(I);
%   R = corr2(I,J)
%
%   See also CORRCOEF, STD2.

%   Copyright 1992-2022 The MathWorks, Inc.

[a,b] = parseInputs(varargin{:});

a = a - mean2(a);
b = b - mean2(b);

r = sum(sum(a.*b))/sqrt(sum(sum(a.*a))*sum(sum(b.*b)));

%--------------------------------------------------------
function [a,b] = parseInputs(varargin)

coder.inline('always');

narginchk(2,2);

A = varargin{1};
B = varargin{2};

validateattributes(A, {'logical' 'numeric'}, {'real','2d'}, mfilename, 'A', 1);
validateattributes(B, {'logical' 'numeric'}, {'real','2d'}, mfilename, 'B', 2);

coder.internal.errorIf(any(size(A)~=size(B)),'images:corr2:notSameSize');

if ~isa(A,'double')
    a = double(A);
else
    a = A;
end

if ~isa(B,'double')
    b = double(B);
else
    b = B;
end

