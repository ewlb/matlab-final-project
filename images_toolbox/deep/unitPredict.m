function translatedImage = unitPredict(gen, inputImage, NameValueArgs)

arguments
    gen {iValidateNet(gen)}
    inputImage {iValidateInput(inputImage)}
    NameValueArgs.OutputType = 'SourceToTarget'
end

images.internal.requiresNeuralNetworkToolbox(mfilename);

OutputType = iValidateOutputType(NameValueArgs.OutputType, ["SourceToTarget", "TargetToSource"]);

NumSourceChannel = gen.Layers(1).InputSize(3);
NumTargetChannel = gen.Layers(2).InputSize(3);

if strcmp(OutputType, 'SourceToTarget')
    % One of the inputs is used as dummy input and the output corresponding to that will be ignored.
    if NumSourceChannel >= NumTargetChannel
        dummy = inputImage(:,:,1:NumTargetChannel,:);
    else
        lastChannel = inputImage(:,:,NumSourceChannel,:);
        img = repmat(lastChannel, [1 1 (NumTargetChannel - NumSourceChannel) 1]);
        dummy = cat(3, inputImage, img);
    end
    
    translatedImage = predict(gen, inputImage, dummy, 'Outputs', 'decoderTargetBlock/out1');
else
    % One of the inputs is used as dummy input and the output corresponding to that will be ignored.
    if NumTargetChannel >= NumSourceChannel
        dummy = inputImage(:,:,1:NumSourceChannel,:);
    else
        lastChannel = inputImage(:,:,NumTargetChannel,:);
        img = repmat(lastChannel, [1 1 (NumSourceChannel - NumTargetChannel) 1]);
        dummy = cat(3, inputImage, img);
    end
    
    translatedImage = predict(gen, dummy, inputImage, 'Outputs', 'decoderSourceBlock/out2');
end
end

%Input arguments validation functions.
function val = iValidateOutputType(val, options)
validateattributes(val, {'char','string'},{},'','OutputType');
val = validatestring(val, options,'','OutputType');
end

function val = iValidateNet(val)
validateattributes(val, {'dlnetwork'}, {'nonempty'},'', '');
if numel(val.Layers) ~= 9 || ( ~isa(val.Layers(3), 'images.unitGenerator.internal.encoderLayer') && ...
        ~isa(val.Layers(4), 'images.unitGenerator.internal.encoderLayer') && ...
        ~isa(val.Layers(6), 'images.unitGenerator.internal.encoderSharedLayer') && ...
        ~isa(val.Layers(7), 'images.unitGenerator.internal.decoderSharedLayer') && ...
        ~isa(val.Layers(8), 'images.unitGenerator.internal.decoderLayer') && ...
        ~isa(val.Layers(9), 'images.unitGenerator.internal.decoderLayer'))
    error(message('images:unitGenerator:mustBeUNITGenerator'));
end
end

function val = iValidateInput(val)
validateattributes(val, {'dlarray'}, {'nonempty'},'', '');
if isempty(dims(val))
    error(message('images:unitGenerator:mustBeFormattedDlarray'));
end
end

%  Copyright 2020-2023 The MathWorks, Inc.