classdef (ConstructOnLoad) RotateSelectedEventData < event.EventData
    % The RotateSelectedEventData class encapsulates data needed for
    % RotateSelected event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        
        Degrees
        
    end
    
    methods
        
        function data = RotateSelectedEventData(val)
            
            data.Degrees = val;
            
        end
        
    end
    
end
