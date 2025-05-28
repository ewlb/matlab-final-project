classdef DepthToSpace2DLayer < nnet.layer.Layer & nnet.internal.cnn.layer.Traceable
    % DepthToSpace2DLayer   DepthToSpace 2D Layer Rearrange data from depth 
    % into blocks of spatial data
    %
    %   To create a depthToSpace 2D layer, use depthToSpace2dLayer.
    %
    %   DepthToSpace2DLayer properties:
    %       Name                   - A name for the layer.
    %       BlockSize              - It specifies the size of the spatial
    %                                block which rearrenges from depth to 
    %                                spatial dimesion.
    %       Mode                   - It specify order of rearranging the input 
    %                                dlarray along the spatial dimension.                             
    %
    %   Example:
    %       % Create a depthToSpace 2d layer.
    %       blockSize = 2;
    %       layer = depthToSpace2dLayer(blockSize)
    %
    %   See also depthToSpace2dLayer
    
    %   Copyright 2020 The MathWorks, Inc.    

    properties (SetAccess = private)
        %   BlockSize       
        %      The block size is used to modify the input's size from 
        %      [height width channels] to [outHeight, outWidth, outChannels]
        %      where outHeight is [height*blockSize(1)], outWidth is
        %      [width*blockSize(2)] and outChannels is
        %      [floor(channels/(blockSize(1)*blockSize(2)))].  
        BlockSize
        %  Mode 
        %     A string scalar or character vector that
        %     specifies the way of arranging elements along
        %     the depth dimension from the input dlarray.
        %     Options are "CRD" and "DCR".In the DCR mode,
        %     rearranged in the depth, column, and then row
        Mode
        
    end

    methods
        function layer = DepthToSpace2DLayer(name, blocksize,mode)
            layer.Name = name;
            layer.BlockSize = blocksize;
            layer.Mode = mode;
            layer.Description = getString(message('images:depthToSpace:depthToSpaceOneLineDisp',mat2str(blocksize)));
            layer.Type = getString(message('images:depthToSpace:depthToSpaceType'));
        end
        
        function Z = predict(layer,X)
            
            X = iCheckAndReturnValidInput(X);
            Z = images.depthToSpace.internal.depthToSpaceForward(X,layer.BlockSize,layer.Mode);
            if isa(X, 'dlarray')
                labels = dims(X);
                isInputDataFormatted = ~isempty(dims(X));
                if isInputDataFormatted
                    Z = dlarray(Z,labels);
                end
            end  
           
        end
        
        function dX = backward(layer, X, Z, dLdZ,~)
            % In backward pass feature maps are reordered back to their
            [~,~,inputChannel,batchSize] = size(Z);
            [outputHeight,outputWidth,outputChannel,~] = size(X);
            
            switch(layer.Mode)
                case "dcr"
                    
                    dX = reshape(dLdZ, [layer.BlockSize(1), outputHeight, layer.BlockSize(2), outputWidth, inputChannel, batchSize]);
                    dX = permute(dX, [2 4 5 3 1 6]);
                    dX = reshape(dX, [outputHeight,outputWidth,outputChannel,batchSize]); 
                                     
                    
                case "crd"
                    dX = reshape(dLdZ, [layer.BlockSize(1), outputHeight, layer.BlockSize(2), outputWidth, inputChannel, batchSize]);
                    dX = permute(dX, [2 4 3 1 5 6]);
                    dX = reshape(dX, [outputHeight,outputWidth,outputChannel,batchSize]);  
                    
            end
            
            if isa(X, 'dlarray')
                labels = dims(X);
                if ~isempty(labels)
                    dX = dlarray(dX,labels);
                end 
            end            
        end
        
    end   
    
    methods(Static, Hidden = true)
        % Added codgenredirect for achieving higher throughput(frames/sec)
        % using for loop based implementation for codegen as reshape-permute-reshape 
        % based forwrad implementation has low throughput but has better
        % simulation performance 
        function name = matlabCodegenRedirect(~)
            name = 'nnet.internal.cnn.coder.DepthToSpace2DLayer';
        end
    end 
end


function input = iCheckAndReturnValidInput(input)

if ndims(input)>4
    error(message('images:depthToSpace:invalidInput2D'));
end

if isa(input,'dlarray')
    isInputDataFormatted = ~isempty(dims(input));
    if isInputDataFormatted
        labels = dims(input);
        numChannelDims = count(labels,'C');

        if (numChannelDims ~= 1)
            error(message('images:depthToSpace:requireChannelDim')); 
        end
    
        numSpatialDims = count(labels,'S');

        if numSpatialDims>2
            error(message('images:depthToSpace:requireValidSpatialDim')); 
        end
    else
        input = deep.internal.dlarray.validateDataFormatArg(input, 'SSCB');
    end
end  
end

