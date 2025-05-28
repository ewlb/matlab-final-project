function detailsTable = dicomCollection(source, varargin)

source = matlab.images.internal.stringToChar(source);
parser = inputParser();
parser.addRequired('source', @sourceValidator)
parser.addParameter('IncludeSubfolders', true, @recursiveValidator)
parser.FunctionName = mfilename;
parser.parse(source, varargin{:});

recursive = parser.Results.IncludeSubfolders;

% Disable DICOM-related warnings.
origWarnState = warning;
warnCleaner = onCleanup(@() warning(origWarnState));
images.internal.app.dicom.disableDICOMWarnings()

% Create the table...
loader = images.internal.dicom.CollectionLoader(source, recursive);
detailsTable = loader.Collection;
if isempty(detailsTable)
    return
end

% Make the table more friendly.
detailsTable = convertCharToString(detailsTable);
detailsTable = addRowNames(detailsTable);
detailsTable = sortFilenames(detailsTable);

if any(string(detailsTable.Properties.VariableNames) == "DICOMFiles")
    detailsTable = removevars(detailsTable, 'DICOMFiles');
end

end


function tf = sourceValidator(source)

validateattributes(source, {'char', 'string'}, {'row', 'nonempty'}, mfilename, 'SOURCE', 1)

tf = true;

end


function tf = recursiveValidator(value)

validateattributes(value, {'logical', 'numeric'}, {'scalar'}, mfilename, 'IncludeSubfolders')

tf = true;

end


function detailsTable = convertCharToString(detailsTable)

detailsTable.PatientName = string(detailsTable.PatientName);
detailsTable.PatientSex = string(detailsTable.PatientSex);
detailsTable.Modality = string(detailsTable.Modality);
detailsTable.StudyDescription = string(detailsTable.StudyDescription);
detailsTable.SeriesDescription = string(detailsTable.SeriesDescription);
detailsTable.StudyInstanceUID = string(detailsTable.StudyInstanceUID);
detailsTable.SeriesInstanceUID = string(detailsTable.SeriesInstanceUID);

end


function detailsTable = addRowNames(detailsTable)

numRows = size(detailsTable,1);
rowNames = cell(numRows,1);
for idx = 1:numRows
    rowNames{idx} = sprintf('s%d', idx);
end
detailsTable.Properties.RowNames = rowNames;

end


function detailsTable = sortFilenames(detailsTable)

numRows = size(detailsTable,1);
for idx = 1:numRows
    filenames = detailsTable.Filenames{idx};
    
    if any(ismember(detailsTable.Properties.VariableNames, "DICOMFiles"))
        fileObjects = detailsTable.DICOMFiles(idx);
        try
            sortedFilenames = images.internal.dicom.getSeriesDetails(filenames, fileObjects);
            detailsTable.Filenames{idx} = sortedFilenames;
        catch
        end
    else
        try
            sortedFilenames = images.internal.dicom.getSeriesDetails(filenames);
            detailsTable.Filenames{idx} = sortedFilenames;
        catch
        end
    end
end
end

% Copyright 2016-2022 The MathWorks, Inc.