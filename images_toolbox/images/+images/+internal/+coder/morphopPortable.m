function B = morphopPortable(A, nhood , height, op_type, B) %#codegen
% morphopPortable to generate portable C code for dilation/erosion

% Copyright 2020 The MathWorks, Inc.

coder.inline('always');
coder.internal.prefer_const(A, nhood , height, op_type);

strelSizeThreshold = 13*13;
isStrel2D = ndims(nhood)<=2;
isStrelBig = numel(nhood)>=strelSizeThreshold;
isStrelFilled = sum(nhood(:))>numel(nhood)/2;
isStrelAllOnes = all(nhood(:));

%%
coder.extrinsic('images.internal.coder.useOptimizedFunctions');
% Faster code branch added for large dense 2D strels (g2152828). Disabled for float-type images due to regression (g2333262).
useOptimizedVersion = coder.const(images.internal.coder.useOptimizedFunctions()) ...
    && isStrelBig && isStrelFilled && (~isStrelAllOnes) && isStrel2D && (~isfloat(A));

if(useOptimizedVersion)
    B = images.internal.coder.optimized.morphopAlgo(A,...
        nhood , height,...
        op_type, B);
else
    B = images.internal.coder.morphopAlgo(A,...
        nhood , height,...
        op_type, B);
end