classdef (ConstructOnLoad) RemovedEventData < event.EventData
    % The RemovedEventData class encapsulates data needed for
    % Removed event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        
        RemovedDataIndices
        RemovedSources
        NewNumEntries
    end
    
    methods
        
        function data = RemovedEventData(removedDataIndices, removedSources, newNumEntries)
            data.RemovedDataIndices = removedDataIndices;
            data.RemovedSources = removedSources;
            data.NewNumEntries = newNumEntries;
        end
        
    end
    
end
