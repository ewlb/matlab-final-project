classdef ModeFilter < images.automation.volume.Algorithm
    %
    
    % Copyright 2019 The MathWorks, Inc.
    properties (Constant)
        
        Name = getString(message('images:segmenter:modeFilterName'));
        
        Description = getString(message('images:segmenter:modeFilterDescription'));
        
        Icon = matlab.ui.internal.toolstrip.Icon('volumeSmooth');
        
        ExecutionMode = 'volume';
        
        UseScaledVolume = false;
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Run
        %------------------------------------------------------------------
        function labels = run(obj,~,labels)
            
            labels = modefilt(labels,obj.Parameters.FilterSize);
                        
        end
        
    end
    
    methods (Static)
        
        function obj = getSettings(~)
            obj = images.automation.volume.settings.ModeFilterSettings;
        end
        
    end
    
end

