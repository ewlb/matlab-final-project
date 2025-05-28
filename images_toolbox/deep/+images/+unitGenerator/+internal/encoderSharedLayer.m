classdef encoderSharedLayer < nnet.layer.Layer & nnet.layer.Formattable
% encoderSharedLayer creates a layer for the shared encoder module for UNIT generator.


% Copyright 2020 The MathWorks, Inc.

    properties(Learnable)
        EncoderShared
    end
    
    properties (SetAccess = private)
        State
    end
   
    methods
        function this = encoderSharedLayer(inputSize, numSharedBlocks, numFilters, filterSize, ...
                convolutionWeightsInitializer, paddingValue, normalization, activation, name)
         this.Name = name;
         this.NumInputs = 1;    
         this.NumOutputs = 1;
         
         % Creating dlnetwork for the property 'EncoderShared'.
         hasInputLayer = true;
         encShared = images.unitGenerator.internal.createResidualBlocks(inputSize, numSharedBlocks, filterSize, numFilters, ...
                convolutionWeightsInitializer, paddingValue, normalization, activation, hasInputLayer, name);
         this.EncoderShared = dlnetwork(encShared);
         
         % Cacheing the state parameters of 'EncoderShared' dlnetwork to be used
         % in updating the state parameters for the layer.
         this.State = images.unitGenerator.internal.BasicCache(this.EncoderShared.State);
        end
        
        function out = forward(this, in)
            this.EncoderShared.State = this.State.Value;
            [out, state] = this.EncoderShared.forward(in);
            this.State.Value = state;
        end
        
        function out = predict(this, in)
            out = this.EncoderShared.predict(in);
        end
    end
end