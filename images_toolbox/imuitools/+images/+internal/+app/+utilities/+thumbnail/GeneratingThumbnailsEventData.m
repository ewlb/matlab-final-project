%

% Copyright 2020 The MathWorks, Inc.

classdef (ConstructOnLoad) GeneratingThumbnailsEventData < event.EventData
   
    properties
        % ImageIndex - Index of the images
        ImageIndex
    end
    
    methods
        
        function data = GeneratingThumbnailsEventData(indices)
            
            data.ImageIndex = indices;
            
        end
    end
    
end