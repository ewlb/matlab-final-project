classdef (ConstructOnLoad) DrawingEventData < event.EventData
    %
    
    % Copyright 2023 The MathWorks, Inc.
    
    properties
        Data
    end
    
    methods
        
        function obj = DrawingEventData(data)
            obj.Data = data;
        end
        
    end
end