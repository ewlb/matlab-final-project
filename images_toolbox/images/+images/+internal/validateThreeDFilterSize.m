function filterSize = validateThreeDFilterSize(filterSize_)  %#codegen
%%validateThreeDFilterSize validates filter size for 3-D filter kernels to
% be non-sparse, real, numeric, odd and integer-valued with 1 or 3
% elements.

% Copyright 2015-2021 The MathWorks, Inc.

validateattributes(filterSize_, {'numeric'},...
    {'real','nonsparse','nonempty','positive','integer','odd'}, mfilename, 'filterSize');
 
if isscalar(filterSize_)
    filterSize = [double(filterSize_) double(filterSize_) double(filterSize_)];
else
    coder.internal.errorIf(numel(filterSize_)~= 3, ...
    'images:validate:badVectorLength','filterSize',3);
    filterSize = [double(filterSize_(1)) double(filterSize_(2)) double(filterSize_(3))];
end
