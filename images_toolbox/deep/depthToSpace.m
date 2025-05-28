function Z = depthToSpace(X, blockSize,NameValueArgs)
%DEPTHTOSPACE Rearrange input dlarray data by the moving values from depth
%dimension to spatial dimension.
%
%   Y = DEPTHTOSPACE (X, BLOCKSIZE) rearranges input dlarray data by moving a block
%   of values from depth dimension to spatial dimension. BLOCKSIZE is a positive  
%   integer scalar or vector of form [height width]. Specify BLOCKSIZE as a scalar 
%   for square blocks.
%
%   For an input dlarray of size [H W C*u*v] and block size [u v], the size of 
%   rearranged output is [h*u  W*v  C].
%
%   Y = DEPTHTOSPACE(___,'PARAM1',VAL1,'PARAM2',VAL2,...) specifies optional 
%   parameter name-value pairs for rearranging the input data
%
%   Supported Name/Value pairs: 
%
%   'DataFormat'              - Character vector or string scalar specifying the dimension 
%                               labels for input dlarray. The label value must be  
%                               a combination of the following labels: 
%                                 'S' - spatial
%                                 'C' - channel
%                                 'B' - batch
%                               Number of dimension labels specified must be same as the  
%                               number of channels in the input data. Specify this parameter   
%                               if the input X is not a formatted dlarray.
%         
%
%   'Mode'                   - Character vector or string scalar specifying the order for   
%                              rearranging the input dlarray along the spatial dimension,
%                              specified as one of the following:
%                              CRD - moves data to spatial dimension in column, 
%                                    row and depth order.
%                              DCR - moves data to spatial dimension in depth, 
%                                    column and row order. 
%
%                              Default: "DCR".
%
%   Example 1
%   ----------
%   % Rearrange unformatted dlarray data using DCR mode.
%   X = reshape(1:32,2,2,8);
%   X = dlarray(X);
%   blockSize = 2;
%   Z = depthToSpace(X, blockSize,'DataFormat','SSCB')
%
%   Example 2
%   ----------
%   % Rearrange formatted dlarray data using CRD mode.
%   X = reshape(1:32,2,2,8);
%   X = dlarray(X,'SSC');
%   blockSize = 2;
%   Z = depthToSpace(X, blockSize,'Mode','CRD')
%
%   See also SPACETODEPTH, DLARRAY, DLRESIZE

% Copyright 2020 The MathWorks, Inc.


arguments
    X {validateattributes(X,{'dlarray'},{'nonempty'},'depthToSpace','X')}
    blockSize {mustBeNumeric, mustBeNonempty, mustBeFinite, ...
        mustBeReal, mustBePositive, mustBeInteger, iAssertValidBlockSize}
    NameValueArgs.DataFormat
    NameValueArgs.Mode string = "DCR"
end


NameValueArgs.Mode = iValidateString(NameValueArgs.Mode,["DCR","CRD"]);

% Ensure X is a dlarray and include DataFormat
labelString = iGetDimensionLabels(NameValueArgs);
[X, perm] = deep.internal.dlarray.validateDataFormatArg(X, labelString);

% Extract labels
labels = dims(X);
numChannelDims = count(labels,'C');

if (numChannelDims ~= 1)
   error(message('images:depthToSpace:requireChannelDim')); 
end

numSpatialDims = count(labels,'S');

if numSpatialDims>2
   error(message('images:depthToSpace:requireValidSpatialDim')); 
end


blockSize = iMakeIntoRowVectorOfTwo(blockSize);

Z = images.depthToSpace.internal.depthToSpaceForward(X,blockSize,NameValueArgs.Mode);

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