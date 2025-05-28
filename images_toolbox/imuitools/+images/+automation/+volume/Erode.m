classdef Erode < images.automation.volume.Algorithm
    %
    
    % Copyright 2019 The MathWorks, Inc.
    properties (Constant)
        
        Name = getString(message('images:segmenter:erodeName'));
        
        Description = getString(message('images:segmenter:erodeDescription'));
        
        Icon = matlab.ui.internal.toolstrip.Icon('volumeErode');
        
        ExecutionMode = 'slice';
        
        UseScaledVolume = false;
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Run
        %------------------------------------------------------------------
        function labels = run(obj,~,labels)
            
            mask = labels == obj.SelectedLabel;
            
            if ~any(mask(:))
                return;
            end
            
            mask = imerode(mask,strel('disk', obj.Parameters.Radius, obj.Parameters.N));
                        
            labels(labels == obj.SelectedLabel) = missing;
            labels(mask) = obj.SelectedLabel;
                        
        end
        
    end
    
    methods (Static)
        
        function obj = getSettings(~)
            obj = images.automation.volume.settings.MorphologySettings;
        end
        
    end
    
end

