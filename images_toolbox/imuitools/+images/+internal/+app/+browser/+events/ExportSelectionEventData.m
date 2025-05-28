classdef (ConstructOnLoad) ExportSelectionEventData < event.EventData
    % The ExportSelectionEventData class encapsulates data needed for
    % ExportSelection event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        Selected
    end
    
    methods
        
        function data = ExportSelectionEventData(selectedInds)            
            data.Selected = selectedInds;
        end
        
    end
    
end
