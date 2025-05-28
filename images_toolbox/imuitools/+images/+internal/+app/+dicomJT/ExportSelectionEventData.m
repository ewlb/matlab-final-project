classdef (ConstructOnLoad) ExportSelectionEventData < event.EventData
    %

    % Copyright 2021 The MathWorks, Inc.

    properties
        Files
   end
   
   methods
      function data = ExportSelectionEventData(files)
         data.Files = files;
      end
   end
end