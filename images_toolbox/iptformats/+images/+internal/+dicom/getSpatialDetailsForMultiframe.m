function spatialDetails = getSpatialDetailsForMultiframe(metadataObj)
%

% Copyright 2016-2018 The MathWorks, Inc.

% Get the per-frame and shared functional groups.
if isstruct(metadataObj)
    if isfield(metadataObj, 'PerFrameFunctionalGroupsSequence')
        perFrameSequence = metadataObj.PerFrameFunctionalGroupsSequence;
    else
        perFrameSequence = struct([]);
    end
    
    if isfield(metadataObj, 'SharedFunctionalGroupsSequence')
        sharedSequence = metadataObj.SharedFunctionalGroupsSequence;
    else
        sharedSequence = struct([]);
    end
else
    % These will return empty if the attribute is not found.
    perFrameSequence = metadataObj.getAttributeByName('PerFrameFunctionalGroupsSequence');
    sharedSequence = metadataObj.getAttributeByName('SharedFunctionalGroupsSequence');
end

metadataSequence = combine(perFrameSequence, sharedSequence);
if isempty(metadataSequence)
    spatialDetails = images.internal.dicom.makeDefaultSpatialDetails();
    return
end

% Extract the patient positions, pixel spacings, and orientation values.
itemNames = fieldnames(metadataSequence);
numFrames = numel(itemNames);

spatialDetails.PatientPositions = zeros(numFrames, 3);
spatialDetails.PixelSpacings = zeros(numFrames, 2);
spatialDetails.PatientOrientations = zeros(2, 3, numFrames);

for idx = 1:numFrames
    thisItem = itemNames{idx};
    oneFrameDetails = metadataSequence.(thisItem);
    
    try
        position = oneFrameDetails.PlanePositionSequence.Item_1.ImagePositionPatient;
        spatialDetails.PatientPositions(idx, :) = position;
        
        spacing = oneFrameDetails.PixelMeasuresSequence.Item_1.PixelSpacing;
        spatialDetails.PixelSpacings(idx, :) = spacing;
        
        orientation = oneFrameDetails.PlaneOrientationSequence.Item_1.ImageOrientationPatient;
        spatialDetails.PatientOrientations(:, :, idx) = reshape(orientation, [3 2])';
    catch
        spatialDetails = images.internal.dicom.makeDefaultSpatialDetails();
        spatialDetails = incorporateSharedSequence(sharedSequence, spatialDetails);
        break
    end
end
end


function metadataStruct = combine(perFrameSequence, sharedSequence)

% Handle the case where one is empty or shared sequence is nonconforming.
if isempty(sharedSequence) || ~isfield(sharedSequence, 'Item_1')
    metadataStruct = perFrameSequence;
    return
elseif isempty(perFrameSequence)
    metadataStruct = sharedSequence;
    return
end

% Loop through each item in the per-frame functional group sequence and add
% any values from the shared functional group sequence, which should only
% have one item. Fields should not be shared in both the per-frame and
% shared functional group sequences. (See PS3.3 Table C.7.6.16-1)
noncompliant = false;
itemFieldnames = fieldnames(perFrameSequence);
subfieldsToProcess = {'PixelMeasuresSequence', 'PlanePositionSequence', 'PlaneOrientationSequence'};

for itemIdx = 1:numel(itemFieldnames)
    for fieldIdx = 1:numel(subfieldsToProcess)
        thisField = subfieldsToProcess{fieldIdx};
        if isfield(sharedSequence.Item_1, thisField)
            if ~isfield(perFrameSequence.(itemFieldnames{itemIdx}), thisField)
                % Only add. Do not replace.
                perFrameSequence.(itemFieldnames{itemIdx}).(thisField) = ...
                    sharedSequence.Item_1.(thisField);
            else
                noncompliant = true;
            end
        end
    end
end

metadataStruct = perFrameSequence;

if noncompliant
    warning(message('images:dicomread:conflictingFunctionalGroupsMetadata'))
end

end


function details = incorporateSharedSequence(sharedSequence, details)

try
    details.PixelSpacings = sharedSequence.Item_1.PixelMeasuresSequence.Item_1.PixelSpacing;
catch
end
end
