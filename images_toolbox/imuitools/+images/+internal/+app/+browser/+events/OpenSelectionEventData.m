classdef (ConstructOnLoad) OpenSelectionEventData < event.EventData
    % The OpenSelectionEventData class encapsulates data needed for
    % OpenSelection event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        Selected
    end
    
    methods
        
        function data = OpenSelectionEventData(selectedInds)            
            data.Selected = selectedInds;
        end
        
    end
    
end
