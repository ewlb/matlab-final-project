%

% Copyright 2020 The MathWorks, Inc.

classdef (ConstructOnLoad) ImportFromFileEventData < event.EventData
   properties
        Filename
   end
   
   methods
      function data = ImportFromFileEventData(filename)
         data.Filename = filename;
      end
   end
end