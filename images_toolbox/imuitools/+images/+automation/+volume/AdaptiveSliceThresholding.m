classdef AdaptiveSliceThresholding < images.automation.volume.Algorithm
    %
    
    % Copyright 2019 The MathWorks, Inc.
    properties (Constant)
        
        Name = getString(message('images:segmenter:adaptThreshName'));
        
        Description = getString(message('images:segmenter:adaptThreshDescription'));
        
        Icon = matlab.ui.internal.toolstrip.Icon('volumeAdaptive');
        
        ExecutionMode = 'slice';
        
        UseScaledVolume = false;
        
    end
    
    properties
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Run
        %------------------------------------------------------------------
        function labels = run(obj,I,labels)
            
            if size(I,3) == 3
                I = rgb2gray(I);
            end
            
            T = adaptthresh(I);
            mask = imbinarize(I,T);
            
            labels(labels == obj.SelectedLabel) = missing;
            labels(mask) = obj.SelectedLabel;
            
        end
        
    end
    
end