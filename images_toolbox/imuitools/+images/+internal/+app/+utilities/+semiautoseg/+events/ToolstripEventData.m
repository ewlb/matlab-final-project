classdef (ConstructOnLoad) ToolstripEventData < event.EventData
    %
    
    % Copyright 2023 The MathWorks, Inc.
    
    properties
        Data
    end
    
    methods
        
        function obj = ToolstripEventData(data)
            obj.Data = data;
        end
        
    end
end