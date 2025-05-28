classdef (ConstructOnLoad) SnapToEventData < event.EventData
    % The SnapToEventData class encapsulates data needed for
    % SnapTo event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties        
        DisplayIndex        
    end
    
    methods        
        function data = SnapToEventData(displayIndex)
            data.DisplayIndex = displayIndex;
        end        
    end   
end
