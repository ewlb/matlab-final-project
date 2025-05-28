classdef Periodic < handle & matlab.mixin.SetGet
    % EventCoalescer - For internal use only.
    
    % Use this class to coalesce app events/interactions into an
    % event fired periodically.
    % This can be used to combine events that would trigger an expensive HG
    % redraw to coalesce mutiple ValueChanging events. This in turn reduces
    % the number of times an event is called (e.g. updating a volume
    % rendering as a user moves a slider, updating document
    % layouts during app resize).
    
    % Copyright 2021-2023 The MathWorks, Inc.
    
    events
        
        PeriodicEventTriggered
        
    end
    
    properties (Dependent)
        
        % Period - Number greater than 0.001 that specifies the delay, in
        % seconds, between executions of TimerFcn.
        % When 'Period', 'Delay' is read only
        %
        % Default = 0.5
        Period
        
        % ExecutionMode - Character vector or string scalar that defines
        % how the timer object schedules timer events. When Running,
        % ExecutionMode is read only. Check MATLAB timer clas for more
        % details.Valid options are:
        % 'fixedRate'    (default)
        % 'fixedDelay'
        % 'fixedSpacing'
        ExecutionMode
        
    end
    
    properties (SetAccess = private, GetAccess = {?uitest.factory.Tester, ?matlab.unittest.TestCase})
        
        Timer
        
        LastTriggerTime (1,6) double
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Event Coalescer
        %------------------------------------------------------------------
        function self = Periodic()
            
            period = 0.5;
            executionMode = 'fixedRate';
            
            self.Timer = timer('Name','IPTPeriodicEventCoalescer',...
                'TimerFcn',@(~,~) periodicTimerCallback(self),...
                'ObjectVisibility','off',...
                'StartDelay',0,...
                'Period',period,...
                'ExecutionMode',executionMode);
            
        end
        
        %------------------------------------------------------------------
        % Periodic Trigger
        %------------------------------------------------------------------
        function trigger(self)

            if ~isvalid(self) || ~isvalid(self.Timer)
                return
            end
            
            self.LastTriggerTime = clock;
            
            if strcmp(self.Timer.Running,'off')

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
        function periodicTimerCallback(self)
            
            if ~isvalid(self)
                return;
            end
            
            % If the trigger hasn't been fired in last (5 * 'Period') seconds,
            % automatically stop the timer. This helps to avoid infinte
            % triggers if the client never calls the stop  method
            if etime(clock,self.LastTriggerTime) > (5 * self.Period)
                self.stop()
            end
            
            notify(self,'PeriodicEventTriggered');
            
        end
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Period
        %------------------------------------------------------------------
        function set.Period(self,val)
            if strcmp(self.Timer.Running,'off')
                self.Timer.Period = val;
            end
        end
        
        function val = get.Period(self)
            val = self.Timer.Period;
        end
        
        %------------------------------------------------------------------
        % Period
        %------------------------------------------------------------------
        function set.ExecutionMode(self,val)
            
            val = validatestring(val,{'fixedRate','fixedDelay','fixedSpacing'});
            if strcmp(self.Timer.Running,'off')
                self.Timer.ExecutionMode = val;
            end
        end
        
        function val = get.ExecutionMode(self)
            val = self.Timer.ExecutionMode;
        end
        
    end
    
end