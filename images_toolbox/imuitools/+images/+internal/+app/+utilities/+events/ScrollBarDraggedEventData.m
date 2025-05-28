classdef (ConstructOnLoad) ScrollBarDraggedEventData < event.EventData
    % The ScrollBarDraggedEventData class encapsulates data needed for
    % ScrollBarDragged event listener.
    
    % Copyright 2020 The MathWorks, Inc.
    
    properties
        
        CurrentPoint
        OriginalPoint
        ScrollBarLimits
        ScrollBarExtents
        
    end
    
    methods
        
        function data = ScrollBarDraggedEventData(pt,oldpt,limits,barextent)
            
            data.CurrentPoint = pt;
            data.OriginalPoint = oldpt;
            data.ScrollBarLimits = limits;
            data.ScrollBarExtents = barextent;
            
        end
        
    end
    
end