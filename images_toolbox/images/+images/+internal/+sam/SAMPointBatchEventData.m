classdef (ConstructOnLoad) SAMPointBatchEventData < event.EventData
% Event Data for processed batch event

%   Copyright 2024 The MathWorks, Inc.

   properties
      CurrentCrop = 0
      TotalCrops
      PointsProcessed
      TotalPoints
   end
   methods
       function evtData = SAMPointBatchEventData(currentCropIdx,numCrops,pointsProcessed,totalPoints)
         evtData.CurrentCrop     = currentCropIdx;
         evtData.TotalCrops      = numCrops;
         evtData.PointsProcessed = pointsProcessed;
         evtData.TotalPoints     = totalPoints;
      end
   end
end