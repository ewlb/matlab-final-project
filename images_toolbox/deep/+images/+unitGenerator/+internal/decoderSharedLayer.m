classdef decoderSharedLayer < nnet.layer.Layer & nnet.layer.Formattable
% decoderSharedLayer creates a layer for the shared decoder module for UNIT generator.


% Copyright 2020 The MathWorks, Inc.
    properties(Learnable)
        DecoderShared
    end
    
    properties (SetAccess = private)
        State
    end
   
    methods
        function this = decoderSharedLayer(inputSize, numSharedBlocks, numFilters, filterSize, ...
                convolutionWeightInitializer, paddingValue, normalization, activation, name)
         this.Name = name;
         this.NumInputs = 1;    
         this.NumOutputs = 1;
         
         % Creating dlnetwork for the property 'DecoderShared'.
         hasInputLayer = true;
         decShared = images.unitGenerator.internal.createResidualBlocks(inputSize, numSharedBlocks, filterSize, numFilters, ...
                convolutionWeightInitializer, paddingValue, normalization, activation, hasInputLayer, name);
         this.DecoderShared = dlnetwork(decShared);
         
         % Cacheing the state parameters of 'DecoderShared' dlnetwork to be used
         % in updating the state parameters for the layer.
         this.State = images.unitGenerator.internal.BasicCache(this.DecoderShared.State);
        end
        
        function out = forward(this, in)
            this.DecoderShared.State = this.State.Value;
            
            % Add noise to input
            noiseSize = size(in);
            noise = randn(noiseSize, 'like', in);
            in = in+noise;
            
            [out, state] = this.DecoderShared.forward(in);
            this.State.Value = state;
        end
        
        function out = predict(this, in)
            out = this.DecoderShared.predict(in);
        end
    end
end