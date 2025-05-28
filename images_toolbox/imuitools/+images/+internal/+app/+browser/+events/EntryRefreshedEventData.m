classdef (ConstructOnLoad) EntryRefreshedEventData < event.EventData
    % The EntryRefreshedEventData class encapsulates data needed for
    % EntryRefreshed event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        
        Index
        
    end
    
    methods
        
        function data = EntryRefreshedEventData(n)
            
            data.Index = n;
            
        end
        
    end
    
end
