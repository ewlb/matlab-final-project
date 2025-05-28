classdef (ConstructOnLoad) UpdateViewSelectionEventData < event.EventData
    % The SelectionUpdatedEventData class encapsulates data needed for
    % SelectionUpdated event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties        
        Selected       
        CurrentHotLocation
    end
    
    methods
        
        function data = UpdateViewSelectionEventData(selectedInds,hotSelection)            
            data.Selected = selectedInds;  
            data.CurrentHotLocation = hotSelection;
        end
        
    end
    
end
