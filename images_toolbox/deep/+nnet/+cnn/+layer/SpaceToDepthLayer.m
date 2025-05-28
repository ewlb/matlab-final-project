classdef SpaceToDepthLayer < nnet.layer.Layer & nnet.internal.cnn.layer.Traceable
    % spaceToDepthLayer   SpaceToDepth Layer Rearrange blocks of spatial data
    %                     of input along the depth.
    %
    %   To create a spaceToDepth layer, use spaceToDepthLayer.
    %
    %   SpaceToDepthLayer properties:
    %       Name                   - A name for the layer.
    %       BlockSize              - It specifies the size of the data
    %                                block which rearrenges from spatial to 
    %                                depth dimesion.
    %
    %   Example:
    %       % Create a spaceToDepth layer.
    %       blockSize = 2;
    %       layer = spaceToDepthLayer(blockSize)
    %
    %   See also spaceToDepthLayer
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties (SetAccess = private)
        %   BlockSize       
        %      The block size is used to modify the input's size from 
        %      [height width channels] to [outHeight, outWidth, outChannels]
        %      where outHeight is [floor(height/blockSize(1))], outWidth is
        %      [floor(width/blockSize(2))] and outChannels is
        %      [channels*(blockSize(1)*blockSize(2))].         

        BlockSize
        
    end

    methods
        function layer = SpaceToDepthLayer(name, blocksize)
            layer.Name = name;
            layer.BlockSize = blocksize;
            layer.Description = getString(message('images:spaceToDepth:spaceToDepthOneLineDisp',mat2str(blocksize)));
            layer.Type = getString(message('images:spaceToDepth:spaceToDepthType'));
        end
        
        function Z = predict(layer,X)
            X = iCheckAndReturnValidInput(X);
            Z = images.spaceToDepth.internal.spaceToDepthForward(X,layer.BlockSize);
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
            % original size.
            [inputHeight,inputWidth,inputChannel,~] = size(Z);
            outputHeight = (inputHeight*layer.BlockSize(1));
            outputWidth = (inputWidth*layer.BlockSize(2));
            outputChannel = inputChannel/(layer.BlockSize(1)*layer.BlockSize(2));
            
            if isa(X, 'dlarray')
                labels = dims(X);
                dX = zeros(size(X),'like',X);
                if ~isempty(labels)
                    dX = dlarray(dX,labels);
                end
            else
              dX = zeros(size(X),'like',X);
            end               
            
            for idxBlockSizeX=1:layer.BlockSize(1)
                for idxBlockSizeY=1:layer.BlockSize(2)
                    idx = (idxBlockSizeX-1)*layer.BlockSize(2) + idxBlockSizeY;
                    val = outputChannel*(idx-1)+1:outputChannel*idx;
                    dX(idxBlockSizeX:layer.BlockSize(1):outputHeight,idxBlockSizeY:layer.BlockSize(2):outputWidth,:,:)= dLdZ(:,:,val,:);
                end
            end
        end
        
    end
    
    methods(Static, Hidden)
        % Loads spaceToDepthLayer and also handles backward compatibility for spaceToDepthLayer saved before R2021a.
        function this = loadobj(in)
            this = nnet.cnn.layer.SpaceToDepthLayer(in.Name, in.BlockSize);
        end
    end      

end

function input = iCheckAndReturnValidInput(input)

if ndims(input)> 4
    error(message('images:spaceToDepth:invalidInput2D'));
end 

if isa(input,'dlarray')
    isInputDataFormatted = ~isempty(dims(input));
    if isInputDataFormatted
        labels = dims(input);
        numSpatialDims = count(labels,'S');
        if ((numSpatialDims < 1) || (numSpatialDims>2))
           error(message('images:spaceToDepth:requireValidSpatialDim')); 
        end
    else
        input = deep.internal.dlarray.validateDataFormatArg(input, 'SSCB');
    end
end  
end
