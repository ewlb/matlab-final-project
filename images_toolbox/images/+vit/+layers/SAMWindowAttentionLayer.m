classdef SAMWindowAttentionLayer < nnet.layer.Layer ...
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
        WindowSize
    end

    properties(Access=private)
        Scale
    end

    methods
        function layer = SAMWindowAttentionLayer(numHeads, numChannels, windowSize, nvArgs)
            arguments
                numHeads
                numChannels
                windowSize
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
            layer.WindowSize = windowSize;
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
            % Partition window
            [X, XSize, XPadSize] = partitionWindow(layer, X);

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

            % Reverse window partition
            Y = reverseWindowPartition(layer, Y, XPadSize, XSize);

            Y = dlarray(Y, 'CSSB');
        end
    end

    methods(Access = private)
        function [x, originalSize, paddedSize] = partitionWindow(layer, x)
            % Partition into non-overlapping windows with padding if needed.
            %
            % Inputs:
            % x          : Input array - [H, W, C, B]
            %
            % Output:
            % x          : Windows extracted from the input tensor - [windowSize, windowSize, C, numWindows*B] 
            % paddedSize : Padded height and width before partition - [Hp, Wp]
            
            windowSize = layer.WindowSize;
            [H, W, C, B] = size(x);
            
            padH = mod(windowSize - mod(H, windowSize), windowSize);
            padW = mod(windowSize - mod(W, windowSize), windowSize);
            if padH > 0 || padW > 0
                %TODO: Use padarray from image processing toolbox
                x = iPadArray(x, [padH padW], [H,W,C,B]);
            end
            Hp = H + padH;
            Wp = W + padW;
            
            x = reshape(x, [windowSize, floor(Hp/windowSize), windowSize, floor(Wp/windowSize), C, B]);
            x = permute(x, [1 3 5 2 4 6]);

            x = reshape(x, windowSize, windowSize, C, []);
            
            originalSize = [H, W];
            paddedSize = [Hp, Wp];
        end

        function x = reverseWindowPartition(layer, x, xPadSize, xSize)
            % Unpartition windowed input and remove padding if added.
            %
            % Inputs:
            % x        : Windowed input array - [C, windowSize, windowSize, numWindows*B]
            % xPadSize : Padded height and width before partition - [Hp, Wp]
            % xSize    : Original height and width before padding - [H, W]
            %
            % Output:
            % x        : Unpartitioned array - [H, W, C, B]
            
            windowSize = layer.WindowSize;
            Hp = xPadSize(1);
            Wp = xPadSize(2);
            H = xSize(1);
            W = xSize(2);
            C = size(x,1);

            x = reshape(x, C, windowSize, windowSize, floor(Hp/windowSize), floor(Wp/windowSize), []);
            x = permute(x, [1 2 4 3 5 6]);
            x = reshape(x, C, Hp, Wp, []);

            if Hp > H || Wp > W
                x = x(:, 1:H, 1:W, :);
            end
            
        end
    end
end

function xPad = iPadArray(x, padSize, xSize)
hPad = zeros([padSize(1), xSize(2:end)]);
xPad = cat(1,x,hPad);

wPad = zeros([size(xPad,1), padSize(2), xSize(3:end)]);
xPad = cat(2, xPad, wPad);
end