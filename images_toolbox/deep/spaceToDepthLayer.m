function layer = spaceToDepthLayer(blockSize, optArgs)
%spaceToDepthLayer Space to depth layer
%
%   layer = spaceToDepthLayer(blockSize) creates a layer that permutes 
%   the spatial blocks of input into the depth dimension by shifting adjacent 
%   pixels from the spatial dimensions into the depth dimension.
%   blockSize is the size of the input blocks that are permuted along the
%   depth dimension. Specify blockSize as a scalar or a two-element
%   vector [height width]. When blockSize is a scalar, the same value
%   is used for the height and width.
%
%   Given an input feature map size of M-by-N-by-P, the space to depth
%   layer outputs a feature map of size:
%   [floor(M/height) floor(N/width) P*height*width]
%
%   Y = spaceToDepthLayer(___,'Name',Name) create a spaceToDepthLayer with
%   spacefied Name. Default value of the name is empty.                
%
%   Example:- Create a space to depth layer.
%   ----------------------------------------
%   % Block size to reorder input activations.
%   blockSize = [2 2];
%
%   % Create a space to depth layer.
%   layer = spaceToDepthLayer(blockSize,'Name','spaceToDepth')
% 
%   See also nnet.cnn.layer.SpaceToDepthLayer,
%   depthToSpace2dLayer, maxPooling2dLayer, spaceToDepth, resize2dLayer
%
%   <a href="matlab:helpview('deeplearning','list_of_layers')">List of Deep Learning Layers</a>

% Copyright 2020 The MathWorks, Inc.


arguments
    blockSize {mustBeNumeric, mustBeNonempty, mustBeFinite, ...
        mustBeReal, mustBePositive, mustBeInteger, iAssertValidBlockSize}
    
    optArgs.Name {nnet.internal.cnn.layer.paramvalidation.validateLayerName} = ''
end


inpArgs.Name = char(optArgs.Name);  % make sure strings get converted to char vectors
inpArgs.blockSize = iMakeIntoRowVectorOfTwo(blockSize);

% Pass the internal layer to a function to construct a user visible layer.
layer = nnet.cnn.layer.SpaceToDepthLayer(inpArgs.Name, inpArgs.blockSize);

end

%--------------------------------------------------------------------------
function iAssertValidBlockSize(BlockSize)
if ~( isscalar(BlockSize) || (isrow(BlockSize) && numel(BlockSize)==2) )
    error(message('images:spaceToDepth:ParamMustBeScalarOrPair', 'blockSize'));
end
end

function x = iMakeIntoRowVectorOfTwo(x)
if(isscalar(x))
    x = [x x];
end
end