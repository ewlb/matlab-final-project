classdef (ConstructOnLoad) ErrorEventData < event.EventData
    %
    
    % Copyright 2021 The MathWorks, Inc.
    
    properties
        
        Message
        
    end
    
    methods
        
        function data = ErrorEventData(message)
            data.Message = message;
        end
        
    end
end