function Z = spaceToDepth(X, blockSize,NameValueArgs)
%SPACETODEPTH Rearrange input dlarray data by the moving values from
%spatial dimension to depth dimension.
%
%   Y = SPACETODEPTH(X, BLOCKSIZE) rearranges input dlarray data by moving a block
%   of values from spatial dimension to depth dimension. BLOCKSIZE is a positive  
%   integer scalar or vector of form [height width]. Specify BLOCKSIZE as a scalar 
%   for square blocks.
%
%   For an input dlarray of size [H W C] and block size [u v], the size of rearranged  
%   output is [floor(H/u)  floor(W/v)  C*u*v].
%
%   Y = SPACETODEPTH(___,'PARAM1',VAL1,'PARAM2',VAL2,...) specifies optional 
%   parameter name-value pairs for rearranging the input data
%
%   Supported Name/Value pairs:
%
%   'DataFormat'              - Character vector or string scalar specifying the 
%                               dimension labels for input dlarray. The label value 
%                               must be a combination of the following labels: 
%                                 'S' - spatial
%                                 'C' - channel
%                                 'B' - batch
%                               Number of dimension labels specified must be same as 
%                               the number of channels in the input data. Specify this 
%                               parameter if the input X is not a formatted dlarray.
%
%
%   Example 1
%   ---------
%   % Rearrange unformatted dlarray data from spatial dimension to depth(channel) dimension.
%   X = reshape(1:32,4,4,2);
%   X = dlarray(X);
%   blockSize = 2;
%   Z = spaceToDepth(X, blockSize,'DataFormat','SSCB')
%
%   Example 2
%   ----------
%   % Rearrange formatted dlarray data from spatial dimension to depth(channel) dimension.
%   X = reshape(1:32,4,4,2);
%   X = dlarray(X,'SSC');
%   blockSize = 2;
%   Z = spaceToDepth(X, blockSize)
%
%   See also DEPTHTOSPACE, DLARRAY, DLRESIZE

% Copyright 2020 The MathWorks, Inc.


arguments
    X {validateattributes(X,{'dlarray'},{'nonempty'},'spaceToDepth','X')}
    blockSize {mustBeNumeric, mustBeNonempty, mustBeFinite, ...
        mustBeReal, mustBePositive, mustBeInteger, iAssertValidBlockSize}
    NameValueArgs.DataFormat
end

% Ensure X is a dlarray and include DataFormat
labelString = iGetDimensionLabels(NameValueArgs);
[X, perm] = deep.internal.dlarray.validateDataFormatArg(X, labelString);

% Extract labels
labels = dims(X);
numSpatialDims = count(labels,'S');
if ((numSpatialDims < 1) || (numSpatialDims>2))
   error(message('images:spaceToDepth:requireValidSpatialDim')); 
end

blockSize = iMakeIntoRowVectorOfTwo(blockSize);

Z = images.spaceToDepth.internal.spaceToDepthForward(X,blockSize);

if isfield(NameValueArgs,'DataFormat')
    Z = stripdims(Z);
    % Permutes back in the same order as DataFormat
    Z = ipermute(Z, perm);
else
    Z = dlarray(Z,labels);
end
end

function labelString = iGetDimensionLabels(NameValueArgs)

if isfield(NameValueArgs,'DataFormat')
    labelString = NameValueArgs.DataFormat;
else
    labelString = [];
end
end

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
