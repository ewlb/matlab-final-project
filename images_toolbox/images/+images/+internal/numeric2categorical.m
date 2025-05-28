function out = numeric2categorical(numericIn, categoriesIn, categoricalLUT)
% NUMERIC2CATEGORICAL converts numeric array to a categorical array based
% on categoriesIn. It uses categoricalLUT if available to speed up the
% conversion. categoricalLUT is created using
% images.internal.cacheCategoricalLUT.

%
% numericIn     - numeric input to be converted
% out           - converted categorical array
% categoriesIn  - categories of the input array
% categoricalLUT- LUT to speed up categorical conversion.

% Copyright 2019-2020 The MathWorks, Inc.

useCategoricalLUTCache = isa(numericIn, 'uint8') && ~isempty(categoricalLUT);
if(useCategoricalLUTCache)
    % Shift values by 1, to account for the '0' label. The LUTCache
    % already includes this shift.
    out = categoricalLUT(numericIn+1);    
else
    out = categorical(numericIn, 1:numel(categoriesIn), categoriesIn, 'Ordinal', true);
end