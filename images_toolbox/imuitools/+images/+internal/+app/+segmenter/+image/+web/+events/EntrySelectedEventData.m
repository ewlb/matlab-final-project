classdef (ConstructOnLoad) EntrySelectedEventData < event.EventData
    % The EntrySelectedEventData class encapsulates data needed for
    % EntrySelected event listener.
    
    % Copyright 2020 The MathWorks, Inc.
    
    properties
        
        CurrentSelection
        PreviousSelection
        
    end
    
    methods
        
        function data = EntrySelectedEventData(cur,prv)
            
            data.CurrentSelection = cur;
            data.PreviousSelection = prv;
            
        end
        
    end
    
end