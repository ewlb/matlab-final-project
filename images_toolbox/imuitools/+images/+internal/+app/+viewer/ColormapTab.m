classdef ColormapTab < images.internal.app.viewer.TabBase
% Helper class that creates and manages the Colormap Tab in the Toolstrip
% of the ImageViewer app.

%   Copyright 2023 The Mathworks, Inc.

    properties(GetAccess = {?uitest.factory.Tester, ...
            ?imtest.apptest.imageViewerTest.PropertyAccessProvider})
        % Colormap Tab: One Control per section
        CmapImportBtn       matlab.ui.internal.toolstrip.Button
        CmapSelectDD        matlab.ui.internal.toolstrip.DropDown
        CmapExprEF          matlab.ui.internal.toolstrip.EditField
    end

    events
        ColormapImportRequested
        ColormapSelectionDone
        ColormapExprSpecified
        ColormapExprInvalid
    end

    properties(GetAccess=public, SetAccess=private)
        CurrentState = struct.empty();
    end

    properties(Access=private)
        IsSourceInList (1, 1) logical = false;
    end

    properties(Access=?imtest.apptest.imageViewerTest.PropertyAccessProvider, Constant)
        CmapList = [ string(getString(message("images:commonUIString:none"))); ...
                     string(getString(message("images:commonUIString:source"))); ...
                     sort( [ "parula"; "turbo"; "hsv"; "hot";...
                             "cool"; "spring"; "summer"; "autumn"; ...
                             "winter"; "gray"; "bone"; "copper"; ...
                             "pink"; "jet"; "lines"; "colorcube"; ...
                             "prism"; "flag"; "white"; "sky"] ) ];

        % List of controls in the colormap tab whose state has to be cached
        ControlsList = images.internal.app.viewer.createControlsList( ...
                            ?images.internal.app.viewer.ColormapTab, ...
                            ["Btn", "DD", "EF"] );
    end

    % Construction
    methods
        function obj = ColormapTab()
            obj@images.internal.app.viewer.TabBase();
            createColormapTab(obj);
        end
    end

    % Interface methods
    methods(Access=public)
        function updateOnSrcChange(obj, im, srcColormap, tabGroup, tabLoc)
            % Update the Colormap Tab controls when a new image is loaded
            % into the image

            if nargin == 4
                tabLoc = 1;
            end

            % The tab is enabled only when the image is a non-empty, single
            % channel matrix
            isEnabled = ~( isempty(im) || (size(im, 3) ~= 1) );

            if isEnabled
                updateListOnLoad(obj, srcColormap);
                enableAll(obj.Tab);
                images.internal.app.viewer.showTab(tabGroup, obj.Tab, tabLoc);
            else
                disableAll(obj.Tab);
                images.internal.app.viewer.hideTab(tabGroup, obj.Tab);
            end
        end

        function updateControlsOnNewColormap(obj, cmapType)
            % Update the colormap tab when new colormap values are loaded

            switch(cmapType)
                case "source"
                    obj.CmapSelectDD.SelectedIndex = 2;
                case "user"
                    obj.CmapSelectDD.SelectedIndex = -1;
                otherwise
                    assert(false, "Invalid Colormap Type")
            end
        end

        function restoreState(obj, state)
            % Store the controls on the colormap tab to the specified
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

        function restoreValues(obj, prevVal)
            % Restore the toolstrip values when loading colormap from
            % workspace is canceled by user.

            obj.CmapSelectDD.SelectedIndex = prevVal.CmapSelectDDIndex;
            obj.CmapExprEF.Editable = prevVal.CmapExprEditable;
            obj.CmapExprEF.Value = prevVal.CmapExprValue;
        end
    end

    % Getters/Setters
    methods
        function val = get.CurrentState(obj)
            % Get the current state of the controls of the Colormap Tab

            for cnt = 1:numel(obj.ControlsList)
                cname = obj.ControlsList(cnt);
                val.(cname) = obj.(cname).Enabled;
            end
        end
    end

    % Callback methods for all controls present in the Colormap Tab
    methods(Access=private)
        function reactToCmapLoadFromWkspace(obj)
            % Callback function when the colormap is loaded from the
            % workspace

            % The values of the other controls at the point the load was
            % requested. If the load was canceled, these values need to be
            % restored
            currValues.CmapSelectDDIndex = obj.CmapSelectDD.SelectedIndex;
            currValues.CmapExprEditable = obj.CmapExprEF.Editable;
            currValues.CmapExprValue = obj.CmapExprEF.Value;

            obj.CmapSelectDD.SelectedIndex = -1;

            obj.CmapExprEF.Editable = false;
            obj.CmapExprEF.Value = ...
                getString(message("images:imageViewer:cmapExprExample"));

            cmapEventData = images.internal.app.viewer.ViewerEventData(currValues);
            notify(obj, "ColormapImportRequested", cmapEventData);
        end

        function reactToCmapSelect(obj, eventData)
            % Callback function when the colormap is selected from a
            % predefined list

            % If "none" is selected, update the SelectedIndex to show the
            % placeholder text
            if obj.CmapSelectDD.SelectedIndex == 1
                obj.CmapSelectDD.SelectedIndex = -1;
                cmapVal = "none";
            elseif obj.CmapSelectDD.SelectedIndex == 2
                if obj.IsSourceInList
                    cmapVal = "source";
                else
                    cmapVal = eventData.NewValue;
                end
            else
                cmapVal = eventData.NewValue;
            end

            % Gray out the Expression Edit field and add a placeholder text
            obj.CmapExprEF.Editable = false;
            obj.CmapExprEF.Value = ...
                getString(message("images:imageViewer:cmapExprExample"));

            cmapEventData = ...
                    images.internal.app.viewer.ViewerEventData(cmapVal);
            notify(obj, "ColormapSelectionDone", cmapEventData);
        end

        function reactToCmapExprChanged(obj, eventData)
            % Callback function when an expression is specified for the
            % colormap

            % Validate the expression
            newExpr = eventData.NewValue;
            try
                if newExpr == ""
                    % Indicates the user has cleared out the text field
                    % entry
                    cmap = [];
                    isCmapValid = true;
                    % Add the placeholder text in the case
                    obj.CmapExprEF.Value = ...
                        getString(message("images:imageViewer:cmapExprExample"));
                else
                    cmap = evalin("base", newExpr);
                    % Colormap must be an Mx3 double precision matrix
                    isCmapValid = isnumeric(cmap) && ismatrix(cmap) && ...
                                size(cmap, 2) == 3;
                end
            catch
                isCmapValid = false;
            end

            if ~isCmapValid
                % If invalid colormap specified, restore the previous value
                if eventData.OldValue == ""
                    obj.CmapExprEF.Value = ...
                        getString(message("images:imageViewer:cmapExprExample"));
                    obj.CmapExprEF.Editable = false;
                else
                    obj.CmapExprEF.Value = eventData.OldValue;
                end
                notify(obj, "ColormapExprInvalid");
            else
                % Reset the colormap selection
                obj.CmapSelectDD.SelectedIndex = -1; 

                cmapEventData = images.internal.app.viewer.ViewerEventData(cmap);
                notify(obj, "ColormapExprSpecified", cmapEventData)
            end
        end

        function reactToCmapExprFocusGained(obj)
            % Callback function when expression edit field gains focus

            if contains( obj.CmapExprEF.Value, ...
                    getString(message("images:imageViewer:cmapExprExample")) )
                obj.CmapExprEF.Value = "";
            end

            % Make the edit field editable
            obj.CmapExprEF.Editable = true;
        end
    end

    % Helper methods for creation
    methods(Access=private)
        function createColormapTab(obj)
            % Helper function to add sections in the Colormap tab
            % The colormap tab is organized as:
            % Import | Select Colormap      | Specify Colormap     
            %        | DD: List             | EF: Expression
            
            import matlab.ui.internal.toolstrip.*;

            obj.Tab = matlab.ui.internal.toolstrip.Tab( getString( ...
                        message("images:commonUIString:colormap") ) );
            obj.Tab.Tag = "ColormapTab";

            % Add Import Column
            importSection = addSection( obj.Tab, ...
                                getString(message("images:commonUIString:import")) );
            importColumn = importSection.addColumn();

            obj.CmapImportBtn = Button(Icon("import_data"));
            obj.CmapImportBtn.Tag = "ColormapImport";
            obj.CmapImportBtn.Enabled = false;
            obj.CmapImportBtn.Description = ...
                    getString(message("images:imageViewer:importCmapFromWkspaceTooltip"));
            cmapImportText = string(getString(message("images:commonUIString:import"))) + ...
                             newline() + ...
                             string(getString(message("images:commonUIString:colormap")));
            obj.CmapImportBtn.Text = cmapImportText;
            addlistener( obj.CmapImportBtn, "ButtonPushed", ...
                         @(~,~) reactToCmapLoadFromWkspace(obj) );
            importColumn.add(obj.CmapImportBtn);

            % Add Selection section
            selectSection = addSection( obj.Tab, ...
                    getString(message("images:commonUIString:select")) );
            selectColumn = selectSection.addColumn();

            selectLabel = Label(getString(message("images:commonUIString:chooseColormap")));
            selectColumn.add(selectLabel);
            obj.CmapSelectDD = DropDown(obj.CmapList);
            obj.CmapSelectDD.Tag = "ColormapSelect";
            obj.CmapSelectDD.Enabled = false;
            obj.CmapSelectDD.Description = ...
                        getString(message("images:imageViewer:selectCmapPresetTooltip"));
            obj.CmapSelectDD.Editable = false;
            obj.CmapSelectDD.SelectedIndex = -1;
            labelStr = getString(message("images:commonUIString:chooseColormap")) + " ...";
            obj.CmapSelectDD.PlaceholderText = labelStr;
            addlistener( obj.CmapSelectDD, "ValueChanged", ...
                         @(~, evt) reactToCmapSelect(obj, evt.EventData) );
            selectColumn.add(obj.CmapSelectDD);

            % Add an Expression Section
            exprSection = addSection( obj.Tab, ...
                            getString(message("images:imageViewer:cmapExprSection")) );
            exprColumn = exprSection.addColumn();

            exprLabel = Label(getString(message("images:imageViewer:cmapExpr")));
            exprColumn.add(exprLabel);

            obj.CmapExprEF = matlab.ui.internal.toolstrip.EditField();
            obj.CmapExprEF.Tag = "ColormapExpr";
            obj.CmapExprEF.Enabled = false;
            obj.CmapExprEF.Editable = false;
            obj.CmapExprEF.Description = ...
                    getString(message("images:imageViewer:cmapExprTooltip"));
            obj.CmapExprEF.Value = ...
                    getString(message("images:imageViewer:cmapExprExample"));
            addlistener( obj.CmapExprEF, "ValueChanged", ...
                        @(~, evt) reactToCmapExprChanged(obj, evt.EventData) );
            addlistener( obj.CmapExprEF, "FocusGained", ...
                         @(~, ~) reactToCmapExprFocusGained(obj) );
            exprColumn.add(obj.CmapExprEF);
        end
    end

    % Helper methods for operations
    methods(Access=private)
        function updateListOnLoad(obj, srcColormap)
            % Update the Colormap Tab when a new image is loaded.

            if ~isempty(srcColormap)
                % If there is a colormap available in the source, ensure
                % the entry "source" is available in the drop down list
                replaceAllItems(obj.CmapSelectDD, obj.CmapList);
                obj.CmapSelectDD.SelectedIndex = 2;
                obj.IsSourceInList = true;
            else
                % If there is no colormap available in the source, remove
                % the "source" entry from the  Drop Down List
                cmapList = obj.CmapList;
                cmapList(2) = [];
                replaceAllItems(obj.CmapSelectDD, cmapList);
                obj.CmapSelectDD.SelectedIndex = -1;
                obj.IsSourceInList = false;
            end
            obj.CmapExprEF.Value = ...
                getString(message("images:imageViewer:cmapExprExample"));
        end
    end
end