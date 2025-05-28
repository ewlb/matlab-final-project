function [out, categoriesIn] = categorical2numeric(in)
% CATEGORICAL2NUMERIC converts categorical array to a numeric array with
% datatype dependent on number of categories.
%
% in            - categorical input to be converted
% out           - converted numeric array
% categoriesIn  - categories of the input array

%  Copyright 2019-2020 The MathWorks, Inc.

categoriesIn = categories(in);
numCategories = numel(categoriesIn);

if(numCategories <= 2^8)
    out = uint8(in); 
elseif(numCategories > 2^8) && (numCategories <= 2^16)
    out = uint16(in); 
elseif(numCategories > 2^16) && (numCategories <= 2^32)
    out = uint32(in); 
else
    out = uint64(in); 
end