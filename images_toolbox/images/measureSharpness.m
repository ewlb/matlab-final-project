function sfrTable = measureSharpness(im, roiPosition, options)
% Generalized Sharpness Measurement Function

    arguments
        im  (:, :, :) { mustBeNumeric, ...
                        images.internal.testchart.mustHaveNumChannels(im, [1 3]) }
        roiPosition (:, 4) { images.internal.testchart.mustBeValidROI( ...
                                    roiPosition, 5 ) }
        options.PercentResponse { mustBeVector, mustBeInteger, ...
                                  mustBeInRange( options.PercentResponse, ...
                                                    1, 100 ) } = 50
    end

    roiImages = images.internal.testchart.splitROIs(im, roiPosition);
    numROIs = numel(roiImages);

    isReliable = true(numROIs, 1);
    sfr = cell(numROIs, 1);
    slopeAngle = zeros(numROIs, 1);
    comment = cell(numROIs, 1);

    numChannels = size(im, 3);
    if numChannels == 3
        sfrChannelNames = ["R" "G" "B", "Y"];
    else
        sfrChannelNames = "I";
    end
    sfrVarNames = ["F" "SFR_" + sfrChannelNames];

    for cnt = 1:numROIs
        currROI = roiImages{cnt};

        [~, currROISFR, ~, ~, ~, ~, ~, contrastTest, slopeAngle(cnt)] = ...
                    images.internal.testchart.sfrmat3(1, 1, [], currROI);

        if contrastTest < 0.2
            isReliable(cnt) = false;
            comment{cnt} = getString(message('images:esfrChart:ROIContrastSharpnessComment'));
        end

        if (slopeAngle(cnt) < 3.5) || (slopeAngle(cnt) > 15)
            isReliable(cnt) = false;
            comment{cnt} = getString(message('images:esfrChart:SlopeAngleSharpnessComment'));
        end

        sfr{cnt} = array2table(currROISFR, VariableNames=sfrVarNames);
    end

    sfrTable = images.internal.testchart.createROITable(roiPosition, im);

    sfrTableVarNames = [ "slopeAngle", "confidenceFlag", ...
                         "SFR", "comment" ];
    sfrTable = addvars( sfrTable, slopeAngle, isReliable, sfr, comment, ...
                        NewVariableNames=sfrTableVarNames, ...
                        Before="ROIPosition" );

    % Compute the MTF and add the variables
    pctResponse = double(options.PercentResponse);
    mtfVarNames = "MTF" + pctResponse + [""; "P"];
    mtfVarNames = mtfVarNames(:)';

    sfrAllROIs = sfrTable.SFR;
    for cnt = 1:numel(pctResponse)
        mtf = images.internal.testchart.calculate_mtf( sfrAllROIs, ...
                                                       pctResponse(cnt) );
        mtf = cell2mat(mtf);
        mtfName = mtfVarNames(2*cnt-1);
        sfrTable = addvars( sfrTable, mtf, ...
                            Before="ROIPosition", ...
                            NewVariableNames=mtfName );

        mtfPeak = images.internal.testchart.calculate_pmtf( sfrAllROIs, ...
                                                        pctResponse(cnt) );
        mtfPeak = cell2mat(mtfPeak);
        mtfName = mtfVarNames(2*cnt);
        sfrTable = addvars( sfrTable, mtfPeak, ...
                            Before="ROIPosition", ...
                            NewVariableNames=mtfName );
    end
end

% Copyright 2017-2023 The MathWorks, Inc.
