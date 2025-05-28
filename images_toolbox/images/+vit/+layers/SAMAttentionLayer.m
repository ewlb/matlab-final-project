classdef SAMAttentionLayer < nnet.layer.Layer ...
        & nnet.layer.Formattable & nnet.layer.Acceleratable

%   Copyright 2023 The MathWorks, Inc.

    properties(Learnable)
        QKVWeights
        QKVBias
        OutputWeights
        OutputBias
        HeightPositionWeights
        WidthPositionWeights
    end

    properties
        NumHeads
        NumChannels
    end

    properties(Access=private)
        Scale
    end

    methods
        function layer = SAMAttentionLayer(numHeads, numChannels, nvArgs)
            arguments
                numHeads
                numChannels
                nvArgs.QKVWeights = []
                nvArgs.QKVBias = []
                nvArgs.OutputWeights = []
                nvArgs.OutputBias = []
                nvArgs.HeightPositionWeights = []
                nvArgs.WidthPositionWeights = []
                nvArgs.Name = ''
            end
            layer.NumHeads = numHeads;
            layer.NumChannels = numChannels;
            layer.Scale = 1/sqrt(numChannels/numHeads);
            layer.QKVWeights = nvArgs.QKVWeights;
            layer.QKVBias = nvArgs.QKVBias;
            layer.OutputWeights = nvArgs.OutputWeights;
            layer.OutputBias = nvArgs.OutputBias;
            layer.HeightPositionWeights = nvArgs.HeightPositionWeights;
            layer.WidthPositionWeights = nvArgs.WidthPositionWeights;
            layer.Name = nvArgs.Name;
        end

        function Y = predict(layer, X)
            
            % Permute to CSSB format for attention computation
            X = permute(stripdims(X), [3 1 2 4]);
            
            Y = vit.layers.util.computeSAMAttention(X, ...
                layer.NumHeads, ...
                layer.Scale, ...
                layer.QKVWeights, ...
                layer.QKVBias, ...
                layer.HeightPositionWeights, ...
                layer.WidthPositionWeights, ...
                layer.OutputWeights, ...
                layer.OutputBias);

            Y = dlarray(Y, 'CSSB');
        end
    end
end