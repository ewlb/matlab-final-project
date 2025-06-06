%

% Copyright 2020 The MathWorks, Inc.

classdef (ConstructOnLoad) ErrorEventData < event.EventData
    properties
        ErrorMessage
    end
    
    methods
        function data = ErrorEventData(message)
            data.ErrorMessage = message;
        end
    end
end
