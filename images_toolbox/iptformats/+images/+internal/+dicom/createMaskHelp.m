function BW = createMaskHelp(rtContours, ROIINDEX, spatial)
% createMask creates a volumetric mask from dicomContours object
% 
% BW = createMaskHelp(rtContours, ROIINDEX, spatial) constructs a 3D voxel representation 
% of the specified ROI, ROIINDEX, in the dicomContours object, "rtContours", as a 3 
% dimensional logical mask, "BW". rtContours is a dicomContours object, contourIndex is an numerical 
% value, character, or string which specifies which contour in "rtContours" is to be densified.
% The contour data is in a world coordinate system; however, the mask is created in the 
% intrinsic image space defined by spatial.
%
% Example 1: Using 'dicomInfo' and imref3d to create mask of 'dicomContours' object.
% -------
% 
% Read metadata of DICOM-RT Structure Set
% info = dicominfo('rtstruct.dcm');
%  
% % Construct dicomContours object
% rtContours = dicomContours(info);
%  
% % Display all ROIs information as a table
% rtContours.ROIs
%  
% % Plot contours of all ROIs. This will plot the contours in world
% % coordinates. The boundaries of this plot can be used to define a world
% % coordinate limits boundaries for an imref3d object to create a dense mask within
% plotContour(rtContours)
% 
% % Construct dicomContours object
% rtContours = dicomContours(info);
% 
% % Create imref3d object with same world limits as plot from 'plotContours'
% % so that the image is in the same space as the contours
% spatial = imref3d([128, 128, 50], [-200 300], [-200 200], [-700 -200]);
% 
% % We will take the first contour ('Body_Contour')in the list of contours within rtContours.
% contourIndex = 1;
% 
% % Create 3-D logical mask using the imref3d objects and the contourIndex
% rtMask = createMask(rtContours, contourIndex, spatial);
% 
% % View this mask in using Volume Viewer
% volshow(rtMask);
%
% 
% See also dicominfo, dicomContours, dicomreadVolume, imref3d

% Copyright 2020-2021 The MathWorks, Inc.

% Display all ROIs information as a table
roiTable = rtContours.ROIs;

%gets the index of the contour which we wish to densify (specified by the
%ROIINDEX variable
idx = getIDX(roiTable, ROIINDEX);

%Grab the correct contour data
dataToMask = roiTable.ContourData{idx};

%if spatial is an imref3d, check to make sure and then set transformObject to it   
if (isa(spatial, 'imref3d'))
    
    % Saving size variable for code cleanliness
    % Gives dimensions of image
    size = spatial.ImageSize;
    
    % transformObject will be the imref3d object used to perform the
    % transform from the patient (world) space into the image (intrinsic) space
    transformObject = spatial;
    
    % In the case of an 'imref3d' object being passed in, there is no
    % rotation... not supported by 'imref3d'.
    rotMatrix = [1 0; 0 1];

% If spatial is not an imref3d object, need to creat one and create a rotation
% matrix for the require transformation
elseif (isfield(spatial, 'PatientPositions') && ...
    isfield(spatial, 'PixelSpacings') && ...
    isfield(spatial, 'PatientOrientations') && ...
    isfield(spatial, 'ImageSize'))

        % Saving size variable for code cleanliness 
        % Gives dimensions of image
        size = spatial.ImageSize;

        % Gives x,y,z dimensions of pixel in world coordinates
        PixSpacings = [spatial.PixelSpacings(1,1), spatial.PixelSpacings(1,2), ...
            abs(spatial.PatientPositions(2,3) - spatial.PatientPositions(1,3))];

        % Gives origin of image (x, y, z) in world coordinates. 
        PatPosition = spatial.PatientPositions(1,:);

        % Check to see if there is rotation in of the z-axis. If there is,
        % error out
        if(find(spatial.PatientOrientations(:,3)))
            error(message('images:dicomContours:zRotationFound'));
        end

        % Pretty certain that this is correct and that it is not necessary to
        % take the transpose, but have to VALIDATE THIS!!!
        PatOrientation = spatial.PatientOrientations(1:2, 1:2, 1);
        
        % Rotation matrix used for rotation of the x y plane about the z
        % axis. 
        rotMatrix = [PatOrientation(1,1) PatOrientation(1,2) * PixSpacings(2)/PixSpacings(1) ;
             PatOrientation(2,1)*PixSpacings(1)/PixSpacings(2) PatOrientation(2,2)];
        
        % Because we are going from world to intrinsic, we take the inverse
        % of the rotation matrix.
        rotMatrix = inv(rotMatrix);

        % Create transformObject (imref3d object for transformation)
        transformObject = imref3d(size, PixSpacings(1), PixSpacings(2), PixSpacings(3));

        %Set the X, Y, and Z world limits based on patient position
        transformObject.XWorldLimits = transformObject.XWorldLimits + PatPosition(1) - .5;
        transformObject.YWorldLimits = transformObject.YWorldLimits + PatPosition(2) - .5;
        transformObject.ZWorldLimits = transformObject.ZWorldLimits + PatPosition(3) - .5;
else

        error(message('images:dicomContours:invalidImageInfo'));

end

% Checks to see if contours are of geometric type CLOSED_PLANAR, removes
% contours that are not of this type, and gives warning stating the number
% of contours that have been removed. 
[numNonPlanar, dataToMask] = planarCheck(dataToMask, roiTable.GeometricType{idx});

% If contours removed is greater than 0, we create a warning that states
% how many have been removed.
if numNonPlanar > 0
    
    
    warning(message('images:dicomContours:incorrectGeometricType', num2str(numNonPlanar)));
    
    
end

% Now we use the transformObject to convert the data to the world
% coordinates:
[minX, maxX, minY, maxY, minZ, maxZ, dataToMask] = convertData(dataToMask, transformObject, rotMatrix);

if (minX > size(1) ||...
    minY > size(2) ||...
    maxX < 1 || maxY < 1 || isnan(maxX) || isnan(maxY) || isnan(maxZ))
    BW = false(size(1), size(2),size(3));
    
else
    BW = maskDensify(dataToMask, size(1), size(2), size(3),...
        minX, maxX, minY, maxY, minZ, maxZ);
end

end


%%Function to get the index of the contour we want

function idx = getIDX(roiTable, ROIINDEX)

    % Get contourNames
    contourNames = roiTable.Name;

    %Make Certain ROIINDEX chooses a specific ROI
    %Check if Numeric.. if numeric check if contained in numbers
    if isnumeric(ROIINDEX) && ROIINDEX > 0 && any(ismember(roiTable.Number, ROIINDEX))

        idx = find(ismember(roiTable.Number, ROIINDEX), 1);

    %If not numeric check if it's a string or character array and if it is
    %contained in 'contourNames'
    elseif (ischar(ROIINDEX) || isstring(ROIINDEX))  && any(ismember(contourNames, ROIINDEX))
        idx = find(ismember(roiTable.Name, ROIINDEX), 1);
    else        
        error(message('images:dicomContours:IncorrectIndex'));
    end

end


%Function used to convert data from patient space to the voxel space
function [minX, maxX, minY, maxY, minZ, maxZ, dataToMask] = convertData(dataToMask, transformObject, rotMatrix)


%Create min/max for x, y, z so that we can create a mask of the same size
%as the ROI first. 
minX = NaN;
maxX = NaN;
minY = NaN;
maxY = NaN;
minZ = NaN;
maxZ = NaN;

% Create BW with imageSize of imref3d object
% BW = false(size);

% Determine which slices fall within the z range of the image
% inImage = false(numel(dataToMask), 1);

% Use imref3d object to manipulate contour data into image plane
for contour = 1:numel(dataToMask)
    
    % Use 'worldToIntrinsic' to transform contour data into Voxel Space
    [dataToMask{contour}(:, 1), dataToMask{contour}(:, 2), dataToMask{contour}(:,3)] = ...
        (worldToIntrinsic(transformObject, dataToMask{contour}(:, 1), dataToMask{contour}(:, 2), ...
        dataToMask{contour}(:,3)));
    
    
    % Perform the necessary rotation to the contour data one contour at a
    % time by multiplying each contour by the rotation matrix:
    rotated = rotMatrix * [dataToMask{contour}(:, 1), dataToMask{contour}(:, 2)]';
    rotated = rotated';
    dataToMask{contour}(:, 1) = rotated(:,1);
    dataToMask{contour}(:, 2) = rotated(:, 2);

    % Round the z values so that they correspond with a specific slice of
    % the image data
    dataToMask{contour}(:,3) = ceil(dataToMask{contour}(:,3));
    
    %update min and max of x y and z
    minX = min(min(dataToMask{contour}(:,1)), minX);
    maxX = max(max(dataToMask{contour}(:,1)), maxX);
    minY = min(min(dataToMask{contour}(:,2)), minY);
    maxY = max(max(dataToMask{contour}(:,2)), maxY);
    %The z values for a contour slice are expected to be the same
    minZ = min(dataToMask{contour}(1,3), minZ);
    maxZ = max(dataToMask{contour}(1,3), maxZ);
        
end

% Convert min and max to integer values to be used when creating the ROI mask.
% This could cause mask to be off by 1 pixel from expected (shifting by
% rounded minima rather than actual in masking function). Ceiling used for
% max and floor used for min in order to make sure ROI is contained within
% mask
minX = floor(minX);
minY = floor(minY);
minZ = floor(minZ);
maxX = ceil(maxX);
maxY = ceil(maxY);
maxZ = ceil(maxZ);

end


% This function will create the logical mask of the region within the
% boundaries of the image.
function denseFinal = maskDensify(contourData1, imFirstDim, imSecondDim, imThirdDim, minX, maxX, minY, maxY, minZ, maxZ)

% denseFinal is initially a mask of the same size of the image but all
% false
denseFinal = false(imFirstDim, imSecondDim, imThirdDim);

% Used to create mask only within boundaries of ROI. Y used first because
% that is the number of rows, which corresponds to y-direction in poly2mask
denseMat = false(maxY - minY + 1, maxX - minX + 1, maxZ - minZ + 1);

% used to determine which image slices have masks within them in order to
% determine which slices must be used for interpolation.
checker = false((maxZ - minZ + 1), 1);

% Create interpolant for interpolating between image slices with masks (in
% order to get completely dense ROI without image slices missing.
% interpolation object found at: 
% images/imuitools/+images/+internal/+app/+utilities/Interpolation

interp = images.internal.app.utilities.Interpolation;
interp.Downsample = false;

%To be used for interpolation
    interpolatedMask = 0;

    function maskCallback(s,evtData)
        interpolatedMask = evtData.Mask;
    end

%Upon each interpolation we update interpolated mask variable
addlistener(interp,'InterpolationCompleted', @maskCallback);

%Create mask of each contour, also record which layers in the image have a
%mask created on them for interpolation later (filling in checker)
for contourIDX = 1:size(contourData1,1)
    
    %pull contour information from contourData1, scale to bounds of ROI by
    %subtracting minX, minY, minZ, subtract one because index starts at
    %(1,1,1) while origin of world and intrinsic coordinates starts at
    %(0,0,0)
    contour = contourData1{contourIDX} - [minX - 1, minY - 1, minZ - 1];
    
    %Determine which image layer the mask of the contour will be created in
    index =  floor(contour(1,3));
    
    %Create the mask and add it to the determined layer
    denseMat(:,:, index) = denseMat(:,:, index) | poly2mask(contour(:,1), contour(:,2), maxY - minY + 1, maxX - minX + 1);
    
    %Record that the layer at 'index' has a mask created in it
    checker(index, 1) = true;

end

% idxBegin and idxEnd are used to loop through the contours and perform
% interpolation wherever needed.
idxBegin = find(checker~=0, 1, 'first');

idxEnd = find(checker~=0, 1, 'last');

if(~isempty(idxBegin))
    

    % Go layer by layer, and interpolate layers that are missng, starting at 1
    for layer = idxBegin:idxEnd
        %set initial index to interpolate from
        initialIndex = layer;

        %Set variable index to find final layer to interpolate to
        index = layer;


        if layer ~= idxBegin
            if ~checker(layer-1,1) && checker(layer, 1)
                index = index - 1;
                while index > 0 && ~checker(index)
                    index = index - 1;
                end
                
                sz = [maxY - minY + 1, maxX - minX + 1];
                
                %This will get the unit vertices of the ROIs used for
                %interpolation:
                pos1 = images.internal.builtins.bwborders(bwlabel(denseMat(:,:,initialIndex), 4), 4);
                %ROI1 = fliplr(pos1{1});
                pos2 = images.internal.builtins.bwborders(bwlabel(denseMat(:,:,index), 4), 4);
                
            %We want to interpolate from the slice with the smallest amount
            %of masks (slice_low)... will take each mask in slice_low and:
            %1. use find MinEuclid to get the closest mask in the second
            %slice (slice_high)
            %2. interpolate between the mask in slice_low and best fit in
            %slice_high
            if numel(pos1) < numel(pos2)
                %ROI2 = fliplr(pos2{1});
                for regionIDX = 1:numel(pos1)
                    %interpolate the masks between the known masks:
                    ROI1 = (pos1{regionIDX});
                    roi2IDX = findMinEuclid(ROI1, pos2);
                    ROI2 = fliplr(pos2{roi2IDX});
                    ROI1 = fliplr(pos1{regionIDX});
                    interp.interpolate(ROI1, ROI2, 1, initialIndex, index, 3, sz);
                    denseMat(:,:, (index + 1):(initialIndex - 1)) = denseMat(:,:, (index + 1):(initialIndex - 1)) | interpolatedMask;% repmat(denseMat(:,:,index), 1, 1, initialIndex - index - 1);
                end
            
            else
                %ROI2 = fliplr(pos2{1});
                for regionIDX = 1:numel(pos2)
                    %interpolate the masks between the known masks:
                    ROI1 = (pos2{regionIDX});
                    roi2IDX = findMinEuclid(ROI1, pos1);
                    ROI2 = fliplr(pos1{roi2IDX});
                    ROI1 = fliplr(pos2{regionIDX});
                    interp.interpolate(ROI1, ROI2, 1, index, initialIndex, 3, sz);
                    denseMat(:,:, (index + 1):(initialIndex - 1)) = denseMat(:,:, (index + 1):(initialIndex - 1)) | interpolatedMask;% repmat(denseMat(:,:,index), 1, 1, initialIndex - index - 1);
                end
            end
            
            end %end if ~checker

        end %end if layer

    end %end for
    
end %endif

% Assign the constructed dense mask volume in denseMat to denseFinal. 
% Y is used first because that is the number of rows (i.e. first dimension
% of the image, imFirstDim), which corresponds to y-direction.
denseFinal(max(1,minY):min(imFirstDim, maxY), ...
    max(1,minX):min(imSecondDim, maxX), ...
    max(1,minZ):min(imThirdDim, maxZ)) = ...
    ...
    denseMat((max(1,minY):min(imFirstDim, maxY)) - minY + 1, ...
    (max(1,minX):min(imSecondDim, maxX)) - minX + 1, ...
    (max(1,minZ):min(imThirdDim, maxZ)) - minZ + 1);

end

%%This Function will check to see if the contours are of CLOSED_PLANAR
%%geometric type. It will return all contours of this type and will also
%%state if any were found to not be CLOSED_PLANAR
function [numNonPlanar, contours] = planarCheck(contours, geoTypes)

%If we are given the geometric types, then we can just check that they are
%all stated to be 'CLOSED_PLANAR'
if numel(geoTypes) == numel(contours) && false
    correctType = strcmp('CLOSED_PLANAR', geoTypes);
    contours = contours(correctType);
    numNonPlanar = sum(~correctType);

    %If not, we must go through each contour and make sure that the z
    %values are all the same within a error of .00001 (because of issues
    %with comparing floating point numbers.
else
    correctType = false(numel(contours), 1);
    for idx = 1:numel(contours)
        toCheck = contours{idx}(:,3);
        test = (toCheck - toCheck(1) < .00001);
        if (all(test))
            correctType(idx) = 1;
        end
        
    end
    contours = contours(correctType);
    numNonPlanar = sum(~correctType);
    
end
end

%This test will determine which index to go to. 
function index = findMinEuclid(initialPoint, positions)
    %get bounds of each portion
    %get euclidean distance from 
    centroid = mean(initialPoint);
    minEuclid = inf;
    index = NaN;
    for tempIDX = 1:numel(positions)
        tempPoint = positions{tempIDX};
        tempCentroid = mean(tempPoint);
        euclid = sum((centroid - tempCentroid).^2);
        
        if euclid < minEuclid
            index = tempIDX;
            minEuclid = euclid;
        end
    end
end