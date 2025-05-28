classdef ContrastTab < images.internal.app.viewer.TabBase
% Helper class that creates and manages the Contrast Tab in the Toolstrip
% of the ImageViewer app.

%   Copyright 2023-2024 The Mathworks, Inc.

    properties ( SetAccess = ?images.internal.app.viewer.ImageViewer, ...
                 GetAccess = { ?uitest.factory.Tester, ...
                               ?images.internal.app.viewer.ImageViewer, ...
                               ?imtest.apptest.imageViewerTest.PropertyAccessProvider} )

        % Contrast Tab: Histogram section Controls
        HistogramTglBtn       matlab.ui.internal.toolstrip.ToggleButton

        % Contrast Tab: Data Range section Controls
        SourceLabelColumn           matlab.ui.internal.toolstrip.Column
        SourceMinEF                 matlab.ui.internal.toolstrip.EditField
        SourceMaxEF                 matlab.ui.internal.toolstrip.EditField

        % Contrast Tab: Window Level section Controls
        WindowSection           matlab.ui.internal.toolstrip.Section

        % Valid Values: [dataTypeMin currentRangeMaxSpVal)
        RangeMinSp              matlab.ui.internal.toolstrip.Spinner

        % Valid Values: (currentRangeMinSpVal, datatypeMax]
        RangeMaxSp              matlab.ui.internal.toolstrip.Spinner

        RangeMinDropperBtn      matlab.ui.internal.toolstrip.Button
        RangeMaxDropperBtn      matlab.ui.internal.toolstrip.Button

        % Valid Values: (0 dataTypeRange)
        RangeWidthSp            matlab.ui.internal.toolstrip.Spinner

        % Valid Values: (datatypeMin datatypeMax)
        RangeCenterSp           matlab.ui.internal.toolstrip.Spinner

        PresetDD                matlab.ui.internal.toolstrip.DropDown

        % Valid Values: (0, 100)
        OutliersSp              matlab.ui.internal.toolstrip.Spinner
        
        RestoreSection          matlab.ui.internal.toolstrip.Section
        RestoreBtn              matlab.ui.internal.toolstrip.Button
    end

    properties(GetAccess=public, SetAccess=private)
        CurrentState = struct.empty();
    end

    % Maintain a copy of the source image that was loaded into the app.
    properties(Access=private)
        SrcImage (:, :, :)

        % Store the toolstrip values before the user starts modifying the
        % settings. These are needed to restore the app in the event the
        % user hits Restore. 
        PrevMin             (1, 1) double
        PrevMax             (1, 1) double
        PrevDDSelection     (1, 1) double
        PrevOutliersPct     (1, 1) double

        % Stores the Delta value that needs to be used to accurately
        % specify limits. This is required because the Spinner always
        % includes the limit values.
        SpinnerLimitsDelta (1, 1) double = 1

        % Stores the previous Elim Outliers (%) value. This is needed to
        % restore the value of spinner in the event current spinner value
        % results in a limits of [0, 1]. The ValueChanged event does not
        % give the old value.
        CurrOutliersSpValue (1, 1) double = 2
    end

    properties(Access=private, Constant)
        % List of controls in the contrast tab whose state has to be cached
        ControlsList = images.internal.app.viewer.createControlsList( ...
                            ?images.internal.app.viewer.ContrastTab, ...
                            ["Btn", "DD", "EF", "Sp"] );

        MinDropperPointerData = makeDropperPointer("min");
        MaxDropperPointerData = makeDropperPointer("max");
    end

    events
        ContrastChanged
        ShowHistogramPressed
        RangeDropperClicked
        ContrastUndoPressed
    end

    % Construction
    methods
        function obj = ContrastTab()
            obj@images.internal.app.viewer.TabBase();
            obj.Tab = matlab.ui.internal.toolstrip.Tab( getString( ...
                        message("images:imageViewer:contrastTab") ) );
            obj.Tab.Tag = "ContrastTab";

            createHistogramSection(obj);
            createSourceDataSection(obj);
            createAdjustContrastSection(obj);
            createRestoreSection(obj);

            reset(obj);
        end
    end

    % Interface methods
    methods(Access=public)
        function updateOnSrcChange(obj, im, tabGroup, tabLoc)
            % Update the Contrast Tab controls when a new image is loaded
            % into the image

            if nargin == 3
                tabLoc = 1;
            end

            % The tab is enabled only when the image is a non-empty, single
            % channel, non-logical matrix with all pixel values within data
            % range
            isEnabled = ~( isempty(im) || islogical(im) || ...
                          (size(im, 3) ~= 1)  || ...
                          images.internal.app.viewer.containsOutOfRangePixels(im) );

            if isEnabled
                updateImage(obj, im);
                obj.HistogramTglBtn.Enabled = true;
                enableAll(obj.SourceLabelColumn);
                enableAll(obj.WindowSection);
                obj.OutliersSp.Enabled = false;
                images.internal.app.viewer.showTab(tabGroup, obj.Tab, tabLoc);
            else
                disableAll(obj.Tab);
                reset(obj);
                images.internal.app.viewer.hideTab(tabGroup, obj.Tab);
            end
        end

        function updateRange(obj, range, options)
            % Update the spinners and optionally other elements for a
            % given range
            arguments
                obj (1, 1) images.internal.app.viewer.ContrastTab
                range (1, 2)
                options.RangeType (1, 1) string { mustBeMember( ...
                            options.RangeType, ...
                            ["datatype", "source", "custom", "previous"] ) } ...
                                                        = "custom"
            end

            assert( ~isempty(obj.SrcImage), ...
                    "SrcImage must be non-empty before setting range" );

            % Compute the width and center of the range specified.
            if ~isfloat(obj.SrcImage)
                range = floor(range);
                dispWidth = range(2) - range(1);
                dispCenter = range(1) + ceil(dispWidth/2);
            else
                dispWidth = range(2) - range(1);
                dispCenter = range(1) + dispWidth/2;
            end

            if range(1) == range(2)
                % Update the spinner component limits to ensure the range
                % value is included in the limits
                obj.RangeMinSp.Limits(2) = range(2);
                obj.RangeMinSp.Value = range(1);

                obj.RangeMaxSp.Limits(1) = range(1);
                obj.RangeMaxSp.Value = range(2);
            else
                % Update the Limits of the RangeMin and RangeMax spinners
                obj.RangeMinSp.Limits(2) = range(2) - obj.SpinnerLimitsDelta;
                obj.RangeMinSp.Value = range(1);

                obj.RangeMaxSp.Limits(1) = range(1)  + obj.SpinnerLimitsDelta;
                obj.RangeMaxSp.Value = range(2);
            end

            % The limits for the width and center are impacted only by the
            % datatype of the source image.
            obj.RangeWidthSp.Value = dispWidth;
            obj.RangeCenterSp.Value = dispCenter;

            % Updating the range indicates the contrast has been updated.
            % Hence, the restore button is enabled.
            switch(options.RangeType)
                case "datatype"
                    updatePresetDD(obj, 1);
                    % A OutliersPct Value of 100 is the same as "Match
                    % Datatype Range". So the app will automatically switch
                    % to it. If the pctVal is not restored the value prior
                    % to the current value, the users will never be able to
                    % select "Elim Outliers" as the pctVal will always
                    % result in a limit if [0, 1] which will cause the app
                    % to switch the "Match Datatype Range".
                    if obj.OutliersSp.Value == 100
                        obj.OutliersSp.Value = obj.CurrOutliersSpValue;
                    end
                    enableRestoreBtnState(obj, false);
                case "source"
                    updatePresetDD(obj, 2);
                    enableRestoreBtnState(obj, true);
                case "custom"
                    updatePresetDD(obj, -1);
                    enableRestoreBtnState(obj, true);
                case "previous"
                    % Do nothing
                otherwise
                    assert(false, "Invalid Range Type");
            end
        end

        function restoreState(obj, state)
            % Store the controls on the contrast tab to the specified
            % state. This impacts whether a control is enabled/disabled and
            % not its actual value.

            fn = string(fieldnames(state));
            for cnt = 1:numel(fn)
                propName = fn(cnt);
                if isprop(obj, propName)
                   obj.(propName).Enabled = state.(propName);
                end
            end
        end
    end

    % Getters/Setters
    methods
        function val = get.CurrentState(obj)
            % Get the current state of the controls of the Contrast Tab

            for cnt = 1:numel(obj.ControlsList)
                cname = obj.ControlsList(cnt);
                val.(cname) = obj.(cname).Enabled;
            end
        end
    end


    % Helpers
    methods(Access=private)
        function createHistogramSection(obj)
            import matlab.ui.internal.toolstrip.*;

            % Histogram
            section = addSection( obj.Tab, ...
                            getString(message("images:commonUIString:histogram")) );
            column = section.addColumn();
            obj.HistogramTglBtn = ToggleButton( ...
                    getString(message("images:imageViewer:interactiveHistogram")), ...
                    Icon("histogramToolstripPlot") );
            obj.HistogramTglBtn.Tag = "Histogram";
            obj.HistogramTglBtn.Enabled = false;
            obj.HistogramTglBtn.Description = ...
                    getString(message("images:imageViewer:interactiveHistogramTooltip"));
            obj.HistogramTglBtn.Value = false;
            addlistener( obj.HistogramTglBtn, "ValueChanged", ...
                         @(~,~) reactToHistogramPressed(obj) );
            column.add(obj.HistogramTglBtn);
        end

        function createSourceDataSection(obj)
            import matlab.ui.internal.toolstrip.*;

            % Data Range
            section = addSection( obj.Tab, ...
                        getString(message("images:imageViewer:dataRangeSection")) );
            obj.SourceLabelColumn = section.addColumn();
            labelStr = getString(message("images:commonUIString:min")) + ": ";
            obj.SourceLabelColumn.add(Label(labelStr));
            labelStr = getString(message("images:commonUIString:max")) + ": ";
            obj.SourceLabelColumn.add(Label(labelStr));

            column = section.addColumn("Width", 60);
            obj.SourceMinEF = EditField();
            obj.SourceMinEF.Description = ...
                        getString(message("images:imageViewer:sourceMinTooltip"));
            obj.SourceMinEF.Tag = "SourceDataMin";
            obj.SourceMinEF.Enabled = false;
            column.add(obj.SourceMinEF);

            obj.SourceMaxEF = EditField();
            obj.SourceMaxEF.Description = ...
                        getString(message("images:imageViewer:sourceMaxTooltip"));
            obj.SourceMaxEF.Tag = "DataMax";
            obj.SourceMaxEF.Enabled = false;
            column.add(obj.SourceMaxEF);
        end

        function createAdjustContrastSection(obj)

            import matlab.ui.internal.toolstrip.*;

            % Contrast
            obj.WindowSection = addSection( obj.Tab, ...
                        getString(message("images:imageViewer:windowSection")) );
            column = obj.WindowSection.addColumn();
            labelStr = getString(message("images:commonUIString:min")) + ": ";
            column.add(Label(labelStr));
            labelStr = getString(message("images:commonUIString:max")) + ": ";
            column.add(Label(labelStr));

            column = obj.WindowSection.addColumn("Width", 80);
            obj.RangeMinSp = Spinner();
            obj.RangeMinSp.Description = ...
                        getString(message("images:imageViewer:windowMinTooltip"));
            obj.RangeMinSp.Tag = "RangeMin";
            obj.RangeMinSp.Enabled = false;
            % The values below will change based on the type of the source
            % image. Values during creation assume a uint8 source.
            dtrange = getrangefromclass(uint8(0));
            obj.RangeMinSp.NumberFormat = "integer";
            obj.RangeMinSp.DecimalFormat = "0f";
            obj.RangeMinSp.Limits = [0 dtrange(2)-1];
            obj.RangeMinSp.Value = dtrange(1);
            obj.RangeMinSp.StepSize = 10;

            addlistener( obj.RangeMinSp, "ValueChanged", ...
                         @(~, ~) reactToRangeMinChanged(obj) );
            column.add(obj.RangeMinSp);

            obj.RangeMaxSp = Spinner();
            obj.RangeMaxSp.Description = ...
                        getString(message("images:imageViewer:windowMaxTooltip"));
            obj.RangeMaxSp.Tag = "RangeMax";
            obj.RangeMaxSp.Enabled = false;
            % The values below will change based on the type of the source
            % image. Values during creation assume a uint8 source.
            obj.RangeMaxSp.NumberFormat = "integer";
            obj.RangeMaxSp.DecimalFormat = "0f";
            obj.RangeMaxSp.Limits = [obj.RangeMinSp.Value+1 dtrange(2)];
            obj.RangeMaxSp.Value = dtrange(2);
            obj.RangeMaxSp.StepSize = 10;
            addlistener( obj.RangeMaxSp, "ValueChanged", ...
                         @(~, ~) reactToRangeMaxChanged(obj) );
            column.add(obj.RangeMaxSp);

            column = obj.WindowSection.addColumn();
            obj.RangeMinDropperBtn = Button("", Icon("eyedropper"));
            obj.RangeMinDropperBtn.Tag = "RangeMinDropper";
            obj.RangeMinDropperBtn.Enabled = false;
            obj.RangeMinDropperBtn.Description = ...
                        getString(message("images:imageViewer:windowDropperMinTooltip"));
            addlistener( obj.RangeMinDropperBtn, "ButtonPushed", ...
                         @(~, evt) reactToRangeDropperClicked(obj, evt) );
            column.add(obj.RangeMinDropperBtn);

            obj.RangeMaxDropperBtn = Button("", Icon("eyedropper"));
            obj.RangeMaxDropperBtn.Tag = "RangeMaxDropper";
            obj.RangeMaxDropperBtn.Enabled = false;
            obj.RangeMaxDropperBtn.Description = ...
                        getString(message("images:imageViewer:windowDropperMaxTooltip"));
            addlistener( obj.RangeMaxDropperBtn, "ButtonPushed", ...
                         @(~, evt) reactToRangeDropperClicked(obj, evt) );
            column.add(obj.RangeMaxDropperBtn);

            column = obj.WindowSection.addColumn();
            column.add(Label(getString(message("images:imageViewer:windowRangeWidth"))));
            column.add(Label(getString(message("images:imageViewer:windowRangeCenter"))));

            column = obj.WindowSection.addColumn("Width", 80);
            obj.RangeWidthSp = Spinner();
            obj.RangeWidthSp.Description = ...
                    getString(message("images:imageViewer:windowWidthTooltip"));
            obj.RangeWidthSp.Tag = "RangeWidth";
            obj.RangeWidthSp.Enabled = false;
            % The values below will change based on the type of the source
            % image. Values during creation assume a uint8 source.
            obj.RangeWidthSp.NumberFormat = "integer";
            obj.RangeWidthSp.DecimalFormat = "0f";
            obj.RangeWidthSp.Limits = [0 diff(dtrange)];
            obj.RangeWidthSp.Value = obj.RangeWidthSp.Limits(1);
            obj.RangeWidthSp.StepSize = 10;
            addlistener( obj.RangeWidthSp, "ValueChanged", ...
                         @(~, ~) reactToRangeWidthChanged(obj) );
            column.add(obj.RangeWidthSp);

            obj.RangeCenterSp = Spinner();
            obj.RangeCenterSp.Description = ...
                    getString(message("images:imageViewer:windowCenterTooltip"));
            obj.RangeCenterSp.Tag = "RangeCenter";
            obj.RangeCenterSp.Enabled = false;
            % The values below will change based on the type of the source
            % image. Values during creation assume a uint8 source.
            obj.RangeCenterSp.NumberFormat = "integer";
            obj.RangeCenterSp.DecimalFormat = "0f";
            obj.RangeCenterSp.Limits = [dtrange(1)+1 dtrange(2)-1];
            obj.RangeCenterSp.Value = obj.RangeCenterSp.Limits(1);
            obj.RangeCenterSp.StepSize = 10;
            addlistener( obj.RangeCenterSp, "ValueChanged", ...
                         @(~, ~) reactToRangeCenterChanged(obj) );
            column.add(obj.RangeCenterSp);

            column = obj.WindowSection.addColumn("Width", 160);

            presetDDStrings = string( { ...
                getString(message("images:imageViewer:presetMatchDtypeRange")); ...
                getString(message("images:imageViewer:presetMatchDataRange")); ...
                getString(message("images:imageViewer:presetElimOutliers")) } );

            obj.PresetDD = DropDown(presetDDStrings);
            obj.PresetDD.Tag = "PresetDD";
            obj.PresetDD.Enabled = false;
            obj.PresetDD.Description = ...
                    getString(message("images:imageViewer:presetContrastTooltip"));
            obj.PresetDD.Editable = false;
            obj.PresetDD.SelectedIndex = 1;
            obj.PresetDD.PlaceholderText = ...
                    getString(message("images:imageViewer:presetPlaceHolder"));
            addlistener( obj.PresetDD, "ValueChanged", ...
                            @(~, ~) reactToPresetSelected(obj) );
            column.add(obj.PresetDD);

            obj.OutliersSp = Spinner();
            obj.OutliersSp.Description = ...
                    getString(message("images:imageViewer:outlierPctTooltip"));
            obj.OutliersSp.Tag = "OutliersSp";
            obj.OutliersSp.Value = 2.00;
            obj.OutliersSp.Enabled = false;
            obj.OutliersSp.NumberFormat = "double";
            obj.OutliersSp.DecimalFormat = "2f";
            obj.OutliersSp.Limits = [0+eps("double") 100-eps("double")];
            obj.OutliersSp.StepSize = 5.00;
            addlistener( obj.OutliersSp, ...
                         "ValueChanged", ...
                         @(~, ~) reactToElimOutliersPctChange(obj) );
            column.add(obj.OutliersSp);
        end

        function createRestoreSection(obj)
            import matlab.ui.internal.toolstrip.*;

            obj.RestoreSection = addSection( obj.Tab, ...
                        getString(message("images:imageViewer:restore")) );

            column = obj.RestoreSection.addColumn();

            obj.RestoreBtn = Button( ...
                        getString(message("images:imageViewer:undoChanges")), ...
                        Icon("restore") );
            obj.RestoreBtn.Tag = "RestoreImage";
            obj.RestoreBtn.Description = ...
                    getString(message("images:imageViewer:undoChangesTooltip"));
            obj.RestoreBtn.Enabled = false;
            addlistener( obj.RestoreBtn, "ButtonPushed", ...
                         @(~, ~) reactToContrastUndo(obj) );
            column.add(obj.RestoreBtn);
        end
    end

    % Callbacks 
    methods(Access=private)
        function reactToHistogramPressed(obj)
            evtData = struct( "Source", "ContrastTab", ...
                              "Value", obj.HistogramTglBtn.Value );
            notify( obj, "ShowHistogramPressed", ...
                    images.internal.app.viewer.ViewerEventData(evtData) );
        end

        function reactToRangeMinChanged(obj)
            minVal = obj.RangeMinSp.Value;
            maxVal = obj.RangeMaxSp.Value;

            range = [minVal maxVal];

            % Update the lower limit of the RangeMax spinner
            obj.RangeMaxSp.Limits(1) = minVal+obj.SpinnerLimitsDelta;

            handleCustomRangeChange(obj, range);
        end

        function reactToRangeMaxChanged(obj)
            minVal = obj.RangeMinSp.Value;
            maxVal = obj.RangeMaxSp.Value;

            range = [minVal maxVal];

            % Update the upper limit of the RangeMin spinner
            obj.RangeMinSp.Limits(2) = maxVal-obj.SpinnerLimitsDelta;

            handleCustomRangeChange(obj, range);
        end

        function reactToRangeWidthChanged(obj)
            % This callback computes the values for the min, max, level and
            % center of the display window by ensuring the values are
            % clamped to the boundary. In the computations, the rangeWidth
            % value is preserved as that is the value the user has
            % changed.

            rangeWidth = obj.RangeWidthSp.Value;
            rangeCenter = obj.RangeCenterSp.Value;

            if isfloat(obj.SrcImage)
                rangeHalfWidth = rangeWidth/2;
            else
                rangeHalfWidth = ceil(rangeWidth/2);
            end

            dtrange = getrangefromclass(obj.SrcImage);

            rangeMin = max(rangeCenter-rangeHalfWidth, dtrange(1));
            rangeMax = min(rangeMin+rangeWidth, dtrange(2));
            rangeMin = rangeMax-rangeWidth;

            handleCustomRangeChange(obj, [rangeMin rangeMax]);
        end

        function reactToRangeCenterChanged(obj)
            % Compute the min/max/width using the new center. These valus
            % are computed by ensuring the min and max values stay within
            % bounds.

            rangeCenter = obj.RangeCenterSp.Value;

            rangeWidth = obj.RangeWidthSp.Value;

            dtypeRange = getrangefromclass(obj.SrcImage);
            
            if isfloat(obj.SrcImage)
                rangeHalfWidth = rangeWidth/2;
            else
                rangeHalfWidth = ceil(rangeWidth/2);
            end
            
            if (rangeCenter - rangeHalfWidth) < dtypeRange(1)
                rangeHalfWidthToUse = rangeCenter - dtypeRange(1);
            else
                rangeHalfWidthToUse = rangeHalfWidth;
            end

            if (rangeCenter + rangeHalfWidth) > dtypeRange(2)
                rangeHalfWidthToUse = min( dtypeRange(2)-rangeCenter, ...
                                          rangeHalfWidthToUse );
            end

            rangeMin = max(dtypeRange(1), rangeCenter - rangeHalfWidthToUse);
            rangeMax = min(dtypeRange(2), rangeCenter + rangeHalfWidthToUse);

            handleCustomRangeChange(obj, [rangeMin rangeMax]);
        end

        function reactToRangeDropperClicked(obj, evt)
            % The min/max value will be selected by clicking a point on the
            % source image.

            if evt.Source.Tag == "RangeMinDropper"
                dropperMode = "min";
                pointerData = obj.MinDropperPointerData;
            else
                dropperMode = "max";
                pointerData = obj.MaxDropperPointerData;
            end

            data = struct( "DropperMode", dropperMode, ...
                           "PointerData", pointerData );
            
            notify( obj, "RangeDropperClicked", ...
                    images.internal.app.viewer.ViewerEventData(data) );
        end

        function reactToPresetSelected(obj)
            % Update displayed image using a preset contrast setting

            % The % outliers spinner must be enabled if "Eliminate
            % Outliers" is selected.
            obj.OutliersSp.Enabled = obj.PresetDD.SelectedIndex == 3;

            switch(obj.PresetDD.SelectedIndex)
                case 1
                    % DataType Range
                    range = getrangefromclass(obj.SrcImage);
                    handlePresetRangeChange(obj, range);

                case 2
                    % Source Range
                    rangeMin = str2double(obj.SourceMinEF.Value);
                    rangeMax = str2double(obj.SourceMaxEF.Value);
                    range = [rangeMin rangeMax];
                    handlePresetRangeChange(obj, range);

                case 3
                    % Eliminate Outliers
                    handleElimOutliersSelected(obj, obj.OutliersSp.Value);

                otherwise
                    assert(false, "Invalid Selection");
            end
        end

        function reactToElimOutliersPctChange(obj)
            % Handle the change to the percentage value in the Eliminate
            % outliers Spinner

            handleElimOutliersSelected(obj, obj.OutliersSp.Value);
        end

        function reactToContrastUndo(obj)
            restoreContrastDDOnUndo(obj);

            range = [obj.PrevMin obj.PrevMax];
            updateRange(obj, range, RangeType="previous");
            enableRestoreBtnState(obj, false);
            
            evtData = images.internal.app.viewer.ViewerEventData(range);
            notify(obj, "ContrastUndoPressed", evtData);
        end
    end
    
    % Helpers
    methods(Access=private)
        function handleCustomRangeChange(obj, range)
            % Update the UI and fire event to indicate there was range
            % change by modification to the min/max/width/center fields

            updatePresetDD(obj, -1);
            
            updateRange(obj, range, RangeType="custom");

            notify( obj, "ContrastChanged", ...
                    images.internal.app.viewer.ViewerEventData(range) );
        end

        function handlePresetRangeChange(obj, range)
            % Update the UI and fire event to indicate there was a range
            % change by selecting a preset range
            
            enableRestoreBtnState(obj, true);
            updateRange(obj, range, RangeType="previous");

            notify( obj, "ContrastChanged", ...
                    images.internal.app.viewer.ViewerEventData(range) );
        end

        function handleElimOutliersSelected(obj, pctVal)

            tol = (pctVal/100)/2;

            % Range is always in the range [0, 1]
            range = stretchlim(obj.SrcImage, tol)';

            if ~isequal(range, [0, 1])
                % Update the current value
                obj.CurrOutliersSpValue = pctVal;
            end

            % Convert the range to match that of the image dataype. This is
            % need to update the min/max/range/center values in the
            % toolstrip
            convFunc = str2func( "im2" + class(obj.SrcImage));
            range = convFunc(range);

            handlePresetRangeChange(obj, range);
        end

        function updateImage(obj, srcImage)
            % For a new image, the default display range is datatype range
            % display. Also, since a new image is being loaded, the Restore
            % button is disabled
            arguments
                obj (1, 1) images.internal.app.viewer.ContrastTab
                srcImage (:, :)
            end

            obj.SrcImage = srcImage;

            % Update the spinner limits and range values suitably
            updateSpinnerProps(obj);

            % Restore the Drop Down elements
            updatePresetDD(obj, 1);

            obj.SourceMinEF.Value = string(min(srcImage, [], "all"));
            obj.SourceMaxEF.Value = string(max(srcImage, [], "all"));

            range = getrangefromclass(obj.SrcImage);
            updateRange(obj, range, RangeType="datatype");

            % For a new load, the Restore button must be disabled as
            % no contrast change was applied
            enableRestoreBtnState(obj, false);

            cacheSessionStartValues(obj);
        end

        function updateSpinnerProps(obj)
            % Update the spinner limits used for contrast adjustment for
            % new source images

            dtype = class(obj.SrcImage);

            if isfloat(obj.SrcImage)
                obj.SpinnerLimitsDelta = double(eps(dtype));
                numFormat = "double";
                decFormat = "4f";
                stepSize = 0.05;
            else
                obj.SpinnerLimitsDelta = 1;
                numFormat = "integer";
                decFormat = "0f";
                stepSize = 10;
            end

            dtrange = getrangefromclass(obj.SrcImage);

            obj.RangeMinSp.NumberFormat = numFormat;
            obj.RangeMinSp.DecimalFormat = decFormat;
            obj.RangeMinSp.StepSize = stepSize;
            obj.RangeMinSp.Value = dtrange(1);
            obj.RangeMinSp.Limits = [ dtrange(1) ...
                                      dtrange(2)-obj.SpinnerLimitsDelta ];

            obj.RangeMaxSp.NumberFormat = numFormat;
            obj.RangeMaxSp.DecimalFormat = decFormat;
            obj.RangeMaxSp.StepSize = stepSize;
            obj.RangeMaxSp.Value = dtrange(2);
            obj.RangeMaxSp.Limits = [ dtrange(1)+obj.SpinnerLimitsDelta ...
                                      dtrange(2) ];

            obj.RangeWidthSp.NumberFormat = numFormat;
            obj.RangeWidthSp.DecimalFormat = decFormat;
            obj.RangeWidthSp.StepSize = stepSize;
            obj.RangeWidthSp.Limits = [0 diff(dtrange)];

            obj.RangeCenterSp.NumberFormat = numFormat;
            obj.RangeCenterSp.DecimalFormat = decFormat;
            obj.RangeCenterSp.StepSize = stepSize;
            obj.RangeCenterSp.Limits = [ dtrange(1)+obj.SpinnerLimitsDelta, ...
                                      dtrange(2)-obj.SpinnerLimitsDelta ];
        end

        function updatePresetDD(obj, idx)
            % Programmtically update the Preset Contrast Settings Drop Down

            obj.PresetDD.SelectedIndex = idx;

            obj.OutliersSp.Enabled = idx == 3;
        end

        function enableRestoreBtnState(obj, isEnabled)
            obj.RestoreBtn.Enabled = isEnabled;
        end

        function restoreContrastDDOnUndo(obj)
            obj.PresetDD.SelectedIndex = obj.PrevDDSelection;
            obj.OutliersSp.Value = obj.PrevOutliersPct;
            obj.OutliersSp.Enabled = obj.PrevDDSelection == 3;
        end

        function cacheSessionStartValues(obj)
            obj.PrevMin = obj.RangeMinSp.Value;
            obj.PrevMax = obj.RangeMaxSp.Value;

            obj.PrevDDSelection = obj.PresetDD.SelectedIndex;
            obj.PrevOutliersPct = obj.OutliersSp.Value;
        end

        function tf = isCustomRangeValuesValid(obj, val)
            tf = isnumeric(val) && isreal(val) && isfinite(val);

            dtypeRange = getrangefromclass(obj.SrcImage);
            tf = tf && (val >= dtypeRange(1));

            % For integer valued images, the range values specified must be
            % integer valued 
            if ~isfloat(obj.SrcImage)
                tf = tf && (ceil(val) == val);
            end
        end

        function reset(obj)
            % Reset the toolstrip values with default values
            obj.HistogramTglBtn.Value = false;
            obj.SourceMinEF.Value = "";
            obj.SourceMaxEF.Value = "";
            obj.RangeMinSp.Value = obj.RangeMinSp.Limits(1);
            obj.RangeMaxSp.Value = obj.RangeMaxSp.Limits(1);
            obj.RangeCenterSp.Value = obj.RangeCenterSp.Limits(1);
            obj.RangeWidthSp.Value = obj.RangeWidthSp.Limits(1);
            obj.PresetDD.SelectedIndex = 1;
            obj.OutliersSp.Value = 2;

            cacheSessionStartValues(obj);
        end
    end
end

function pointerShape = makeDropperPointer(iconType)

    iconRoot = ipticondir;
    if iconType == "min"
        cursorFileName = fullfile(iconRoot, "cursor_eyedropper_black.png");
    else
        cursorFileName = fullfile(iconRoot, "cursor_eyedropper_white.png");
    end

    cdata = images.internal.app.utilities.makeToolbarIconFromPNG(cursorFileName);
    pointerShape = cdata(:,:,1)+1;
end
