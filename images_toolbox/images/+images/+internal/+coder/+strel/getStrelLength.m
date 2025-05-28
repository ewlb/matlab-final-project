function l = getStrelLength(varargin)
%GETSTRELLENGTH Internal helper function to get the length of the
% structuring element object.
%   l = GETSTRELLENGTH(varargin) computes length of structuring element by declaring
%   as an extrinsic function when generating code with all constant folded inputs.
%   This helper function is needed, since length function is being overloaded in the
%   StructuringElementHelper.m

% Copyright 2020 The MathWorks, Inc.

se = strel(varargin{:});
l = length(se);
end