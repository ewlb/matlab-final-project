function validateDataFormat(fmt)
%validateDataFormat Error if a format vector is invalid.
%
%   validateDataFormat(fmt) throws an error in the caller context if fmt
%   does not contain a valid set of format labels.  This function tests
%   that the format characters are all valid and that there are correct
%   counts of each one.  It does not test that the format is in an order
%   that is valid for a dlarray.

%   Copyright 2020 The MathWorks, Inc.

[validChars, validCounts] = images.internal.qualitymetric.isValidDataFormat(fmt);
if ~validChars
    throwAsCaller(MException(message('images:qualitymetric:InvalidDimLabel')));
elseif ~validCounts
    throwAsCaller(MException(message('images:qualitymetric:RepeatedDimLabels')));
end
end