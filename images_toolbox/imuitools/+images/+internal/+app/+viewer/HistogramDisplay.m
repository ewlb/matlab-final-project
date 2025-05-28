classdef HistogramDisplay < matlab.mixin.SetGetExactNames
% Class that handles the Histogram Display for the App

%   Copyright 2023, The MathWorks, Inc.

    properties(Access=public, Dependent)
        IsEnabled (1, 1) logical
        ImageData (:, :)
        HistRange (1, 2) double
    end

    properties(Access=private)
        ImageDataInternal (:, :) = zeros(0, 0);
        HistRangeInternal (1, 2) double = [0 0];

        % Manages the frequency at which Contrast Change events are fired
        % to avoid too many calls to imadjust
        PeriodicTimer
    end

    properties(Access=?imtest.apptest.imageViewerTest.PropertyAccessProvider)
        HistogramHdl = []
        HistListener = []

        ParentPanel = [];
        HistAxes = [];
    end

    events
        ContrastSliderChanged
    end

    % Construction
    methods
        function obj = HistogramDisplay(app, im)
            histFigPanel.Title = ...
                getString(message("images:commonUIString:histogram"));
            histFigPanel.Tag = "HistogramPanel";
            histFigPanel.Region = "bottom";

            obj.ParentPanel = matlab.ui.internal.FigurePanel(histFigPanel);
            obj.ParentPanel.Figure.AutoResizeChildren = "off";
            obj.ParentPanel.Opened = false;
            add(app, obj.ParentPanel);

            obj.ParentPanel.Figure.SizeChangedFcn = @(~, ~) resize(obj);

            obj.HistogramHdl = images.internal.app.utilities.Histogram(obj.ParentPanel.Figure);
            % Match imhist default value
            obj.HistogramHdl.NumBins = 256;
            obj.HistogramHdl.Visible = true;
            obj.HistogramHdl.Enable = "on";
            obj.HistListener = addlistener( obj.HistogramHdl, ...
                         "ContrastChanged", ...
                         @(~, ~) reactToContrastChanged(obj) );


            % This timer fires the ContrastSliderChanged event at specified
            % intervals. This avoids excessive calls to imadjust which
            % results in jerky histogram slider motion
            obj.PeriodicTimer = images.internal.app.utilities.eventCoalescer.Periodic();
            obj.PeriodicTimer.Period = 0.1;
            addlistener( obj.PeriodicTimer, "PeriodicEventTriggered", ...
                         @(~, ~) reactToTimerTriggered(obj) );

            obj.ImageData = im;
            obj.HistRange = [NaN NaN];
        end

        function delete(obj)
            if isvalid(obj.PeriodicTimer)
                stop(obj.PeriodicTimer);
                delete(obj.PeriodicTimer);
            end

            if isvalid(obj.HistogramHdl)
                delete(obj.HistogramHdl);
            end
        end

    end

    % Setters/Getters
    methods
        function set.IsEnabled(obj, tf)
            assert( ~tf || ...
                    (tf && ~isempty(obj.ImageDataInternal)), ...
                    "Valid Image Data must be provided before enabling app" );

            obj.ParentPanel.Opened = tf;
        end

        function tf = get.IsEnabled(obj)
            tf = obj.ParentPanel.Opened;
        end

        function set.ImageData(obj, im)
            obj.ImageDataInternal = im;
            if isempty(im)
                obj.HistRangeInternal = [0 0];
            else
                initHistogram(obj);
            end
        end

        function im = get.ImageData(obj)
            im = obj.ImageDataInternal;
        end

        function set.HistRange(obj, range)
            if any(isnan(range))
                obj.HistRangeInternal = ...
                    getrangefromclass(obj.ImageDataInternal);
            else
                obj.HistRangeInternal = range;
            end

            obj.HistogramHdl.SelectedHistRange = obj.HistRangeInternal;
        end

        function range = get.HistRange(obj)
            range = obj.HistRangeInternal;
        end
    end

    % Callbacks
    methods(Access=private)
        function reactToContrastChanged(obj)
            % Trigger the timer. For an already running timer, this just
            % refreshes the last time it was called. This ensures the timer
            % is not shut down.
            trigger(obj.PeriodicTimer);
        end

        function reactToTimerTriggered(obj)
            % Obtain the current slider location and notify clients.
            clim = obj.HistogramHdl.SelectedHistRange;
            evtData = images.internal.app.viewer.ViewerEventData(clim);
            notify(obj, "ContrastSliderChanged", evtData);
        end
    end

    % Helper functions
    methods(Access=private)
        function initHistogram(obj)
            obj.HistogramHdl.UseDataBoundsAsDefaultInteractionLimits = true;
            reset(obj.HistogramHdl, getrangefromclass(obj.ImageDataInternal));
            obj.HistListener.Enabled = false;
            obj.HistogramHdl.Interactive = true;
            obj.HistListener.Enabled = true;
            if isfloat(obj.ImageDataInternal)
                gapVal = eps("double");
            else
                gapVal = 1;
            end
            obj.HistogramHdl.MinGapBetweenMinMaxMarkers = gapVal;
            update(obj.HistogramHdl, obj.ImageDataInternal);
            obj.HistogramHdl.UseDataBoundsAsDefaultInteractionLimits = false;
        end

        function resize(obj)
            resize(obj.HistogramHdl);
        end
    end
end


