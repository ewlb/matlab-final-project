function sz = getStrelSize(params, varargin)
%GETSTRELSIZE Internal helper function to get the length of the
% structuring element object.
%   sz = GETSTRELSIZE(params, varargin) computes size of structuring element by declaring
%   as an extrinsic function when generating code with all constant folded inputs.
%   This helper function is needed, since size function is being overloaded in the
%   StructuringElementHelper.m

% Copyright 2020 The MathWorks, Inc.

se = strel(params{:});
sz = size(se, varargin{:});
end