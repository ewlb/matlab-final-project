%

% Copyright 2021 The MathWorks, Inc.

classdef (ConstructOnLoad) ExportDataEventData < event.EventData
   properties
        BW
        RegionData
   end
   
   methods
      function ed = ExportDataEventData(bw,regionPropTable)
         ed.BW = bw;
         ed.RegionData = regionPropTable;
      end
   end
end