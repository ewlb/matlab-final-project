function layers = patchGANDiscriminatorLayers(namePrefix, inputChannels, filterSize, numFilters, numDownsamplingBlocks, convolutionPaddingValue, convolutionWeightsInitializer, activationLayer, normalizationLayer, networkType)
% patchGANDiscriminatorLayers Internal function to create PatchGAN discriminator layers

%   Copyright 2020-2021 The MathWorks, Inc.


if strcmpi(networkType, 'patch')
    padding = 1;
    stride = 2;
    layers = [...
        convolution2dLayer(filterSize, numFilters, 'Stride', stride, ...
             'Padding', padding, 'NumChannels', inputChannels, ...
             'PaddingValue', convolutionPaddingValue, 'Name', sprintf('%s%s',namePrefix, 'conv2d_top'))];
    if ~strcmpi(activationLayer, "none")
        activationLayer.Name = sprintf('%s%s',namePrefix, 'act_top');
        layers = [layers, activationLayer];
    end
    numFiltersScaleFactor = 1;
    
    layersN = [];
    for n = 1:numDownsamplingBlocks-1
        numFiltersScaleFactorPrevious = numFiltersScaleFactor;
        numFiltersScaleFactor = min(2 ^ n, 8);
        
        layersN = [layersN,...
            convolution2dLayer(filterSize, numFilters * numFiltersScaleFactor, ...
                 'Stride', stride, 'Padding', padding, 'PaddingValue', convolutionPaddingValue,...
                 'NumChannels', numFilters * numFiltersScaleFactorPrevious, ...
                 'WeightsInitializer', convolutionWeightsInitializer, ...
                 'Name', sprintf('%s%s_%d',namePrefix, 'conv2d_mid',n))];
        if ~strcmpi(normalizationLayer, "none")
            normalizationLayer.Name = sprintf('%s%s_%d',namePrefix,'norm2d_mid',n);
            layersN = [layersN, normalizationLayer];
        end
        if ~strcmpi(activationLayer, "none")
            activationLayer.Name = sprintf('%s%s_%d',namePrefix,'act_mid',n);
            layersN = [layersN, activationLayer];
        end
    end
    
    layers = [layers,layersN];
    
    numFiltersScaleFactorPrevious = numFiltersScaleFactor;
    numFiltersScaleFactor = min(2 ^ numDownsamplingBlocks, 8);
    stride = 1;
    layers = [layers,...
        convolution2dLayer(filterSize, numFilters * numFiltersScaleFactor, ...
             'Stride', stride, 'Padding', padding, 'PaddingValue', convolutionPaddingValue,...
             'NumChannels', numFilters * numFiltersScaleFactorPrevious, ...
             'WeightsInitializer', convolutionWeightsInitializer,...
             'Name', sprintf('%s%s',namePrefix,'conv2d_tail'))];
    if ~strcmpi(normalizationLayer, "none")
        normalizationLayer.Name = sprintf('%s%s',namePrefix,'norm2d_tail');
        layers = [layers, normalizationLayer];
    end
    if ~strcmpi(activationLayer, "none")
        activationLayer.Name = sprintf('%s%s',namePrefix,'act_tail');
        layers = [layers, activationLayer];
    end
    
    stride = 1;
    layers = [layers,...
        convolution2dLayer(filterSize, 1, 'Stride', stride, 'Padding', padding, ...
             'PaddingValue', convolutionPaddingValue, 'NumChannels', numFilters * numFiltersScaleFactor, ...
             'WeightsInitializer', convolutionWeightsInitializer,...
             'Name', sprintf('%s%s',namePrefix,'conv2d_final'))
        ];
    
elseif strcmpi(networkType,'pixel')
    
    filterSize = 1;
    stride = 1;
    padding = 0;
    numDownsamplingBlocks = 2;
    numFiltersScaleFactor = 1;
    layers = [...
        convolution2dLayer(filterSize, numFilters, 'Stride', stride, ...
             'Padding', padding, 'PaddingValue', convolutionPaddingValue, ...
             'NumChannels', inputChannels, 'WeightsInitializer', convolutionWeightsInitializer,...
             'Name', sprintf('%s%s',namePrefix,'conv2d_top'))];
    if ~strcmpi(activationLayer, "none")
        activationLayer.Name = sprintf('%s%s',namePrefix,'act_top');
        layers = [layers, activationLayer];
    end
    
    layersN = [];
    for n = 1:numDownsamplingBlocks-1
        numFiltersScaleFactorPrevious = numFiltersScaleFactor;
        numFiltersScaleFactor = min(2 ^ n, 8);
        layersN = [layersN,...
            convolution2dLayer(filterSize, numFilters * numFiltersScaleFactor, ...
                 'Stride', stride, 'Padding', padding, 'PaddingValue', convolutionPaddingValue,...
                 'NumChannels', numFilters * numFiltersScaleFactorPrevious, ...
                 'WeightsInitializer', convolutionWeightsInitializer,...
                 'Name', sprintf('%s%s_%d',namePrefix,'conv2d_mid',n))];
        if ~strcmpi(normalizationLayer, "none")
            normalizationLayer.Name = sprintf('%s%s_%d',namePrefix,'norm2d_mid',n);
            layersN = [layersN, normalizationLayer];
        end
        if ~strcmpi(activationLayer, "none")
            activationLayer.Name = sprintf('%s%s_%d',namePrefix,'act_mid',n);
            layersN = [layersN, activationLayer];
        end
    end
    
    layers = [layers,layersN];
    
    stride = 1;
    layers = [layers,...
        convolution2dLayer(filterSize, 1, 'Stride', stride, 'Padding', padding, ...
             'PaddingValue', convolutionPaddingValue, ...
             'NumChannels', numFilters * numFiltersScaleFactor, ...
             'WeightsInitializer', convolutionWeightsInitializer,...
             'Name', sprintf('%s%s',namePrefix,'conv2d_final'))
        ];
else
    error(message('images:patchGANDiscriminator:unexpectedNetworkType'));
end

end
