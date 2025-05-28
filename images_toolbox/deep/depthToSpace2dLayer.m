function layer = depthToSpace2dLayer(blockSize, optArgs)
%depthToSpace2dLayer 2-D Depth to space layer
%
%   layer = depthToSpace2dLayer(blockSize) creates a layer that permutes 
%   input data by moving values from depth dimension to spatial dimension.
%   blockSize is the size of the input blocks that are permuted along the
%   spatial dimension. Specify blockSize as a scalar or a two-element
%   vector [height width]. When blockSize is a scalar, the same value
%   is used for the height and width.
%
%   Given an input dlarray of size [H W C] and block size of [u v]
%   depth to space layer outputs a feature map of size
%   [h*u  W*v  C/u*v].
%
%   Y = depthToSpace2dLayer(___,'PARAM1',VAL1,'PARAM2',VAL2,...)
%   specifies optional parameter name/value pairs for creating the layer:
%
%   Supported Name/Value pairs:
%
%       'Name'                    - A string or character array that
%                                   specifies the name for the layer.
%
%                                   Default : '' 
%
%       'Mode'                   - Character vector or string scalar specifying the 
%                                  order for rearranging the input data along the 
%                                  spatial dimension, specified as one of the following:
%                                  CRD - moves data to spatial dimension in column, 
%                                        row and depth order.
%                                  DCR - moves data to spatial dimension in depth, 
%                                        column and row order 
% 
%                                  Default: "DCR".             
%
%   Example:- Create a depth to space layer.
%   ----------------------------------------
%   % Block size to reorder input activations.
%   blockSize = [2 2];
%
%   % Create a depth to space layer.
%   layer = depthToSpace2dLayer(blockSize,'Name','depthToSpaceLayer','Mode','CRD')
%
%   See also nnet.cnn.layer.DepthToSpace2DLayer, spaceToDepthLayer,
%   spaceToDepth, resize2dLayer
%
%   <a href="matlab:helpview('deeplearning','list_of_layers')">List of Deep Learning Layers</a>

% Copyright 2020 The MathWorks, Inc.


arguments
    blockSize {mustBeNumeric, mustBeNonempty, mustBeFinite, ...
        mustBeReal, mustBePositive, mustBeInteger, iAssertValidBlockSize}
    
    optArgs.Name {nnet.internal.cnn.layer.paramvalidation.validateLayerName} = ''
    optArgs.Mode string = "DCR"
end

inpArgs.Mode = iValidateString(optArgs.Mode,["DCR","CRD"]);
inpArgs.Name = char(optArgs.Name);  % make sure strings get converted to char vectors
inpArgs.blockSize = iMakeIntoRowVectorOfTwo(blockSize);

% Pass the internal layer to a function to construct a user visible layer.
layer = nnet.cnn.layer.DepthToSpace2DLayer(inpArgs.Name, inpArgs.blockSize,inpArgs.Mode);

end

%--------------------------------------------------------------------------
function iAssertValidBlockSize(BlockSize)
if ~( isscalar(BlockSize) || (isrow(BlockSize) && numel(BlockSize)==2) )
    error(message('images:depthToSpace:ParamMustBeScalarOrPair', 'blockSize'));
end
end

function x = iMakeIntoRowVectorOfTwo(x)
if(isscalar(x))
    x = [x x];
end
end

function str = iValidateString(str,vals)
% Workaround to avoid needing to call validatestring against Name/Values
% set to the value set.
str = lower(str);
if any(str == lower(vals))
    return
else
    str = validatestring(str,vals);
end
end