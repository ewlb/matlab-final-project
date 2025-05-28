function caTable = measureChromaticAberration(im, roiPosition)
% Generalized Chromatic Aberration Measurements

    arguments
        im  (:, :, 3) {mustBeNumeric}
        roiPosition (:, 4) { images.internal.testchart.mustBeValidROI( ...
                                roiPosition, 5 ) }
    end

    caTable = images.internal.testchart.createROITable(roiPosition, im);
    roiRect = caTable{:, "ROIPosition"};

    % The Chromatic Aberration Calculation function appears to expect the
    % height/width to be in pixel counts.
    roiRect(:, 3:4) = roiRect(:, 3:4)+1;
    
    roiImages = images.internal.testchart.splitROIs(im, roiPosition);
    numROIs = numel(roiImages);

    aberration = zeros(numROIs, 1);
    pctAberration = aberration;
    
    edgeProfile = cell(numROIs, 1);
    normEdgeProfile = edgeProfile;

    imageCenter = size(im, [2 1]) / 2;

    edgeProfileVarNames = "edgeProfile_" + ["R" "G" "B" "Y"];
    normEdgeProfileVarNames = "normalizedEdgeProfile_" + ["R" "G" "B" "Y"];

    for cnt = 1:numROIs
        currROI = roiRect(cnt, :);
        roiImage = roiImages{cnt};

        [~, ~, ~, ~, esf] = images.internal.testchart.sfrmat3(1, 1, [], roiImage);

        [esfNorm, aberration(cnt)] = images.internal.testchart.calculateChAberration(currROI, esf);
        pctAberration(cnt) = ...
            images.internal.testchart.calculateCorrPercentChAberraton(currROI, aberration(cnt), imageCenter);

        edgeProfile{cnt} = array2table(esf, VariableNames=edgeProfileVarNames);
        normEdgeProfile{cnt} = array2table(esfNorm, VariableNames=normEdgeProfileVarNames);
    end

    caTableVarNames = [ "aberration", "percentAberration", ...
                        "edgeProfile", "normalizedEdgeProfile" ];
    caTable = addvars( caTable, aberration, pctAberration, ...
                       edgeProfile, normEdgeProfile, ...
                       NewVariableNames=caTableVarNames, ...
                       Before="ROIPosition" );
end

% Copyright 2023 The MathWorks, Inc.