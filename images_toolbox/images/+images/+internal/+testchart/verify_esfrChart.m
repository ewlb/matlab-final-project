function verify_esfrChart(chart)
% Verify that the detected chart is a valid esfrChart chart image and error out if
% conditions are not met

% Copyright 2017-2020 The MathWorks, Inc.

im = im2double(imgaussfilt(chart.ImageGray,1));

%test for alignment of registration points moved to register_esfrChart
% Check alignment using two dark circular regions for styles 1,3,4
if(~strcmp(chart.Style,'Enhanced'))
    alignmentPoint1 = chart.modelPoints(181,:);
    alignmentPoint2 = chart.modelPoints(182,:);

    intensity1 = im(alignmentPoint1(2),alignmentPoint1(1));
    intensity2 = im(alignmentPoint2(2),alignmentPoint2(1));

    % Intensities should be similar
    measIntensity1 = norm(intensity1-intensity2);% Check less than 0.1

    % Intensity of point in the middle of the two points should be
    % significantly more than that of the two dark points.
    measIntensity2 = im(round((alignmentPoint1(2)+alignmentPoint2(2))/2),...
        round((alignmentPoint1(1)+alignmentPoint2(1))/2))/((intensity1+intensity2)/2);% Check greater than 2

    if(measIntensity1 > 0.1) || (measIntensity2 < 2)
       error(message('images:esfrChart:IntensityMismatchAlignmentPoints'));
    end
end

% check if gray patches have monotonically increasing intensity
GrayROIs = images.internal.testchart.detectGrayPatches(chart);
grayIntensities = zeros(chart.numGrayPatches,1);
for i =1:chart.numGrayPatches
    grayIntensities(i) = mean2(GrayROIs(i).ROIIntensity);
end
%ignore ROIs 1,2,3,4 to make the verification more robust
measGrayPatches = issorted(movmean(grayIntensities(5:end),3),'ascend');
if(measGrayPatches==0)
   error(message('images:esfrChart:IntensityMismatchGrayPatches'));
end
end
