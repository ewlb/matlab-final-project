classdef (ConstructOnLoad) RotatedEventData < event.EventData
    % The RotatedSelectedEventData class encapsulates data needed for
    % Rotated event listener sent from the model->browser->client
    
    % Copyright 2021 The MathWorks, Inc.
    
    properties
        
        Degrees
        Sources
    end
    
    methods
        
        function data = RotatedEventData(src, theta)
            
            data.Degrees = theta;
            data.Sources = src;
        end
        
    end
    
end