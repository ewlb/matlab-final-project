function [seriesFilenames, spatialDetails, sliceDim, seriesFileObjects] = getSeriesDetails(allFilenames, allFileObjects)
%getSeriesDetails  Load filenames, spatial details and DICOMFiles for a set of DICOM files.

% Copyright 2016-2023 The MathWorks, Inc.

if ischar(allFilenames)
    allFilenames = {allFilenames};
end

numFiles = numel(allFilenames);

% Handle the case where only one file is part of the series. By definition,
% it will be its own series and all of the orientation data will match (but
% maybe found in a different set of attributes.)
if numFiles == 1
    filename = allFilenames{1};

    % If an existing DICOMFile object was passed in, reuse it. Otherwise
    % open a new instance.
    if (nargin == 2)
        d = allFileObjects(1);
    else
        try
            d = images.internal.dicom.DICOMFile(filename);
        catch
            error(message('images:dicomread:loadFile', filename))
        end
    end

    numFrames = d.getAttribute(0x0028,0x0008);
    if isempty(numFrames) || (numFrames < 2)
        error(message('images:dicomread:notEnoughSlices'))
    end

    spatialDetails = images.internal.dicom.getSpatialDetailsForMultiframe(d);

    if (isempty(spatialDetails.PatientPositions))
        throwMissingMultiframeAttributes(filename)
    end

    seriesFilenames = allFilenames;
    if (nargin == 2)
        seriesFileObjects = allFileObjects;
    else
        seriesFileObjects = d;
    end
    sliceDim = images.internal.dicom.findSortDimension(spatialDetails.PatientPositions);
    return
end

% From here on, handle multiple files in the same directory. Find out if
% they're related and get the spatial orientation information.
allPatientPositions = zeros(numFiles, 3);
allPixelSpacings = zeros(numFiles, 2);
allPatientOrientations = zeros(2, 3, numFiles);
sliceDim = [];

if isempty(allFilenames)
    error(message('images:dicomread:noSuccessfulReads'))
end

partOfSeries = false(numFiles, 1);
previousSeriesInstanceUID = '';
previousPatientOrientation = [];

firstFilename = allFilenames{1};

if nargin < 2
    % If allFileObjects was not passed in, don't assume that file is DICOM
    % and use a separate counter decoupled from the filenames to store the
    % DICOMFile objects.
    allFileCounter = 0;
end

for idx = 1:numel(allFilenames)
    filename = allFilenames{idx};

    if (nargin == 2)
        assert(numel(allFileObjects)==1)
        d = allFileObjects{1}(idx);
    else
        try
            d = images.internal.dicom.DICOMFile(filename);
            allFileCounter = allFileCounter + 1;
            allFileObjects(allFileCounter) = d; 
        catch
            if isdicom(filename)
                error(message('images:dicomread:loadFile', filename))
            else
                partOfSeries(idx) = false;
                continue
            end
        end
    end

    try
        allPatientPositions(idx, :) = d.getAttribute(0x0020,0x0032);
    catch
        throwMissingPatientPosition(filename);
    end
    
    thisPatientOrientation = d.getAttribute(0x0020,0x0037);
    if isempty(thisPatientOrientation)
        throwMissingOrientation(filename);
    end
    
    try
        allPixelSpacings(idx, :) = d.getAttribute(0x0028,0x0030);
    catch
        throwMissingPixelSpacing(filename);
    end
    
    thisSeriesInstanceUID = d.getAttribute(0x0020,0x000E);
    
    partOfSeries(idx) = true;
    
    if isempty(previousSeriesInstanceUID)
        previousSeriesInstanceUID = thisSeriesInstanceUID;
    elseif ~isequal(previousSeriesInstanceUID, thisSeriesInstanceUID)
        error(message('images:dicomread:multipleSeries', ...
            firstFilename, filename))
    end
    
    if isempty(previousPatientOrientation)
        previousPatientOrientation = thisPatientOrientation;
    elseif ~isequal(previousPatientOrientation, thisPatientOrientation)
        error(message('images:dicomread:differentPatientOrientations'))
    end
    
    if ~isempty(thisPatientOrientation)
        allPatientOrientations(:, :, idx) = reshape(thisPatientOrientation, [3 2])';
    end
end

allPatientPositions = allPatientPositions(partOfSeries,:);
allPixelSpacings = allPixelSpacings(partOfSeries,:);

seriesFilenames = allFilenames(partOfSeries);

if (nargin == 2)
    assert(numel(allFileObjects)==1)
    seriesFileObjects = allFileObjects{1}(partOfSeries);
else
    seriesFileObjects = [];
end

if isempty(seriesFilenames)
    error(message('images:dicomread:noSuccessfulReads'))
else
    [seriesFilenames, allPatientPositions, allPixelSpacings, allPatientOrientations, sliceDim, seriesFileObjects] = sortSlices(seriesFilenames, allPatientPositions, allPixelSpacings, allPatientOrientations, seriesFileObjects);
end

spatialDetails.PatientPositions = allPatientPositions;
spatialDetails.PixelSpacings = allPixelSpacings;
spatialDetails.PatientOrientations = allPatientOrientations;

end


function [seriesFilenames, allPatientPositions, allPixelSpacings, allPatientOrientations, sortDim, seriesFileObjects] = sortSlices(seriesFilenames, allPatientPositions, allPixelSpacings, allPatientOrientations, seriesFileObjects)

sortDim = images.internal.dicom.findSortDimension(allPatientPositions);
[~, sortIdx] = sort(allPatientPositions(:,sortDim));

seriesFilenames = seriesFilenames(sortIdx);
allPatientPositions = allPatientPositions(sortIdx,:);
allPixelSpacings = allPixelSpacings(sortIdx,:);
allPatientOrientations = allPatientOrientations(:,:,sortIdx);

if ~isempty(seriesFileObjects)
    seriesFileObjects = seriesFileObjects(sortIdx);
end

end

function throwMissingMultiframeAttributes(filename)

msg = message('images:dicomread:missingMultiframeAttributes', filename);
ex = MException('images:dicomread:missingMultiframeAttributes', ...
    strrep(msg.getString(), '\', '\\'));
throw(ex)

end


function throwMissingPatientPosition(filename)

msg = message('images:dicomread:missingPatientPositions', filename);
ex = MException('images:dicomread:missingPatientPositions', ...
    strrep(msg.getString(), '\', '\\'));
throw(ex)

end


function throwMissingOrientation(filename)
msg = message('images:dicomread:missingPatientOrientations', filename);
ex = MException('images:dicomread:missingPatientOrientations', ...
    strrep(msg.getString(), '\', '\\'));
throw(ex)

end


function throwMissingPixelSpacing(filename)
msg = message('images:dicomread:missingPixelSpacing', filename);
ex = MException('images:dicomread:missingPixelSpacing', ...
    strrep(msg.getString(), '\', '\\'));
throw(ex)

end
