classdef TSControls < handle
    % Class that manages the toolstrip controls used in Semi Automatic
    % Segmentation techniques such as Graphcut/GrabCut/SAM

    properties(Access=public)
        ForegroundButton
        BackgroundButton
        EraseButton

        ClearButton

        ROIButton
        ROIStyleLabel
        ROIStyleButton
    end

    events
        ForegroundButtonPressed
        BackgroundButtonPressed
        EraseButtonPressed
        
        ClearForegroundSelected
        ClearBackgroundSelected
        ClearAllSelected
        
        RectangleROISelected
        PolygonROISelected
        ROIButtonPressed
    end

    % Public interface
    methods(Access=public)
        function obj = TSControls()
        end

        function addScribbleControls(obj, parent)
            import matlab.ui.internal.toolstrip.Icon;
            addFGControl(obj, parent, Icon("edit_graphCutForeground"));
            addBGControl(obj, parent, Icon("edit_graphCutBackground"));
        end

        function addEraseControls(obj, parent)
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;

            column = addColumn(parent);
            obj.EraseButton = ToggleButton(getMessageString("erase"),Icon("eraser"));
            obj.EraseButton.Tag = "btnEraseButton";
            obj.EraseButton.Description = getMessageString("eraseTooltip");
            addlistener( obj.EraseButton, "ValueChanged", ...
                                        @(~, evt) reactToEraseButton(obj, evt) );
            add(column, obj.EraseButton);
        end

        function addClearControls(obj, parent)
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;

            column = addColumn(parent);

            % Drop down list
            popupList = PopupList();

            clearAll = ListItem(getMessageString("clearAll"));
            clearAll.ShowDescription = false;
            clearAll.Tag = "ClearAll";
            addlistener(clearAll, "ItemPushed", @(~, ~) reactToClearAll(obj));
            
            clearFG = ListItem(getMessageString("clearForeground"));
            clearFG.Tag = "ClearForeground";
            clearFG.ShowDescription = false;
            addlistener(clearFG, "ItemPushed", @(~, ~) reactToClearFG(obj));
            
            clearBG = ListItem(getMessageString("clearBackground"));
            clearBG.ShowDescription = false;
            clearBG.Tag = "ClearBackground";
            addlistener(clearBG, "ItemPushed", @(~, ~) reactToClearBG(obj));
            
            popupList.add(clearAll);
            popupList.add(clearFG);
            popupList.add(clearBG);
            
            % Clear Split Button
            obj.ClearButton = SplitButton( getMessageString("clearAll"), ...
                                                Icon("clear") );
            obj.ClearButton.Tag = "btnClearButton";
            obj.ClearButton.Description = getMessageString("clearAllTooltip");
            obj.ClearButton.Popup = popupList;
            obj.ClearButton.Popup.Tag = "btnClearButtonPopup";
            addlistener( obj.ClearButton, "ButtonPushed", ...
                                            @(~, ~) reactToClearAll(obj) );

            add(column, obj.ClearButton);
        end

        function addROIControls(obj, parent, roiStyle)
            arguments
                obj
                parent
                roiStyle (1, :) string
            end

            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;

            roiStyle = unique(roiStyle, "stable");
            for cnt = 1:numel(roiStyle)
                roiStyle(cnt) = validatestring(roiStyle(cnt), ["rectangle", "polygon"]);
            end

            if ~isscalar(roiStyle)
                column = addColumn( parent, Width=90, ...
                                    HorizontalAlignment="center" );

                obj.ROIStyleLabel = Label(getMessageString("roiStyle"));
                obj.ROIStyleLabel.Tag = "ROIStyleLabel";
                add(column, obj.ROIStyleLabel);
    
                
                %Method Dropdown
                popupList = PopupList();

                for roi = roiStyle
                    switch roi
                        case "rectangle"
                            itemName = getMessageString("rectangle");
                            itemDesc = getMessageString("rectangleTooltip");
                            itemTag = "Rectangle";
                            itemCB = @(~, ~) reactToRectStyle(obj);

                        case "polygon"
                            itemName = getMessageString("polygon");
                            itemDesc = getMessageString("polygonTooltip");
                            itemTag = "Polygon";
                            itemCB = @(~, ~) reactToPolygonStyle(obj);

                        otherwise
                            assert(false, "Unsupported style");
                    end

                    item = ListItem(itemName);
                    item.Description = itemDesc;
                    item.Tag = itemTag;
                    addlistener(item, "ItemPushed", itemCB);

                    popupList.add(item);
                end
                
                firstStyle = roiStyle(1);
                switch(firstStyle)
                    case "rectangle"
                        ddMsg = getMessageString("rectangle");
                    case "polygon"
                        ddMsg = getMessageString("polygon");
                    otherwise
                        assert(false, "Unsupported style")
                end

                % ROI Style Button
                obj.ROIStyleButton = DropDownButton(ddMsg);
                obj.ROIStyleButton.Tag = "btnROIStyle";
                obj.ROIStyleButton.Description = getMessageString("drawROITooltip");
                
                obj.ROIStyleButton.Popup = popupList;
                obj.ROIStyleButton.Popup.Tag = "popupROIStyleList";

                add(column, obj.ROIStyleButton);
            end

            column = addColumn(parent);
            obj.ROIButton = ToggleButton( getMessageString('drawROI'), ...
                                                Icon('drawRectangle') );
            obj.ROIButton.Tag = 'btnROIButton';
            obj.ROIButton.Description = getMessageString('drawROITooltip');
            addlistener(obj.ROIButton, 'ValueChanged', @(~, evt) reactToDrawROI(obj, evt) );
            add(column, obj.ROIButton);
        end

        
        function enableAllControls(obj)
            if ~isempty(obj.ForegroundButton)
                obj.ForegroundButton.Enabled = true;
            end
            if ~isempty(obj.BackgroundButton)
                obj.BackgroundButton.Enabled = true;
            end
            if ~isempty(obj.EraseButton)
                obj.EraseButton.Enabled = true;
            end
            if ~isempty(obj.ClearButton)
                obj.ClearButton.Enabled = true;
            end
            if ~isempty(obj.ROIButton)
                obj.ROIButton.Enabled = true;
            end
            if ~isempty(obj.ROIStyleButton)
                obj.ROIStyleButton.Enabled = true;
            end
        end

        function disableAllControls(obj)
            if ~isempty(obj.ForegroundButton)
                obj.ForegroundButton.Enabled = false;
            end
            if ~isempty(obj.BackgroundButton)
                obj.BackgroundButton.Enabled = false;
            end
            if ~isempty(obj.EraseButton)
                obj.EraseButton.Enabled = false;
            end
            if ~isempty(obj.ClearButton)
                obj.ClearButton.Enabled = false;
            end
            if ~isempty(obj.ROIButton)
                obj.ROIButton.Enabled = false;
            end
            if ~isempty(obj.ROIStyleButton)
                obj.ROIStyleButton.Enabled = false;
            end
        end
    end
    
    % Toolstrip Layout Control
    methods(Access=protected)
        function addFGControl(obj, parent, icon)
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;

            column = addColumn(parent);
            obj.ForegroundButton = ToggleButton( ...
                            getMessageString("drawForeground"),icon );
            obj.ForegroundButton.Tag = "btnForegroundButton";
            obj.ForegroundButton.Description = getMessageString("foregroundTooltip");
            addlistener( obj.ForegroundButton, "ValueChanged", ...
                                        @(~, evt) reactToFGButton(obj, evt) );
            add(column, obj.ForegroundButton);
        end

        function addBGControl(obj, parent, icon)
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;

            column = addColumn(parent);
            obj.BackgroundButton = ToggleButton( ...
                                getMessageString("drawBackground"),icon );
            obj.BackgroundButton.Tag = "btnBackgroundButton";
            obj.BackgroundButton.Description = getMessageString("backgroundTooltip");
            addlistener( obj.BackgroundButton, "ValueChanged", ...
                                        @(~, evt) reactToBGButton(obj, evt) );
            add(column, obj.BackgroundButton);
        end
    end

    % Callbacks
    methods(Access=protected)
        function reactToFGButton(obj, evt)
            if evt.Source.Value
                obj.BackgroundButton.Value = false;
                if ~isempty(obj.EraseButton)
                    obj.EraseButton.Value = false;
                end
                evtData = images.internal.app.utilities.semiautoseg.events.ToolstripEventData(evt.Source.Value);
                notify(obj, "ForegroundButtonPressed", evtData);
            else
                evt.Source.Value = true;
            end
        end

        function reactToBGButton(obj, evt)
            if evt.Source.Value
                obj.ForegroundButton.Value = false;
                if ~isempty(obj.EraseButton)
                    obj.EraseButton.Value = false;
                end
                evtData = images.internal.app.utilities.semiautoseg.events.ToolstripEventData(evt.Source.Value);
                notify(obj, "BackgroundButtonPressed", evtData);
            else
                evt.Source.Value = true;
            end
        end

        function reactToEraseButton(obj, evt)
            if evt.Source.Value
                if ~isempty(obj.ForegroundButton)
                    obj.ForegroundButton.Value = false;
                    obj.BackgroundButton.Value = false;
                end
                evtData = images.internal.app.utilities.semiautoseg.events.ToolstripEventData(evt.Source.Value);
                notify(obj, "EraseButtonPressed", evtData);
            else
                evt.Source.Value = true;
            end
        end

        function reactToClearFG(obj)
            notify(obj, "ClearForegroundSelected");
        end

        function reactToClearBG(obj)
            notify(obj, "ClearBackgroundSelected");
        end

        function reactToClearAll(obj)
            notify(obj, "ClearAllSelected");
        end

        function reactToRectStyle(obj)
            import images.internal.app.segmenter.image.web.getMessageString;
            obj.ROIStyleButton.Text = getMessageString("rectangle");
            notify(obj, "RectangleROISelected");
        end

        function reactToPolygonStyle(obj)
            import images.internal.app.segmenter.image.web.getMessageString;
            obj.ROIStyleButton.Text = getMessageString("polygon");
            notify(obj, "PolygonROISelected");
        end

        function reactToDrawROI(obj, evt)
            evtData = images.internal.app.utilities.semiautoseg.events.ToolstripEventData(evt.Source.Value);
            notify(obj, "ROIButtonPressed", evtData);
        end
    end
end


% Copyright 2023-2024 The MathWorks, Inc.