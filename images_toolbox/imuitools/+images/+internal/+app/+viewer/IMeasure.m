classdef IMeasure < matlab.mixin.SetGetExactNames
% Abstract Helper Base Class that manages the measurements that are drawn
% on the displayed image
% This helper requires only an axes on which the measurement has to be
% drawn.

%   Copyright 2023, The MathWorks, Inc.   

    properties(Access=public, Dependent)
        IsEnabled (1, 1) logical
    end

    properties(GetAccess=public, SetAccess=private, Dependent)
        NumMeas
    end

    properties(GetAccess=protected, SetAccess=private)
        % Stores all measurements that have been drawn in the current
        % session. This includes measurements that have been deleted. This
        % is needed to number the newly drawn measurements correctly.
        MeasObj = [];
    end
    
    properties(Access=private)
        IsEnabledInternal (1, 1) logical = false;
        CurrMeasBeingDrawn = [];
    end

    % Tag prefixes
    properties(Access=protected, Constant)
        % Tag prefix for the ROI object that is drawn
        MeasBaseTag = "Meas_";

        % Tag prefix for the Export Context Menu attached to every ROI
        % object
        ExportMeasMenuBaseTag = "ExportMeas_";
    end

    events(NotifyAccess=protected)
        MeasurementStarted
        MeasurementAdded
        MeasurementRemoved
        MeasurementSelected
        MeasurementCancelled
        ExportMeasurement
    end

    % Construction
    methods(Access=public)
        function obj = IMeasure()
        end

        function delete(obj)
            deleteAll(obj);
        end
    end

    % Setters/Getters
    methods
        function set.IsEnabled(obj, tf)
            obj.IsEnabledInternal = tf;
            enable(obj, tf);
        end

        function tf = get.IsEnabled(obj)
            tf = obj.IsEnabledInternal;
        end

        function val = get.NumMeas(obj)
            if isempty(obj.MeasObj)
                val = 0;
            else
                % Find only valid measurements as the array stores deleted
                % measurements as well.
                val = numel(find(isvalid(obj.MeasObj)));
            end
        end
    end

    methods(Access=public)
        function add(obj, ax, startPoint)
            % Add a new measurement and start drawing.
            measNum = numel(obj.MeasObj)+1;
            newMeas = addImpl(obj, ax, measNum);
            newMeas.LabelTextColor = "white";

            addlistener(newMeas, "DrawingStarted", @(~, ~) reactToDrawingStarted(obj) );
            addlistener(newMeas, "MovingROI", @(src, ~) reactToMovingROI(obj, src));
            addlistener(newMeas, "ROIMoved", @(src, ~) reactToROIMoved(obj, src));
            addlistener(newMeas, "DrawingFinished", @(src, ~) reactToDrawingFinished(obj, src));
            addlistener(newMeas, "DeletingROI", @(src, ~) reactToDeletingROI(obj, src));
            addlistener(newMeas, "ROIClicked", @(src, evt) reactToROISelected(obj, src, evt));

            uimenu( Parent=newMeas.ContextMenu, ...
                    Label="Export Measurement", ...
                    Tag=obj.ExportMeasMenuBaseTag + measNum, ...
                    MenuSelectedFcn=@(src, ~) exportMeas(obj, src) );

            obj.CurrMeasBeingDrawn = newMeas;

            beginDrawingFromPoint(newMeas, startPoint);
        end

        function deleteSpecific(obj, meas)
            % Delete a specific measurement

            idx = find(obj.MeasObj == meas);
            if isempty(idx)
                return;
            end

            % Do not remove the measurement from the array. This is done to
            % easily index into measurements drawn during export.
            delete(obj.MeasObj(idx));
            notify(obj, "MeasurementRemoved");
        end

        function deleteAll(obj)
            delete(obj.MeasObj);
            obj.MeasObj = [];
        end

        function meas = getAllMeas(obj)
            % Provide values of all the valid measurements drawn on the
            % image. It is a dictionary containing the mapping of Measure
            % Labels -> Measure Values 

            meas = dictionary();
            for cnt = 1:numel(obj.MeasObj)
                if ~isvalid(obj.MeasObj(cnt))
                    continue;
                end

                measData = createMeasData(obj, cnt);
                measLabel = measData.Label;
                measData = rmfield(measData, "Label");
                meas(measLabel) = measData;
            end
        end
    end

    % Abstract methods
    methods(Access=protected, Abstract)
        % Implementation that adds the UI object to perform the measurement
        addImpl(obj, ax, measNum);

        % Implementation to perform the measurement computation
        [measVal, measLabel] = computeMeasImpl(obj, src);

        measType = getMeasType(obj);
    end

    % Callbacks that are used by child classes as well.
    methods(Access=protected, Sealed)
        function reactToROIMoved(obj, src)
            % Compute and display measurements once the shape has completed
            % the move (which can mean adding a new vertex as well)

            % Measurement was cancelled. Do not perform any computations on
            % it.
            if isempty(src.Position)
                return;
            end

            src.LabelVisible = "on";
            [src.UserData, src.Label] = computeMeasImpl(obj, src);
        end
    end

    % Callbacks used only by the base class
    methods(Access=private)
        function reactToDrawingStarted(obj)
            notify(obj, "MeasurementStarted");
        end

        function reactToMovingROI(~, src)
            % Hide any measurement labels when shape is being updated to
            % ensure label does not overlay on the image region of user
            % interest
            src.LabelVisible = "off";
        end

        function reactToDrawingFinished(obj, src)
            % Actions to perform when drawing is complete

            % Measurement was cancelled. Do not store it.
            if isempty(src.Position)
                notify(obj, "MeasurementCancelled");
            else
                % Store the currently drawn measurement
                obj.MeasObj = [obj.MeasObj; src];
                obj.CurrMeasBeingDrawn = [];
    
                notify(obj, "MeasurementAdded");
            end
        end

        function reactToDeletingROI(obj, src)
            % Delete the selected measurement
            
            deleteSpecific(obj, src);
        end

        function reactToROISelected(obj, src, evt)
            % Handle ROI selection

            % Right click on ROI brings up the Context Menu. So do not
            % treat it as a selection. As otherwise, the bringToFront call
            % blows up the parent of the ContextMenu causing it not to
            % appear ton Linux/Mac. See g3039057 for details
            if evt.SelectionType =="right"
                return;
            end
            
            bringToFront(src);

            measType = getMeasType(obj);
            data = struct("Measurement", src, "MeasType", measType);
            
            notify( obj, "MeasurementSelected", ...
                    images.internal.app.viewer.ViewerEventData(data) );
        end
    end

    % Private Helpers
    methods(Access=private)
        function enable(obj, tf)
            % Helper function that makes all the valid measurments visible

            for cnt = 1:numel(obj.MeasObj)
                % The MeasObj array holds on to instances of deleted
                % measurements. This is done to easily index into
                % measurements drawn during export. Check for validity
                % before making it visible.
                if isvalid(obj.MeasObj(cnt))
                    obj.MeasObj(cnt).Visible = tf;
                end
            end
        end

        function exportMeas(obj, src)
            % Export the values of the selected measurement

            % Obtain the index of the measurement being exported
            measIdx = str2double(extractAfter(src.Tag, obj.ExportMeasMenuBaseTag));

            measData = createMeasData(obj, measIdx);

            evtData = images.internal.app.viewer.ViewerEventData(measData);
            notify(obj, "ExportMeasurement", evtData);
        end

        function measData = createMeasData(obj, measIdx)
            % The Label has the format "<MEAS_TYPE><IDX> = <VALUE>". For
            % example, a distance measurement label appears as "D1 = 30".
            % The "<MEAS_TYPE><IDX>" is used as the exported variable name.
            % Extract it from the label string.
            measLabel = strip(extractBefore(obj.MeasObj(measIdx).Label, "="));

            measData = struct( "Label", measLabel, ...
                               "Position", obj.MeasObj(measIdx).Position, ...
                               "Value", obj.MeasObj(measIdx).UserData );
        end
    end
end