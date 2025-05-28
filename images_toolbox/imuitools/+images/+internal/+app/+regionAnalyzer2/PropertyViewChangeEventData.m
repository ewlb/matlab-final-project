%

% Copyright 2020 The MathWorks, Inc.

classdef (ConstructOnLoad) PropertyViewChangeEventData < event.EventData
   properties
        EnabledPropertyState
   end
   
   methods
      function ed = PropertyViewChangeEventData(propEnabledState)
         ed.EnabledPropertyState = propEnabledState;
      end
   end
end