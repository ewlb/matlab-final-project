classdef SAMTSControls < images.internal.app.utilities.semiautoseg.TSControls

    properties(Access=public)
        UseGPUButton

        SAMFlavorLabel
        SAMFlavorButton

        % Controls whether Auto Seg Mode is enabled/disabled on the
        % toolstrp
        AutoSegTglBtn matlab.ui.internal.toolstrip.ToggleButton ...
                        = matlab.ui.internal.toolstrip.ToggleButton.empty()

        % Clicking this lets client know that user wants to configure the
        % automatic segmentation parameters. It is the client's
        % responsibility to handle the parameter specification
        AutoSegConfigBtn matlab.ui.internal.toolstrip.Button ...
                        = matlab.ui.internal.toolstrip.Button.empty()
    end

    events
        UseGpuButtonPressed

        SAMFlavorSelected

        SAMAutoSegButtonPressed
        SAMAutoSegFGButtonPressed
        SAMAutoSegEraseButtonPressed

        SAMAutoSegConfigButtonPressed
    end

    % Public Methods
    methods(Access=public)
        function obj = SAMTSControls()
            obj@images.internal.app.utilities.semiautoseg.TSControls();
        end

        function addScribbleControls(obj, parent)
            import matlab.ui.internal.toolstrip.Icon;
            addFGControl(obj, parent, Icon("addRegion"));
            addBGControl(obj, parent, Icon("removeRegion"));
        end

        function addUseGPUControls(obj, parent)
            import matlab.ui.internal.toolstrip.*
            import images.internal.app.segmenter.image.web.getMessageString;

            column = addColumn(parent);

            useGpuBtn = ToggleButton( getMessageString("useGpuBtn"), ...
                                        Icon("gpu") );
            useGpuBtn.Tag = "UseGPUTglBtn";
            useGpuBtn.Description = getMessageString("useGpuTooltip");
            add(column, useGpuBtn);
            obj.UseGPUButton = useGpuBtn;
            obj.UseGPUButton.Enabled = canUseGPU();
            addlistener( obj.UseGPUButton, "ValueChanged", ...
                                @(~, evt) reactToUseGPUButton(obj, evt) );
        end

        function addSAMAutoSegControls(obj, parent)
            import matlab.ui.internal.toolstrip.*
            import images.internal.app.segmenter.image.web.getMessageString;

            column = addColumn(parent);

            doAutoSegTglBtn = ToggleButton( getMessageString("samAutoSegShowBoundary"), ...
                                        Icon("imageSegmentation") );
            doAutoSegTglBtn.Tag = "DoAutoSegTglBtn";
            doAutoSegTglBtn.Description = getMessageString("samAutoSegShowBndryTooltip");
            obj.AutoSegTglBtn = doAutoSegTglBtn;
            addlistener( obj.AutoSegTglBtn, "ValueChanged", ...
                                    @(~, evt) reactToAutoSegTglBtn(obj, evt) );
            add(column, obj.AutoSegTglBtn);
        end

        function addSAMAutoSegConfigControls(obj, parent)
            import matlab.ui.internal.toolstrip.*
            import images.internal.app.segmenter.image.web.getMessageString;

            column = addColumn(parent);

            configBtn = Button( getMessageString("samSettings"), ...
                                Icon("settings") );
            configBtn.Tag = "AutoSegConfigButton";
            configBtn.Description = getMessageString("samSettingsTooltip");
            obj.AutoSegConfigBtn = configBtn;
            addlistener( obj.AutoSegConfigBtn, "ButtonPushed", ...
                            @(~, ~) reactToAutoSegConfigBtn(obj) );
            add(column, obj.AutoSegConfigBtn);
        end

        function addSAMFlavorControls(obj, parent, samFlavor)
            arguments
                obj
                parent
                samFlavor (:, 1) string
            end

            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;

            samFlavor = unique(samFlavor, "stable");

            column = addColumn( parent, Width=90, ...
                                HorizontalAlignment="center" );

            obj.SAMFlavorLabel = Label(getMessageString("samFlavorLabel"));
            obj.SAMFlavorLabel.Tag = "SAMFlavorLabel";
            add(column, obj.SAMFlavorLabel);

            obj.SAMFlavorButton = DropDown(samFlavor);
            obj.SAMFlavorButton.Tag = "btnSAMFlavor";
            obj.SAMFlavorButton.Editable = false;
            obj.SAMFlavorButton.Description = getMessageString("samFlavorTooltip");
            obj.SAMFlavorButton.SelectedIndex = 1;
            addlistener( obj.SAMFlavorButton, "ValueChanged", ...
                         @(~, evt) reactTOSAMFlavorChanged(obj, evt) );

            add(column, obj.SAMFlavorButton);
        end

        function configureForScribbleDrawing(obj)
            import images.internal.app.segmenter.image.web.getMessageString;

            if ~isempty(obj.ForegroundButton)
                % Users typically creating FG, BG and Erase buttons
                % together
                obj.ForegroundButton.Enabled = true;
                obj.ForegroundButton.Value = true;
                obj.ForegroundButton.Description = ...
                                getMessageString("foregroundTooltip");
            
                obj.BackgroundButton.Enabled = true;
                obj.BackgroundButton.Value = false;
                obj.BackgroundButton.Description = ...
                                        getMessageString("backgroundTooltip"); 
            end

            if ~isempty(obj.EraseButton)
                obj.EraseButton.Enabled = false;
                obj.EraseButton.Value = false;
                obj.EraseButton.Description = ...
                                        getMessageString("eraseTooltip");
            end

            if ~isempty(obj.ClearButton)
                obj.ClearButton.Enabled = false;
                obj.ClearButton.Description = ...
                                    getMessageString("clearAllTooltip");
            end

            if ~isempty(obj.ROIButton)
                obj.ROIButton.Enabled = true;
                obj.ROIButton.Value = false;
            end

            if ~isempty(obj.AutoSegTglBtn)
                obj.AutoSegTglBtn.Enabled = true;
            end

            if ~isempty(obj.AutoSegConfigBtn)
                obj.AutoSegConfigBtn.Enabled = true;
            end
        end

        function configureForAutoSeg(obj)
            import images.internal.app.segmenter.image.web.getMessageString;

            if ~isempty(obj.ForegroundButton)
                obj.ForegroundButton.Enabled = true;
                obj.ForegroundButton.Value = true;
                obj.ForegroundButton.Description = ...
                            getMessageString("samForegroundAutoSegTooltip");
    
                obj.BackgroundButton.Enabled = false;
                obj.BackgroundButton.Value = false;
                obj.BackgroundButton.Description = "";
            end

            if ~isempty(obj.EraseButton)
                obj.EraseButton.Enabled = false;
                obj.EraseButton.Value = false;
                obj.EraseButton.Description = ...
                                    getMessageString("samEraseAutoSegTooltip");
            end

            if ~isempty(obj.ClearButton)
                obj.ClearButton.Enabled = false;
                obj.ClearButton.Description = "";
            end
            
            if ~isempty(obj.ROIButton)
                obj.ROIButton.Enabled = false;
            end

            if ~isempty(obj.AutoSegTglBtn)
                obj.AutoSegTglBtn.Enabled = true;
            end
            
            if ~isempty(obj.AutoSegConfigBtn)
                obj.AutoSegConfigBtn.Enabled = true;
            end
        end

        function enableAllControls(obj)
            enableAllControls@images.internal.app.utilities.semiautoseg.TSControls(obj);
            if ~isempty(obj.UseGPUButton)
                obj.UseGPUButton.Enabled = canUseGPU();
            end
            if ~isempty(obj.SAMFlavorButton)
                obj.SAMFlavorButton.Enabled = true;
            end
            if ~isempty(obj.AutoSegTglBtn)
                obj.AutoSegTglBtn.Enabled = true;
            end
            if ~isempty(obj.AutoSegConfigBtn)
                obj.AutoSegConfigBtn.Enabled = true;
            end
        end

        function disableAllControls(obj)
            disableAllControls@images.internal.app.utilities.semiautoseg.TSControls(obj);

            if ~isempty(obj.UseGPUButton)
                obj.UseGPUButton.Enabled = false;
            end
            if ~isempty(obj.SAMFlavorButton)
                obj.SAMFlavorButton.Enabled = false;
            end
            if ~isempty(obj.AutoSegTglBtn)
                obj.AutoSegTglBtn.Enabled = false;
            end
            if ~isempty(obj.AutoSegConfigBtn)
                obj.AutoSegConfigBtn.Enabled = false;
            end
        end
    end

    % Overriding parent class methods
    methods(Access=protected)
        function reactToFGButton(obj, evt)
            if ~isempty(obj.AutoSegTglBtn) && ...
                    obj.AutoSegTglBtn.Enabled && obj.AutoSegTglBtn.Value
                if evt.Source.Value
                    obj.EraseButton.Value = false;
                else
                    obj.Source.Value = true;
                end
                evtData = images.internal.app.utilities.semiautoseg.events.ToolstripEventData(evt.Source.Value);
                notify(obj, "SAMAutoSegFGButtonPressed", evtData);
            else
                reactToFGButton@images.internal.app.utilities.semiautoseg.TSControls(obj, evt);
            end
        end

        function reactToEraseButton(obj, evt)
            if ~isempty(obj.AutoSegTglBtn) && ...
                    obj.AutoSegTglBtn.Enabled && obj.AutoSegTglBtn.Value
                if evt.Source.Value
                    obj.ForegroundButton.Value = false;
                else
                    evt.Source.Value = true;
                end
                evtData = images.internal.app.utilities.semiautoseg.events.ToolstripEventData(evt.Source.Value);
                notify(obj, "SAMAutoSegEraseButtonPressed", evtData);
            else
                reactToEraseButton@images.internal.app.utilities.semiautoseg.TSControls(obj, evt);
            end
        end
    end

    methods(Access=private)
        function reactToUseGPUButton(obj, evt)
            evtData = images.internal.app.utilities.semiautoseg.events.ToolstripEventData(evt.Source.Value);
            notify(obj, "UseGpuButtonPressed", evtData);
        end

        function reactTOSAMFlavorChanged(obj, evt)
            if isequal(evt.EventData.NewValue, evt.EventData.OldValue)
                return;
            end

            evtData = images.internal.app.utilities.semiautoseg.events.ToolstripEventData(evt.EventData.NewValue);
            notify(obj, "SAMFlavorSelected", evtData);
        end

        function reactToAutoSegTglBtn(obj, evt)
            % Default SAM Auto Segmentation behaviour is to re-use the
            % Scribble Controls to combine and/or erase regions. There is
            % an expectation that Scribble tools have been initialized

            if evt.Source.Value
                configureForAutoSeg(obj);
            else
                configureForScribbleDrawing(obj);
            end

            evtData = images.internal.app.utilities.semiautoseg.events.ToolstripEventData(evt.Source.Value);
            notify(obj, "SAMAutoSegButtonPressed", evtData);
        end

        function reactToAutoSegConfigBtn(obj)
            notify(obj, "SAMAutoSegConfigButtonPressed");
        end
    end
end

% Copyright 2023-2024 The MathWorks, Inc.