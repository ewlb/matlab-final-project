classdef (ConstructOnLoad) DataEntriesRemovedEventData < event.EventData
    % The DataEntriesRemovedEventData class encapsulates data needed for
    % DataEntriesRemoved event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties        
        NewNumEntries
        % These indices are computed _before_ removing entries
        RemovedDisplayIndices
    end
    
    methods
        
        function data = DataEntriesRemovedEventData(newNumEntries, removedDisplayIndices)                        
            data.NewNumEntries = newNumEntries;            
            data.RemovedDisplayIndices = removedDisplayIndices;
        end
        
    end
    
end
