%

% Copyright 2020 The MathWorks, Inc.

classdef (ConstructOnLoad) CodeGeneratedEventData < event.EventData
   properties
        CodeString
   end
   
   methods
      function ed = CodeGeneratedEventData(codestr)
         ed.CodeString = codestr;
      end
   end
end