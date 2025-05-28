function net = blockedNetwork(blockCreationFcn,numBlocks,NameValueArgs)
%  Create a network with repeating block structure
%
%  net = blockedNetwork(fun,numBlocks) takes an input function, fun, and
%  a number of blocks, numBlocks and returns net, a dlnetwork object. The
%  function fun must have the following signature:
% 
%       block = fun(blockIndex)
%
%  where blockIndex is a scalar integer in the range [1,numBlocks]. The
%  output from fun, block, can be a layer, or a layer array. fun is called 
%  numBlocks times, with each block connected
%  together sequentially.
%
%  net = blockedNetwork(___,Name,Value,___) creates a network with
%  Name/Value pairs used to control aspects of network creation. Supported
%  options:
%
%   'NamePrefix'        Character vector or string which is appended to the
%                       start of the name of each layer when a layer does
%                       not have a name.
%
%                       Default: ""
%
%  Notes
%  -----
%  [1] The dlnetwork returned by blockedNetwork is uninitialized and not
%  ready to be used for training or inference. To initialize the the
%  network, use the initialize function: 
%
%       netInitialized = initialize(net);
%
%  Examples
%  --------
%  % Build a U-net-style encoder
%
%  unetBlock = @(block) [convolution2dLayer(3,2^5+block)
%                       reluLayer
%                       convolution2dLayer(3,2^5+block)
%                       reluLayer
%                       maxPooling2dLayer(2,'Stride',2)];
%  net = blockedNetwork(unetBlock,4,'NamePrefix','encoder');
%
%  % Initialize network weights for [224,224,3] input
%  net = initialize(net,dlarray(zeros(224,224,3),'SSC'));
%
%  % Visualize network
%  analyzeNetwork(net)
%
%   See also dlnetwork, dlarray, trainNetwork

% Copyright 2020 The MathWorks, Inc.


arguments
    blockCreationFcn function_handle
    numBlocks (1,1) {mustBeNumeric, mustBePositive,mustBeNonempty,mustBeNonsparse,mustBeFinite,mustBeInteger,mustBeReal}
    NameValueArgs.NamePrefix {mustBeA(NameValueArgs.NamePrefix,["string","char"]),mustBeNonzeroLengthText}
end

mustBeValidBlockFcn(blockCreationFcn);

if ~isfield(NameValueArgs,'NamePrefix')
    NameValueArgs.NamePrefix = "";
else
    NameValueArgs.NamePrefix = string(NameValueArgs.NamePrefix);
end

lgraph = layerGraph();
for idx = 1:numBlocks
    block = blockCreationFcn(idx);
    block = iManageNames(block,idx,NameValueArgs.NamePrefix);
    lgraph = iAddBlock(block,lgraph);
end

net = dlnetwork(lgraph,'Initialize',false);

end

function lgraph = iAddLayers(lgraph,layers)
% Thin wrapper around addLayers to manage possible exceptions
try
    lgraph = addLayers(lgraph,layers);
catch ME
    if ME.identifier == "nnet_cnn:nnet:cnn:LayerGraph:LayerNamesMustNotAlreadyExist"
        error(message('images:blockedNetwork:blockRepeatedLayerName'));
    elseif ME.identifier == "nnet_cnn:nnet:cnn:LayerGraph:LayerNamesMustBeUnique"
        error(message('images:blockedNetwork:repeatedLayerNameWithinBlock'));
    else
        rethrow(ME);
    end
end
end

function lgraph = iAddBlock(block,lgraph)
if ~isempty(lgraph.Layers)
    lastBlockOutputName = lgraph.Layers(end).Name;
    lgraph = iAddLayers(lgraph,block);
    lgraph = connectLayers(lgraph,lastBlockOutputName,block(1).Name);
else
    lgraph = iAddLayers(lgraph,block);
end
end

function block = iManageNames(block,blockIndex,namePrefix)
for idx = 1:length(block)
    if isempty(block(idx).Name)
       block(idx).Name =  namePrefix+"Block"+blockIndex+"Layer"+idx;
    else
       block(idx).Name = namePrefix+block(idx).Name;
    end
end
end

function mustBeValidBlockFcn(blockFcn)
try
   block = blockFcn(1);
catch ME
    newException = images.deep.internal.BlockFunctionException();
    newException = newException.addCause(ME);
    throwAsCaller(newException);
end
mustBeLayerOrLayerArray(block);
end

function mustBeLayerOrLayerArray(layer)
if ~(isa(layer,'nnet.cnn.layer.Layer') || isa(layer,'nnet.layer.Layer'))
    error(message('images:blockedNetwork:invalidBlock'))
end
end
