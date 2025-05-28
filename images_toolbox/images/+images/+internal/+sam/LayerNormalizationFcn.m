function [Z, numDims] = LayerNormalizationFcn(X, weight, bias)
% Adapt layernorm in a format expected by the ONNX imported SAM decoder
% function.

%   Copyright 2023 The MathWorks, Inc.
    
    Xmod = dlarray(permute(stripdims(X),[3,2,1]),"SSCB");
    Ztmp = layernorm(Xmod,bias,weight,"OperationDimension","channel-only");
    Z = dlarray(permute(stripdims(Ztmp),[3,2,1,4]));
    numDims = ndims(Z) + 1;
end