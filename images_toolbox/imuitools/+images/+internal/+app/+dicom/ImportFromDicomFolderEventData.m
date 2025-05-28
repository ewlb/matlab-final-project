classdef (ConstructOnLoad) ImportFromDicomFolderEventData < event.EventData
    % IMPORTFROMDICOMFOLDEREVENTDATA Helper function to import DICOM folder event data
    
    % Copyright 2018 The MathWorks, Inc.

   properties
        DirectoryName
   end
   
   methods
      function data = ImportFromDicomFolderEventData(dirName)
         data.DirectoryName = dirName;
      end
   end
end

