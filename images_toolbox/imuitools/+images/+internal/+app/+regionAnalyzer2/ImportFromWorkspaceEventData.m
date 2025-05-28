%

% Copyright 2021 The MathWorks, Inc.

classdef (ConstructOnLoad) ImportFromWorkspaceEventData < event.EventData
   properties
        VarName
   end
   
   methods
      function ed = ImportFromWorkspaceEventData(varname)
         ed.VarName = varname;
      end
   end
end