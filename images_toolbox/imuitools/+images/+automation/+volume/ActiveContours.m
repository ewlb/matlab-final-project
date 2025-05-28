classdef ActiveContours < images.automation.volume.Algorithm
    %
    
    % Copyright 2019 The MathWorks, Inc.
    properties (Constant)
        
        Name = getString(message('images:segmenter:activeContourName'));
        
        Description = getString(message('images:segmenter:activeContourDescription'));
        
        Icon = matlab.ui.internal.toolstrip.Icon('volumeActiveContour');
        
        ExecutionMode = 'slice';
        
        UseScaledVolume = true;
        
    end
    
    properties
        
        LastSlice
                
    end
    
    methods
        
        %------------------------------------------------------------------
        % Run
        %------------------------------------------------------------------
        function labels = run(obj,I,labels)
            
            mask = labels == obj.SelectedLabel;
            
            if ~any(mask(:))
                
                if isempty(obj.LastSlice)
                    % No valid labels match the SelectedLabel.
                    error(message('images:segmenter:noLabeledRegion'));
                end
                
                mask = obj.LastSlice;
                
            end
            
            mask = activecontour(I,mask,obj.Parameters.Iterations);
            
            % Stop condition - mask is empty
            if ~any(mask(:))
                stop(obj);
                return;
            end
            
            labels(labels == obj.SelectedLabel) = missing;
            labels(mask) = obj.SelectedLabel;
            
            obj.LastSlice = mask;
            
        end
        
    end
    
    methods (Static)
        
        function obj = getSettings(~)
            obj = images.automation.volume.settings.ActiveContourSettings;
        end
        
    end
    
end

