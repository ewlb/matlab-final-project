classdef (ConstructOnLoad) EntriesAddedEventData < event.EventData
    % The EntriesAddedEventData class encapsulates data needed for
    % EntriesAdded event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        
        NumEntries
        
    end
    
    methods
        
        function data = EntriesAddedEventData(n)
            
            data.NumEntries = n;
            
        end
        
    end
    
end
