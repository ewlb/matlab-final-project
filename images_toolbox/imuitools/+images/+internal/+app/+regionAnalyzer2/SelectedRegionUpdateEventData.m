%

% Copyright 2020-2021 The MathWorks, Inc.

classdef (ConstructOnLoad) SelectedRegionUpdateEventData < event.EventData
   properties
        SelectionMask
        BW
   end
   
   methods
      function ed = SelectedRegionUpdateEventData(selectionMask,bw)
         ed.SelectionMask = selectionMask;
         ed.BW = bw;
      end
   end
end