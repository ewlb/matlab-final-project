function Z = spaceToDepthForward(X,blockSize) %#codegen
%SPACETODEPTHFORWARD Summary of this function goes here
% Crop features from activations depending on block size, as
% they cannot be retrieved during back propagation.

%   Copyright 2020-2024 The MathWorks, Inc.

[tmpInputHeight,tmpInputWidth,~,~] = size(X);

tmpInputHeightReduced = floor(tmpInputHeight/blockSize(1));
tmpInputWidthReduced =  floor(tmpInputWidth/blockSize(2));

coder.internal.errorIf((tmpInputHeightReduced < 1) || (tmpInputWidthReduced<1), ...
    'images:spaceToDepth:OutputSpatialDimnsAtleastOne');

remInputHeight = tmpInputHeight - (blockSize(1)* tmpInputHeightReduced);
remInputWidth  = tmpInputWidth - (blockSize(2)* tmpInputWidthReduced);
X = X(1:(tmpInputHeight-remInputHeight),1:(tmpInputWidth-remInputWidth),:,:);

% Forward input data through the layer and output the result.
[inputHeight,inputWidth,inputChannel,batchSize] = size(X);
outputHeight = floor(inputHeight/blockSize(1));
outputWidth = floor(inputWidth/blockSize(2));
outputChannel = inputChannel*(blockSize(1)*blockSize(2));

Z = reshape(X, [blockSize(1), outputHeight, blockSize(2), outputWidth, inputChannel, batchSize]);
Z = permute(Z, [2 4 5 3 1 6]);
Z = reshape(Z, [outputHeight,outputWidth,outputChannel,batchSize]);
end