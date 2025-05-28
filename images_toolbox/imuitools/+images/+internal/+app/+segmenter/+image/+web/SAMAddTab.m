classdef SAMAddTab < images.internal.app.segmenter.image.web.SAMTab
%   SAM Tab when it is opened in Add Mode

    properties(Access=private)
        % UI to handle the Automatic Segmentation Parameters
        AutoSegConfigDlg images.internal.app.segmenter.image.web.sam.AutoSegConfigUI = ...
                images.internal.app.segmenter.image.web.sam.AutoSegConfigUI.empty()

        % Buttons for the Automatic Segmentation (aka Full Image
        % Segmentation)
        AutoSegSection matlab.ui.internal.toolstrip.Section ...
                            = matlab.ui.internal.toolstrip.Section.empty()
    end

    properties(Access=private)
        % Label indices selected when creating a mask from Automatic
        % Segmentation
        AutoSegSelectedLbls (:, :) double = [];

        % Parameters used for Automatic Segmentation
        AutoSegParamsUsed struct = struct.empty();

        % Cache the Automatic Segmentation for performance reasons
        AutoSegCachedLM (:, :) = [];

        SAMAddMode (1, 1) string { mustBeMember( SAMAddMode, ...
                            ["prompt", "autoseg"] ) } = "prompt";
    end

    % Public Interface
    methods(Access=public)
        function obj = SAMAddTab(toolGroup, tabGroup, theToolstrip, theApp, varargin)
            % Call base class constructor
            obj@images.internal.app.segmenter.image.web.SAMTab( ...
                        toolGroup, tabGroup, theToolstrip, ...
                        theApp, varargin{:} );

            addlistener( obj.DrawCtrls, "SuperpixDrawingDone", ...
                        @(~, evt) reactToSuperpixDrawingDone(obj, evt) );
        end
    end

    % Implementation of Abstract Methods
    methods(Access=public)
        function onApply(obj)
            if obj.SAMAddMode == "autoseg"
                % Auto Seg
                isRGB = numel(obj.ImageProperties.ImageSize) == 3;
                if isRGB
                    varName = "RGB";
                else
                    varName = "X";
                end

                mlCode = "imsz = size(" + varName + ", [1 2]);" + newline() + ...
                         "BWout = false(imsz);" + newline() + ...
                         obj.createAutoSegMLCode(obj.AutoSegParamsUsed, isRGB);
                obj.CurrSessMLCode = mlCode + obj.CurrSessMLCode;
                
                mlCode = "idx = ismember(L, selectedLbls);" + newline() + ... 
                         "BWout(idx) = ~BWout(idx);" + newline();
                obj.CurrSessMLCode = obj.CurrSessMLCode + mlCode;
            end

            % This is needed only for Add mask workflows. 
            obj.CurrSessMLCode = obj.CurrSessMLCode + ...
                                    "BW = BW | BWout;" + newline();

            onApply@images.internal.app.segmenter.image.web.SAMTab(obj);
        end
        
        function setMode(obj, mode)
            import images.internal.app.segmenter.image.web.AppMode;
            switch(mode)
                case AppMode.ImageLoaded
                    setMode@images.internal.app.segmenter.image.web.SAMTab(obj, mode);

                    % Update the dimensions of the loaded image
                    if ~isempty(obj.AutoSegConfigDlg) && ...
                                            isvalid(obj.AutoSegConfigDlg)
                        obj.AutoSegConfigDlg.ImageSize = obj.ImageProperties.ImageSize;
                    end

                    % Cached Label Matrix is invalid once a new image is
                    % loaded into the app.
                    obj.AutoSegCachedLM = [];

                case {AppMode.NoImageLoaded, AppMode.SAMDone}
                    setMode@images.internal.app.segmenter.image.web.SAMTab(obj, mode);

                    % Delete the Config Params UI once the Tab is closed
                    delete(obj.AutoSegConfigDlg);
                    obj.AutoSegConfigDlg = ...
                        images.internal.app.segmenter.image.web.sam.AutoSegConfigUI.empty();

                    % Discard the cached values of the Auto Seg parameters
                    % used
                    obj.AutoSegParamsUsed = struct.empty();

                case AppMode.SAMAddTabOpened
                    if ~setupTabForSegmentation(obj)
                        onClose(obj);
                    end

                case AppMode.AppClosing
                    % Delete the Config Params UI when the app is closing
                    delete(obj.AutoSegConfigDlg);
                    obj.AutoSegConfigDlg = ...
                        images.internal.app.segmenter.image.web.sam.AutoSegConfigUI.empty();

                otherwise
                    % App contains modes not relevant for this Tab
            end
        end
    end

    % Implementation of internal abstract methods
    methods(Access=protected)
        function layoutTab(obj)
            layoutUseGPUSection(obj);
            layoutROISection(obj);
            layoutDrawingMarkersSection(obj);
            layoutAutoSegmentSection(obj);
            layoutApplyCloseSection(obj);
        end

        function layoutApplyCloseSection(obj)
            import images.internal.app.segmenter.image.web.getMessageString;
                        
            useApplyAndClose = false;
            obj.ApplyCloseMgr = iptui.internal.ApplyCloseManager(obj.hTab, ...
                    getMessageString("samTabShortName"), useApplyAndClose );
            obj.ApplyCloseSection = obj.ApplyCloseMgr.Section;
            
            addlistener( obj.ApplyCloseMgr.ApplyButton, "ButtonPushed", ...
                                                @(~, ~) onApply(obj) );
            addlistener( obj.ApplyCloseMgr.CloseButton, "ButtonPushed", ...
                                                @(~,~) onClose(obj) );
        end

        function createBox(obj)
            createROI(obj, Deletable=true);
        end

        function mask = getBinaryMask(obj)
            mask = getScrollPanelPreview(obj.hApp) | ...
                                        getScrollPanelCommitted(obj.hApp);
        end

        function hideTab(obj)
            showSegmentTab(obj.hToolstrip);
            hideSAMAddTab(obj.hToolstrip);
        end

        function setupDefaultTabSegState(obj)
            obj.CommonTSCtrls.AutoSegTglBtn.Enabled = true;
            obj.CommonTSCtrls.AutoSegTglBtn.Value = false;

            % These settings apply only to Auto Seg. However, a user might
            % want to update settings before performing auto seg instead of
            % using default values. This is reasonable given that auto seg
            % takes ~20secs on GPU and ~80secs on CPU.
            obj.CommonTSCtrls.AutoSegConfigBtn.Enabled = true;

            obj.SAMAddMode = "prompt";
        end

        function cleanupOnSegDoneImpl(obj)
            clear(obj.DrawCtrls.Brush);
            obj.AutoSegSelectedLbls = [];
        end
    end

    % Layout helpers
    methods(Access=private)
        function layoutAutoSegmentSection(obj)
            import matlab.ui.internal.toolstrip.*
            import images.internal.app.segmenter.image.web.getMessageString;
            
            obj.AutoSegSection = addSection( obj.hTab, ...
                                    getMessageString("samAutoSegSection") );
            obj.AutoSegSection.Tag = "AutoSegSection";
            
            addlistener( obj.CommonTSCtrls, "SAMAutoSegFGButtonPressed", ...
                                @(~, evt) reactToAutoSegFGPressed(obj, evt) );

            addlistener( obj.CommonTSCtrls, "SAMAutoSegEraseButtonPressed", ...
                                @(~, evt) reactToAutoSegErasePressed(obj, evt) );
            
            addSAMAutoSegControls(obj.CommonTSCtrls, obj.AutoSegSection);
            addlistener( obj.CommonTSCtrls, "SAMAutoSegButtonPressed", ...
                                @(~, evt) reactToAutoSegTglBtn(obj, evt) );

            addSAMAutoSegConfigControls(obj.CommonTSCtrls, obj.AutoSegSection);
            addlistener( obj.CommonTSCtrls, "SAMAutoSegConfigButtonPressed", ...
                            @(~, ~) reactToAutoSegSettingsBtn(obj) );

        end
    end

    % Overriding methods from SAMTab
    methods(Access=protected)
        function cmd = getCommandsForHistory(obj)
            if obj.SAMAddMode == "autoseg"
                cmd = obj.CurrSessMLCode;
            else
                cmd = getCommandsForHistory@images.internal.app.segmenter.image.web.SAMTab(obj);
            end
        end
    end

    % Callbacks
    methods(Access=private)
        function reactToAutoSegFGPressed(obj, evt)
            if evt.Data
                obj.DrawCtrls.EditMode = "superpix";
            end
        end

        function reactToAutoSegErasePressed(obj, evt)
            if evt.Data
                obj.DrawCtrls.EditMode = "superpixerase";
            end
        end

        function reactToAutoSegTglBtn(obj, evt)
            import images.internal.app.segmenter.image.web.sam.getCurrAutoSegParams;

            if evt.Data
                % Data contains parameters used for automatic segmentation.
                % Indicates button is pressed
                turnOnAutoSegMode(obj);

                params = getCurrAutoSegParams( obj.AutoSegConfigDlg, ...
                                            obj.ImageProperties.ImageSize );

                % Perform Automatic Segmentation only if it has not been
                % cached
                if isempty(obj.AutoSegCachedLM)
                    doAutoSeg(obj, params);
                end

                updateSuperPixDisplay(obj, obj.AutoSegCachedLM);
            else
                % Indicates button is unpressed
                turnOffAutoSegMode(obj);

                % The computed Auto Seg LM does not need to be thrown away.
                % Update the Image Display to hide the super pixel
                % boundaries.
                updateSuperPixDisplay(obj, []);
            end
        end
    
        function reactToAutoSegSettingsBtn(obj)
            import images.internal.app.segmenter.image.web.sam.handleAutoSegSettingsBtnClicked;
            
            if obj.SAMAddMode == "autoseg"
                % Config Button was clicked AFTER Tab is already in Auto
                % Seg Mode.
                if isempty(obj.AutoSegConfigDlg)
                    createUI(obj);
                else
                    handleAutoSegSettingsBtnClicked(obj.AutoSegConfigDlg);
                end
                
            else
                % Tab is not in Auto Seg Mode. No segmentation has been
                % done yet. Mark the App as Busy
                obj.hAppContainer.Busy = true;
                createUI(obj);
            end
        end

        function reactToAutoSegUpdate(obj, evt)
            % React to user request for updating the segmentation after
            % updated the parameters

            % App can be in Busy state IF Update was requested from UI
            % before tab being put in Auto seg Mode.
            obj.hAppContainer.Busy = false;

            doAutoSeg(obj, evt.Data);
            updateSuperPixDisplay(obj, obj.AutoSegCachedLM);

            if obj.SAMAddMode == "prompt"
                % If the Auto Seg update is invoked even before explicity
                % putting the app in Auto Seg mode, then move app to auto
                % seg mode.
                obj.CommonTSCtrls.AutoSegTglBtn.Value = true;
                turnOnAutoSegMode(obj);
            end
        end

        function reactToAutoSegSettingsClosing(obj)
            if obj.SAMAddMode == "prompt"
                % The Auto Seg Params Dialog is being closed. This code
                % branch indicates the Auto Seg button has not been
                % pressed. This indicates user wanted to run Auto Seg after
                % configuring it but decided against it. Hence, the
                % previous prompt-based state needs to be restored.
                obj.hAppContainer.Busy = false;
            end
        end

        function reactToSuperpixDrawingDone(obj, evt)
            import images.internal.app.segmenter.image.web.getMessageString;
            import images.internal.app.segmenter.image.web.SAMTab.matrix2dToString;

            lblsInMask = evt.Data.LabelsInMask;
            obj.CommonTSCtrls.EraseButton.Enabled = ~isempty(lblsInMask);

            if ~obj.CommonTSCtrls.EraseButton.Enabled
                obj.CommonTSCtrls.EraseButton.Value = false;
                obj.CommonTSCtrls.ForegroundButton.Value = true;
                obj.DrawCtrls.EditMode = "superpix";
            end

            if ~isempty(lblsInMask)
                mlCode = "selectedLbls = " + matrix2dToString(lblsInMask, true) ...
                                                    + ";" + newline();
                showLegend(obj.hApp);
            else
                mlCode = "selectedLbls = [];" + newline();
                hideLegend(obj.hApp);
            end
            obj.CurrSessMLCode = mlCode;

            obj.AutoSegSelectedLbls = lblsInMask;
            obj.ApplyCloseMgr.ApplyButton.Enabled = ~isempty(lblsInMask);

            mask = evt.Data.Mask;
            maskSrc = getMessageString("segmentAnythingComment");
            setTempHistory(obj, mask, maskSrc);
        end
    end

    % Helpers
    methods(Access=private)
        function turnOnAutoSegMode(obj)
            % Actions that need to be taken when Auto Segmentation is
            % enabled

            import images.internal.app.segmenter.image.web.getMessageString;

            obj.SAMAddMode = "autoseg";
            
            if isempty(obj.AutoSegCachedLM)
                updateEditMode(obj, "none");
            else
                updateEditMode(obj, "brush");
            end

            % "Press" the AutoSegTglBtn in case the first segmentation is
            % being done via the ConfigBtn.
            obj.CommonTSCtrls.AutoSegTglBtn.Enabled = true;
            obj.CommonTSCtrls.AutoSegTglBtn.Value = true;

            % Update the state of the Marker Controls suitably.
            if ~isempty(obj.DrawSection)
                obj.CommonTSCtrls.ForegroundButton.Enabled = true;
                obj.CommonTSCtrls.ForegroundButton.Value = true;

                obj.CommonTSCtrls.BackgroundButton.Enabled = false;
                
                obj.CommonTSCtrls.EraseButton.Enabled = true;
                obj.CommonTSCtrls.EraseButton.Value = false;

                obj.CommonTSCtrls.ClearButton.Enabled = false;
            end

            % Disable ROI Section
            if ~isempty(obj.ROISection)
                disableAll(obj.ROISection);
            end

            hideLegend(obj.hApp);

            enableAll(obj.AutoSegSection);
            obj.ApplyCloseMgr.CloseButton.Enabled = true;

            % Undo any alpha data changes
            if ~isempty(obj.DrawCtrls.ROI)
                updateROIDisplay(obj, false);
            end

            % Remove all user inputs
            clearAllScribbles(obj.DrawCtrls);
            clearROI(obj.DrawCtrls);

            obj.MaskLogits = [];
            obj.CurrSessMLCode = "";

            clearTemporaryHistory(obj.hApp);
        end

        function turnOffAutoSegMode(obj)
            % Actions that need to be taken when Auto Segmentation is
            % disabled

            import images.internal.app.segmenter.image.web.getMessageString;

            if ~isempty(obj.AutoSegConfigDlg)
                obj.AutoSegConfigDlg.FigureHandle.Visible = "off";
            end

            obj.AutoSegParamsUsed = struct.empty();

            obj.SAMAddMode = "prompt";

            updateEditMode(obj, "fore");
            
            updateSuperpixels(obj.DrawCtrls, []);

            hideLegend(obj.hApp);

            obj.ApplyCloseMgr.ApplyButton.Enabled = false;

            obj.MaskLogits = [];
            obj.CurrSessMLCode = "";

            obj.AutoSegSelectedLbls = [];

            clearTemporaryHistory(obj.hApp);
        end

        function doAutoSeg(obj, params)
            % Perform Auto Segmentation and update the App UI

            if ~isempty(obj.AutoSegConfigDlg)
                disableControls(obj.AutoSegConfigDlg);
            end

            bringToFront(obj.hAppContainer);

            im = getRGBImage(obj.hApp);
            useGPU = obj.CommonTSCtrls.UseGPUButton.Enabled && ...
                                    obj.CommonTSCtrls.UseGPUButton.Value;
            [L, isCanceled, isError] = segmentAllObjects( ...
                    obj.SAMMgrObj, im, params, useGPU, obj.hAppContainer );

            if isError || isCanceled
                % Keep the update auto seg button enabled if the Auto Seg
                % operation was not performed OR errored out.
                if ~isempty(obj.AutoSegConfigDlg)
                    obj.AutoSegConfigDlg.ParamControls.UpdateAutoSeg.Enable = "on";
                end

                % Discard previously cached label matrix as it is no longer
                % valid
                if isError
                    obj.AutoSegCachedLM = [];
                end
            else
                obj.AutoSegParamsUsed = params;

                % Cache the computed label matrix for improved performance
                obj.AutoSegCachedLM = L;
            end

            % If the label matrix is empty (either due to error or valid
            % run), there are no regions available to select. Hence, do not
            % show a paintbrush to paint FG regions.
            if isempty(L)
                updateEditMode(obj, "none");
            else
                updateEditMode(obj, "brush");
            end

            % When Auto Seg is executed, UI elements which allow users to
            % update Auto Seg Parameters are disabled. Re-enable it once
            % the Auto Seg operation has completed either successfully or
            % unsuccessfully.
            if ~isempty(obj.AutoSegConfigDlg)
                enableControls(obj.AutoSegConfigDlg);
            end
        end

        function updateSuperPixDisplay(obj, L)
            updateSuperpixels(obj.DrawCtrls, L);
            obj.hApp.ScrollPanel.Image.Superpixels = L;
            redraw(obj.hApp.ScrollPanel);
        end

        function createUI(obj)
            import images.internal.app.segmenter.image.web.sam.AutoSegConfigUI;
            obj.AutoSegConfigDlg = AutoSegConfigUI.createUI( ...
                                            obj.hAppContainer, ...
                                            obj.ImageProperties.ImageSize );
            obj.AutoSegConfigDlg.ParamControls.UpdateAutoSeg.Enable = "on";

            addlistener( obj.AutoSegConfigDlg, "UpdateSegmentation", ...
                            @(~, evt) reactToAutoSegUpdate(obj, evt) );

            addlistener( obj.AutoSegConfigDlg, "ParamsDialogClosing", ... 
                                @(~, ~) reactToAutoSegSettingsClosing(obj) );
        end
    end

    methods(Access=private, Static)
        function mlCode = createAutoSegMLCode(params, isRGB)
            import images.internal.app.segmenter.image.web.SAMTab.matrix2dToString;
            ptGridSizeStr = matrix2dToString(params.PointGridSize, true, false);
            if isRGB
                varName = "RGB";
            else
                varName = "X";
            end
            mlCode = "% SAM expects image data to be in the range [0-255]." + newline() + ...
                     "samImage = 255*rescale(" + varName + ");" + newline() + newline() + ...
                     "cc = imsegsam(samImage, " + ...
                     "MinObjectArea=" + string(params.MinObjectArea) + ", " + ...
                     "MaxObjectArea=" + string(params.MaxObjectArea) + ", " + ...
                     "PointGridSize=" + ptGridSizeStr + ", " + ...
                     "PointGridDownscaleFactor=" + string(params.PointGridDownscaleFactor) + ", " + ...
                     "NumCropLevels=" + string(params.NumCropLevels) + ", " + ...
                     "ScoreThreshold=" + string(params.ScoreThreshold) +", " + ...
                     "SelectStrongestThreshold=" + string(params.SelectStrongestThreshold) +", " + ...
                     "ExecutionEnvironment=""auto"");" + newline();
            mlCode = mlCode + "L = labelmatrix(cc);" + newline();
            mlCode = mlCode + "L = refineBorders(L);" + newline() + newline();
        end
    end
end


% Copyright 2023-2024 The MathWorks, Inc.
