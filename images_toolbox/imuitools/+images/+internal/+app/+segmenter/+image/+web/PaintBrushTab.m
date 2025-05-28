classdef PaintBrushTab < handle
    %

    % Copyright 2020-2024 The MathWorks, Inc.
    
    %%Public
    properties (GetAccess = public, SetAccess = protected)
        Visible = false;
    end
    
    
    %%Tab Management
    properties (Access = protected)
        hTab
        hAppContainer
        hTabGroup
        hToolstrip
        hApp
    end
    
    %%UI Controls
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        PaintBrushSection
        PaintBrushTglBtn
        EraserTglBtn
        BrushSizeSlider

        SubregionsSection
        UseSuperpixTglBtn

        SAMAutoSegSection
        
        ViewSection
        ViewMgr
        
        OpacitySliderListener
        ShowBinaryButtonListener
        
        ApplyCloseSection
        ApplyCloseMgr

        ModeListener

    end

    properties(Access=private)
        SAMTSCtrls

        % Manages the life time of the SAM object. Needed to support
        % canceling in the middle of a long running auto segmentation
        % operation
        SAMMgrObj (1, 1) images.internal.app.segmenter.image.web.sam.SAMMgr = ...
                    images.internal.app.segmenter.image.web.sam.SAMMgr.getInstance();

        % UI to handle the Automatic Segmentation Parameters
        AutoSegConfigDlg images.internal.app.segmenter.image.web.sam.AutoSegConfigUI = ...
                images.internal.app.segmenter.image.web.sam.AutoSegConfigUI.empty()

        % Cache the Automatic Segmentation for performance reasons
        AutoSegCachedLM (:, :) = []
    end
    
    %%Algorithm
    properties
                
        Brush
        ImageProperties
        Mask
        PriorMask

    end
    
    %%Public API
    methods
        function self = PaintBrushTab(toolGroup, tabGroup, theToolstrip, theApp, varargin)

            if (nargin == 5)
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup, 'paintOneLine');
            else
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup, drawROITab, varargin{:});
            end
            
            self.hAppContainer = toolGroup;
            self.hTabGroup = tabGroup;
            self.hToolstrip = theToolstrip;
            self.hApp = theApp;

            self.SAMTSCtrls = images.internal.app.utilities.semiautoseg.SAMTSControls();
            
            self.layoutTab();
            
            self.Brush = images.roi.internal.PaintBrush();
            set(self.Brush,'EraseColor',[1 1 1],'Color',[0 1 1]);
            
            self.disableAllButtons();
            self.PaintBrushTglBtn.Value = true;
        end
        
        function setMode(self, mode)
            import images.internal.app.segmenter.image.web.AppMode;
            
            switch (mode)
                case AppMode.NoMasks
                    %If the app enters a state with no mask, make sure we
                    %set the state back to unshow binary.
                    if self.ViewMgr.ShowBinaryButton.Enabled
                        self.reactToUnshowBinary();
                        % This is needed to ensure that state is settled
                        % after unshow binary.
                        drawnow;
                    end
                    self.ViewMgr.Enabled = false;
                    
                case AppMode.MasksExist
                    self.ViewMgr.Enabled = true;
                    
                case AppMode.ImageLoaded
                    self.updateImageProperties();

                    % Update the Max Object Size once the image is loaded
                    if ~isempty(self.AutoSegConfigDlg) && ...
                                            isvalid(self.AutoSegConfigDlg)
                        self.AutoSegConfigDlg.ImageSize = self.ImageProperties.ImageSize;
                    end
                    clearEmbeddings(self.SAMMgrObj);

                    % Cached Label Matrix is invalid once a new image is
                    % loaded into the app.
                    self.AutoSegCachedLM = [];
    
                case AppMode.OpacityChanged
                    self.reactToOpacityChange()
                case AppMode.ShowBinary
                    self.reactToShowBinary()
                case AppMode.UnshowBinary
                    self.reactToUnshowBinary()

                case {AppMode.DrawingDone, AppMode.AppClosing}
                    delete(self.AutoSegConfigDlg);
                    self.AutoSegConfigDlg = ...
                        images.internal.app.segmenter.image.web.sam.AutoSegConfigUI.empty();

                otherwise
                    % Tab receives events for which it has to take no
                    % action.
            end
        end
        
        function onApply(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            currentMask = self.Mask;

            commandForHistory = self.getCommandsForHistory();
            
            self.hApp.setTemporaryHistory(currentMask, ...
                 'ROIs', {commandForHistory});
            
            self.hApp.setCurrentMask(currentMask);
            
            self.ApplyCloseMgr.ApplyButton.Enabled = false;
            self.hApp.addToHistory(currentMask,getMessageString('paintBrushComment'),commandForHistory);
            
        end
        
        function onClose(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            self.hApp.clearTemporaryHistory()
                        
            updateDispSuperPixels(self,[]);
            
            % This ensures that zoom tools have settled down before the
            % marker pointer is removed.
            drawnow;
            
            % ROITab doesn't have a removePointer method, so set the
            % pointer to 'arrow' on close
            self.hApp.MousePointer = 'arrow';
            hIm = self.hApp.getScrollPanelImage();
            hIm.ButtonDownFcn = [];
            
            self.hToolstrip.showSegmentTab()
            self.hToolstrip.hidePaintTab()
            self.disableAllButtons();
            self.hToolstrip.setMode(AppMode.DrawingDone);
        end
        
        function show(self)
            currentMask = self.hApp.getCurrentMask();
            m = self.ImageProperties.ImageSize(1);
            n = self.ImageProperties.ImageSize(2);
            
            if isempty(currentMask)
                self.Mask = false([m,n]);
            else
                self.Mask = currentMask;
            end
            
            self.PriorMask = self.Mask;
            
            if (~self.isVisible())
                self.hTabGroup.add(self.hTab)
            end
            
            self.hApp.MousePointer = 'brush';
            self.Brush.Parent = getScrollPanelAxes(self.hApp);
            reactToBrushSizeSlider(self);
            if strcmp(self.hApp.ScrollPanel.Image.ImageHandle.InteractionMode,'')
                self.Brush.OutlineVisible = true;
            end
            set(self.Brush,'ImageSize',self.ImageProperties.ImageSize(1:2));
            set(self.Brush,'Mask',self.Mask);
            enableAllButtons(self);
            self.hApp.showLegend()
            hIm = self.hApp.getScrollPanelImage();
            hIm.ButtonDownFcn = @(~,~) self.drawCallback();
            
            self.makeActive()
            self.Visible = true;
            
            self.handleCreateSubregion();

            if isempty(self.ModeListener)
                self.ModeListener = addlistener( self.hApp.ScrollPanel.Image, ...
                        'InteractionModeChanged', ...
                        @(~,evt) reactToModeChange(self,evt) );
            end
        end
        
        function hide(self)
            
            self.hApp.MousePointer = 'arrow';
            self.Brush.OutlineVisible = false;
            self.hApp.hideLegend()
            
            self.hTabGroup.remove(self.hTab)
            self.Visible = false;
            disableAllButtons(self);
        end
        
        function makeActive(self)
            self.hTabGroup.SelectedTab = self.hTab;
        end        
    end
    
    %%Layout
    methods (Access = protected)
        
        function layoutTab(self)
            self.layoutPaintBrushSection();
            self.layoutSubregionSection();

            self.layoutViewSection();
            self.layoutApplyCloseSection();
        end

        function layoutPaintBrushSection(self)
            import matlab.ui.internal.toolstrip.*
            import images.internal.app.segmenter.image.web.getMessageString;

            self.PaintBrushSection = self.hTab.addSection( ...
                                        getMessageString("paintOneLine") );

            % Paint Brush
            column = self.PaintBrushSection.addColumn();
            self.PaintBrushTglBtn = ToggleButton( getMessageString('paint'),...
                                            Icon('brush') );
            self.PaintBrushTglBtn.Tag = "PaintBrushTglBtn";
            self.PaintBrushTglBtn.Description = getMessageString('paintTooltip');
            column.add(self.PaintBrushTglBtn);

            addlistener( self.PaintBrushTglBtn, "ValueChanged", ...
                         @(src,evt) reactToPaintBrushTglBtn(self) );

            % Eraser
            column = self.PaintBrushSection.addColumn();
            self.EraserTglBtn = ToggleButton( getMessageString('eraser'), ...
                                                        Icon('eraser') );
            self.EraserTglBtn.Tag = 'EraserTglBtn';
            self.EraserTglBtn.Description = getMessageString('eraserTooltip');
            column.add(self.EraserTglBtn);
            addlistener(self.EraserTglBtn,'ValueChanged',@(src,evt) reactToEraserTglBtn(self));
            
            % Brush Size
            column = self.PaintBrushSection.addColumn( 'HorizontalAlignment', ...
                                            'center', 'Width', 120);
            brushLabel = Label(getMessageString('brushSize'));
            column.add(brushLabel);
            
            self.BrushSizeSlider = Slider([0 100],50);
            self.BrushSizeSlider.Tag = 'BrushSizeSlider';
            self.BrushSizeSlider.Ticks = 0;
            self.BrushSizeSlider.Description = getMessageString('brushSizeTooltip');
            column.add(self.BrushSizeSlider);
            addlistener(self.BrushSizeSlider,'ValueChanged',@(~,~) reactToBrushSizeSlider(self));
        end

        function layoutSubregionSection(self)
            import matlab.ui.internal.toolstrip.*
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.SubregionsSection = self.hTab.addSection( ...
                            getMessageString("paintBrushSubregionMethod") );
            column = self.SubregionsSection.addColumn();

            self.UseSuperpixTglBtn = ToggleButton( getMessageString("paintSuperpixels"), ...
                                        Icon("superpixel") );
            self.UseSuperpixTglBtn.Tag = "UseSuperpixTglBtn";
            self.UseSuperpixTglBtn.Description = ...
                            getMessageString("paintSuperpixelsTooltip");
            addlistener( self.UseSuperpixTglBtn, "ValueChanged", ...
                                        @(~,~) reactToSuperpixTglBtn(self) );
            column.add(self.UseSuperpixTglBtn);

            addSAMAutoSegControls(self.SAMTSCtrls, self.SubregionsSection);
            self.SAMTSCtrls.AutoSegTglBtn.Text = getMessageString("paintBySAM");
            self.SAMTSCtrls.AutoSegTglBtn.Description = ...
                                    getMessageString("paintBySAMTooltip");
            addlistener(self.SAMTSCtrls, "SAMAutoSegButtonPressed", ...
                                @(~, evt) reactToSAMAutoSegButton(self, evt) );

            layoutSAMAutoSegSection(self);
        end

        function layoutSAMAutoSegSection(self)
            import images.internal.app.segmenter.image.web.getMessageString;

            section = self.hTab.addSection( ...
                            getMessageString("paintBySAMAutoSegParams") );

            addUseGPUControls(self.SAMTSCtrls, section);
            addlistener( self.SAMTSCtrls, "UseGpuButtonPressed", ...
                        @(~, evt) reactToUseGPUBtnPressed(self, evt) );

            addSAMAutoSegConfigControls(self.SAMTSCtrls, section);
            self.SAMTSCtrls.AutoSegConfigBtn.Text = ...
                                getMessageString("paintBrushSAMConfigBtn");
            addlistener( self.SAMTSCtrls, "SAMAutoSegConfigButtonPressed", ...
                            @(~, ~) reactToSAMAutoSegSettingsBtn(self) );

            self.SAMTSCtrls.AutoSegConfigBtn.Text = ...
                                getMessageString("paintBrushSAMConfigBtn");

            self.SAMAutoSegSection = section;
        end

        function layoutViewSection(self)
            self.ViewMgr = images.internal.app.segmenter.image.web.ViewControlsManager(self.hTab);
            self.ViewSection = self.ViewMgr.Section;
            
            self.OpacitySliderListener = ...
                    addlistener( self.ViewMgr.OpacitySlider, ...
                                 'ValueChanged', ...
                                 @(~,~)self.opacitySliderMoved() );

            self.ShowBinaryButtonListener = ...
                    addlistener( self.ViewMgr.ShowBinaryButton, ...
                                 'ValueChanged', ...
                                 @(hobj,~)self.showBinaryPress(hobj) );
        end
        
        function layoutApplyCloseSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            tabName = getMessageString('paintOneLine');
            
            useApplyAndClose = false;
            self.ApplyCloseMgr = iptui.internal.ApplyCloseManager(self.hTab, tabName, useApplyAndClose);
            self.ApplyCloseSection = self.ApplyCloseMgr.Section;
            
            addlistener(self.ApplyCloseMgr.ApplyButton,'ButtonPushed',@(~,~)self.onApply());
            addlistener(self.ApplyCloseMgr.CloseButton,'ButtonPushed',@(~,~)self.onClose());
        end

    end
    
    %%Callbacks
    methods (Access = protected)
        
        function reactToPaintBrushTglBtn(self)
            self.PaintBrushTglBtn.Value = true;
            self.EraserTglBtn.Value = false;
            self.Brush.Erase = false;
        end
        
        function reactToEraserTglBtn(self)
            self.PaintBrushTglBtn.Value = false;
            self.EraserTglBtn.Value = true;
            self.Brush.Erase = true;
        end
        
        function reactToSuperpixTglBtn(self)
            if self.UseSuperpixTglBtn.Value
                if self.SAMTSCtrls.AutoSegTglBtn.Value
                    % Enable mouse interactions. Interactions might be
                    % disabled if Auto Seg was previously used and an empty
                    % label matrix was received
                    installPointer(self);
                end
                self.SAMTSCtrls.AutoSegTglBtn.Value = false;
                disableAllControls(self.SAMTSCtrls);
                self.SAMTSCtrls.AutoSegTglBtn.Enabled = true;

                if ~isempty(self.AutoSegConfigDlg)
                    self.AutoSegConfigDlg.FigureHandle.Visible = "off";
                end

                L = self.segmentUsingSuperPix(self.BrushSizeSlider.Value/100);
                self.updateDispSuperPixels(L);
            else
                self.updateDispSuperPixels([]);
                self.SAMTSCtrls.AutoSegConfigBtn.Enabled = true;
            end
        end

        function reactToSAMAutoSegButton(self, evt)
            import images.internal.app.segmenter.image.web.sam.getCurrAutoSegParams;
            if evt.Data
                updateAppUIForSAMAutoSeg(self);

                params = getCurrAutoSegParams( ...
                                            self.AutoSegConfigDlg, ...
                                            self.ImageProperties.ImageSize );
                if isempty(self.AutoSegCachedLM)
                    self.segmentUsingSAM(params);
                end
                self.updateDispSuperPixels(self.AutoSegCachedLM);
            else
                if ~isempty(self.AutoSegConfigDlg)
                    self.AutoSegConfigDlg.FigureHandle.Visible = "off";
                end
                self.updateDispSuperPixels([]);

                % Enable mouse interactions. Interactions might be disabled
                % if Auto Seg returns an empty label matrix
                installPointer(self);
            end
        end

        function handleCreateSubregion(self)
             assert( ~( self.UseSuperpixTglBtn.Value && ...
                        self.SAMTSCtrls.AutoSegTglBtn.Value ), ...
                        "Both subregion methods cannot be active" );

             if self.UseSuperpixTglBtn.Value
                 self.reactToSuperpixTglBtn();
             elseif self.SAMTSCtrls.AutoSegTglBtn.Value
                 evt.Data = true;
                 self.reactToSAMAutoSegButton(evt);
             else
                 % No action
             end
        end

        function reactToUseGPUBtnPressed(~, evt)
            s = settings;
            activeVal = s.images.imagesegmentertool.SAMUseGPU.ActiveValue;
            if evt.Data
                pval = "yes";
            else
                pval = "no";
            end

            % If user has requested that they be prompted on whether to use
            % GPU, then do not save the Use GPU Toggle button value. 
            if activeVal ~= "prompt"
                s.images.imagesegmentertool.SAMUseGPU.PersonalValue = pval;
            end
        end

        function reactToSAMAutoSegSettingsBtn(self)
            import images.internal.app.segmenter.image.web.sam.handleAutoSegSettingsBtnClicked;

            if self.SAMTSCtrls.AutoSegTglBtn.Value
                % Config Button was clicked AFTER Tab is already in SAM
                % Auto Seg
                if isempty(self.AutoSegConfigDlg)
                    createUI(self);
                else
                    handleAutoSegSettingsBtnClicked(self.AutoSegConfigDlg);
                end
            else
                % Mark the app as busy until an initial segmentation has
                % been done
                self.hAppContainer.Busy = true;
                createUI(self);
                self.AutoSegConfigDlg.ParamControls.UpdateAutoSeg.Enable = "on";
            end
        end

        function reactToAutoSegUpdate(self, evt)
            % React to "Update Segmentation" being clicked on the settings
            % UI

            % App can be in Busy state IF Update was requested from UI
            % before tab being put in Auto seg Mode. 
            self.hAppContainer.Busy = false;

            self.segmentUsingSAM(evt.Data);
            self.updateDispSuperPixels(self.AutoSegCachedLM);

            if ~self.SAMTSCtrls.AutoSegTglBtn.Value
                % Indicates the Tab has not been put into Auto Seg Mode
                % when requesting the segmentation. Do so now.
                enableAllButtons(self);
                updateAppUIForSAMAutoSeg(self);
            end
        end

        function reactToAutoSegSettingsClosing(self)
            % React to the figure that contains the auto seg parameter
            % controls being closed

            if ~self.SAMTSCtrls.AutoSegTglBtn.Value
                % Indicates that Auto seg Settings UI was launched even
                % before the Tab was put into Auto Seg Mode. The reason for
                % this is to configure parameters before running a
                % segmentation. This code path indicates no segmentation
                % was actually done.
                self.hAppContainer.Busy = false;
            end
        end

        function createUI(self)
            import images.internal.app.segmenter.image.web.sam.AutoSegConfigUI;
            self.AutoSegConfigDlg = AutoSegConfigUI.createUI( ...
                                            self.hAppContainer, ...
                                            self.ImageProperties.ImageSize );
            self.AutoSegConfigDlg.FigureHandle.Visible = "on";
            self.AutoSegConfigDlg.ParamControls.UpdateAutoSeg.Enable = "on";
    
            addlistener( self.AutoSegConfigDlg, "UpdateSegmentation", ...
                            @(~, evt) reactToAutoSegUpdate(self, evt) );

            addlistener( self.AutoSegConfigDlg, "ParamsDialogClosing", ... 
                                @(~, ~) reactToAutoSegSettingsClosing(self) );
        end

        function reactToBrushSizeSlider(self)
            
            val = self.BrushSizeSlider.Value/100;
            
            % Input slider value between 0 and 1 to compute brush size
            if val < 0
                val = 0;
            elseif val > 1
                val = 1;
            end
        
            minSize = min(self.ImageProperties.ImageSize(1:2));
            % Biggest marker is 10% of smallest image dimension + one pixel
            % Smallest marker is one pixel
            % Requiring that marker size be an odd value is enforced in the
            % Paint Brush object
            val = round(val*minSize*0.1) + 1;
            
            self.Brush.BrushSize = val;
            
            self.handleCreateSubregion();
        end

        function updateAppUIForSAMAutoSeg(self)

            % Check if GPU can be used for computing embeddings
            [useGPU, isEnabledBtn] = ...
                images.internal.app.segmenter.image.web.sam.canUseGPU(self.hAppContainer);

            self.SAMTSCtrls.UseGPUButton.Enabled = isEnabledBtn;
            self.SAMTSCtrls.UseGPUButton.Value = useGPU;

            self.UseSuperpixTglBtn.Value = false;
            self.SAMTSCtrls.AutoSegTglBtn.Value = true;
            enableAllControls(self.SAMTSCtrls);
        end
        
        function updateDispSuperPixels(self, L)
            self.hApp.ScrollPanel.Image.Superpixels = L;
            redraw(self.hApp.ScrollPanel);

            self.Brush.ImageSize = self.ImageProperties.ImageSize(1:2);
            self.Brush.Superpixels = L;
        end

        function L = segmentUsingSuperPix(self, sliderVal)
            if isempty(sliderVal)
                L = [];
            else
                imSize = self.ImageProperties.ImageSize(1:2);
                reqNumSuperPix = round((((imSize(1)*imSize(2))/100)*((1-sliderVal))) + 100);

                L = superpixels(getImage(self.hApp), reqNumSuperPix);
            end
        end

        function segmentUsingSAM(self, params)

            if ~isempty(self.AutoSegConfigDlg)
                disableControls(self.AutoSegConfigDlg);
            end

            im = getRGBImage(self.hApp);

            useGPU = self.SAMTSCtrls.UseGPUButton.Enabled && ...
                                    self.SAMTSCtrls.UseGPUButton.Value;
            init(self.SAMMgrObj, im, self.hAppContainer);
            bringToFront(self.hAppContainer);
            [L, isCanceled, isError] = segmentAllObjects( ...
                self.SAMMgrObj, im, params, useGPU, self.hAppContainer );

            if isError || isCanceled
            else
                % Update the cached labels only if the operation was not
                % canceled by the user
                self.AutoSegCachedLM = L;
            end
            
            if ~isCanceled
                % Keep the update auto seg button enabled if the Auto Seg
                % operation was not performed OR errored out.
                if ~isempty(self.AutoSegConfigDlg)
                    self.AutoSegConfigDlg.ParamControls.UpdateAutoSeg.Enable = "on";
                end

                % Discard previously cached label matrix as it is no longer
                % valid
                if isError
                    self.AutoSegCachedLM = [];
                end
            else
                % Since Auto Seg was canceled, keep the Update Auto Seg
                % button enabled
                if ~isempty(self.AutoSegConfigDlg)
                    self.AutoSegConfigDlg.ParamControls.UpdateAutoSeg.Enabled = true;
                end
            end

            if ~isempty(self.AutoSegConfigDlg)
                enableControls(self.AutoSegConfigDlg);
            end

            if isempty(L)
                % Disable mouse interactions
                self.hApp.MousePointer = 'arrow';
                hIm = self.hApp.getScrollPanelImage();
                hIm.ButtonDownFcn = [];
            else
                % Enable mouse interactions
                installPointer(self);
            end
        end

        function L = generateSuperpixels(self,sz)  
            if isempty(sz)
                L = [];
            else
                % N --> numel(img/100)*(% of slider) + 100
                self.hAppContainer.Busy = true;
                imSize = self.ImageProperties.ImageSize(1:2);
                self.Brush.ImageSize = imSize(1:2);
                L = superpixels(getImage(self.hApp),round((((imSize(1)*imSize(2))/100)*((1-sz))) + 100));
                self.hAppContainer.Busy = false;
            end
            
            self.Brush.Superpixels = L;
            
        end
        
        function opacitySliderMoved(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
                        
            newOpacity = self.ViewMgr.Opacity;
            self.hApp.updateScrollPanelOpacity(newOpacity)
            
            self.hToolstrip.setMode(AppMode.OpacityChanged)
            
        end
        
        function showBinaryPress(self,hobj)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            if hobj.Value
                self.hApp.showBinary()
                self.ViewMgr.OpacitySlider.Enabled = false;
                self.ViewMgr.OpacityLabel.Enabled  = false;
                self.hToolstrip.setMode(AppMode.ShowBinary)
            else
                self.hApp.unshowBinary()
                self.ViewMgr.OpacitySlider.Enabled = true;
                self.ViewMgr.OpacityLabel.Enabled  = true;
                self.hToolstrip.setMode(AppMode.UnshowBinary)
            end
        end
        
    end
    
     %%Helpers
    methods (Access = protected)
        
        function reactToOpacityChange(self)
            % We move the opacity slider to reflect a change in opacity
            % level coming from a different tab.            
            newOpacity = self.hApp.getScrollPanelOpacity();
            self.ViewMgr.Opacity = 100*newOpacity;
            
        end
        
        function reactToShowBinary(self)
            self.ViewMgr.OpacitySlider.Enabled  = false;
            self.ViewMgr.ShowBinaryButton.Value = true;
            self.Brush.Color = [1 1 1];
        end
        
        function reactToUnshowBinary(self)
            self.ViewMgr.OpacitySlider.Enabled  = true;
            self.ViewMgr.ShowBinaryButton.Value = false;
            self.Brush.Color = [0 1 1];
        end

        function reactToModeChange(self,evt)
            if self.Visible
                self.Brush.OutlineVisible = strcmp(evt.Mode,'');
            end
        end
        
        function updateInteraction(self)
            self.installPointer()
        end
        
        function installPointer(self)
            
            hIm  = self.hApp.getScrollPanelImage();
            self.hApp.MousePointer = 'brush';
            
            hFig = getScrollPanelFigure(self.hApp);
            images.roi.setBackgroundPointer(hFig,'dot');

            hIm.ButtonDownFcn = @(~,~) self.drawCallback();

        end
        
        function drawCallback(self)

            if ~isClickValid(self.hApp)
                return;
            end
            
            beginDrawing(self.Brush);
            self.Mask = self.Brush.Mask;
            clear(self.Brush);
            self.Brush.Mask = self.Mask;

            updateCommittedMask(self.hApp.ScrollPanel,self.PriorMask & self.Mask)
            updatePreviewMask(self.hApp.ScrollPanel,self.Mask)
            enableApply(self);
            
        end
        
        function TF = isVisible(self)
            TF = ~isempty(self.hAppContainer.SelectedToolstripTab) && strcmp(self.hAppContainer.SelectedToolstripTab.title, self.hTab.Title);
        end
        
        function updateImageProperties(self)
            im = self.hApp.getImage();
            
            self.ImageProperties = struct(...
                'ImageSize',size(im),...
                'DataType',class(im),...
                'DataRange',[min(im(:)) max(im(:))]);
        end
            
        function enableApply(self)
            self.ApplyCloseMgr.ApplyButton.Enabled = true;
        end
        
        function disableApply(self)
            self.ApplyCloseMgr.ApplyButton.Enabled = false;
        end
        
        function showAsBusy(self)
            self.hAppContainer.Busy = true;
        end
        
        function unshowAsBusy(self)
            self.hAppContainer.Busy = false;
        end
        
        function enableAllButtons(self)
            self.PaintBrushTglBtn.Enabled = true;

            self.UseSuperpixTglBtn.Enabled = true;
            self.SAMTSCtrls.AutoSegTglBtn.Enabled = true;
            if self.SAMTSCtrls.AutoSegTglBtn.Value
                enableAllControls(self.SAMTSCtrls);
            else
                disableAllControls(self.SAMTSCtrls);
                self.SAMTSCtrls.AutoSegConfigBtn.Enabled = true;
                self.SAMTSCtrls.AutoSegTglBtn.Enabled = true;
            end
            
            self.EraserTglBtn.Enabled = true;
            self.BrushSizeSlider.Enabled = true;
            self.ViewMgr.Enabled = true;
            self.ApplyCloseMgr.CloseButton.Enabled = true;
        end
        
        function disableAllButtons(self)
            self.PaintBrushTglBtn.Enabled = false;

            self.UseSuperpixTglBtn.Enabled = false;
            disableAllControls(self.SAMTSCtrls);
            
            self.EraserTglBtn.Enabled = false;
            self.BrushSizeSlider.Enabled = false;
            self.ViewMgr.Enabled = false;
            self.ApplyCloseMgr.CloseButton.Enabled = false;
        end
        
        function commands = getCommandsForHistory(~)
            
            commands = {};

        end
        
    end
    
end
