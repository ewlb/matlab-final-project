function roiImages = splitROIs(im, roiPosition)
% Helper function that splits the image into ROI images

    % Indices are of the form [xstart ystart xend yend]
    roiIndices = images.internal.testchart.pos2indices(roiPosition, im);
    
    numROIs = size(roiIndices, 1);
    roiImages = cell(numROIs, 1);

    for cnt = 1:numROIs
        roi = roiIndices(cnt, :);
        roiImages{cnt} = im(roi(2):roi(4), roi(1):roi(3), :);
    end
end

% Copyright 2023 The MathWorks, Inc.