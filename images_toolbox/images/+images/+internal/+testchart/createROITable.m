function t = createROITable(roiPosition, im)
% Helper function that creates the basic table that is used by all the
% imchart* functions

% Copyright 2023 The MathWorks, Inc.

    varNames = ["ROI", "ROIPosition"];

    % Indices are of the form [xstart ystart xend yend]
    roiIndices = images.internal.testchart.pos2indices(roiPosition, im);

    % The position reported is of the form [startx starty width height]
    % The width and height are "continuous" values not counted as number of
    % image pixels.
    roiPos = [ roiIndices(:, 1:2) roiIndices(:, 3)-roiIndices(:, 1) ...
               roiIndices(:, 4)-roiIndices(:, 2) ];

    roiIdx = (1:size(roiPos, 1))';

    t = table(roiIdx, roiPos, VariableNames=varNames); 
end