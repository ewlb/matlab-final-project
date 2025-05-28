classdef (ConstructOnLoad) DataEntryUpdatedEventData < event.EventData
    % The DataEntryUpdatedEventData class encapsulates data needed for
    % EntryRefreshed event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        
        DataEntry
        DisplayIndex
        
    end
    
    methods
        
        function data = DataEntryUpdatedEventData(dataEntry, displayIndex)
            data.DataEntry = dataEntry;
            data.DisplayIndex = displayIndex;
            
        end
        
    end
    
end
