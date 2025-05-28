%

% Copyright 2021 The MathWorks, Inc.

classdef (ConstructOnLoad) FilterPropertyUpdateEventData < event.EventData
   properties
        PropName
        Index
   end
   
   methods
      function ed = FilterPropertyUpdateEventData(propName,index)
         ed.PropName = propName;
         ed.Index = index;
      end
   end
end