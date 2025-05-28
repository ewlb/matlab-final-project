function attn = addDecomposedPositionEmbedding(attn, q, relPosH, relPosW, qSize, kSize)
% Calculate and add decomposed Relative Positional Embeddings.
% (From mvitv2: https://github.com/facebookresearch/mvit/blob/master/mvit/models/attention.py)
%
% Inputs:
% attn    : Attention map - [kh*kw, qh*qw, B].
% q       : Query - [C, qh * qw, B].
% relPosH : Relative position embedding for height dim - [C, Lh].
% relPosW : Relative position embedding for width dim - [C, Lw].
% qSize   : Spatial sequence size of query q - [qh, qw].
% kSize   : Spatial sequence size of key k - [kh, kw].
%
% Output:
% attn    : Attention map with relative positional embedding - [kh*kw, qh*qw, B].

%   Copyright 2023 The MathWorks, Inc.

qh = qSize(1);
qw = qSize(2);
kh = kSize(1);
kw = kSize(2);

relH = iGetRelativePositionEmbedding(qh, kh, relPosH);
relW = iGetRelativePositionEmbedding(qw, kw, relPosW);

q = reshape(q, size(q,1), qw, qh, []);
relH = pagemtimes(q, 'transpose', relH, 'none'); % [qw, kh, qh, B]
relH = permute(relH, [5,2,1,3,4]); % [1, kh, qw, qh, B]

q = permute(q, [1, 3, 2, 4]);
relW = pagemtimes(q, 'transpose', relW, 'none'); % [qh, kw, qw, B]
relW = permute(relW, [2,5,3,1,4]); % [kw, 1, qw, qh, B]

attn = reshape(attn, kw, kh, qw, qh, []);
attn = attn + relH + relW;
attn = reshape(attn, kw*kh, qw*qh, []);

end


function out = iGetRelativePositionEmbedding(qSize, kSize, embedding)
% Get relative positional embeddings according to the relative positions of
% query and key sizes.
%
% Inputs:
% qSize: Size of query.
% kSize: Size of key.
% embedding: relative position embeddings [C, L].
%
% Output:
% out : Extracted positional embeddings according to relative positions [C, qSize, kSize].

maxRelDist = 2 * max(qSize, kSize) - 1;
if size(embedding, 2) ~= maxRelDist
    % Interpolate rel pos if needed
    embeddingResized = imresize(embedding, [size(embedding, 1), maxRelDist], 'bilinear');
else
    embeddingResized = embedding;
end

% Scale the coords with short length if shapes for query and key are
% different
qCoords = (1:qSize)' * max(kSize / qSize, 1);
kCoords = (1:kSize) * max(qSize / kSize, 1);
relativeCoords = (kCoords - qCoords) + kSize * max(qSize / kSize, 1);

out = embeddingResized(:, relativeCoords);
out = reshape(out, [], kSize, qSize);
end
