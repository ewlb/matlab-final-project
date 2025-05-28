%

% Copyright 2021 The MathWorks, Inc.

classdef (ConstructOnLoad) FilterDataUpdateEventData < event.EventData
   properties
        FilterData
        RegionDataMin
        RegionDataMax
        PropIncrements
   end
   
   methods
      function ed = FilterDataUpdateEventData(filterData,regionDataMin,regionDataMax,propInc)
         ed.FilterData = filterData;
         ed.RegionDataMin = regionDataMin;
         ed.RegionDataMax = regionDataMax;
         ed.PropIncrements = propInc;
      end
   end
end