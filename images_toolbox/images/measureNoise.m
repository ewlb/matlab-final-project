function noiseTable = measureNoise(im, roiPosition)

    arguments
        im  (:, :, :) {mustBeNumeric, images.internal.testchart.mustHaveNumChannels(im, [1 3])}
        roiPosition (:, 4) {images.internal.testchart.mustBeValidROI}
    end

    roiImages = images.internal.testchart.splitROIs(im, roiPosition);
    numROIs = numel(roiImages);

    numInputChannels = size(im, 3);

    if numInputChannels == 1
        channelNames = "I";
    else
        channelNames = ["R"; "G"; "B"];
    end

    varsPrefix = ["MeanIntensity_" "RMSNoise_" "PercentNoise_" "SignalToNoiseRatio_" "SNR_" "PSNR_"];

    % Using implicit expansion to append the channel names to each of the
    % variables.
    colorChanVars = varsPrefix + channelNames(:);
    colorChanVars = colorChanVars(:)';
    
    meanIntensity = zeros(numROIs, numInputChannels);
    rmsNoise = meanIntensity;

    for cnt = 1:numROIs
        currROI = roiImages{cnt};

        for cntC = 1:numInputChannels
            meanIntensity(cnt, cntC) = mean2(currROI(:, :, cntC));
            rmsNoise(cnt, cntC) = std2(currROI(:, :, cntC));
        end
    end

    classRange = getrangefromclass(im);
    classMax = classRange(2);

    percNoise = 100*rmsNoise/classMax;

    snrVal = meanIntensity ./ rmsNoise;
    snrDB = 20*log10(snrVal);
    psnrDB = 20*log10(classMax ./ rmsNoise );

    noiseTable = images.internal.testchart.createROITable(roiPosition, im);
    if numInputChannels == 1
        noiseTable = addvars( noiseTable, meanIntensity, rmsNoise, ...
                              percNoise, snrVal, snrDB, psnrDB, ...
                              NewVariableNames=colorChanVars, ...
                              Before="ROIPosition" );
    else

        ycbcrInput = rgb2ycbcr(im);
        ycbcrROIImages = images.internal.testchart.splitROIs(ycbcrInput, roiPosition);

        rmsYCbCrNoise = zeros(numROIs, numInputChannels);
        for cnt = 1:numROIs
            currYCbCrROI = ycbcrROIImages{cnt};
    
            for cntC = 1:numInputChannels
                rmsYCbCrNoise(cnt, cntC) = std2(currYCbCrROI(:, :, cntC));
            end
        end

        meanIntensityTemp = num2cell(meanIntensity, 1);
        rmsNoiseTemp = num2cell(rmsNoise, 1);
        percNoiseTemp = num2cell(percNoise, 1);
        snrValTemp = num2cell(snrVal, 1);
        snrDBTemp = num2cell(snrDB, 1);
        psnrDBTemp = num2cell(psnrDB, 1);
        rmsYCbCrTemp = num2cell(rmsYCbCrNoise, 1);

        colorChanVars = [colorChanVars "RMSNoise_" + ["Y" "Cb" "Cr"]];
        noiseTable = addvars( noiseTable, meanIntensityTemp{:}, ...
                              rmsNoiseTemp{:}, percNoiseTemp{:}, ...
                              snrValTemp{:}, snrDBTemp{:}, psnrDBTemp{:}, ...
                              rmsYCbCrTemp{:}, ...
                              NewVariableNames=colorChanVars, ...
                              Before="ROIPosition" );
    end
end

% Copyright 2017-2023 The MathWorks, Inc.
