classdef (ConstructOnLoad) SelectionUpdatedEventData < event.EventData
    % The SelectionUpdatedEventData class encapsulates data needed for
    % SelectionUpdated event listener.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        Selected
    end
    
    methods
        function data = SelectionUpdatedEventData(TF)
            data.Selected = TF;
        end
    end
end
