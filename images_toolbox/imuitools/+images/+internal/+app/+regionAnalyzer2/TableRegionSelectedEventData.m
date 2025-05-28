%

% Copyright 2020 The MathWorks, Inc.

classdef (ConstructOnLoad) TableRegionSelectedEventData < event.EventData
   properties
        TableRowIndices
   end
   
   methods
      function ed = TableRegionSelectedEventData(idx)
         ed.TableRowIndices = idx;
      end
   end
end