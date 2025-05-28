function [net,outputNames] = pretrainedEncoderNetwork(networkName,depth)
% pretrainedEncoderNetwork Create encoder network from pre-trained network.
%
% [net,outputNames] = pretrainedEncoderNetwork(networkName,depth) takes a 
% string specifying a pre-trained network and a depth, which defines the 
% number of downsampling operations that are performed in the resulting 
% output dlnetwork, net. The second output argument, outputNames, is a
% string vector which defines the names of layers in net that come directly
% before downsampling operations. These activations from the layers named 
% in outputNames correspond to features of interest at a particular spatial 
% resolution/scale. Valid networkName inputs are listed below, and require 
% installation of the associated Add-On:
%
%                <a href="matlab:helpview('deeplearning','alexnet')">'alexnet'</a>
%                <a href="matlab:helpview('deeplearning','vgg16')">'vgg16'</a>
%                <a href="matlab:helpview('deeplearning','vgg19')">'vgg19'</a>
%                <a href="matlab:helpview('deeplearning','resnet18')">'resnet18'</a>
%                <a href="matlab:helpview('deeplearning','resnet50')">'resnet50'</a>
%                <a href="matlab:helpview('deeplearning','resnet101')">'resnet101'</a>
%                <a href="matlab:helpview('deeplearning','inceptionv3')">'inceptionv3'</a>
%                <a href="matlab:helpview('deeplearning','googlenet')">'googlenet'</a>
%                <a href="matlab:helpview('deeplearning','inceptionresnetv2')">'inceptionresnetv2'</a>
%                <a href="matlab:helpview('deeplearning','squeezenet')">'squeezenet'</a>
%                <a href="matlab:helpview('deeplearning','mobilenetv2')">'mobilenetv2'</a>
%
%   Notes
%   -----
%   1. When N levels are specified, the specified network is trimmed such
%   that it contains N distinct spatial resolutions. The final layer is
%   selected by trimming just prior to the next downsampling operation.
%
%   Examples
%   --------
%   % Build an encoder network from a squeezenet backbone
%
%   encoderNet = pretrainedEncoderNetwork('squeezenet',3);
%
%   See also DLARRAY, DLNETWORK

% Copyright 2020 The MathWorks, Inc.
arguments
   networkName string {mustBeMember(networkName,["alexnet","vgg16","vgg19","resnet18","resnet50","resnet101",...
    "inceptionv3","googlenet","inceptionresnetv2","squeezenet","mobilenetv2"])}
   depth (1,1) {mustBeNumeric,mustBePositive,mustBeScalarOrEmpty,mustBeNonempty,mustBeNonsparse,mustBeFinite,mustBeInteger,mustBeReal}
end

m = buildMap();
outputNames = m(networkName);
net = constructNetwork(networkName);
[net,outputNames] = trimNetwork(net,outputNames,depth,networkName);
net = dlnetwork(net);        

end

function [net,outputNames] = trimNetwork(net,outputNames,depth,networkName)

validDepth = (length(outputNames) - 1);
if depth > validDepth
    error(message('images:pretrainedEncoderNetwork:tooManyLevelsSpecified',depth,networkName,validDepth))
end

outputNames = outputNames(1:depth+1);

if isa(net,'SeriesNetwork')
    net = layerGraph(net.Layers);
else
    net = layerGraph(net);
end

% Can I depend on the supported networks from support package already being
% topo sorted?
names = string({net.Layers.Name});
idx = find(outputNames(end)==names);
namesToCut = names(idx+1:end);
net = removeLayers(net,namesToCut);    

end

function net = constructNetwork(networkName)
    net = feval(networkName);
end

function m = buildMap

supportedNetworkNames = iGetSupportedNetworkNames();

m = containers.Map(supportedNetworkNames,cell(1,length(supportedNetworkNames)));
m("alexnet") = ["data","norm1","norm2","relu5","pool5"];
m("vgg16") = ["relu1_2","relu2_2","relu3_3","relu4_3","relu5_3"];
m("vgg19") = ["relu1_2","relu2_2","relu3_4","relu4_4","relu5_4"];
m("resnet18") = ["data","conv1_relu","res2b_relu","res3b_relu","res4b_relu","res5b_relu"];
m("resnet50") = ["data","activation_1_relu","activation_10_relu","activation_22_relu","activation_40_relu","activation_49_relu"];
m("resnet101") = ["data","conv1_relu","res2c_relu","res3b3_relu","res4b22_relu","res5c_relu"];
m("inceptionv3") = ["input_1","activation_3_relu","activation_5_relu","mixed2","mixed7","mixed10"];
m("googlenet") = ["data","conv1-relu_7x7","conv2-norm2","inception_3b-output","inception_4e-output","inception_5b-output"];
m("inceptionresnetv2") = ["input_1","activation_3","activation_5","block35_10_ac","block17_20_ac","conv_7b_ac"];
m("squeezenet") = ["data","relu_conv1","fire3-concat","fire5-concat","relu_conv10"];
m("mobilenetv2") = ["input_1","block_1_expand_relu","block_3_expand_relu","block_6_expand_relu","block_13_expand_relu","out_relu"];

end

function supportedNames = iGetSupportedNetworkNames
supportedNames = ["alexnet","vgg16","vgg19","resnet18","resnet50","resnet101",...
    "inceptionv3","googlenet","inceptionresnetv2","squeezenet","mobilenetv2"];
end