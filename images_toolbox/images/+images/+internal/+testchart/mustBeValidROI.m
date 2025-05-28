function mustBeValidROI(roiPosition, minSize, isEmptyAllowed)
% Validate that ROI locations are completely within the image

    arguments
        roiPosition (:, 4) { mustBeNumeric, mustBeReal, mustBeFinite }
        minSize (1, 1) { mustBeNumeric, mustBeReal, mustBeNonnegative, ...
                                        mustBeFinite } = 0
        isEmptyAllowed (1, 1) logical = false
    end

    if isEmptyAllowed && isempty(roiPosition)
        return;
    end

    if any(roiPosition(:, 3:4) <= minSize, "all")
        error(message("images:common:invalidROIDimensions", minSize));
    end
end

% Copyright 2023-2024 The MathWorks, Inc.