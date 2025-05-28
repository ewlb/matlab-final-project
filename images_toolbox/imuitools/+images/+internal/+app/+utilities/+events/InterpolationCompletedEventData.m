classdef (ConstructOnLoad) InterpolationCompletedEventData < event.EventData
% The InterpolationCompletedEventData class encapsulates data needed for
% InterpolationCompleted event listener.

% Copyright 2021 The MathWorks, Inc.
    
   properties
       
      Mask
      Label
      SliceNumber

      SliceDimension
      
   end
   
   methods
       
       function data = InterpolationCompletedEventData(mask,label,sliceNum)
           
           data.Mask = mask;
           data.Label = label;
           data.SliceNumber = sliceNum;
           
       end
       
   end
   
end