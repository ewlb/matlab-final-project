classdef (ConstructOnLoad) DisplayRefreshedEventData < event.EventData
    % The DisplayRefreshedEventData class encapsulates data needed for
    % DisplayRefreshed event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        
        DisplayRange
        
    end
    
    methods
        
        function data = DisplayRefreshedEventData(n)
            
            data.DisplayRange = n;
            
        end
        
    end
    
end
