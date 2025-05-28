classdef positionEmbedding2dLayer < nnet.layer.Layer ...
        & nnet.layer.Formattable & nnet.layer.Acceleratable

%   Copyright 2023 The MathWorks, Inc.

    properties(Learnable)
        Weights
    end

    properties(SetAccess = private)
        OutputSize
    end

    methods
        function layer = positionEmbedding2dLayer(outputSize, nvArgs)
            arguments
                outputSize
                nvArgs.Weights = []
                nvArgs.Name = ''
            end
            layer.OutputSize = outputSize;
            layer.Weights = nvArgs.Weights;
            layer.Name = nvArgs.Name;
        end

        function X = predict(layer, X)
            X = layer.Weights + X;
        end
    end
end