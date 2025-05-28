classdef (ConstructOnLoad) ModeChangedEventData < event.EventData
    % The ModeChangedEventData class encapsulates data needed for
    % InteractionModeChanged event listener.
    
    % Copyright 2020 The MathWorks, Inc.
    
    properties
        
        Mode
        PreviousMode
        
    end
    
    methods
        
        function data = ModeChangedEventData(mode,priorMode)
            
            data.Mode = mode;
            data.PreviousMode = priorMode;
            
        end
        
    end
    
end