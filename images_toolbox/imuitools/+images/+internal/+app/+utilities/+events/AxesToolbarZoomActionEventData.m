classdef (ConstructOnLoad) AxesToolbarZoomActionEventData < event.EventData
    % The AxesToolbarZoomActionEventData class encapsulates data needed
    % for clients who have to react to Axes Toolbar based Zoom operations
    
    % Copyright 2023 The MathWorks, Inc.
    
    properties
        
        ZoomMode
        
    end
    
    methods
        
        function data = AxesToolbarZoomActionEventData(zoomMode)
            
            data.ZoomMode = zoomMode;
            
        end
        
    end
    
end