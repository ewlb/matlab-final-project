function LUT = cacheCategoricalLUT(categoriesIn)
% Create a LUT to convert a numeric array into categorical. The
% categories are shifted by 1 to accommodate '0' label.
%
% categories - Cell array of category/class names. The max allowed length
%              of categories is 256.
%
% Example
% -------
%
% % Convert a categorical to numeric and back to categorical using a LUT.
%
% ACat = categorical(randi([1:4], [10,10]);
% categoriesIn = categories(A);
% A = uint8(ACat);
%
% % Create a LUT
% lut = images.internal.cacheCategoricalLUT(categoriesIn);
%
% % Convert A back to categorical
% % Shift the numeric values by 1, to account for '0' label, which is
% already accounted for in the LUT.
% B = lut(A+1);

%  Copyright 2019-2020 The MathWorks, Inc.


% Shift value set for labels by 1, to account for '0' label,
% corrsponding to '<undefined>' pixels.
numericLUT = 1:256+1;
LUT = categorical(numericLUT, 2:numel(categoriesIn)+1, categoriesIn, 'Ordinal', true);