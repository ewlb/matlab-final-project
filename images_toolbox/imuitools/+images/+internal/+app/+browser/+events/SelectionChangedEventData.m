classdef (ConstructOnLoad) SelectionChangedEventData < event.EventData
    % The SelectionChangedEventData class encapsulates data needed for
    % SelectionChanged event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        
        ClickType
        CurrentHotLocation
        DisplayRange
        
    end
    
    methods
        
        function data = SelectionChangedEventData(clickType,currentLoc,range)
            
            data.ClickType = clickType;
            data.CurrentHotLocation = currentLoc;
            data.DisplayRange = range;
            
        end
        
    end
    
end
