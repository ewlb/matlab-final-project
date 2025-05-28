function [colorTable, ccm] = measureColor(im, roiPosition, refLAB, options)
    arguments
        im  (:, :, 3) {mustBeA(im, ["uint8", "uint16", "single", "double"])}
        roiPosition (:, 4) {images.internal.testchart.mustBeValidROI}
        refLAB (:, 3) {mustBeValidReferenceLAB(refLAB, roiPosition)}

        options.InputColorSpace (1, 1) string = "srgb"
        options.ReferenceLABWhitePoint = "d65"
    end

    inColorSpace = validatestring( options.InputColorSpace, ...
                                   [ "srgb", "adobe-rgb-1998", ...
                                     "prophoto-rgb" ] );
    refLabWP = images.color.internal.checkWhitePoint(options.ReferenceLABWhitePoint);

    roiImages = images.internal.testchart.splitROIs(im, roiPosition);
    numROIs = numel(roiImages);

    measRGB = zeros(numROIs, 3, class(im));

    for cnt = 1:numROIs
        currROI = roiImages{cnt};
        measRGB(cnt, 1) = mean2(currROI(:, :, 1));
        measRGB(cnt, 2) = mean2(currROI(:, :, 2));
        measRGB(cnt, 3) = mean2(currROI(:, :, 3));
    end

    % The Reference LAB values might use their own WhitePoint. Hence, the
    % RGB values must be converted to LAB values at this specifiec
    % whitepoint.
    measLAB = rgb2lab(measRGB, Colorspace=inColorSpace, WhitePoint=refLabWP);
    
    de = deltaE(measLAB, refLAB, isInputLab=true);

    colorTable = images.internal.testchart.createROITable(roiPosition, im);

    ctableVarNames = [ "Measured_" + ["R" "G" "B"] ...
                       "Reference_" + ["L" "a" "b"] ...
                       "Delta_E" ];
    colorTable = addvars( colorTable, ...
                          measRGB(:, 1), measRGB(:, 2), measRGB(:, 3), ...
                          refLAB(:, 1), refLAB(:, 2), refLAB(:, 3), ...
                          mean(de, 2), NewVariableNames=ctableVarNames, ...
                          Before="ROIPosition" );

    colorTable = addprop( colorTable, ...
                      ["InputColorSpace", "ReferenceLABWhitePoint"], ...
                      ["table", "table"] );
    colorTable.Properties.CustomProperties.InputColorSpace = inColorSpace;
    colorTable.Properties.CustomProperties.ReferenceLABWhitePoint = ...
                                        options.ReferenceLABWhitePoint;

    % Remove Gamma Correction and convert to linear RGB values in the
    % source colorspace
    measLinearRGB = rgb2lin(measRGB, ColorSpace=inColorSpace);

    % Convert the reference LAB values into RGB values in the input
    % colorspace
    refRGB = lab2rgb( refLAB, WhitePoint=refLabWP, ...
                      ColorSpace=inColorSpace, ...
                      OutputType=class(im) );

    % Remove Gamma Correction. Doing this in two steps because lab2rgb
    % does not support disabling gamma correction application
    refLinearRGB = rgb2lin(refRGB, ColorSpace=inColorSpace);

    ccm = images.internal.testchart.calculateColorCorMatrix( ...
                                            measLinearRGB, refLinearRGB );
end

function mustBeValidReferenceLAB(refLAB, roiLocations)
% Must be valid reference LAB data

    mustBeA(refLAB, ["single", "double"]);

    if size(refLAB, 1) ~= size(roiLocations, 1)
        error(message("images:measureColor:invalidNumRefLAB"));
    end
end

% Copyright 2017-2024 The MathWorks, Inc.
