classdef (ConstructOnLoad) DisplayedIndexEventData < event.EventData
    % The DisplayedIndexEventData class encapsulates data needed for
    % DisplayUpdated event listener.
    
    % Copyright 2021-2022 The MathWorks, Inc.
    
    properties
        
        DisplayIndex
        
    end
    
    methods
        
        function data = DisplayedIndexEventData(n)
            
            data.DisplayIndex = n;
            
        end
        
    end
    
end
