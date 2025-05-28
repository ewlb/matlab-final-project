function [f,noise] = wiener2(I, varargin)
%WIENER2 2-D adaptive noise-removal filtering for gpuArray data.
%   J = WIENER2(I,[M N],NOISE)
%   [J,NOISE] = WIENER2(I,[M N])
%
%   See also wiener2, gpuArray.

%   Copyright 2020 The MathWorks, Inc.

% Make sure only I is on GPU
if nargin>1
    [varargin{:}] = gather(varargin{:});
end

% Re-direct back to the original function
fcn = "images/images/wiener2";
if nargout>1
    [f,noise] = parallel.internal.array.callToolboxFunction(fcn, I, varargin{:});
else
    f = parallel.internal.array.callToolboxFunction(fcn, I, varargin{:});
end
