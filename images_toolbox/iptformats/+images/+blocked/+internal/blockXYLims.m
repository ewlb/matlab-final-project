function [refBlockXYLim, totalNumBlocks]  = blockXYLims(R,blockSize)
% For the given blockedImage at given resolution level using its spatial
% referencing imref2d object (R) and given (blockSize):
% 1. Give the world co-ordinate locations of all the blocks (at that resolution level).
% 2. Find total number of blocks (at that resolution level).
% big image block extents  [Xmin Xmax Ymin Ymax; ...]

% Finds XY Limits for all blocks of a blockedImage
LevelSize = R.ImageSize;
blocksPerCol = ceil(LevelSize(1)/blockSize(1));
blocksPerRow = ceil(LevelSize(2)/blockSize(2));
totalNumBlocks = blocksPerCol * blocksPerRow;
colVec = 1:blockSize(2):LevelSize(2);
rowVec = 1:blockSize(1):LevelSize(1);

% Block Extent in World Coordinates

blockExtentX = R.PixelExtentInWorldX * blockSize(2);
blockExtentY = R.PixelExtentInWorldY * blockSize(1); 

% Block Origin with Initial value as Image world limits

blockOriginX = R.XWorldLimits(1);
blockOriginY = R.YWorldLimits(1);

% Generate reference co-ordinates [Xmin Xmax Ymin Ymax; ...] for each block in bigimage
refBlockXYLim = zeros(totalNumBlocks,4);

for cid = 1:length(colVec)
    for rid = 1:length(rowVec)
        cStart = colVec(cid);
        rStart = rowVec(rid);
        blockNum = floor(cStart/blockSize(2))*blocksPerCol + floor(rStart/blockSize(1)) + 1;
        xmin = blockOriginX;
        ymin = blockOriginY;
        xmax = blockOriginX+blockExtentX;
        ymax = blockOriginY+blockExtentY;
        
        if(rid == length(rowVec) && cid == length(colVec))
            % Inner blocks
            refBlockXYLim(blockNum,:) = [xmin xmax ymin ymax];
        elseif(rid == length(rowVec))
            % Bottommost edge
            refBlockXYLim(blockNum,:) = [xmin xmax-eps(xmax) ymin ymax];
        elseif(cid == length(colVec))
            % Rightmost edge
            refBlockXYLim(blockNum,:) = [xmin xmax ymin ymax-eps(ymax)];
        else
            % Corner block
            refBlockXYLim(blockNum,:) = [xmin xmax-eps(xmax) ymin ymax-eps(ymax)];
        end

        % Block Origin for the next block along the column 
        blockOriginY = blockOriginY + blockExtentY;

    end
    % Reset Y on moving to new column   
    blockOriginY = R.YWorldLimits(1);

    % Adding Xdir offset to blockOrigin every time we move columns
    blockOriginX = blockOriginX + blockExtentX;
   
    
      
end