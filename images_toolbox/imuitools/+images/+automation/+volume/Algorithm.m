classdef (Abstract) Algorithm < handle
    %
    
    % Copyright 2019 The MathWorks, Inc.
    
    events (Hidden)
        
        StopAutomation
        
    end
    
    
    properties (Abstract, Constant)
        
        Name
        
        Description
        
        Icon
        
        ExecutionMode char {mustBeMember(ExecutionMode,{'slice','volume'})}
        
        UseScaledVolume (1,1) logical
        
    end
    
    
    properties (SetAccess = {?images.internal.app.labeler.volume.data.Automation})
        
        SelectedLabel char
        
        Parameters struct
        
    end
    
    
    methods (Abstract)
    
        labels = run(obj,I,labels)
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Algorithm
        %------------------------------------------------------------------
        function obj = Algorithm(selectedLabel,settingsStruct)
            
            obj.SelectedLabel = selectedLabel;
            obj.Parameters = settingsStruct;
            
        end
        
        %------------------------------------------------------------------
        % Initialize
        %------------------------------------------------------------------
        function initialize(~)
            
            % Overload this method to initalize variables before the
            % automation algorithm executes.
            
        end
        
        %------------------------------------------------------------------
        % Stop
        %------------------------------------------------------------------
        function stop(obj)
            
            notify(obj,'StopAutomation');
            
        end
        
    end
    
    
    methods (Static)
        
        function obj = getSettings(~)
            obj = [];
        end
        
    end

    
end