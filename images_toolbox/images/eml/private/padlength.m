function varargout = padlength(varargin)%#codegen
%PADLENGTH Pad input vectors with ones to give them equal lengths.
%
%   Example
%   -------
%       [a,b,c] = padlength([1 2],[1 2 3 4],[1 2 3 4 5])
%       a = 1 2 1 1 1
%       b = 1 2 3 4 1
%       c = 1 2 3 4 5

%   Copyright 2022 The MathWorks, Inc.

% Find longest size vector.  Call its length "numDims".
numDims = zeros(nargin, 1);
for k = 1:nargin
    numDims(k) = length(varargin{k});
end
numDimsMax = max(numDims);

% Append ones to input vectors so that they all have the same length;
% assign the results to the output arguments.
limit = max(1,nargout);
out = cell(1,limit);
for k = 1 : limit
    out{k} = [varargin{k} ones(1,numDimsMax-length(varargin{k}))];
end

varargout = out;
