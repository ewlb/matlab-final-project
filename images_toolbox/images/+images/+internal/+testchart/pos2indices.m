function roiEPIndices = pos2indices(roiPositions, im)
% Helper function that converts ROI Locations specified by the user into
% matrix indices. The returned value contains the the array index
% coordinates [startx starty endx endy]

    [width, height] = size(im, [2 1]);

    roiBBoxXY = [roiPositions(:, 1:2) roiPositions(:, 1:2)+roiPositions(:, 3:4)];

    roiEPIndices = round(roiBBoxXY);
    roiEPIndices(:, 1) = min(max(roiEPIndices(:, 1), 1), width);
    roiEPIndices(:, 2) = min(max(roiEPIndices(:, 2), 1), height);
    roiEPIndices(:, 3) = min(max(roiEPIndices(:, 3), 1), width);
    roiEPIndices(:, 4) = min(max(roiEPIndices(:, 4), 1), height);
end

% Copyright 2023 The MathWorks, Inc.