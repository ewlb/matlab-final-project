classdef (ConstructOnLoad) LogUpdateEventData < event.EventData
    %EventData for LogUpdate

    %   Copyright 2022 The MathWorks, Inc.

   properties
      MetricsStruct
      IsValidationIteration
   end
   
   methods
       function self = LogUpdateEventData(structIn,isValidationIteration)
         self.MetricsStruct = structIn;
         self.IsValidationIteration = isValidationIteration;
      end
   end
end