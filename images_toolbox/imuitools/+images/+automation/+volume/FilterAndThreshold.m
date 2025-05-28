classdef FilterAndThreshold < images.automation.volume.Algorithm
    %
    
    % Copyright 2020 The MathWorks, Inc.
    properties (Constant)
        
        Name = getString(message('images:segmenter:filterThresholdName'));
        
        Description = getString(message('images:segmenter:filterThresholdDescription'));
        
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
            
            if obj.Parameters.ApplyFilter
                I = imgaussfilt3(I,obj.Parameters.Sigma,'FilterSize',obj.Parameters.FilterSize);
            end

            mask = I >= obj.Parameters.Threshold;
            
            labels(labels == obj.SelectedLabel) = missing;
            labels(mask) = obj.SelectedLabel;
            
        end
        
    end
    
    methods (Static)
        
        function obj = getSettings(~)
            obj = images.automation.volume.settings.GaussianFilterSettings;
        end
        
    end
    
end