function percentChAberration = calculateCorrPercentChAberraton( ROI, ch_aberration, imageCenter)
%

% Copyright 2017-2020 The MathWorks, Inc.

ROICenter = [ROI(1)+ROI(3)/2 ROI(2)+ROI(4)/2];
distVector = imageCenter-ROICenter;
dist = norm(distVector);
percentChAberration = (ch_aberration/dist)*100;


