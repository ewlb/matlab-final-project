function bout = polyToBlockedImage(roiPositions,roiLabelIDs,imageSize,options)

%polyToBlockedImage Create labeled blockedImage from set of ROIs
%   BOUT = polyToBlockedImage(ROIPOSITIONS,ROILABELIDS,IMAGESIZE) creates a
%   numeric labeled 2-D blockedImage BOUT from the regions of interest
%   (ROIs) defined in ROIPOSITIONS. ROIPOSITIONS is a P-element cell array
%   where each element is an S-by-2 coordinate vector of the form [x1 y1;
%   ...;xs ys], where s is the total number of vertices for that ROI. The
%   x,y pairs define the vertices of the ROI. polyToBlockedImage closes the
%   polygons if the polygons are not already closed.
%
%   ROILABELIDS is a numeric or logical vector, of the same length as
%   ROIPOSITIONS, that specifies the labels for each ROI. IMAGESIZE is a
%   two-element vector of the form [m n] that specifies the first two
%   spatial dimensions, row and column, of the resultant blockedImage. If
%   more than two dimensions are provided, polyToBlockedImage considers the
%   first two dimensions. The output BOUT is a numeric labeled
%   blockedImage. The values in BOUT are populated based on the values in
%   ROILABELIDs. The background label is 0.
%
%   BOUT = polyToBlockedImage(___, NAME, VALUE) returns a
%   labeled 2-D blockedImage using Name-Value pairs to control the output
%   blockedImage.
%
%   Parameters include:
%
%   'BlockSize'      Size of blocks. Two-element vector of the form [p q]
%                    corresponding to the first two spatial dimensions, row
%                    and column, of the block. The default BlockSize is
%                    [512 512].
%
%   'WorldStart'     World coordinates of the starting edge of the
%                    blockedImage where the ROIs are labeled. ROIPOSITIONS
%                    is assumed to be in world coordinates corresponding to
%                    WorldStart and WorldEnd. The default WorldStart is
%                    [0.5 0.5].
%
%   'WorldEnd'       World coordinates of the closing edge of the
%                    blockedImage where the ROIs are labeled. ROIPOSITIONS
%                    is assumed to be in world coordinates corresponding to
%                    WorldStart and WorldEnd. The default WorldEnd is
%                    IMAGESIZE + 0.5.
%                       
%   'OutputLocation' Specifies where the output blockedImage is stored. It
%                    can be a file name with .TIF or .TIFF extension or it
%                    can be the directory name without any extension. By
%                    default, the blockedImage will be stored in memory.
%                         
%   'Adapter'        An images.blocked.Adapter object. The default adapter 
%                    is automatically picked based on the destination.
%
%  'DisplayWaitbar'  A logical scalar. When set to true, a waitbar is
%                    displayed for long running operations. If the waitbar
%                    is cancelled a partial output is returned if
%                    available. The default value is true.                    
%                   
%   Class Support 
%   -------------
%   ROIPOSITIONS is a cell array containing coordinate vectors of one of
%   the following classes: uint8, uint16, uint32, int8, int16, int32,
%   single or double. ROILABELIDS is a numeric or logical vector consisting
%   of labels for the corresponding ROIs in ROIPOSITIONS. The length of the
%   ROILABELIDS vector must equal the length of ROIPOSITIONS.
%
%   The output labeled numeric blockedImage BOUT has the same datatype as
%   ROILABELIDS.
%
%   Notes
%   ----- 
%
%   1. When the positions of several ROIs overlap each other, the ROI label
%   with a lower index number in the ROIPOSITIONS cell array overwrites the
%   other ROIs.
%
%   2. To create a labeled blockedImage, BOUT, to overlay on an existing
%   blockedImage, specify IMAGESIZE to match the size of the existing
%   blockedImage at the desired resolution level. If the resolution level
%   of BOUT matches the finest resolution level of the existing
%   blockedImage you can use the default values for WorldStart and
%   WorldEnd. Alternatively, to display the overlay at a coarse resolution
%   level, specify WorldStart and WorldEnd to match those of the existing
%   blockedImage at the desired resolution level.
%
%   Example 1
%   ---------
%
%    bim = blockedImage('tumor_091R.tif');
%
%    % Initialize the ROI positions and label IDs
%    numPolygon = 3;
%    roiPositions = cell(numPolygon,1);
%    roilabelID = zeros(numPolygon,1,'uint8');  
%   
%    % Circle parameters to draw over figure
%    center = [2774 1607;2071 3100;2208 2262];
%    radius = [390;470;161];
%    % Assign corresponding labels 
%    roilabelID(1) = 1;
%    roilabelID(2) = 2;
%    roilabelID(3) = 2;
%
%    hbim = bigimageshow(bim);
%    % Draw 3 circular polygons on the figure
%    for id = 1:numPolygon
%        hROI = drawcircle('Radius',radius(id),'Center',center(id,:),...
%               'InteractionsAllowed','none');
%        roiPositions{id} = hROI.Vertices;
%    end
%  
%    % Choose finest resolution level to create the mask
%    maskLevel = 1;
%  
%    % Create a label matrix from the ROIs
%    L = polyToBlockedImage(roiPositions,roilabelID,...
%        bim.Size(maskLevel,1:2));
% 
%    figure
%    hbim = bigimageshow(bim);
%    showlabels(hbim,L)
%
%   See also BLOCKEDIMAGE, BIGIMAGESHOW/SHOWLABELS, POLY2LABEL, DRAWCIRCLE

%   Copyright 2021 The MathWorks, Inc.

arguments    
    roiPositions (:,1) cell {validateCellContents}
    roiLabelIDs (:,1) {validateLabelID,mustBeEqualSize(roiPositions,roiLabelIDs)}
    imageSize {mustBePositive,mustBeAtleast2D,mustBeRowVector} 
    options.BlockSize {mustBePositive,mustBeAtleast2D,mustBeRowVector} = [512 512] 
    options.WorldStart {mustBeVector,mustBeAtleast2D} = [0.5 0.5]
    options.WorldEnd {mustBeVector,mustBeAtleast2D} = 0.5 + imageSize
    options.OutputLocation = []
    options.Adapter 
    options.DisplayWaitbar (1,1) logical = true
end

% Create an Output blockedImage
initialValue = zeros([1 1], 'like', roiLabelIDs);

imageSize = imageSize(1:2);
blockSize = options.BlockSize(1:2);
worldStart = options.WorldStart(1:2);
worldEnd = options.WorldEnd(1:2);

if isfield(options,'Adapter')
    % Create blockedImage with Adapter provided by the user
    bout = blockedImage(options.OutputLocation, imageSize, blockSize,...
        initialValue, "Mode", 'w',"Adapter", options.Adapter,...
        'WorldStart',worldStart,'WorldEnd',worldEnd);
else
    % Create a blockedImage which picks the adapter based on the
    % destination
    bout = blockedImage(options.OutputLocation, imageSize, blockSize,...
        initialValue, "Mode",'w',...
        'WorldStart',worldStart,'WorldEnd',worldEnd);
end

% Waitbar initialization
if (options.DisplayWaitbar)
    startTic = tic;
    waitBar = [];
    thresholdTime = 15;% seconds
end

% Creating a spatialRef object
XWorldLimits = [bout.WorldStart(2) bout.WorldEnd(2)];
YWorldLimits = [bout.WorldStart(1) bout.WorldEnd(1)];
R = imref2d(imageSize,XWorldLimits,YWorldLimits);

pixelWorldExtents = [R.PixelExtentInWorldX R.PixelExtentInWorldY];

% Find the X-Y Limits for each block
[refBlockXYLims, totalNumBlocks]  = images.blocked.internal.blockXYLims(R,blockSize);

% ROIs in each block
roiIndicesPerBlk = images.blocked.internal.roisPerBlock(roiPositions,refBlockXYLims);

% Loop through all blocks
for blockNum=1:totalNumBlocks
    % Check if ROIs are present
    if ~isempty(roiIndicesPerBlk{blockNum})
        xyStartWorld = [refBlockXYLims(blockNum,1) refBlockXYLims(blockNum,3)]; % [xmin ymin]
        
        blockOut = zeros(blockSize,'like',initialValue);
        
        % Loop through all ROIs in the block
        % ROI with lower index overwrites the other ROIs
        for idx=length(roiIndicesPerBlk{blockNum}):-1:1
            
            ROIid = roiIndicesPerBlk{blockNum}(idx);
            roiPos1 = roiPositions{ROIid};
            roiPos1 = double(roiPos1);
            
            label = roiLabelIDs(ROIid);
            
            % Translate roiPositions to Intrinsic Coordinates for poly2mask
            roiPos = (roiPos1 - xyStartWorld + pixelWorldExtents/2)./pixelWorldExtents;                        
                 
            in = poly2mask(roiPos(:,1),roiPos(:,2),blockSize(1), blockSize(2));
            
            % Assign labels to block
            blockOut(in) = label;
        end
        % Write out the block
        [blockrow, blockcol] = ind2sub(bout.SizeInBlocks, blockNum);
        
        % Write the labeled block to blockedImage
        setBlock(bout,[blockrow, blockcol], blockOut);
    end

if(options.DisplayWaitbar)
    if isempty(waitBar)
        % Wait bar not yet shown
        elapsedTime = toc(startTic);
        % Decide if we need a wait bar or not
        remainingTime = elapsedTime / blockNum * (totalNumBlocks - blockNum);
        if remainingTime > thresholdTime % seconds
            % Create a wait bar
            waitBar = iptui.cancellableWaitbar(getString(message('images:bigimage:waitbarTitleGUI')),...
                getString(message('images:blockedImage:processingBlocks')),...
                totalNumBlocks,blockNum);
        end
    else
        % Show progress on existing wait bar
        waitBar.update(blockNum);
        drawnow;
    end
end

end
if (options.DisplayWaitbar && ~isempty(waitBar))
    destroy(waitBar);
end
% Close file for writing
bout.Mode = 'r';
end

function validateCellContents(roiPositions)

validateattributes(roiPositions,{'cell'},{'nonempty'});
cellfun(@(roiPositions) validateattributes(roiPositions,...
    images.internal.iptnumerictypes,...
    {'nonempty','ncols',2,'real','finite','nonnan','nonsparse'}),roiPositions);
end

function validateLabelID(roiLabelIDs)

validateattributes(roiLabelIDs, images.internal.iptlogicalnumerictypes,...
    {'nonempty','nonnan','real','finite','nonsparse','nonnegative'});
end

function mustBeEqualSize(roiPositions, roiLabelIDs)

if ~isequal(numel(roiPositions),numel(roiLabelIDs))
    error(message('images:poly2label:sizeMismatchPosLabels'));
end

end

function mustBeRowVector(value)
    validateattributes(value,images.internal.iptnumerictypes,{'integer','row'})
end

function mustBeAtleast2D(value)
    if numel(value) < 2
        error(message('images:poly2label:sizeMustBeAtleast2D'));
    end
end
