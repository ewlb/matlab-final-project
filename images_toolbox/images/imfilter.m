function b = imfilter(varargin)
args = matlab.images.internal.stringToChar(varargin);
b = matlab.internal.math.imfilter(args{:});
end

%   Copyright 1993-2024 The MathWorks, Inc.

% Testing notes
% Syntaxes
% --------
% B = imfilter(A,H)
% B = imfilter(A,H,Option1, Option2,...)
%
% A:       numeric, full, N-D array.  May not be uint64 or int64 class.
%          May be empty. May contain Infs and Nans. May be complex. Required.
%
% H:       double, full, N-D array.  May be empty. May contain Infs and Nans.
%          May be complex. Required.
%
% A and H are not required to have the same number of dimensions.
%
% OptionN  string or a scalar number. Not case sensitive. Optional.  An
%          error if not recognized.  While there may be up to three options
%          specified, this is left unchecked and the last option specified
%          is used.  Conflicting or inconsistent options are not checked.
%
%        A choice between these options for boundary options
%        'Symmetric'
%        'Replicate'
%        'Circular'
%         Scalar #  - Default to zero.
%       A choice between these strings for output options
%        'Full'
%        'Same'  - default
%       A choice between these strings for functionality options
%        'Conv'
%        'Corr'  - default
%
% B:   N-D array the same class as A.  If the 'Same' output option was
%      specified, B is the same size as A.  If the 'Full' output option was
%      specified the size of B is size(A)+size(H)-1, remembering that if
%      size(A)~=size(B) then the missing dimensions have a size of 1.
