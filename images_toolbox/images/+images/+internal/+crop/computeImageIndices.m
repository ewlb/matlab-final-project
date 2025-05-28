function [r1, c1, r2, c2] = computeImageIndices( spatialRect, xmin, ymin, ...
                                    pixPerHorizUnit, pixPerUnitVert)
% Helper function that computes the image array indices that will be used
% to crop the image given spatial coordinates of the ROI rectangle

% Copyright 2023 The MathWorks, Inc.

    pixelHeight = spatialRect(4) * pixPerUnitVert;
    pixelWidth = spatialRect(3) * pixPerHorizUnit;
    r1 = (spatialRect(2) - ymin) * pixPerUnitVert + 1;
    c1 = (spatialRect(1) - xmin) * pixPerHorizUnit + 1;
    r2 = round(r1 + pixelHeight);
    c2 = round(c1 + pixelWidth);
    r1 = round(r1);
    c1 = round(c1);
end