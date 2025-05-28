function [V, spatialInfo, sliceDim] = dicomreadVolume(inputSource, varargin)

narginchk(1,4)
validateattributes(inputSource, {'string', 'char', 'table', 'cell'}, {'nonempty'});

% Obtain the parsing arguments.
[rows, isIsotropic] = parseInputs(istable(inputSource), varargin{:});

% Expected only 2 arguments when input source is string, char, or cell array.
if ischar(inputSource)
    filenames = getFilenames(inputSource);
elseif iscellstr(inputSource)
    filenames = inputSource;
elseif isstring(inputSource)
    if isscalar(inputSource)
        filenames = getFilenames(matlab.images.internal.stringToChar(inputSource));
    else
        filenames = cellstr(inputSource);
    end
elseif istable(inputSource)
    switch nargin
        case 1
            % Input source with single row with false isotropy.
            filenames = getFilenamesFromTable(inputSource);
        case 2
            if (ischar(rows) || isstring(rows))
                % Default isotropy is false.
                filenames = getFilenamesFromTable(inputSource, rows);
            end
        case 3
            % Input source with single row with true isotropy.
            filenames = getFilenamesFromTable(inputSource);
        case 4
            % When input source is table with multiple rows.
            filenames = getFilenamesFromTable(inputSource, rows);
    end
end

% Get the details of slices from metadata.
[seriesFilenames, spatialInfo, sliceDim] = images.internal.dicom.getSeriesDetails(filenames);

% Make volume isotropic.
if logical(isIsotropic)
    V = makeIsotropicVolume(seriesFilenames, spatialInfo);
else
    % Create a volume from given slices.
    if isscalar(seriesFilenames)
        V = dicomread(seriesFilenames{1});
    else
        V = images.internal.dicom.loadImagesByFilename(seriesFilenames);
    end
    
end

%This field gives the size of the 3D iamge being created. (Necessary for
%dicomContours.createMask(...) method. 
spatialInfo.ImageSize = size(V, 1, 2, 4);

end


function X = makeIsotropicVolume(seriesFilenames, spatialInfo)

% Get the information about the slice.
im = dicomread(seriesFilenames{1});

% Check the input size of the slice.
if isscalar(im)
    error(message('images:dicomread:invalidImageSize'));
end

imSize = size(im);
imInfo = dicominfo(seriesFilenames{1});

if numel(imSize) == 2
    imSize(3) = 1;
end

% Check spacing between slice field is available or not.
if ~isfield(imInfo,'SpacingBetweenSlices')
    error(message('images:dicomread:missingSpacingBetweenSlices'));
end

% Find the x, y and z spacing to make volume isotropic.
minSpacing = min(spatialInfo.PixelSpacings(1,1),spatialInfo.PixelSpacings(1,2));
xyzSpacing = [spatialInfo.PixelSpacings(1,2)/minSpacing ...
    spatialInfo.PixelSpacings(1,1)/minSpacing imInfo.SpacingBetweenSlices/minSpacing];

% Get the maximum distance between first and last slice. Maximum distance
% divided by pixel spacing gives number of extra pixels requires
% to make a volume.
extraPixelsInXdir = max(spatialInfo.PatientPositions(:,1)) - min(spatialInfo.PatientPositions(:,1));
extraPixelsInYdir = max(spatialInfo.PatientPositions(:,2)) - min(spatialInfo.PatientPositions(:,2));
extraPixels = ceil(abs(([extraPixelsInXdir extraPixelsInYdir]./spatialInfo.PixelSpacings(1,:)).*xyzSpacing(1:2)));

% Add those extra calculated pixels to size of the input slice. New volume
% with fill value zero.
X = zeros(imSize(1)+extraPixels(1), imSize(2)+extraPixels(2), imSize(3),'like',im);

% Create a meshgrid for real world points.
[xGrid, yGrid] = meshgrid(0:imSize(2)-1, 0:imSize(1)-1);
movingImgPosition = spatialInfo.PatientPositions(1,:);
refImgPosition = movingImgPosition;

% mm per voxel in x, y and z directions.
mmPerVoxel = [spatialInfo.PixelSpacings(1,2) spatialInfo.PixelSpacings(1,1) imInfo.SpacingBetweenSlices];

% Since orientation for all the slices are same.
sliceOrientations = spatialInfo.PatientOrientations(:,:,1);
sliceCount = 1;
movingSliceTform = eye(4);
xStart = 1;
yStart = 1;


% Find the z directional cosine when input is 4D volume
dircosZ = ((refImgPosition - spatialInfo.PatientPositions(end,:))./  ...
    size(spatialInfo.PatientOrientations,3))./imInfo.SpacingBetweenSlices;

for sliceNum = 2:size(spatialInfo.PatientOrientations,3)
    
    if numel(imSize) ~= 4
        validateattributes(dicomread(seriesFilenames{sliceNum}),...
            {'numeric'},...
            {'nonempty','size', imSize}, mfilename, 'Image', sliceNum);
        
        % Read the slice
        slice = dicomread(seriesFilenames{sliceNum-1});
    end
    
    nextSliceCoordinates = spatialInfo.PatientPositions(sliceNum,:);
    
    % Get tform matrix and 3D points.
    [imtoXYZ, realWorldPoints] = slicePointsToWorldCoords(mmPerVoxel, sliceOrientations, ...
        nextSliceCoordinates, xGrid, yGrid, numel(imSize), dircosZ);
    
    % Estimate the intermediate points between two consecutive slices.
    linspacedPoints = linspace(0,1,ceil(xyzSpacing(3)))';
    intermediatePoints = (1-linspacedPoints).*movingImgPosition + linspacedPoints.*nextSliceCoordinates;

    % Interpolate the intermediate slices based on intermediate points.
    for imgCount = size(intermediatePoints,1):-1:1
        
        % Estimate the expected position of the slice in a volume.
        pointLoc = round(abs((refImgPosition(1:2) - ...
            intermediatePoints(end-imgCount+1,1:2))./mmPerVoxel(1:2)) .* xyzSpacing(1:2));
        
        xEnd = pointLoc(1);
        yEnd = pointLoc(2);
        % Get the intermediate tform.
        movingSliceTform(1:3,4) = (movingImgPosition - nextSliceCoordinates)*linspacedPoints(imgCount);
        tform = movingSliceTform*imtoXYZ;
        
        % Get the intermediate 3D points.
        newPts = tform\realWorldPoints;
        
        if numel(imSize) == 4
            % Interpolate the intermediate slices and make volume isotropic.
            X(xStart+xEnd:imSize(1)+xEnd,yStart+yEnd:imSize(2)+yEnd,:,sliceCount) = ...
                interpolateSlice(im(:,:,:,sliceNum-1), newPts, imSize);
        else
            
            X(xStart+xEnd:imSize(1)+xEnd,yStart+yEnd:imSize(2)+yEnd,:,sliceCount) = ...
                interpolateSlice(slice, newPts, imSize);
        end
        
        % Increase the count to store the intermediate slices.
        sliceCount = sliceCount+1;
    end
    
    movingImgPosition = nextSliceCoordinates;
end
end


function paralleledImg = interpolateSlice(slices, newPts, imSize)
% Interpolate the new slices between two adjacent slices.

% Expected new points in image plane starts from one.
xAxis = newPts(1,:)'+1;
yAxis = newPts(2,:)'+1;
xx = reshape(xAxis,[imSize(1) imSize(2)]);
yy = reshape(yAxis,[imSize(1) imSize(2)]);

% Interpolate the slice based on estimated new points
if imSize(3) == 1
   
   % Gray scaled image.
   % halide call
   paralleledImg = images.internal.builtins.bilinearInterp_halide(slices,xx,yy);
 
else
    % Color channeled image.
    for sliceChannels = 1:3
        paralleledImg(:,:,1) = images.internal.builtins.bilinearInterp_halide(slices(:,:,1),xx,yy);
        paralleledImg(:,:,2) = images.internal.builtins.bilinearInterp_halide(slices(:,:,2),xx,yy);
        paralleledImg(:,:,3) = images.internal.builtins.bilinearInterp_halide(slices(:,:,3),xx,yy);
        
    end
end
end


function [imtoXYZ, realWorldCoordinates] = slicePointsToWorldCoords(mmperVoxel, ...
    imgOrientations, imgCoordinates, X, Y, isVolume, zdir)
% Compute transformation matrix between realworld points and 2D plane.

% Image orientation patient (IOP)
rowIOP = imgOrientations(1,:); % Row direction cosine
colIOP = imgOrientations(2,:); % Column direction cosine

if (isVolume ==4)
    % When input is having multiple slices (volume), z directional cosine
    % formula will be different.
    dircosZ = zdir;
else
    % Find the normal between rowIOP and colIOP to find the rotations.
    dircosZ = cross(rowIOP, colIOP);
end
xyDirectionalCosine = [rowIOP(1) colIOP(1);rowIOP(2) colIOP(2);rowIOP(3) colIOP(3)];

imtoXYZ(1:3,1) = xyDirectionalCosine(:,1);
imtoXYZ(1:3,2) = xyDirectionalCosine(:,2);
imtoXYZ(1:3,3) = dircosZ;
imtoXYZ(1:3,4) = imgCoordinates;

% Transformation matrix between image plane and 3D real world points.
imtoXYZ(1:3,1:3) = imtoXYZ(1:3,1:3).*repmat(mmperVoxel,3,1);
imtoXYZ(4,4) = 1;

% Real world coordinates.
realWorldCoordinates = imtoXYZ*[X(:) Y(:) zeros(length(X(:)),1) ones(length(X(:)),1)]';
end


function filenames = getFilenamesFromTable(inputTable, row)

switch nargin
    case 1
        if size(inputTable, 1) == 1
            filenames = inputTable.Filenames{1};
        else
            error(message('images:dicomread:numTableRows'))
        end
    case 2
        row = matlab.images.internal.stringToChar(row);
        validateattributes(row, {'char'}, {'nonempty'})
        rowNames = inputTable.Row;
        if ~isempty(rowNames)
            row = validatestring(row, rowNames);
        else
            error(message('images:dicomread:missingRowNames'))
        end
        
        filenames = inputTable.Filenames{row};
end
end


function filenames = getFilenames(dirName)

detailsStruct = dir(dirName);
if isempty(detailsStruct)
    error(message('images:dicomread:dirNotReadable'))
else
    numberOfResultsFromDir = numel(detailsStruct);
end

isDirectory = [detailsStruct.isdir];
detailsStruct(isDirectory) = [];

if numberOfResultsFromDir == 1 && ~detailsStruct.isdir
    filenames = {dirName};
elseif ~isempty(detailsStruct)
    filenames = {detailsStruct.name};
    for idx = 1:numel(filenames)
        filenames{idx} = fullfile(dirName, filenames{idx});
    end
else
    filenames = {};
end
end


function [rows, isotropic] = parseInputs(isInputTable,varargin)
parser = inputParser;
parser.FunctionName = mfilename;
parser.CaseSensitive = false;
parser.PartialMatching = true;

if (isInputTable == 1)
switch nargin
    case 2
        % First input argument is rows.
        rows = varargin{1};
        parser.addParameter('MakeIsotropic', 0, @checkMakeIsotropic);
        parser.parse(varargin{2:end});
    case 4
        % First input argument is rows.
        % Second argument is NV pair.
        rows = varargin{1};
        parser.addParameter('MakeIsotropic', 0, @checkMakeIsotropic);
        parser.parse(varargin{2:end});
    otherwise
        % If function is having 3 arguments.
        rows = [];
        parser.addParameter('MakeIsotropic', 0, @checkMakeIsotropic);
        parser.parse(varargin{:});
end
   
    isotropic = parser.Results.MakeIsotropic;
else
    % When input source is cell array, string or char.
    parser.addParameter('MakeIsotropic', 0, @checkMakeIsotropic);
    parser.parse(varargin{:});
    % Assuming rows are empty.
    rows = [];
    isotropic = parser.Results.MakeIsotropic;
end
end


function tf = checkMakeIsotropic(MakeIsotropic)
% Validate the input argument NV pair.
validateattributes(MakeIsotropic, ...
    {'numeric','logical'},...
    {'real'},...
    mfilename, 'MakeIsotropic');

tf = true;
end

% Copyright 2016-2024 The MathWorks, Inc.
