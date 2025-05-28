classdef (ConstructOnLoad) ContrastAdjustEventData < event.EventData
    % The ContrastAdjustEventData class encapsulates data needed for
    % AdjustContrast event listeners.
    
    % Copyright 2020-2023 The MathWorks, Inc.
    
    properties
        
        CLim
        
    end
    
    methods
        
        function data = ContrastAdjustEventData(cLim)
            
            data.CLim = cLim;
            
        end
        
    end
    
end