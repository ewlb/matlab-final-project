function roiMask = createROIMask(im, roiPosition)
% Helper function that creates a mask showing the ROIs

    % Indices are of the form [xstart ystart xend yend]
    roiIndices = images.internal.testchart.pos2indices(roiPosition, im);
    numROIs = size(roiIndices, 1);
    
    roiMask = false(size(im, [1 2]));
    for cnt = 1:numROIs
        currROI = roiIndices(cnt, :);

        roiMask(currROI(2):currROI(4), currROI(1):currROI(3)) = true;
    end
end

% Copyright 2023 The MathWorks, Inc.