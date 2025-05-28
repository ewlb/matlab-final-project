classdef (ConstructOnLoad) ViewerEventData < event.EventData
% Helper class that stores the event data that is used by th ImageViewer
% infrastruture
    
%   Copyright 2023 The MathWorks, Inc.
    
    properties(Access=public)
        Data
    end
    
    methods
        function evt = ViewerEventData(data) 
            evt.Data = data;
        end
    end
end