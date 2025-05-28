classdef OtsuVolumeThresholding < images.automation.volume.Algorithm
    %
    
    % Copyright 2019 The MathWorks, Inc.
    properties (Constant)
        
        Name = getString(message('images:segmenter:otsuThreshName'));
        
        Description = getString(message('images:segmenter:otsuThreshDescription'));
        
        Icon = matlab.ui.internal.toolstrip.Icon('volumeOtsu');
        
        ExecutionMode = 'volume';
        
        UseScaledVolume = false;
        
    end
    
    properties
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Run
        %------------------------------------------------------------------
        function labels = run(obj,I,labels)
            
            if size(I,4) == 3
                error(message('images:segmenter:volumeIsRGB'));
            end
            
            counts = imhist(I,32);
            
            T = otsuthresh(counts);
            mask = imbinarize(I,T);
            
            labels(labels == obj.SelectedLabel) = missing;
            labels(mask) = obj.SelectedLabel;
            
        end
        
    end
    
end