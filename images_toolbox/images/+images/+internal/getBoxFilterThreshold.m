function minKernelElems = getBoxFilterThreshold() %#codegen
%GETBOXFILTERTHRESHOLD returns threshold for 2-D box filtering.
%   minKernelElems = getBoxFilterThreshold(imtype) returns the minimum
%   number of kernel elements at which 2-D box filtering is expected to
%   out-perform convolution-based filtering for an image.
%
%   Note that this is only for internal use by functions like imboxfilt.

%   Copyright 2015-2021 The MathWorks Inc.

minKernelElems = 250;  %break-even is close to 15x15

end