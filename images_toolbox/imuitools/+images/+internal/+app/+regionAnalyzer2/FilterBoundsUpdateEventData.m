%

% Copyright 2020 The MathWorks, Inc.

classdef (ConstructOnLoad) FilterBoundsUpdateEventData < event.EventData
   properties
        PropName
        Range
        Index
        Enabled
        FilterType
   end
   
   methods
      function ed = FilterBoundsUpdateEventData(propName,range,index,enabled,filterType)
         ed.PropName = propName;
         ed.Range = range;
         ed.Index = index;
         ed.Enabled = enabled;
         ed.FilterType = filterType;
      end
   end
end