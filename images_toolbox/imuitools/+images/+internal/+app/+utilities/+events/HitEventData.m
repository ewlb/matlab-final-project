classdef (ConstructOnLoad) HitEventData < event.EventData
    % The HitEventData class encapsulates data needed for
    % ImageClicked event listener.
    
    % Copyright 2021 The MathWorks, Inc.
    
    properties
        
        IntersectionPoint
        
    end
    
    methods
        
        function data = HitEventData(pos)
            
            data.IntersectionPoint = pos(1:2);
            
        end
        
    end
    
end