classdef Delayed < handle & matlab.mixin.SetGet
    % EventCoalescer - For internal use only.
    
    % Use this class to coalesce app events/interactions into a single
    % event. This can be used to combine events that would trigger an
    % expensive HG redraw (e.g. updating a volume rendering as a user clicks
    % a button several times, updating document layouts during app resize).
    
    % Copyright 2021-2023 The MathWorks, Inc.
    
    events
        
        DelayedEventTriggered
        
    end
    
    properties (Dependent)
        
        % Delay - Number greater than or equal to 0 that specifies the
        % delay, in seconds, between the call to 'trigger' method and
        % broadcasting 'DelayedEventTriggered' event.
        % When 'Running', 'Delay' is read only
        %
        % Default = 0.5
        Delay
        
    end
    
    properties (SetAccess = private, GetAccess = {?uitest.factory.Tester, ?matlab.unittest.TestCase})
        
        Timer
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Event Coalescer
        %------------------------------------------------------------------
        function self = Delayed()
            
            delay = 0.5;
            self.Timer = timer('Name','IPTDelayedEventCoalescer',...
                'TimerFcn',@(~,~) delayTimerCallback(self),...
                'ObjectVisibility','off',...
                'StartDelay',delay,...
                'ExecutionMode','singleShot');
            
        end
        
        %------------------------------------------------------------------
        % Delay Trigger
        %------------------------------------------------------------------
        function trigger(self)

            if ~isvalid(self) || ~isvalid(self.Timer)
                return
            end
            
            if strcmp(self.Timer.Running,'on')
                stop(self.Timer);
            end
            
            try
                % Stop is a non-blocking MATLAB call. It does not clear if
                % anything is already added to the TimerExecution queue.
                % Because of this, 'start' can throw an error if something
                % is already in the Timer queue
                start(self.Timer);

            catch ME
                if isequal(ME.identifier, 'MATLAB:timer:alreadystarted')
                    % Just skip the start call
                    return
                else
                    rethrow(ME)
                end

            end
            
        end
        
        %------------------------------------------------------------------
        % Stop
        %------------------------------------------------------------------
        function stop(self)
            
            if isvalid(self.Timer)
                stop(self.Timer); 
            end
            
        end
        
        %------------------------------------------------------------------
        % Delete
        %------------------------------------------------------------------
        function delete(self)
            
            if isvalid(self.Timer)
                stop(self.Timer);
                delete(self.Timer);
            end
            
        end
        
    end
    
    methods (Access = private)
        
        %--Delay Timer Callback--------------------------------------------
        function delayTimerCallback(self)
            
            if ~isvalid(self)
                return;
            end
            
            notify(self,'DelayedEventTriggered');
            
        end
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Delay
        %------------------------------------------------------------------
        function set.Delay(self,val)
            if strcmp(self.Timer.Running,'off')
                self.Timer.StartDelay = val;
            end
        end
        
        function val = get.Delay(self)
            val = self.Timer.StartDelay;
        end
        
    end
    
end