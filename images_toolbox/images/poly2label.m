function L = poly2label(roiPositions,roiLabelIDs,sizeOrRef)
%POLY2LABEL Create label matrix from set of ROIs
% 
%   L = POLY2LABEL(ROIPOSITIONS,ROILABELIDS,IMAGESIZE) creates the numeric
%   label matrix L from the regions of interest (ROIs) defined in
%   ROIPOSITIONS. ROIPOSITIONS is a 1-by-P cell array where each element is
%   an S-by-2 coordinate vector of the form of [x1 y1; ...;xs ys]. The x,y
%   pairs define the vertices of the ROI. POLY2LABEL closes the polygons
%   automatically, if the polygon is not already closed.
%
%   ROILABELIDS is a numeric vector, the same length as ROIPOSITIONS, that
%   specifies the labels for each ROI. IMAGESIZE is a two-element vector of
%   the form [m n] that specifies the size of the output label matrix. If
%   you specify size as an m-by-n-by-3 RGB image, POLY2LABEL uses only the
%   first two dimensions. The output L is a matrix of contiguous regions,
%   returned as m-by-n array of nonnegative values. The pixels labeled 0
%   are the background. 
%
%   L = POLY2LABEL(ROIPOSITIONS,ROILABELIDS,R) creates a label matrix,
%   where the spatial referencing object R specifies the coordinate system
%   used by the ROI positions in ROIPOSITIONS. R is an IMREF2D spatial
%   referencing object. The function assumes that the ROI positions are in
%   world limits defined by R. The ImageSize property of R specifies the
%   size of the label matrix L.
%                       
%   Class Support 
%   -------------
%   ROIPOSITIONS is a cell array containing coordinate vectors of one of
%   the following classes: uint8, uint16, uint32, int8, int16, int32,
%   single or double. ROILABELIDS is a numeric vector consisting of labels
%   for the corresponding ROIs in ROIPOSITIONS. The length of the
%   ROILABELIDS vector must equal the length of ROIPOSITIONS.
%
%   The output label matrix L is a numeric matrix of the same numeric type
%   as ROILABELIDS.
%
%   Notes
%   ----- 
%
%   1. When the positions of several ROIs overlap each other, the ROI label
%   with a lower index number in the ROIPOSITIONS cell array overwrites the
%   other ROIs.
%
%   2. The background is labeled as zeros.
%
%   3. POLY2LABEL handles ROIs that partially enclose pixels the same way
%   as POLY2MASK.   
%
%   Example 1
%   ---------
%   % Create a label matrix from a set of labeled ROIs.
%
%    % Display an image
%    figure;
%    I = imread('baby.jpg');
%    imshow(I);
% 
%    % Initialize the ROI position, label ID, and image size variables
%    numPolygon = 3;
%    roiPositions = cell(numPolygon,1);
%    % uint8 datatype is used here for ROILabelID since there are only 2
%    % classes and they can be represented completely using uint8.
%    roilabelID = zeros(numPolygon,1,'uint8');
%    imSize = size(I);
%    
%    % Setting up the data
%    
%    % ROI positions to draw over figure
%    roiPositions{1} = [500 500;250 1300;1000 500];
%    roiPositions{2} = [1500 1100;1500 1400;2000 1400;2000 700];
%    roiPositions{3} = [80 2600;480 2700; 470 3000;100 3000];
%    
%    % Corresponding labels
%    % ROIs with 3 vertices are given a label 1
%    roilabelID(1) = 1;
%    
%    % ROIs with 4 vertices are given a label 2
%    roilabelID(2) = 2;
%    roilabelID(3) = 2;
%    
%    % Draw the 3 polygons on the figure
%    for id = 1:numPolygon
%        drawpolygon('Position',roiPositions{id},'InteractionsAllowed','none');
%    end
% 
%    % Create a label matrix from the ROIs 
%    L = poly2label(roiPositions,roilabelID,imSize);
% 
%    % Display the original image overlaid with the label matrix
%    figure;
%    B = labeloverlay(I,L);
%    imshow(B)
%
%   See also POLY2MASK, DRAWPOLYGON, LABELOVERLAY, ROIPOLY 
 
%   Copyright 2020 The MathWorks, Inc.


arguments    
    roiPositions (:,1) cell {validateCellContents}
    roiLabelIDs (:,1) {validateLabelID,mustBeEqualSize(roiPositions,roiLabelIDs)}
    sizeOrRef {validateSizeOrRef}
end

isSpatialRef = isa(sizeOrRef,'imref2d');

% Image size
if isSpatialRef
   m = sizeOrRef.ImageSize(1);
   n = sizeOrRef.ImageSize(2);  
else
    m = sizeOrRef(1);
    n = sizeOrRef(2);
end
    
% Label matrix
L = zeros(m,n,'like',roiLabelIDs);

% Loop through all the ROIs starting from the bottom of the stack
for idx = numel(roiPositions):-1:1
    
    % Get ROI positions for current ROI
    roiPos = roiPositions{idx};
    % Convert to double for poly2mask
    roiPos = double(roiPos);

    % Get label ID   
    label = roiLabelIDs(idx);
    
    % Convert to intrinsic coordinates for ROIs with spatial referencing
    if isSpatialRef
    [roiPos(:,1), roiPos(:,2)] = worldToIntrinsic(sizeOrRef,roiPos(:,1),roiPos(:,2));   
    end
        
    % Get mask for the particular ROI
    bw = poly2mask(roiPos(:,1),roiPos(:,2),m,n);
    
    % Assign class labels to L
    L(bw) = label;
    
end

end

function validateCellContents(roiPositions)

validateattributes(roiPositions,{'cell'},{'nonempty'});
cellfun(@(roiPositions) validateattributes(roiPositions,...
    images.internal.iptnumerictypes,...
    {'nonempty','ncols',2,'real','finite','nonnan','nonsparse'}),roiPositions);
end

function validateLabelID(roiLabelIDs)

validateattributes(roiLabelIDs, images.internal.iptlogicalnumerictypes,...
    {'nonempty','real','finite','nonnan','nonsparse','nonnegative'});
end

function mustBeEqualSize(roiPositions,roiLabelIDs)

if ~isequal(numel(roiPositions),numel(roiLabelIDs))
    error(message('images:poly2label:sizeMismatchPosLabels'));
end

end

function validateSizeOrRef(sizeOrRef)

if isnumeric(sizeOrRef)
    validateattributes(sizeOrRef,'numeric',{...
        'nonnan','finite','nonsparse','real','nonzero','nonnegative'});
    if(numel(sizeOrRef)~= 2 && numel(sizeOrRef) ~= 3)
        error(message('images:poly2label:sizeOrRefSizeInvalid'));
    end 
elseif isa(sizeOrRef,'imref2d')
    validateattributes(sizeOrRef,'imref2d',{'scalar'})
else
    error(message('images:poly2label:inputnotsizeOrRef'));
end

end
