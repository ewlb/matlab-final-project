% This undocumented class may be removed in a future release.

%   obj = cancellableWaitbar(dlgName, statusFormatter, totalImages, processedImages)
%
%   The title of the dialog will be:  DLGNAME [X]% completed.  So a typical
%   value for dlgName might be:
%
%       'Block Processing:'
%
%   There are 2 lines of text that appear above the actual wait bar.  The
%   top line is defined by the STATUSFORMATTER.  The status formatter
%   should contain a "%d", where it will receive the total number of images
%   to be processed.  For example a status formatter might look like:
%
%       'Processing %d blocks'
%
%   TOTALIMAGES should be the total number of images/elements that the
%   waitbar will process.  PROCESSEDIMAGES should be the number of
%   images/elements (out of TOTALIMAGES) that were processed BEFORE
%   creating the waitbar.
%
%   The UPDATE(PROCESSED_IMAGES) method will update the wait bar.
%   PROCESSED_IMAGES should be the total number of images that are
%   completed, including any that may have been processed before the
%   waitbar was created (the PROCESSEDIMAGES from the constructor).  If the
%   argument is omitted, the waitbar just increments by 1.

%   Copyright 2008-2022 The MathWorks, Inc.

classdef cancellableWaitbar < handle
    
    properties (SetAccess = 'private',GetAccess = 'public')
        dlgName
        statusFormatter
        
        % gui components
        hWait
        cancelPressed
        % image counters
        totalImages
        processedImages
        lastUpdateImage
        % times
        startTime
        lastTime
        % timing buffers
        updateTimes
        updateStepSizes
        % time strings
        isCalculating
        elapsedTimeStr
        estimatedTimeStr
    end

    properties (Access = private, Constant)
        % Disable all waitbar logic if running on a thread/worker. 
        DisableWaitBar = parallel.internal.pool.isPoolWorker()
    end
    
    methods
        function obj = cancellableWaitbar(dlgName, statusFormatter, totalImages, processedImages, params)
            arguments
                dlgName
                statusFormatter
                totalImages
                processedImages = 0
                params.Cancellable (1,1) logical = true
                params.Parent (1,1) {mustBeA(params.Parent, ["matlab.ui.Figure","matlab.ui.container.internal.AppContainer"])}
            end

            if obj.DisableWaitBar
                return
            end
            
            if nargin > 3
                obj.resetWaitbarState(dlgName, statusFormatter, totalImages, processedImages);
            else
                obj.resetWaitbarState(dlgName, statusFormatter, totalImages);
            end
            
            
            if isfield(params,'Parent')
                % Use a UIPROGRESSDLG. This is for use in App clients.
                obj.hWait = uiprogressdlg(params.Parent);
                obj.hWait.Cancelable = params.Cancellable;
            else
                % create waitbar dialog
                if params.Cancellable
                    obj.hWait = waitbar(0, '', 'CreateCancelBtn', @obj.cancel);
                    set(obj.hWait, 'CloseRequestFcn', @obj.cancel);
                else
                    obj.hWait = waitbar(0, '');
                end
            end
        end
        
        function obj = resetWaitbarState(obj, dlgName, statusFormatter, totalImages, processedImages)
            
            obj.dlgName = dlgName;
            obj.statusFormatter = statusFormatter;
            obj.processedImages = 0;
            
            % initial images processed
            obj.totalImages = totalImages;
            if nargin > 4
                obj.processedImages = processedImages;
            else
                obj.processedImages = 0;
            end
            obj.lastUpdateImage = obj.processedImages;
            
            % initialize all flags / counters / strings
            obj.cancelPressed = false;
            obj.estimatedTimeStr = getString(message('images:textWaitUpdater:calculating'));
            obj.updateTimes = [];
            obj.updateStepSizes = [];
            obj.isCalculating = true;
            
            % Put the percentage done in the figure title, so it shows up
            % when minimized.
            percent_done = round(100 * (obj.processedImages / obj.totalImages));
            title = sprintf('%s %d%% %s', obj.dlgName, percent_done,...
                getString(message('images:textWaitUpdater:completed')));
            if isa(obj.hWait,'matlab.ui.dialog.ProgressDialog')
                obj.hWait.Title = title;
            else
                set(obj.hWait, 'Name', title);
            end
            
            % start timing
            obj.startTime = tic;
            obj.lastTime = obj.startTime;
            
            % do a single update
            obj.update(obj.processedImages);
            
        end
        
        function update(obj,processed_images)

            if obj.DisableWaitBar
                return
            end
            
            if isa(obj.hWait,'matlab.ui.dialog.ProgressDialog') && ...
                    obj.hWait.CancelRequested
                obj.cancel();
            end
            
            % increment our counter
            if nargin > 1
                obj.processedImages = processed_images;
            else
                obj.processedImages = obj.processedImages + 1;
            end
            
            % update at most once per second (updates are expensive)
            current_time = toc(obj.lastTime);
            if current_time < 1
                return
            end
            
            % we are going to update, how big is this update?
            current_step_size = obj.processedImages - obj.lastUpdateImage;
            
            if(current_step_size==0)
                return; %nothing to do
            end
            
            % update time estimates
            obj.updateTimeEstimates(current_time,current_step_size);
            
            obj.refreshWaitbar()
            
            % reset counters
            obj.lastUpdateImage = obj.processedImages;
            obj.lastTime = tic;
            
        end
        
        function destroy(obj)
            
            delete(obj.hWait);
            obj.hWait = [];
            
        end
        
        function cancel(obj, varargin)
            
            obj.destroy;
            obj.cancelPressed = true;
            
        end
        
        function tf = isCancelled(obj)
            
            tf = obj.cancelPressed;
            
        end
        
        function refreshWaitbar(obj)

            if obj.DisableWaitBar
                return
            end

            % update dialog text and bar
            pct = min((obj.processedImages / obj.totalImages), 1);
            if obj.isCalculating
                str = getString(message('images:textWaitUpdater:timeCalculating'));
                status_msg = sprintf([obj.statusFormatter '\n' str],...
                    obj.totalImages);
            else
                str = getString(message('images:textWaitUpdater:timeXofY', ...
                    obj.elapsedTimeStr, obj.estimatedTimeStr));
                status_msg = sprintf([obj.statusFormatter '\n' str],...
                    obj.totalImages);
            end
            % update waitbar only if its not cancelled by now
            if isempty(obj.hWait)
                return
            end
            
            title = sprintf('%s %d%% %s',...
                obj.dlgName,round(100*pct),getString(message('images:textWaitUpdater:completed')));
            if isa(obj.hWait,'matlab.ui.dialog.ProgressDialog')
                obj.hWait.Message = status_msg;
                obj.hWait.Title = title;
                obj.hWait.Value = pct;
            elseif isvalid(obj.hWait)
                waitbar(pct, obj.hWait,status_msg);
                set(obj.hWait, 'Name', title);
                %else
                % the old waitbar was closed, but Cancellable==false, so
                % just ignore.
            end
        end
    end
    
    methods (Access = 'private')
        function updateTimeEstimates(obj,current_time,current_step_size)
            
            % update elapsed time string
            elapsed_time = toc(obj.startTime);
            obj.elapsedTimeStr = getTimeStr(elapsed_time);
            
            % update our set of times
            timeBufferSize = 5;
            if numel(obj.updateTimes) < timeBufferSize
                
                % add to buffer of update times
                obj.updateTimes     = [current_time obj.updateTimes];
                obj.updateStepSizes = [current_step_size obj.updateStepSizes];
                
            else
                
                % set flag
                obj.isCalculating = false;
                % update buffer of update times
                obj.updateTimes = [current_time obj.updateTimes(1:timeBufferSize-1)];
                obj.updateStepSizes = [current_step_size obj.updateStepSizes(1:timeBufferSize-1)];
                % compute new estimate
                timePerImage = sum(obj.updateTimes) / sum(obj.updateStepSizes);
                remainingTime = timePerImage * (obj.totalImages - obj.processedImages);
                estTotalTime = elapsed_time + remainingTime;
                obj.estimatedTimeStr = getTimeStr(estTotalTime);
                
            end
            
        end
    end
    
end


function str = getTimeStr(time)

% convert to serial date number (units == days)
seconds_per_day = 60 * 60 * 24;
time = time / seconds_per_day;

hour = 1/24;
if time > hour && time < 1 % Time in hours
    str = datestr(time, 'HH:MM:SS');
    if str(1) == '0'
        str(1) = '';
    end
elseif time >= 1 % Time in days
    str = datestr(time, 'dd:HH:MM:SS');
    if str(1) == '0'
        str(1) = '';
    end
else             % Time in minutes
    str = datestr(time, 'MM:SS');
end

end