function [validChars, validCounts] = isValidDataFormat(fmt) %#codegen
%isValidDataFormat Test whether a format contains valid characters
%
%   [validChars, validCounts] = isValidDataFormat(fmt) returns two flags
%   that indicate whether the characters in a format string are valid and
%   whether the character counts are valid.  If either flag is true then
%   the format is not valid.

%   Copyright 2020 The MathWorks, Inc.

supportedLabels = 'SCB'; % Don't support T and U currently.

[isInSet, idxInSet] = ismember(fmt, supportedLabels);
validChars = all(isInSet);

% Check the counts for all the valid labels;
idxInSet = idxInSet(idxInSet>0);
counts = accumarray(idxInSet(:),1, [numel(supportedLabels), 1]);
validCounts = all(counts(2:end)<=1);
end