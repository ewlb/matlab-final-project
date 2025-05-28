classdef Measurement < matlab.mixin.SetGet
% Helper class that manages all the Measurements that are drawn on the app.
% This class simply tracks the number of measurements drawn of each type.

%   Copyright 2023 The MathWorks, Inc.

    % Flags to show/hide each specific measurement type supported by the
    % app
    properties(Access=public, Dependent)
        IsDistMeasEnabled
        IsAreaMeasEnabled
    end

    % Total number of measurements that have currently been drawn on the
    % image
    properties(GetAccess=public, SetAccess=private, Dependent)
        NumMeas (1, 1) double

        % Stores all the currently drawn distance measurements
        DistMeas

        % Stores all the currently drawn area measurements
        AreaMeas
    end

    % Instances of classes that actually implement the measurement actions.
    % These classes manage the lifetime of the UI objects drawn on the
    % image and perform the measurement calculations. Each of these classes
    % maintain a list of all measurements drawn of a specific type.
    properties(Access=private)
        MeasDist (1, 1) images.internal.app.viewer.MeasureDist
        MeasArea (1, 1) images.internal.app.viewer.MeasureArea
    end

    events
        MeasurementStarted
        MeasurementCancelled
        MeasurementSelected
        NumMeasurementsChanged
        ExportMeasurement
    end

    methods
        function obj = Measurement()
            obj.MeasDist = images.internal.app.viewer.MeasureDist();
            wireUpListeners(obj, obj.MeasDist);

            obj.MeasArea = images.internal.app.viewer.MeasureArea();
            wireUpListeners(obj, obj.MeasArea);
        end

        function delete(obj)
            delete(obj.MeasDist);
            delete(obj.MeasArea);
        end
    end

    % Setters/Getters
    methods
        function set.IsDistMeasEnabled(obj, tf)
            obj.MeasDist.IsEnabled = tf;
        end

        function tf = get.IsDistMeasEnabled(obj)
            tf = obj.MeasDist.IsEnabled;
        end

        function set.IsAreaMeasEnabled(obj, tf)
            obj.MeasArea.IsEnabled = tf;
        end

        function tf = get.IsAreaMeasEnabled(obj)
            tf = obj.MeasArea.IsEnabled;
        end

        function numMeas = get.NumMeas(obj)
            numMeas = obj.MeasDist.NumMeas + obj.MeasArea.NumMeas;
        end

        function distMeas = get.DistMeas(obj)
            distMeas = getAllMeas(obj.MeasDist);
        end

        function areaMeas = get.AreaMeas(obj)
            areaMeas = getAllMeas(obj.MeasArea);
        end
    end

    % Public methods
    methods(Access=public)
        function addDistMeas(obj, ax, startPoint)
            add(obj.MeasDist, ax, startPoint);
        end

        function addAreaMeas(obj, ax, startPoint)
            add(obj.MeasArea, ax, startPoint);
        end

        function removeMeas(obj, meas, measType)
            switch(measType)
                case "distance"
                    deleteSpecific(obj.MeasDist, meas);
                case "area"
                    deleteSpecific(obj.MeasArea, meas);
                otherwise
                    assert(false, "Invalid Measurement Type");
            end
        end

        function showMeas(obj, tf)
            obj.MeasDist.IsEnabled = tf;
            obj.MeasArea.IsEnabled = tf;
        end

        function deleteAll(obj)
            deleteAll(obj.MeasDist);
            deleteAll(obj.MeasArea);
        end
    end

    % Callbacks
    methods(Access=private)
        function reactToMeasStarted(obj)
            notify(obj, "MeasurementStarted");
        end

        function reactToMeasCancelled(obj)
            notify(obj, "MeasurementCancelled");
        end

        function reactToMeasSelected(obj, evtData)
            notify( obj, "MeasurementSelected", ...
                    images.internal.app.viewer.ViewerEventData(evtData.Data) );
        end

        function reactToMeasChanged(obj)
            evtData = images.internal.app.viewer.ViewerEventData(obj.NumMeas);
            notify(obj, "NumMeasurementsChanged", evtData);
        end

        function reactToExportMeas(obj, evt)
            evtData = images.internal.app.viewer.ViewerEventData(evt.Data);
            notify(obj, "ExportMeasurement", evtData);
        end
    end

    % Helper methods
    methods(Access=private)
        function wireUpListeners(obj, eventSource)
            addlistener( eventSource, "MeasurementStarted", ...
                         @(~, ~) reactToMeasStarted(obj) );
            addlistener( eventSource, "MeasurementCancelled", ...
                         @(~, ~) reactToMeasCancelled(obj) );
            addlistener( eventSource, "MeasurementSelected", ...
                         @(~, evt) reactToMeasSelected(obj, evt) );
            addlistener( eventSource, "MeasurementAdded", ...
                         @(~, ~) reactToMeasChanged(obj) );
            addlistener( eventSource, "MeasurementRemoved", ...
                         @(~, ~) reactToMeasChanged(obj) );
            addlistener( eventSource, "ExportMeasurement", ...
                         @(~, evt) reactToExportMeas(obj, evt) );
        end
    end
end