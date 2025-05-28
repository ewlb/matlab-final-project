%

% Copyright 2020 The MathWorks, Inc.

classdef (ConstructOnLoad) NewImageDataEventData < event.EventData
   properties
        ModifiedBW
        RegionData
        SelectedPropertyState
        ExcludeBorders
        FillHoles
        PixelIdxList
        FilterData
   end
   
   methods
      function ed = NewImageDataEventData(filteredBW,regionData,...
              selectedPropertyState,excludeBorders,fillHoles,filterData)
          
         ed.ModifiedBW = filteredBW;
         ed.RegionData = regionData;
         ed.SelectedPropertyState = selectedPropertyState;
         ed.ExcludeBorders = excludeBorders;
         ed.FillHoles = fillHoles;
         ed.FilterData = filterData;
         
         % Separate the PixelIdxList from the table of user visible region
         % props for view purposes
         ed.PixelIdxList = regionData.PixelIdxList;
         ed.RegionData.PixelIdxList = [];
      end
   end
end