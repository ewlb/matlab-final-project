classdef (ConstructOnLoad) ViewChangedEventData < event.EventData
    % The ViewChangedEventData class encapsulates data needed for
    % ViewChanged event listener.
    
    % Copyright 2020 The MathWorks, Inc.
    
    properties
        
        XLim
        YLim
        
    end
    
    methods
        
        function data = ViewChangedEventData(xLim,yLim)
            
            data.XLim = xLim;
            data.YLim = yLim;
            
        end
        
    end
    
end