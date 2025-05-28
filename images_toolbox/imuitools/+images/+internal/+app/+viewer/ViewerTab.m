classdef ViewerTab < images.internal.app.viewer.TabBase
% Helper class that creates and manages the Main Tab in the Toolstrip
% of the ImageViewer app.

%   Copyright 2023 The Mathworks, Inc.

    events
        ImportFromFileRequested
        ImportFromWorkspaceRequested

        OverviewPressed
        ImageInfoPressed

        ImageInterpChanged

        ZoomPctChanged
        PixelValueDisplayChecked

        CropRequested
        CropApplied
        CropCancelled

        MeasureDistancePressed
        MeasureAreaPressed
        MeasureShowAllPressed
        MeasureDeleteAllClicked
    end

    properties ( SetAccess = ?images.internal.app.viewer.ImageViewer, ...
                 GetAccess = { ?uitest.factory.Tester, ...
                               ?images.internal.app.viewer.ImageViewer, ...
                               ?imtest.apptest.imageViewerTest.PropertyAccessProvider} )

        % Viewer Tab: Import section Controls
        DataImportSplitBtn      matlab.ui.internal.toolstrip.SplitButton
        DataExportSection       images.internal.app.viewer.ExportSection

        % Viewer Tab: Info section Controls
        OverviewTglBtn        matlab.ui.internal.toolstrip.ToggleButton
        ImageInfoTglBtn       matlab.ui.internal.toolstrip.ToggleButton

        % Viewer Tab: Image Display Controls
        InterpDD                matlab.ui.internal.toolstrip.DropDown

        % Main Tab: Zoom section Controls
        ZoomDD                  matlab.ui.internal.toolstrip.DropDown
        ZoomPixLevelChkBox      matlab.ui.internal.toolstrip.CheckBox

        % Main Tab: Crop section Controls
        CropReqCol      matlab.ui.internal.toolstrip.Column
        CropConfirmCol  matlab.ui.internal.toolstrip.Column
        CropSection     matlab.ui.internal.toolstrip.Section
        CropReqBtn      matlab.ui.internal.toolstrip.Button
        CropApplyBtn    matlab.ui.internal.toolstrip.Button
        CropCancelBtn   matlab.ui.internal.toolstrip.Button

        % Main Tab: Measure section Controls
        MeasSection         matlab.ui.internal.toolstrip.Section
        MeasOptionsCol      matlab.ui.internal.toolstrip.Column
        MeasDispCol         matlab.ui.internal.toolstrip.Column
        MeasDistTglBtn      matlab.ui.internal.toolstrip.ToggleButton
        MeasAreaTglBtn      matlab.ui.internal.toolstrip.ToggleButton
        MeasShowAllTglBtn   matlab.ui.internal.toolstrip.ToggleButton
        MeasDeleteAllBtn    matlab.ui.internal.toolstrip.Button
    end

    properties(GetAccess=public, SetAccess=private)
        CurrentState = struct.empty();
    end

    properties(Access=private)
        % Cache the viewer tab state of the app before the latest change
        % was made to it.
        CachedState = struct.empty();
    end

    properties(Access=public, Constant)
        ZoomDDEntries = [ string(message("images:commonUIString:fitToWindow")); ...
                          string(message("images:imageViewer:zoomDDEntryZoomToPixel")); ...
                          "100%"; "200%"; "400%"; "1000%" ];
    end

    properties(Access=private, Constant)
        % List of controls in the viewer tab whose state has to be cached
        ControlsList = images.internal.app.viewer.createControlsList( ...
                            ?images.internal.app.viewer.ViewerTab, ...
                            ["Btn", "DD", "ChkBox"] );
    end

    % Constructor
    methods(Access=public)
        function obj = ViewerTab(tabGroup)
            obj@images.internal.app.viewer.TabBase();
            createViewerTab(obj, tabGroup);
        end
    end

    % Interface methods
    methods(Access=public)
        function updateOnSrcChange(obj, im, interp)
            % Update the Colormap Tab controls when a new image is loaded
            % into the image
            
            if isempty(im)
                % Indicates an empty app was launched
                disableAll(obj.Tab)

                obj.InterpDD.SelectedIndex = -1;
                obj.DataImportSplitBtn.Enabled = true;
            else
                % Indicates a valid image was provided
                enableAll(obj.Tab);

                if interp == "nearest"
                    obj.InterpDD.SelectedIndex = 1;
                else
                    obj.InterpDD.SelectedIndex = 2;
                end

                obj.ZoomPixLevelChkBox.Enabled = false;

                % The Crop Apply/Cancel buttons must be disabled
                enableAll(obj.CropReqCol);
                disableAll(obj.CropConfirmCol);

                % The Show Meas/Delete Meas buttons must be disabled
                enableAll(obj.MeasOptionsCol);
                disableAll(obj.MeasDispCol);
            end
        end
        
        function setZoomPctValue(obj, zoomPct, zoomPctToUseForPreset)
            % Sets the user supplied value in the Zoom Drop Down
            % zoomPct can take on the following values:
            % 1. "fit" => Fit to Window
            % 2. "pix" => Pixel Level Display
            % 3. Valid numeric value
            % 
            % zoomPctToUseForPreset is the numeric zoom percent value that
            % is used to create the display string if the zoomPct is "fit"
            % or "pix"
            arguments
                obj (1, 1) images.internal.app.viewer.ViewerTab

                % Values can be a positive numeric scalar or the string
                % "fit"
                zoomPct

                % Numeric zoom value to display in the UI if the zoom is
                % "fit"
                zoomPctToUseForPreset double = []
            end

            if isnumeric(zoomPct)
                if ~isValidNumericZoomPct(zoomPct)
                    return;
                end
                obj.ZoomDD.Value = round(zoomPct) + "%";
            elseif isstring(zoomPct) && (zoomPct == "fit")
                appendZoomPctToPresetVal(obj, zoomPctToUseForPreset);
            elseif isstring(zoomPct) && (zoomPct == "pix")
                appendZoomPctToPresetVal(obj, zoomPctToUseForPreset);

                obj.ZoomPixLevelChkBox.Enabled = true;
                obj.ZoomPixLevelChkBox.Value = true;
            else
                assert( false, "Invalid Zoom Percent" );
            end
        end
        
        function restoreState(obj, state)
            % Store the controls on the viewer tab to the specified state.
            % This impacts whether a control is enabled/disabled and not
            % its actual value.

            restoreState(obj.DataExportSection, state);
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
            % Get the current state of the controls of the Viewer Tab

            val = obj.DataExportSection.CurrentState;

            for cnt = 1:numel(obj.ControlsList)
                cname = obj.ControlsList(cnt);
                val.(cname) = obj.(cname).Enabled;
            end
        end
    end

    % Callback methods for all controls present in the Viewer Tab
    methods (Access = private)
        function reactToOverview(obj)
            notify( obj, "OverviewPressed", ...
                    images.internal.app.viewer.ViewerEventData(obj.OverviewTglBtn.Value) )
        end

        function reactToImageInfoPressed(obj)
            notify( obj, "ImageInfoPressed", ...
                    images.internal.app.viewer.ViewerEventData(obj.ImageInfoTglBtn.Value) )
        end

        function reactToImageInterpChanged(obj, evt)

            if isequal(evt.EventData.NewValue, evt.EventData.OldValue)
                return;
            end

            switch(obj.InterpDD.SelectedIndex)
                case 1
                    interpMode = "nearest";
                case 2
                    interpMode = "bilinear";
                otherwise
                    assert( false, "Invalid Interp Mode" );
            end

            notify( obj, "ImageInterpChanged", ...
                images.internal.app.viewer.ViewerEventData(interpMode) );
        end

        function reactToZoomPercentChanged(obj, evt)

            newVal = strip(evt.EventData.NewValue, "right", "%");
            switch(obj.ZoomDD.SelectedIndex)
                case -1
                    % Custom value specified
                    zoomToUse = str2double(strip(newVal, "right", "%"));
                    if ~isValidNumericZoomPct(zoomToUse)
                        % If the Zoom value specified is invalid, then take
                        % no action and simply restore the previous state
                        % of the Zoom Drop Down
                        obj.ZoomDD.Value = evt.EventData.OldValue;
    
                        return;
                    else
                        % If a custom value matches one of the preset
                        % values, then use the preset value itself.
                        zoomEntries = strip(obj.ZoomDDEntries, "right", "%");
                        presetIdx = find( strcmp( zoomEntries, ...
                                            string(zoomToUse) ) );
                        if ~isempty(presetIdx)
                            obj.ZoomDD.SelectedIndex = presetIdx;
                        end
                    end
                    
                case 1
                    % Fit To Window Selected
                    zoomToUse = "fit";

                case 2
                    % Pixel Level selected
                    zoomToUse = "pix";
                    obj.ZoomPixLevelChkBox.Enabled = true;
                    obj.ZoomPixLevelChkBox.Value = true;

                otherwise
                    % Other predefined numeric values
                    zoomToUse = str2double(strip(newVal, "right", "%"));
            end

            notify( obj, "ZoomPctChanged", ...
                images.internal.app.viewer.ViewerEventData(zoomToUse) );
        end

        function reactToZoomPixLevelChkBoxClicked(obj, evt)
            notify( obj, "PixelValueDisplayChecked", ...
                images.internal.app.viewer.ViewerEventData(evt.EventData.NewValue) );
        end

        function reactToCropRequested(obj)
            vstate = obj.CurrentState;

            disableAll(obj.Tab);
            enableAll(obj.CropConfirmCol);

            obj.CachedState = vstate;
            notify( obj, "CropRequested", ...
                images.internal.app.viewer.ViewerEventData(vstate) );
        end

        function reactToCropApplied(obj)
            notify(obj, "CropApplied");
        end

        function reactToCropCancelled(obj)
            restoreState(obj, obj.CachedState);
            obj.CachedState = struct.empty();

            notify(obj, "CropCancelled");
        end
    
        function reactToMeasDistPressed(obj)
            distBtnVal = obj.MeasDistTglBtn.Value;
            if distBtnVal
                obj.MeasAreaTglBtn.Value = false;
            end

            notify( obj, "MeasureDistancePressed", ...
                    images.internal.app.viewer.ViewerEventData(distBtnVal) );
        end

        function reactToMeasAreaPressed(obj)
            areaBtnVal = obj.MeasAreaTglBtn.Value;
            if areaBtnVal
                obj.MeasDistTglBtn.Value = false;
            end

            notify( obj, "MeasureAreaPressed", ...
                    images.internal.app.viewer.ViewerEventData(areaBtnVal) );
        end

        function reactToMeasShowAllPressed(obj)
            notify( obj, "MeasureShowAllPressed", ...
                    images.internal.app.viewer.ViewerEventData(obj.MeasShowAllTglBtn.Value) );
        end
    end

    % Helpers for creating/managing sections in the Viewer Tab
    methods(Access=private)
        function createViewerTab(obj, tabGroup)
            obj.Tab = tabGroup.addTab( ...
                    getString(message("images:imageViewer:viewerTab")) );
            obj.Tab.Tag = "ViewerTab";

            createImportSection(obj);
            createImageInfoSection(obj);
            createImageDisplaySection(obj);
            createZoomSection(obj);
            createCropSection(obj);
            createMeasureSection(obj);
            createExportSection(obj);
        end

        function createImportSection(obj)
            import matlab.ui.internal.toolstrip.*
            % Helper code that creates Import section of the Main Tab
            section = addSection( obj.Tab, ...
                            getString(message("images:commonUIString:import")) );
            
            column = section.addColumn();
            openWorkspace = ListItem( ...
                            getString(message("images:imageViewer:importImageFromWorkspace")), ...
                            Icon("workspace") );
            openWorkspace.ShowDescription = false;
            openWorkspace.Tag = "OpenFromWorkspace";
            addlistener( openWorkspace, "ItemPushed", ...
                        @(~,~) notify(obj, "ImportFromWorkspaceRequested") );
            
            openFile = ListItem( ...
                            getString(message("images:imageViewer:importImageFromFile")), ...
                            Icon("folder") );
            openFile.ShowDescription = false;
            openFile.Tag = "OpenFile";
            addlistener( openFile, "ItemPushed", ...
                            @(~,~) notify(obj, "ImportFromFileRequested") );

            popup = matlab.ui.internal.toolstrip.PopupList();
            add(popup, openWorkspace);
            add(popup, openFile);
            
            obj.DataImportSplitBtn = SplitButton( ...
                        getString(message("images:imageViewer:importImage")), ...
                        Icon("import_data") );
            obj.DataImportSplitBtn.Tag = "Import";
            obj.DataImportSplitBtn.Enabled = false;
            obj.DataImportSplitBtn.Description = ...
                    getString(message("images:imageViewer:importImageTooltip"));
            obj.DataImportSplitBtn.Popup = popup;
            addlistener( obj.DataImportSplitBtn, "ButtonPushed", ...
                        @(~,~) notify(obj, "ImportFromWorkspaceRequested") );
            column.add(obj.DataImportSplitBtn);
        end

        function createImageInfoSection(obj)
            import matlab.ui.internal.toolstrip.*

            section = addSection( obj.Tab, ...
                        getString(message("images:imageViewer:infoSection")) );
            column = section.addColumn();

            % Overview
            obj.OverviewTglBtn = ToggleButton( ...
                    getString(message("images:imageViewer:imageOverview")), ...
                    Icon("image") );
            obj.OverviewTglBtn.Tag = "Overview";
            obj.OverviewTglBtn.Enabled = false;
            obj.OverviewTglBtn.Description = ...
                    getString(message("images:imageViewer:imageOverviewTooltip"));
            obj.OverviewTglBtn.Value = false;
            addlistener( obj.OverviewTglBtn, "ValueChanged", ...
                                        @(~,~) reactToOverview(obj) );
            column.add(obj.OverviewTglBtn);

            % Info
            column = section.addColumn();
            obj.ImageInfoTglBtn = ToggleButton( ...
                    getString(message("images:imageViewer:imageMetadata")), ...
                    Icon("properties") );
            obj.ImageInfoTglBtn.Tag = "Info";
            obj.ImageInfoTglBtn.Enabled = false;
            obj.ImageInfoTglBtn.Description = ...
                    getString(message("images:imageViewer:imageMetadataTooltip"));
            obj.ImageInfoTglBtn.Value = false;
            addlistener( obj.ImageInfoTglBtn, "ValueChanged", ...
                         @(~,~) reactToImageInfoPressed(obj) );
            column.add(obj.ImageInfoTglBtn);
        end

        function createImageDisplaySection(obj)
           import matlab.ui.internal.toolstrip.*

            section = addSection( obj.Tab, ...
                        getString(message("images:imageViewer:imageDisplaySection")) );
            column = section.addColumn();

            interpLabel = Label(getString(message("images:imageViewer:imageInterpolation")) );
            column.add(interpLabel);
            
            obj.InterpDD = DropDown(["nearest"; "bilinear"]);
            obj.InterpDD.Tag = "InterpDD";
            obj.InterpDD.Editable = false;
            obj.InterpDD.Enabled = false;

            interpDDTooltip = getString( message( "images:imageViewer:imageInterpTooltip", ...
                                            getString(message("images:imageViewer:showPixelValues")) ) );
            obj.InterpDD.Description = interpDDTooltip;
            obj.InterpDD.SelectedIndex = -1;
            obj.InterpDD.PlaceholderText = ...
                    getString(message("images:commonUIString:select")) + " ...";
            addlistener( obj.InterpDD, "ValueChanged", ...
                         @(~, evt) reactToImageInterpChanged(obj, evt) );
            column.add(obj.InterpDD);
        end

        function createZoomSection(obj)
            import matlab.ui.internal.toolstrip.*;

            section = addSection( obj.Tab, ...
                        getString(message("images:imageViewer:zoomSection")) );
            column = section.addColumn("Width", 170);

            obj.ZoomDD = DropDown(obj.ZoomDDEntries);
            obj.ZoomDD.Tag = "ZoomDD";
            obj.ZoomDD.Enabled = false;
            obj.ZoomDD.Description = getString(message("images:imageViewer:zoomTooltip"));
            obj.ZoomDD.Editable = true;
            obj.ZoomDD.SelectedIndex = 1;
            addlistener( obj.ZoomDD, "ValueChanged", ...
                         @(~, evt) reactToZoomPercentChanged(obj, evt) );
            column.add(obj.ZoomDD);

            obj.ZoomPixLevelChkBox = CheckBox();
            obj.ZoomPixLevelChkBox.Tag = "ZoomPixLevelCheckBox";
            obj.ZoomPixLevelChkBox.Text = ...
                    getString(message("images:imageViewer:showPixelValues"));
            obj.ZoomPixLevelChkBox.Enabled = false;
            obj.ZoomPixLevelChkBox.Value = true;
            obj.ZoomPixLevelChkBox.Description = ...
                    getString(message("images:imageViewer:showPixelValuesTooltip"));
            addlistener( obj.ZoomPixLevelChkBox, "ValueChanged", ...
                            @(~, evt) reactToZoomPixLevelChkBoxClicked(obj, evt) );
            column.add(obj.ZoomPixLevelChkBox);
        end

        function createCropSection(obj)
            % Create the crop section. The layout of the crop section will
            % be:
            % CROP  | APPLY
            %       | CANCEL

            import matlab.ui.internal.toolstrip.*;

            obj.CropSection = addSection( obj.Tab, ...
                        getString(message("images:imageViewer:cropSection")) );

            obj.CropReqCol = obj.CropSection.addColumn();

            obj.CropReqBtn = Button( getString(message("images:imageViewer:cropImage")), ...
                                     Icon("crop") );
            obj.CropReqBtn.Tag = "Crop";
            obj.CropReqBtn.Enabled = false;
            obj.CropReqBtn.Description = ...
                        getString(message("images:imageViewer:cropImageTooltip"));
            addlistener( obj.CropReqBtn, "ButtonPushed", ...
                         @(~,~) reactToCropRequested(obj) );
            obj.CropReqCol.add(obj.CropReqBtn);

            obj.CropConfirmCol = obj.CropSection.addColumn();

            obj.CropApplyBtn = Button( getString(message("images:commonUIString:apply")), ...
                                       Icon("validated") );
            obj.CropApplyBtn.Tag = "CropApply";
            obj.CropApplyBtn.Enabled = false;
            obj.CropApplyBtn.Description = ...
                        getString(message("images:commonUIString:applyTooltip"));
            addlistener( obj.CropApplyBtn, "ButtonPushed", ...
                         @(~,~) reactToCropApplied(obj) );
            obj.CropConfirmCol.add(obj.CropApplyBtn);

            obj.CropCancelBtn = Button( getString(message("images:commonUIString:cancel")), ...
                                        Icon("close") );
            obj.CropCancelBtn.Tag = "CropCancel";
            obj.CropCancelBtn.Enabled = false;
            obj.CropCancelBtn.Description = ...
                    getString(message("images:commonUIString:cancelOnlyTooltip"));
            addlistener( obj.CropCancelBtn, "ButtonPushed", ...
                         @(~,~) reactToCropCancelled(obj) );
            obj.CropConfirmCol.add(obj.CropCancelBtn);
        end

        function createMeasureSection(obj)
            import matlab.ui.internal.toolstrip.*;

            section = addSection( obj.Tab, ...
                            getString(message("images:imageViewer:measurement")));

            % distanceMeasurement icon is not rendering. So using a place
            % holder icon for now.
            obj.MeasOptionsCol = section.addColumn();
            obj.MeasDistTglBtn = ToggleButton( ...
                        getString(message("images:imageViewer:measDistance")), ...
                        Icon("ruler") );
            obj.MeasDistTglBtn.Tag = "MeasureLine";
            obj.MeasDistTglBtn.Description = ...
                    getString(message("images:imageViewer:measDistanceTooltip"));
            obj.MeasDistTglBtn.Value = false;
            obj.MeasDistTglBtn.Enabled = false;
            addlistener( obj.MeasDistTglBtn, "ValueChanged" , ...
                         @(~, ~) reactToMeasDistPressed(obj) );
            obj.MeasOptionsCol.add(obj.MeasDistTglBtn);

            obj.MeasAreaTglBtn = ToggleButton( ...
                        getString(message("images:imageViewer:measArea")), ...
                        Icon("areaMeasurement") );
            obj.MeasAreaTglBtn.Tag = "MeasureArea";
            obj.MeasAreaTglBtn.Description = ...
                    getString(message("images:imageViewer:measAreaTooltip"));
            obj.MeasAreaTglBtn.Value = false;
            obj.MeasAreaTglBtn.Enabled = false;
            addlistener( obj.MeasAreaTglBtn, "ValueChanged", ...
                         @(~, ~) reactToMeasAreaPressed(obj) );
            obj.MeasOptionsCol.add(obj.MeasAreaTglBtn);

            obj.MeasDispCol = section.addColumn();
            
            obj.MeasShowAllTglBtn = ToggleButton( ...
                    getString(message("images:imageViewer:measShowAll")), ...
                    Icon("showUI") );
            obj.MeasShowAllTglBtn.Tag = "MeasureShowAll";
            obj.MeasShowAllTglBtn.Description = ...
                    getString(message("images:imageViewer:measShowAllTooltip"));
            obj.MeasShowAllTglBtn.Value = false;
            obj.MeasShowAllTglBtn.Enabled = false;
            addlistener( obj.MeasShowAllTglBtn, "ValueChanged" , ...
                         @(~, ~) reactToMeasShowAllPressed(obj) );
            obj.MeasDispCol.add(obj.MeasShowAllTglBtn);

            obj.MeasDeleteAllBtn = Button( ...
                    getString(message("images:imageViewer:measDeleteAll")), ...
                    Icon("delete") );
            obj.MeasDeleteAllBtn.Tag = "MeasureDeleteAll";
            obj.MeasDeleteAllBtn.Description = ...
                    getString(message("images:imageViewer:measDeleteAllTooltip"));
            obj.MeasDeleteAllBtn.Enabled = false;
            addlistener( obj.MeasDeleteAllBtn, "ButtonPushed" , ...
                         @(~, ~) notify(obj, "MeasureDeleteAllClicked") );
            obj.MeasDispCol.add(obj.MeasDeleteAllBtn);
        end

        function createExportSection(obj)
            obj.DataExportSection = ...
                    images.internal.app.viewer.ExportSection(obj.Tab);
        end
    end

    % Helper functions
    methods(Access=private)
        function appendZoomPctToPresetVal(obj, zoomPct)
            zoomDDVal = obj.ZoomDD.Value;

            if contains(zoomDDVal, obj.ZoomDDEntries(1))
                baseStr = obj.ZoomDDEntries(1);
            elseif contains(zoomDDVal, obj.ZoomDDEntries(2))
                baseStr = obj.ZoomDDEntries(2);
            else
                baseStr = "";
            end

            if baseStr ~= ""
                zoomValueDisp = baseStr + " (" + round(zoomPct) + "%)";
                obj.ZoomDD.Value = zoomValueDisp;
            end
        end
    end
end

function tf = isValidNumericZoomPct(zp)

    tf = isempty(zp) || ~isscalar(zp) || isnan(zp) || ~isreal(zp) || ...
         ~isfinite(zp) || (zp <= 0);

    tf = ~tf;
end


