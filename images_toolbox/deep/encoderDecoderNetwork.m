function net = encoderDecoderNetwork(inputSize,encoder,decoder,NameValueArgs)
% Create an encoder/decoder network
%
% net = encoderDecoderNetwork(inputSize,encoder,decoder) takes an encoder network,
% encoder, and a decoderNetwork, decoder, and connects them to create an
% encoder/decoderNetwork. The output, net, is a dlnetwork object.
%
% net = encoderDecoderNetwork(___,Name,Value,___) creates an
% encoder/decoder network, taking Name/Value pairs to control aspects of
% network creation. Supported options are:
%
%   'LatentNetwork'         A layer, or array of layers that a define a
%                           network connected between the encoder and
%                           decoder. 
%
%                           Default: []
%                           
%   'FinalNetwork'          A layer, or array of layers that define a
%                           network that is connected to the output of the
%                           decoder. If 'NumChannels' is specified, the
%                           'FinalNetwork' is connected after the size 1
%                           convolution.
%
%                           Default: []
%
%   'OutputChannels'        A numeric scalar specifying the number of
%                           channels desired at the output of the network.
%                           This option inserts a size 1 convolution at the
%                           end of the decoder with the specified number of
%                           channels.
%
%                           Default: []
%
%   'SkipConnectionNames'   A Mx2 string of the form
%                           [encoderName1,decoderName1;encoderNameN,decoderNameN]
%                           which defines the names of pairs of
%                           encoder/decoder layers whos activations are
%                           merged when 'SkipConnections' is not "none".
%                           When 'SkipConnectionNames' is 'auto', a
%                           introspection of the encoder and decoder is
%                           done to determine SkipConnectionNames.
%           
%                           Default: "auto"
%                           
%   'SkipConnections'       A string or character array that defines the
%                           kind of skip connections inserted between the
%                           encoder and decoder networks. Options are:
%                           "concatenate","add", and "none".
%
%                           Default: "none"
%
%  Notes
%  -----
%  [1] The specified decoder must be a single input, single output
%  network.
%
% Example - Build a U-net network
% -------------------------------
% 
%  encoderBlock = @(block) [convolution2dLayer(3,2^(5+block),'Padding','same')
%                       reluLayer
%                       convolution2dLayer(3,2^(5+block),'Padding','same')
%                       reluLayer
%                       maxPooling2dLayer(2,'Stride',2)];
%
%  encoder = blockedNetwork(encoderBlock,4,'NamePrefix','encoder');
%
%  decoderBlock = @(block) [transposedConv2dLayer(2,2^(10-block),'Stride',2)
%                           convolution2dLayer(3,2^(10-block),'Padding','same')
%                           reluLayer
%                           convolution2dLayer(3,2^(10-block),'Padding','same')
%                           reluLayer];
%
%  bridge = [convolution2dLayer(3,1024,'Padding','same')
%           reluLayer
%           convolution2dLayer(3,1024,'Padding','same')
%           reluLayer
%           dropoutLayer(0.5)];
%                 
%  decoder = blockedNetwork(decoderBlock,4,'NamePrefix','decoder');
%
%  inputSize = [224 224 3];
%  unet = encoderDecoderNetwork(inputSize,encoder,decoder,...
%   'OutputChannels',3,...
%   'SkipConnections','concatenate',...
%   'LatentNetwork',bridge);
%
%  Example - Build U-net from pre-trained googLenet backbone
%  -----------------------------------------------
%  depth = 4;
%  [encoder,outputNames] = pretrainedEncoderNetwork('googlenet',depth);
%  exampleInput = dlarray(zeros(encoder.Layers(1).InputSize),'SSC');
%  exampleOutput = cell(1,length(outputNames));
%  [exampleOutput{:}] = forward(encoder,exampleInput,'Outputs',outputNames);
%  numChannelsInDecoderBlocks = cellfun(@(x) size(extractdata(x),3),exampleOutput);
%  numChannelsInDecoderBlocks = fliplr(numChannelsInDecoderBlocks(1:end-1));
%  decoderBlock = @(block) [transposedConv2dLayer(2,numChannelsInDecoderBlocks(block),'Stride',2)
%                           convolution2dLayer(3,numChannelsInDecoderBlocks(block),'Padding','same')
%                           reluLayer
%                           convolution2dLayer(3,numChannelsInDecoderBlocks(block),'Padding','same')
%                           reluLayer];
%  decoder = blockedNetwork(decoderBlock,depth);
%  net = encoderDecoderNetwork([224 224 3],encoder,decoder,...
%   'OutputChannels',3,...
%   'SkipConnections','concatenate');
%
%   See also dlnetwork, dlarray, blockedNetwork, pretrainedEncoderNetwork

% Copyright 2020 The MathWorks, Inc.
                                             
arguments
    inputSize {mustBeInteger mustBePositive}
    encoder {mustBeA(encoder,["dlnetwork","nnet.cnn.LayerGraph"])}
    decoder {mustBeA(decoder,["dlnetwork","nnet.cnn.LayerGraph"]) mustBeSISONetwork mustBeSeriesNetwork}
    NameValueArgs.SkipConnections string {mustBeMember(NameValueArgs.SkipConnections,["none","add","concatenate"])} = "none"
    NameValueArgs.LatentNetwork {mustBeA(NameValueArgs.LatentNetwork,["nnet.cnn.layer.Layer","nnet.layer.Layer"])} = nnet.cnn.layer.Layer.empty()
    NameValueArgs.FinalNetwork {mustBeA(NameValueArgs.FinalNetwork,["nnet.cnn.layer.Layer","nnet.layer.Layer"])} = nnet.cnn.layer.Layer.empty()
    NameValueArgs.SkipConnectionNames string = "auto"
    NameValueArgs.OutputChannels (1,1) {mustBeNumeric, mustBePositive,mustBeNonempty,mustBeNonsparse,mustBeFinite,mustBeInteger,mustBeReal}
end

mustBeValidSkipConnectionNames(NameValueArgs.SkipConnectionNames,encoder,decoder,NameValueArgs.SkipConnections);

% Work internally with lgraph representations of inputs if provided as dlnetwork
encoder = iConvertToLayerGraph(encoder);
decoder = iConvertToLayerGraph(decoder);

if ~isfield(NameValueArgs,'OutputChannels')
    NameValueArgs.OutputChannels = [];
end

numSpatialDims = length(inputSize)-1;

encoder = iAddInputLayer(encoder,inputSize,numSpatialDims);

if NameValueArgs.SkipConnections == "none"
    [encoder,encoderOutputName] = iAddLatentNetwork(encoder,NameValueArgs.LatentNetwork);
    encoderDecoder = iCreateLinearEncoderDecoder(encoder,decoder,encoderOutputName);
else
    encoderDecoder = iCreateEncoderDecoderWithSkipConnections(encoder,decoder,NameValueArgs.SkipConnections,...
        NameValueArgs.SkipConnectionNames,NameValueArgs.LatentNetwork);    
end

encoderDecoder = iAddFinalNetwork(encoderDecoder,NameValueArgs.OutputChannels,numSpatialDims,NameValueArgs.FinalNetwork,decoder.Layers(end).Name);

net = dlnetwork(encoderDecoder);

end

function net = iConvertToLayerGraph(net)
if isa(net,'dlnetwork')
    net = layerGraph(net);
end
end

function [encoder,outputName] = iAddLatentNetwork(encoder,latentNetwork)

encoderOutputName = encoder.Layers(end).Name;

if isempty(latentNetwork)
    outputName = encoder.Layers(end).Name;
else
    latentNetwork = iManageNames(latentNetwork,"LatentNetwork");
    encoder = addLayers(encoder,latentNetwork);
    latentNetworkInput = latentNetwork(1).Name;
    encoder = connectLayers(encoder,encoderOutputName,latentNetworkInput);
    outputName = latentNetwork(end).Name;
end

encoder = toposort(encoder);

end

function net = iAddDummyInputLayerToDecoder(decoder,dummyInput)
% TODO: Remove this once the requirement that a dlnetwork must have an
% input layer is lifted.

net = decoder;
if ndims(dummyInput) == 3
    inputLayer = imageInputLayer(size(dummyInput),...
        'Name','dummyInputLayerForDecoder',...
        'Normalization','none');
elseif ndims(dummyInput) == 4
    inputLayer = image3dInputLayer(size(dummyInput),...
        'Name','dummyInputLayerForDecoder',...
        'Normalization','none');
else
   assert(false,'Unexpected dummy input size'); 
end

net = addLayers(net,inputLayer);
net =  connectLayers(net,inputLayer.Name,decoder.Layers(1).Name);
net = toposort(net);    

end

function sizes = iFindOutputActivationSizes(net,dummyInput)
% Returns cell array containing size of each layer activation in order
% corresponding to Layers ordering.

outputNames = string({net.Layers.Name});
sizes = deep.internal.sdk.forwardDataAttributes(net,dummyInput,'Outputs',outputNames);

end

function skipNames = iAutoDetermineSkipConnectionNames(encoder,decoder)
% Introspect to determine locations where features from encoder
% will be merged with activations in decoder
encoderInputSize = encoder.Layers(1).InputSize;
dummyEncoderInput = iCreateDummyInput(encoderInputSize);

encoder = dlnetwork(encoder);

[dummyDecoderInputSize,dummyDecoderFormat] = deep.internal.sdk.forwardDataAttributes(encoder,dummyEncoderInput);
dummyDecoderInput = dlarray(zeros(dummyDecoderInputSize{1}),dummyDecoderFormat{1});

% Introspect decoder to find upsampling layers
tempDecoder = dlnetwork(iAddDummyInputLayerToDecoder(decoder,dummyDecoderInput));
decoderLayerSizes = iFindOutputActivationSizes(tempDecoder,dummyDecoderInput);
decoderInputNames = findUpsampleLayers(decoderLayerSizes,tempDecoder);
decoderInputNames = fliplr(decoderInputNames);

% Introspect encoder to determine the output taps for skip connections
encoderOutputNames = iFindEncoderSkipOutputs(encoder,dummyEncoderInput);

if length(decoderInputNames) ~= length(encoderOutputNames) || isempty(decoderInputNames) || isempty(encoderOutputNames)
    error(message('images:encoderDecoderNetwork:autoDetectionOfSkipConnectionsFailed'));
end

skipNames = [encoderOutputNames;decoderInputNames]';
skipNames = flipud(skipNames);

end

function net = iCreateEncoderDecoderWithSkipConnections(encoder,decoder,skipConnections,skipNames,latentNet)

if skipNames == "auto"
    skipNames = iAutoDetermineSkipConnectionNames(encoder,decoder);
end

numSpatialDims = length(encoder.Layers(1).InputSize)-1;
featureCatLayer = iGetFeatureCatLayer(skipConnections,numSpatialDims);

encoder = iAddLatentNetwork(encoder,latentNet);
temp = dlnetwork(encoder,'Initialize',false);
encoderDecoder = iCreateLinearEncoderDecoder(encoder,decoder,temp.OutputNames{1});

% Connect skip connections
net = addSkipConnections(encoderDecoder,featureCatLayer,skipNames);

end

function net = addSkipConnections(encoderDecoder,catLayer,skipNames)

% So that naming of feature merging/crop will start with inner-most skip
% connections (lowest spatial resolution).
encoderOutputNames = skipNames(:,1);
decoderInputNames = skipNames(:,2);

lgraph = encoderDecoder;

destinationNames = string(lgraph.Connections.Destination);
sourceNames = string(lgraph.Connections.Source);

% Base num spatial dims off of input layer InputSize.
numInputSpatialDims = length(encoderDecoder.Layers(1).InputSize)-1;
cropLayer = iGetCropLayer(numInputSpatialDims);
    
for idx = 1:length(decoderInputNames)
    connIdx = decoderInputNames(idx) == sourceNames;
    thisLayerDestination = destinationNames(connIdx);
    cropName = "encoderDecoderSkipConnection"+"Crop"+idx;
    centerCrop = cropLayer;
    centerCrop.Name = cropName;
    lgraph = addLayers(lgraph,centerCrop);
    lgraph = disconnectLayers(lgraph,decoderInputNames(idx),thisLayerDestination);
    lgraph = connectLayers(lgraph,decoderInputNames(idx),cropName+"/ref");
    thisCatLayer = catLayer;
    thisCatLayer.Name = "encoderDecoderSkipConnectionFeatureMerge"+idx;
    lgraph = addLayers(lgraph,thisCatLayer);
    lgraph = connectLayers(lgraph,decoderInputNames(idx),thisCatLayer.Name+"/in2");
    lgraph = connectLayers(lgraph,thisCatLayer.Name,thisLayerDestination);
    lgraph = connectLayers(lgraph,cropName,thisCatLayer.Name+"/in1");
    
    % Finally, connect skip connection from encoder at current scale to
    % crop layer in decoder
    lgraph = connectLayers(lgraph,encoderOutputNames(idx),cropName+"/in");
end
net = lgraph;
end


function lgraphOverall = iCreateLinearEncoderDecoder(encoder,decoder,encoderOutputName)
decoderInputName = decoder.Layers(1).Name;
lgraphOverall = encoder;
lgraphOverall = addLayers(lgraphOverall,decoder.Layers);
lgraphOverall = connectLayers(lgraphOverall,encoderOutputName,decoderInputName);
end
        
function net = iAddInputLayer(net,inputSize,numSpatialDims)

inputLayerIdx = iFindInputLayerIndices(net);

if nnz(inputLayerIdx) > 1
    error(message('images:encoderDecoderNetwork:tooManyInputLayers'))
end

if any(inputLayerIdx)
    inputLayer = net.Layers(inputLayerIdx);
    currentInputName = inputLayer.Name;
    inputLayer = images.deep.internal.reduceInputLayerStats(inputLayer,inputSize);
    net = replaceLayer(net,currentInputName,inputLayer);
else
    if numSpatialDims == 2
        newInputLayer = imageInputLayer(inputSize,'Normalization','none','Name','encoderImageInputLayer');
    else
        newInputLayer = image3dInputLayer(inputSize,'Normalization','none','Name','encoderImageInputLayer');
    end
    
    currentDanglingInputName = net.Layers(1).Name;
    net = addLayers(net,newInputLayer);
    net = connectLayers(net,'encoderImageInputLayer',currentDanglingInputName);
end

net = toposort(net);

end

function net = iAddFinalNetwork(net,outputChannels,numSpatialDims,finalNetwork,outputName)
if ~isempty(outputChannels)
    if numSpatialDims == 2
        outputConvLayer = convolution2dLayer(1,outputChannels);
    else
        outputConvLayer = convolution3dLayer(1,outputChannels);
    end
    outputConvLayer.Name = 'encoderDecoderFinalConvLayer';
    
    net = addLayers(net,outputConvLayer);
    net = connectLayers(net,outputName,outputConvLayer.Name);
    outputName = outputConvLayer.Name;
end

if ~isempty(finalNetwork)
    finalNetwork = iManageNames(finalNetwork,"FinalNetwork");
    net = addLayers(net,finalNetwork);
    net = connectLayers(net,outputName,finalNetwork(1).Name);
end

net = toposort(net);

end

function cropLayer = iGetCropLayer(numSpatialDims)

if numSpatialDims == 2
    cropLayer = crop2dLayer('centercrop');
elseif numSpatialDims == 3
    cropLayer = crop3dLayer('centercrop');
else
    assert(false,'unexpected num spatial dims');
end

end

function layer = iGetFeatureCatLayer(name,numSpatialDims)

if name == "add"
   layer  = additionLayer(2);
elseif name == "concatenate"
    layer = concatenationLayer(numSpatialDims+1,2);
else
    assert(false,'Unexpected merge method specified');
end
end

function block = iManageNames(block,namePrefix)
for idx = 1:length(block)
    if isempty(block(idx).Name)
       block(idx).Name =  "Layer"+idx;
    end
    block(idx).Name = namePrefix + block(idx).Name;
end
end

function decoderUpsampleNames = findUpsampleLayers(sizes,lgraph)
% Compare each layers activations to the one before it to look up 2*
% upsampling of spatial dims. This assumes there is an input layer at the
% first layer of the decoder otherwise this wouldn't work.
decoderUpsampleNames = string.empty();
for idx = 2:numel(sizes)
    if isequal(sizes{idx}(1:end-1),2*sizes{idx-1}(1:end-1))
        decoderUpsampleNames(end+1) = lgraph.Layers(idx).Name; %#ok<AGROW>
    end 
end 
end

function outputNames = iFindEncoderSkipOutputs(encoder,dummyEncoderInput)

downsampleNames = string.empty();
numLayers = numel(encoder.Layers);
for idx = 1:numLayers
    if iIsDownsampleLayer(encoder.Layers(idx))
        downsampleNames(end+1) = encoder.Layers(idx).Name; %#ok<AGROW>
    end
end

destNames = string(encoder.Connections.Destination);
sourceNames = string(encoder.Connections.Source);
outputNames = string.empty();
for idx = 1:length(downsampleNames)
    downsampleLayerName = downsampleNames(idx);
    sourceIndex = destNames == downsampleLayerName;
    sourceName = sourceNames(sourceIndex);
    outputNames(end+1) = sourceName; %#ok<AGROW>
end

outputNames = unique(outputNames,'stable');

outputNames = iRemoveNamesWithDuplicateSpatialSizes(outputNames,dummyEncoderInput,encoder);

end

function outputNames = iRemoveNamesWithDuplicateSpatialSizes(outputNames,dummyEncoderInput,encoder)

% If multiple downsampling layers result in the same activation size, take
% the first one in topological order to handle cases like inceptionv3 where
% downsampling is performed within DAG inception blocks.
if ~isempty(outputNames)
    sampleSkipOutputs = cell(1,length(outputNames));
    [sampleSkipOutputs{:}] = forward(encoder,dummyEncoderInput,'Outputs',outputNames);
    sizes = cellfun(@(x) size(x),sampleSkipOutputs,'UniformOutput',false);
    spatialSizes = cat(1,sizes{:});
    spatialSizes = spatialSizes(:,1:ndims(dummyEncoderInput)-1);
    duplicateSizes = iFindDuplicateSizes(spatialSizes);
    
    for idx = 1:size(duplicateSizes,1)
        sz = duplicateSizes(idx,:);
        outputsWithDuplicateSize = all(spatialSizes == sz,2);
        duplicateToKeep =  find(outputsWithDuplicateSize,1,'first');
        duplicatesToRemove = outputsWithDuplicateSize;
        duplicatesToRemove(duplicateToKeep) = false;
        outputNames(duplicatesToRemove) = [];
    end
end

end

function duplicateSizes = iFindDuplicateSizes(x)

[~,I] = unique(x, 'rows', 'first');
ixDupRows = setdiff(1:size(x,1), I);
dupRowValues = x(ixDupRows,:);
duplicateSizes = unique(dupRowValues);

end

function TF = iIsDownsampleLayer(layer)
TF = isprop(layer,'Stride') && all(~mod(layer.Stride,2)); % Downsamples by a factor of 2
end


function idx =  iFindInputLayerIndices(net)
numLayers = length(net.Layers);
idx = false(1,numLayers);
for layerIdx = 1:numLayers
   idx(layerIdx) = isa(iExternalToInternal(net.Layers(layerIdx)),'nnet.internal.cnn.layer.InputLayer'); 
end
end

function x = iCreateDummyInput(inputSize)
dims = repmat('S',1,numel(inputSize)-1);
dims = [dims,'C'];
x = dlarray(zeros(inputSize),dims);
end

function internalLayer = iExternalToInternal(externalLayer)
% TODO: Talk to Joss about this, is there a better way to know whether a
% layer isa InputLayer that doesn't require reaching into nnet.internal?
% Conceptual review of what I'm doing here with input layers would be good
% too.
internalLayer = nnet.internal.cnn.layer.util.ExternalInternalConverter.getInternalLayers(externalLayer);
internalLayer = internalLayer{1};
end

function mustBeSISONetwork(net)
if ~isa(net,'dlnetwork')
    net = dlnetwork(net,'Initialize',false);
end

if (length(net.InputNames) > 1) || (length(net.OutputNames) > 1)
   error(message('images:encoderDecoderNetwork:mustBeSISONetwork')) 
end

end

function mustBeSeriesNetwork(net)

if ~isa(net,'nnet.cnn.LayerGraph')
   net = layerGraph(net); 
end

reconstructedNet = layerGraph(net.Layers);
if ~isequal(net,reconstructedNet)
    error(message('images:encoderDecoderNetwork:mustBeSeriesNetwork'));
end
end

function mustBeValidSkipConnectionNames(skipConnectionNames,encoder,decoder,skipConnectionType)
validateattributes(skipConnectionNames,{'string','char'},{'nonempty'},'encoderDecoderNetwork','SkipConnectionNames');
if skipConnectionNames == "auto"
    return
else
    if size(skipConnectionNames,2) ~= 2
        error(message('images:encoderDecoderNetwork:invalidSkipConnectionNamesSize'))
    end
    
    layerNamesNotInNetwork = iLayerNamesNotInNetwork(skipConnectionNames(:,1),encoder);
    if ~isempty(layerNamesNotInNetwork)
        error(message('images:encoderDecoderNetwork:invalidSkipConnectionNamesEncoder',layerNamesNotInNetwork(1)))
    end
    
    layerNamesNotInNetwork = iLayerNamesNotInNetwork(skipConnectionNames(:,2),decoder);
    if ~isempty(layerNamesNotInNetwork)
        error(message('images:encoderDecoderNetwork:invalidSkipConnectionNamesDecoder',layerNamesNotInNetwork(1)))
    end
    
    if skipConnectionType == "none"
        error(message('images:encoderDecoderNetwork:SkipConnectionTypeAndExplictNamingNotAllowed'))
    end
end
end

function namesNotInNetwork = iLayerNamesNotInNetwork(names,network)
idx = ismember(names,string({network.Layers.Name}));
namesNotInNetwork = names(~idx);
end