classdef (ConstructOnLoad) EntriesUpdatedEventData < event.EventData
    % The EntriesUpdatedEventData class encapsulates data needed for
    % EntriesUpdated event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        
        Entries
        Selected
        CurrentHotLocation
        
    end
    
    methods
        
        function data = EntriesUpdatedEventData(entries,TF,hotSelection)
            
            data.Entries = entries;
            data.Selected = TF;
            data.CurrentHotLocation = hotSelection;
            
        end
        
    end
    
end
