function Y = computeSAMAttention(X, numHeads, scale, qkvWeights, qkvBias, heightPositionWeights, widthPositionWeights, outputWeights, outputBias)
%computeSAMAttention Compute multi-head attention with decomposed relative
% position embedding
%
% Inputs:
% X                     : Input data - [S, S, C, B]
% numHeads              : Number of attention heads - Scalar
% numChannelsPerHead    : Number of channels per head - Scalar (Cn)
% scale                 : Scale - Scalar
% qkvWeights            : Weights for query, key, and value - [Chidden, C]
% heightPositionWeights : Relative position weights for height - [Cn, Lh]
% widthPositionWeights  : Relative position weights for width - [Cn, Lw]
% outputWeights         : Output weights - [Cout, Chidden/3]
%
% Output:
% Y : Attention output - [Cout, S, S, B]

%   Copyright 2023 The MathWorks, Inc.

[~, Sh, Sw, B] = size(X);

% Compute input projection
X = pagemtimes(qkvWeights, X) + qkvBias;

% Split heads
numSequences = Sh*Sw;
X = reshape(X, [], numHeads, 3, numSequences, B);
X = permute(X, [1,4,2,5,3]);
X = reshape(X, [], numSequences, B*numHeads, 3);

% Split qkv
Q = squeeze(X(:,:,:,1));
K = squeeze(X(:,:,:,2));
V = squeeze(X(:,:,:,3));

% Compute scaled dot product
Y = pagemtimes(K, 'transpose', Q.*scale, 'none');

Y = vit.layers.util.addDecomposedPositionEmbedding(Y, Q, heightPositionWeights, widthPositionWeights, [Sh,Sw], [Sh,Sw]);

Y = softmax(Y, DataFormat="CSB");
Y = pagemtimes(V, Y);

% Merge heads
Y = reshape(Y, [], Sh, Sw, numHeads, B);
Y = permute(Y, [1,4,2,3,5]);
Y = reshape(Y, [], Sh, Sw, B);

% Compute output projection
Y = pagemtimes(outputWeights, Y) + outputBias;

end