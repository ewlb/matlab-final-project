classdef GraphCutBaseTab < handle
    
    % Tab with shared components for Lazy Snapping and GrabCut UIs
    
    % Copyright 2017-2023 The MathWorks, Inc.
    
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
        
        HideDataBrowser = true;
    end
    
    %%UI Controls
    properties (GetAccess = {?uitest.factory.Tester,...
            ?images.internal.app.segmenter.image.web.GraphCutTab,...
            ?images.internal.app.segmenter.image.web.GrabCutTab, ...
            ?images.internal.app.segmenter.image.web.SAMTab}, SetAccess = protected)
        CommonTSCtrls (1, 1) images.internal.app.utilities.semiautoseg.TSControls
        DrawCtrls (1, 1) images.internal.app.utilities.semiautoseg.DrawingControls

        DrawSection
        ClearSection
        SuperpixelSection
        ShowSuperpixelButton
        SuperpixelDensityButton
        SuperpixelSliderLabel
        
        TextureSection
        TextureMgr
        
        ViewSection
        ViewMgr
        
        ApplyCloseSection
        ApplyCloseMgr
        
        OpacitySliderListener
        ShowBinaryButtonListener
        
        MessageStatus = true;        
    end
    
    %%Algorithm
    properties
        ImageProperties
        GraphCutter
        NumSuperpixels
        NumRequestedSuperpixels
        isGraphBuilt
        SuperpixelLabelMatrix
    end
    
    methods (Abstract)
        onApply(self);
        onClose(self);
        setMode(self, mode);
    end
    
    methods (Abstract, Access = protected)
        ctrl = createCommonTSControls(self);
        layoutTab(self);
        reactToScribbleDone(obj);
        [mask, maskSrc] = applySegmentation(self);
        TF = isUserDrawingValid(self);
        cleanupAfterClearAll(self);
        cleanupAfterClear(self, markerType);
        disableAllButtons(self);
        getCommandsForHistory(self);
        showMessagePane(self);
        hideMessagePane(self)
    end
    
    %%Public API
    methods
        function self = GraphCutBaseTab(toolGroup, tabGroup, theToolstrip, theApp, tabTag, varargin)

            if (nargin == 5)
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup, tabTag);
            else
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup, tabTag, varargin{:});
            end
            
            self.hAppContainer = toolGroup;
            self.hTabGroup = tabGroup;
            self.hToolstrip = theToolstrip;
            self.hApp = theApp;
            
            self.CommonTSCtrls = self.createCommonTSControls();

            self.DrawCtrls = images.internal.app.utilities.semiautoseg.DrawingControls();

            addlistener( self.DrawCtrls, "ScribbleDone", ...
                            @(~, ~) self.reactToScribbleDone() );

            self.layoutTab();
            
            self.disableAllButtons();
            
        end
        
        function show(self)
            
            if self.HideDataBrowser
                self.hApp.disableBrowser();
            end
            
            if (~self.isVisible())
                self.hTabGroup.add(self.hTab)
            end
            
            self.hApp.showLegend()
            
            self.makeActive()
            self.Visible = true;
        end
        
        function hide(self)
            
            self.hApp.hideLegend()
            
            if self.HideDataBrowser
                self.hApp.enableBrowser();
            end
            
            self.hTabGroup.remove(self.hTab)
            self.Visible = false;
        end
        
        function makeActive(self)
            self.hTabGroup.SelectedTab = self.hTab;
        end
        
    end
    
    %%Layout
    methods (Access = protected)
        
        function layoutDrawSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;

            addScribbleControls(self.CommonTSCtrls, self.DrawSection);
            addlistener( self.CommonTSCtrls, "ForegroundButtonPressed", ...
                            @(~, evt) self.reactToForegroundButton(evt) );
            addlistener( self.CommonTSCtrls, "BackgroundButtonPressed", ...
                            @(~, evt) self.reactToBackgroundButton(evt) );

            addEraseControls(self.CommonTSCtrls, self.DrawSection);
            addlistener( self.CommonTSCtrls, "EraseButtonPressed", ...
                                @(~, evt) self.reactToEraseButton(evt) );
        end
        
        function layoutClearTools(self, parent)
            % Layout

            addClearControls(self.CommonTSCtrls, parent);

            addlistener( self.CommonTSCtrls, "ClearForegroundSelected", ...
                            @(~, ~) self.clearForeground() );
            addlistener( self.CommonTSCtrls, "ClearBackgroundSelected", ...
                            @(~, ~) self.clearBackground() );
            addlistener( self.CommonTSCtrls, "ClearAllSelected", ...
                            @(~, ~) self.clearAll() );
        end
        
        function layoutSuperpixelSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;
            
            % Show Superpixel Boundary Button
            self.ShowSuperpixelButton = ToggleButton( getMessageString('showSuperpixelBoundaries'), ...
                                                    Icon('superpixel') );
            self.ShowSuperpixelButton.Tag = 'btnShowSuperpixelButton';
            self.ShowSuperpixelButton.Description = ...
                                getMessageString('showSuperpixelTooltip');
            addlistener( self.ShowSuperpixelButton, 'ValueChanged', ...
                                @(~,~) self.showSuperpixelBoundaries() );

            % Superpixel Density Slider
            self.SuperpixelDensityButton = Slider([0,100],50);
            self.SuperpixelDensityButton.Tag = 'btnSuperpixelDensitySlider';
            self.SuperpixelDensityButton.Ticks = 0;
            self.SuperpixelDensityButton.Description = ...
                                    getMessageString('superpixelTooltip');
            addlistener( self.SuperpixelDensityButton, 'ValueChanged', ...
                                @(~,~) self.updateSuperpixelDensity() );

            self.SuperpixelSliderLabel = Label(getMessageString('superpixelDensity'));
            self.SuperpixelSliderLabel.Tag = "SuperpixelDensityLabel";

            % Layout
            c = self.SuperpixelSection.addColumn('width',120,...
                'HorizontalAlignment','center');
            c.add(self.ShowSuperpixelButton);
            c.add(self.SuperpixelSliderLabel);
            c.add(self.SuperpixelDensityButton);  
            
        end
        
        function section = addViewSection(self)
            
            self.ViewMgr = images.internal.app.segmenter.image.web.ViewControlsManager(self.hTab);
            section = self.ViewMgr.Section;
            
            self.OpacitySliderListener = addlistener( self.ViewMgr.OpacitySlider, ...
                        'ValueChanged', @(~,~)self.opacitySliderMoved() );
            self.ShowBinaryButtonListener = addlistener( self.ViewMgr.ShowBinaryButton, ...
                    'ValueChanged', @(hobj,~)self.showBinaryPress(hobj) );
        end

    end
    
    %%Algorithm
    methods (Access = protected)
        function initDrawControls(self)
            init( self.DrawCtrls, self.hApp.getScrollPanelImage(), ...
                                        self.ImageProperties.ImageSize );
        end

        function initializeGraphCut(self)
            self.initDrawControls();
            
            % Set default number of superpixels
            self.setSuperpixelDensity(self.SuperpixelDensityButton.Value)
                
            self.defineSuperpixels();
        end
        
        function defineSuperpixels(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.hApp.updateStatusBarText(getMessageString('performingOversegmentation'));
            self.showAsBusy()
            
            % Number of superpixels can't exceed the number of pixels
            imageSize = self.ImageProperties.ImageSize;
            if self.NumRequestedSuperpixels > imageSize(1)*imageSize(2)
                self.NumRequestedSuperpixels = imageSize(1)*imageSize(2);
            end
            
            [self.SuperpixelLabelMatrix,self.NumSuperpixels] = superpixels(...
                self.hApp.getImage(),self.NumRequestedSuperpixels,'IsInputLab',self.hApp.wasRGB);
                        
            self.isGraphBuilt = false;
            
            if self.isUserDrawingValid()
                [mask, maskSrc] = self.applySegmentation();
                self.setTempHistory(mask, maskSrc);
            else
                self.hApp.updateStatusBarText('');
                self.unshowAsBusy()
            end
            
        end

        function doSegmentationAndUpdateApp(self)
            if self.isUserDrawingValid()
                [mask, maskSrc] = self.applySegmentation();
                self.setTempHistory(mask, maskSrc);
                self.hideMessagePane();
            else
                if isempty(self.DrawCtrls.BackgroundInd)
                    self.MessageStatus = false;
                else
                    self.MessageStatus = true;
                end
                self.showMessagePane();
                self.disableApply();
                self.hApp.hideLegend();
                self.hApp.ScrollPanel.resetPreviewMask();
            end
        end

    end
    
    %%Callbacks
    methods(Access=private)
        function reactToForegroundButton(self, evt)
            if evt.Data
                self.addForegroundScribble();
            end
        end

        function reactToBackgroundButton(self, evt)
            if evt.Data
                self.addBackgroundScribble();
            end
        end

        function reactToEraseButton(self, evt)
            if evt.Data
                self.eraseScribbles();
            end
        end
    end

    methods (Access = protected)
        function addForegroundScribble(self)
            self.updateEditMode("fore");
        end
        
        function addBackgroundScribble(self)
            self.updateEditMode("back");
        end

        function eraseScribbles(self)
            self.updateEditMode("erase");
        end
        
        function clearForeground(self)
            % This is necessary to allow any lines to finish drawing before
            % they are deleted.
            drawnow;
            
            self.DrawCtrls.clearFGScribbles();
            self.MessageStatus = true;
            self.cleanupAfterClear("fore");
        end
        
        function clearBackground(self)
            % This is necessary to allow any lines to finish drawing before
            % they are deleted.
            drawnow;
            
            self.DrawCtrls.clearBGScribbles();
            self.MessageStatus = false;
            self.cleanupAfterClear("back");
        end

        function clearAll(self)
            % This is necessary to allow any lines to finish drawing before
            % they are deleted.
            drawnow;
            
            self.DrawCtrls.clearFGScribbles();
            self.DrawCtrls.clearBGScribbles();
            self.MessageStatus = true;

            self.cleanupAfterClearAll();
        end
        
        function updateSuperpixelDensity(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
          
            self.setSuperpixelDensity(self.SuperpixelDensityButton.Value)
            
            self.defineSuperpixels();
            self.isGraphBuilt = false;
            if self.ShowSuperpixelButton.Value
                self.hApp.ScrollPanel.Image.Superpixels = self.SuperpixelLabelMatrix;
                redraw(self.hApp.ScrollPanel);
            end

        end
        
        function setSuperpixelDensity(self,val)            
            % Number of Superpixels = (numel/100)*(% of slider) + 50;
            imageSize = self.ImageProperties.ImageSize;
            self.NumRequestedSuperpixels = round((((imageSize(1)*imageSize(2))/100)*(val/100)) + 100);            
        end
        
        function showSuperpixelBoundaries(self)
            % Toggle view of superpixel boundaries
            if self.ShowSuperpixelButton.Value
                self.hApp.ScrollPanel.Image.Superpixels = self.SuperpixelLabelMatrix;
            else
                self.hApp.ScrollPanel.Image.Superpixels = [];
            end
            redraw(self.hApp.ScrollPanel);
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
            self.ViewMgr.OpacitySlider.Enabled     = false;
            self.ViewMgr.ShowBinaryButton.Value = true;
        end
        
        function reactToUnshowBinary(self)
            self.ViewMgr.OpacitySlider.Enabled     = true;
            self.ViewMgr.ShowBinaryButton.Value = false;
        end
        
        function resetAppState(self)
            
            self.hApp.resetAxToolbarMode();
        
            self.hApp.MousePointer = 'arrow';
        end
        
        function TF = isVisible(self)
            TF = ~isempty(self.hAppContainer.SelectedToolstripTab) && ...
                    strcmp(self.hAppContainer.SelectedToolstripTab.title, self.hTab.Title);
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
        
        function setTempHistory(self, mask, maskSrc)
            commandForHistory = self.getCommandsForHistory();
            self.hApp.setTemporaryHistory(mask, ...
                 maskSrc, {commandForHistory});
        end

        function updateEditMode(self, editMode)
            self.hApp.resetAxToolbarMode();
            dcEditMode = editMode;

            switch editMode
                case {"fore", "back"}
                    % Install new pointer behavior
                    self.hApp.MousePointer = 'fore';

                case "erase"
                    % Install new pointer behavior
                    self.hApp.MousePointer = 'eraser';

                case "ROI"
                    self.hApp.MousePointer = 'roi';

                case "none"
                    self.hApp.MousePointer = 'arrow';

                case "brush"
                    self.hApp.MousePointer = 'brush';
                    dcEditMode = "superpix";
            end

            self.DrawCtrls.EditMode = dcEditMode;
        end
    
    end
    
end
