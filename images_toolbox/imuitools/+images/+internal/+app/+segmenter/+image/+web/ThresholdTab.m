classdef ThresholdTab < handle
    %

    % Copyright 2015-2024 The MathWorks, Inc.
    
    %%Public
    properties (GetAccess = public, SetAccess = private)
        Visible = false;
    end
    
    %%Tab Management
    properties (Access = private)
        hTab
        hAppContainer
        hTabGroup
        hToolstrip
        hApp
    end
    
    %%UI Controls
    properties
        ThresholdSection
        MethodButton
        ThresholdLabel
        ThresholdSlider
        ThresholdText
        SensitivityControl
        ForegroundPolarityLabel
        ForegroundPolarityCombo
        
        ViewSection
        ViewMgr
        
        ApplyCloseSection
        ApplyCloseMgr
        
        ThresholdSliderListener
        ThresholdTextListener
        OpacitySliderListener
        ShowBinaryButtonListener
        
        UserActionStarted = false;
    end
    
    %%Algorithm
    properties
        ImageProperties
        ForegroundPolarityItems = {'bright','dark'};
    end
    
    %%Public API
    methods
        function self = ThresholdTab(toolGroup, tabGroup, theToolstrip, theApp, varargin)

            if (nargin == 3)
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup,'thresholdTab');
            else
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup,'thresholdTab', varargin{:});
            end
            
            self.hAppContainer = toolGroup;
            self.hTabGroup = tabGroup;
            self.hToolstrip = theToolstrip;
            self.hApp = theApp;
            
            self.layoutTab();
        end
        
        function show(self)
            self.UserActionStarted = false;
            self.hApp.disableBrowser();
            
            if (~self.isVisible())
                self.hTabGroup.add(self.hTab)
            end
            
            if ~isempty(self.ImageProperties)
                self.updateSliderLimits()
            end
            
            self.hApp.showLegend()
            
            self.makeActive()
            self.Visible = true;
        end
        
        function hide(self)
            
            self.hApp.hideLegend()
            
            self.hApp.enableBrowser();
            
            self.hTabGroup.remove(self.hTab)
            self.Visible = false;
        end
        
        function makeActive(self)
            self.hTabGroup.SelectedTab = self.hTab;
        end
        
        function setMode(self, mode)
            import images.internal.app.segmenter.image.web.AppMode;
            
            switch (mode)
            case AppMode.NoMasks
                %If the app enters a state with no mask, make sure we set
                %the state back to unshow binary.
                if self.ViewMgr.ShowBinaryButton.Enabled
                    self.reactToUnshowBinary();
                    % This is needed to ensure that state is settled after
                    % unshow binary.
                    drawnow;
                end
                self.ViewMgr.Enabled = false;
                
            case AppMode.MasksExist
                self.ViewMgr.Enabled = true;
                
            case AppMode.ImageLoaded
                self.updateImageProperties()

            case AppMode.ThresholdImage
                self.enableAllButtons()
                self.applySelectedThreshold()
                
            case AppMode.OpacityChanged
                self.reactToOpacityChange()
                case AppMode.ShowBinary
                    self.reactToShowBinary()
                case AppMode.UnshowBinary
                    self.reactToUnshowBinary()

            otherwise
                % Many App Modes do not require any action from this tab.
            end
            
        end
        
        function applyAndClose(self)
            self.onApply();
            self.onClose();
        end
        
        function onApply(self)
            
            self.ApplyCloseMgr.ApplyButton.Enabled = false;
            
            self.hApp.commitTemporaryHistory()
            self.UserActionStarted = false;
            
        end
        
        function onClose(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            self.hApp.clearTemporaryHistory()
            
            self.hToolstrip.showSegmentTab()
            self.hToolstrip.hideThresholdTab()
            self.hToolstrip.setMode(AppMode.ThresholdDone);
        end
    end
    
    %%Layout
    methods (Access = private)
        
        function layoutTab(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.ThresholdSection   = self.hTab.addSection(getMessageString('threshold'));
            self.ThresholdSection.Tag = 'Threshold';
            self.ViewSection        = self.addViewSection();
            self.ApplyCloseSection  = self.addApplyCloseSection();
            
            self.layoutThresholdSection();
        end
        
        function layoutThresholdSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            %Method Label
            methodLabel = matlab.ui.internal.toolstrip.Label(getMessageString('method'));
            methodLabel.Tag = 'labelMethod';
            methodLabel.Description = getMessageString('thresholdMethodTooltip');
            
            %Method Button
            self.MethodButton =  matlab.ui.internal.toolstrip.DropDownButton(getMessageString('globalThreshold'));             
            self.MethodButton.Tag = 'btnMethod';
            self.MethodButton.Description = getMessageString('thresholdMethodTooltip');            
            
            sub_popup = matlab.ui.internal.toolstrip.PopupList();
            
            sub_item1 = matlab.ui.internal.toolstrip.ListItem(getMessageString('globalThreshold'));
            sub_item1.Description = getMessageString('globalDescription');
            sub_item1.Tag = "globalThreshold";
            addlistener(sub_item1, 'ItemPushed', @(~,~) self.setGlobalMethodSelection());
            
            sub_item2 = matlab.ui.internal.toolstrip.ListItem(getMessageString('manualThreshold'));
            sub_item2.Description = getMessageString('manualDescription');
            sub_item2.Tag = "manualThreshold";
            addlistener(sub_item2, 'ItemPushed', @(~,~) self.setManualMethodSelection());
            
            sub_item3 = matlab.ui.internal.toolstrip.ListItem(getMessageString('adaptiveThreshold'));
            sub_item3.Description = getMessageString('adaptiveDescription');
            sub_item3.Tag = "adaptiveThreshold";
            addlistener(sub_item3, 'ItemPushed', @(~,~) self.setAdaptiveMethodSelection());
            
            sub_popup.add(sub_item1);
            sub_popup.add(sub_item2);
            sub_popup.add(sub_item3);
            
            self.MethodButton.Popup = sub_popup;
            self.MethodButton.Popup.Tag = 'popupMethodList';
            
            %Threshold Label
            self.ThresholdLabel = matlab.ui.internal.toolstrip.Label(getMessageString('threshold'));
            self.ThresholdLabel.Tag = 'thresholdLabel';
            self.ThresholdLabel.Description = getMessageString('thresholdSliderTooltip');
                        
            %Threshold Slider
            self.ThresholdSlider = matlab.ui.internal.toolstrip.Slider([0,100],5);
            self.ThresholdSlider.Compact = true;
            self.ThresholdSlider.Ticks = 0;
            self.ThresholdSlider.Tag = 'thresholdSlider';
            self.ThresholdSlider.Description = getMessageString('thresholdSliderTooltip');
            self.ThresholdSliderListener = addlistener(self.ThresholdSlider,'ValueChanged',@(src,~)self.manualThresholdChanged(src));
            
            %Threshold Text
            self.ThresholdText = matlab.ui.internal.toolstrip.EditField(num2str(self.ThresholdSlider.Value));
            self.ThresholdText.Tag = 'thresholdEdit';
            self.ThresholdText.Description = getMessageString('thresholdTextTooltip');
            self.ThresholdTextListener = addlistener(self.ThresholdText,'ValueChanged',@(src,~)self.manualThresholdChanged(src));
            
            %Sensitivity
            self.SensitivityControl = iptui.internal.SliderEditControl(getMessageString('sensitivity'),0,100,50);
            addlistener(self.SensitivityControl,'PropValueChanged', @(~,~)self.sensitivityChanged());
            self.SensitivityControl.LabelControl.Description = getMessageString('sensitivitySliderTooltip');
            self.SensitivityControl.SliderControl.Description = getMessageString('sensitivitySliderTooltip');
            self.SensitivityControl.EditControl.Description = getMessageString('sensitivityTextTooltip');
            
            %Foreground Polarity Label
            self.ForegroundPolarityLabel = matlab.ui.internal.toolstrip.Label(getMessageString('fgPolarity'));
            self.ForegroundPolarityLabel.Tag = 'labelFGPolarity';
            self.ForegroundPolarityLabel.Description = getMessageString('fgPolarityTooltip');
            
            %Foreground Polarity Combo Box
            self.ForegroundPolarityCombo = matlab.ui.internal.toolstrip.DropDown({getMessageString('bright');getMessageString('dark')});
            self.ForegroundPolarityCombo.SelectedIndex = 1;
            self.ForegroundPolarityCombo.Tag = 'comboFGPolarity';
            self.ForegroundPolarityCombo.Description = getMessageString('fgPolarityTooltip');
            addlistener(self.ForegroundPolarityCombo, 'ValueChanged', @(~,~)self.foregroundPolarityChanged());
            
            %Layout
            c = self.ThresholdSection.addColumn('HorizontalAlignment','center');
            c.add(methodLabel);
            c.add(self.MethodButton);
            c5 = self.ThresholdSection.addColumn(...
                'HorizontalAlignment','center');
            c5.add(self.ForegroundPolarityLabel);
            c5.add(self.ForegroundPolarityCombo);
            c2 = self.ThresholdSection.addColumn();
            c2.add(self.ThresholdLabel);
            c2.add(self.SensitivityControl.LabelControl);
            c3 = self.ThresholdSection.addColumn('width',120,...
                'HorizontalAlignment','center');
            c3.add(self.ThresholdSlider);
            c3.add(self.SensitivityControl.SliderControl);
            c4 = self.ThresholdSection.addColumn('width',80,...
                'HorizontalAlignment','center');
            c4.add(self.ThresholdText);
            c4.add(self.SensitivityControl.EditControl);
            
        end
        
        function section = addViewSection(self)
            
            self.ViewMgr = images.internal.app.segmenter.image.web.ViewControlsManager(self.hTab);
            section = self.ViewMgr.Section;
            
            self.OpacitySliderListener = addlistener(self.ViewMgr.OpacitySlider, 'ValueChanged', @(~,~)self.opacitySliderMoved());
            self.ShowBinaryButtonListener = addlistener(self.ViewMgr.ShowBinaryButton, 'ValueChanged', @(hobj,~)self.showBinaryPress(hobj));
        end
        
        function section = addApplyCloseSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            tabName = getMessageString('thresholdTab');
            
            useApplyAndClose = true;
            
            self.ApplyCloseMgr = iptui.internal.ApplyCloseManager(self.hTab, tabName, useApplyAndClose);
            section = self.ApplyCloseMgr.Section;
            
            addlistener(self.ApplyCloseMgr.ApplyButton,'ButtonPushed',@(~,~)self.applyAndClose());
            addlistener(self.ApplyCloseMgr.CloseButton,'ButtonPushed',@(~,~)self.onClose());
        end
    end
    
    %%Algorithm
    methods (Access = private)
        function applySelectedThreshold(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            im = im2gray(self.hApp.getRGBImage());

            if self.hApp.wasRGB
                variableName = 'RGB';
            else
                variableName = 'X';
            end
            
            switch self.MethodButton.Text
            case getMessageString('globalThreshold')
                mask = imbinarize(im);
                commandForHistory = sprintf('BW = imbinarize(im2gray(%s));',...
                    variableName);
                comment_text = getMessageString('globalThresholdComment');
                
            case getMessageString('manualThreshold')
                t = str2double(self.ThresholdText.Value);
                mask = im > t;
                commandForHistory = sprintf('BW = im2gray(%s) > %d;', ...
                    variableName, t);
                comment_text = getMessageString('manualThresholdComment');
                
            case getMessageString('adaptiveThreshold')
                sensitivity = self.SensitivityControl.SliderControl.Value / 100;
                
                idx = self.ForegroundPolarityCombo.SelectedIndex;
                foregroundPolarity  = self.ForegroundPolarityItems{idx};
                
                mask = imbinarize(im, 'adaptive','Sensitivity',sensitivity,'ForegroundPolarity',foregroundPolarity);
                commandForHistory = sprintf('BW = imbinarize(im2gray(%s), ''adaptive'', ''Sensitivity'', %f, ''ForegroundPolarity'', ''%s'');', ...
                    variableName, sensitivity, foregroundPolarity);
                comment_text = getMessageString('adaptiveThresholdComment');
                
            otherwise
                assert(false, 'Incorrect threshold option')
            end
            
            if (self.UserActionStarted)
                self.hApp.setCurrentMask(mask)
                self.hApp.setTemporaryHistory(mask, ...
                    comment_text, ...
                    {commandForHistory})
            else
                self.hApp.setTemporaryHistory(mask, ...
                    comment_text, ...
                    {commandForHistory})
                self.UserActionStarted = true;
            end
            
            self.hApp.updateScrollPanelPreview(mask)
        end
    end
    
    %%Callbacks
    methods (Access = private)
        function setGlobalMethodSelection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.MethodButton.Text = getMessageString('globalThreshold');
            
            self.hToolstrip.setMode(AppMode.ThresholdImage);
        end
        
        function setManualMethodSelection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.MethodButton.Text = getMessageString('manualThreshold');
            
            self.hToolstrip.setMode(AppMode.ThresholdImage);
        end
        
        function setAdaptiveMethodSelection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.MethodButton.Text = getMessageString('adaptiveThreshold');
            
            self.hToolstrip.setMode(AppMode.ThresholdImage);
        end
        
        function manualThresholdChanged(self, updatedControl)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.manageThresholdControlSync(updatedControl)
            

            self.hToolstrip.setMode(AppMode.ThresholdImage);
        end
        
        function sensitivityChanged(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            

            self.hToolstrip.setMode(AppMode.ThresholdImage);
        end
        
        function foregroundPolarityChanged(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            

            self.hToolstrip.setMode(AppMode.ThresholdImage);
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
    methods (Access = private)
        
        function manageThresholdControlSync(self, controlToMatch)
            
            dataType = self.ImageProperties.DataType;
            isFloat  = strcmpi(dataType,'double') || strcmpi(dataType,'single');
            
            % If slider was moved, update text.
            if isa(controlToMatch, 'matlab.ui.internal.toolstrip.Slider')
                if isFloat
                    self.ThresholdText.Value = num2str(controlToMatch.Value / 255);
                else
                    self.ThresholdText.Value = num2str(controlToMatch.Value);
                end
            
            % If text was edited, update slider.    
            elseif isa(controlToMatch, 'matlab.ui.internal.toolstrip.EditField')
                value = str2double(controlToMatch.Value);
                if isnan(value) || ~isreal(value)
                    sliderValue = self.ThresholdSlider.Value;
                    if isFloat
                        sliderValue = sliderValue / 255;
                    end
                    self.ThresholdText.Value = num2str(sliderValue);
                    return;
                end
                
                if isFloat
                    minValue = self.ThresholdSlider.Limits(1) / 255;
                    maxValue = self.ThresholdSlider.Limits(2) / 255;
                else
                    minValue = self.ThresholdSlider.Limits(1);
                    maxValue = self.ThresholdSlider.Limits(2);
                end
                
                % Valid value - continue.
                if value < minValue
                    value = minValue;
                elseif value > maxValue
                    value = maxValue;
                end
                
                self.ThresholdText.Value = num2str(value);
                if isFloat
                    self.ThresholdSlider.Value = value * 255;
                else
                    self.ThresholdSlider.Value = value;
                end
                
            end
            
        end
        
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
        
        function TF = isVisible(self)
            TF = ~isempty(self.hAppContainer.SelectedToolstripTab) && strcmp(self.hAppContainer.SelectedToolstripTab.title, self.hTab.Title);
        end
        
        function updateImageProperties(self)
            im = im2gray(self.hApp.getRGBImage());
            
            self.ImageProperties = struct(...
                'ImageSize',size(im),...
                'DataType',class(im),...
                'DataRange',[min(im(:)) max(im(:))]);
        end
        
        function updateSliderLimits(self)
            
            dataRange = self.ImageProperties.DataRange;
            dataType  = self.ImageProperties.DataType;
            % Disable listener for threshold slider when limits are
            % updated.
            self.ThresholdSliderListener.Enabled = false;
            self.ThresholdTextListener.Enabled   = false;
            drawnow;
            
            if strcmpi(dataType,'double') || strcmpi(dataType,'single')
                % Expect the image to be normalized in [0,1].
                self.ThresholdSlider.Limits = [double(dataRange(1)) * 255,double(dataRange(2)) * 255];
                self.ThresholdSlider.Value   = mean(dataRange(:),'double') * 255;
            else
                self.ThresholdSlider.Limits = [dataRange(1),dataRange(2)];
                self.ThresholdSlider.Value   = mean(dataRange(:));
            end
            
            manageThresholdControlSync(self, self.ThresholdSlider);
            
            % Enable listener for threshold slider when finished.
            self.ThresholdSliderListener.Enabled = true;
            self.ThresholdTextListener.Enabled = true;
        end
        
        function enableAllButtons(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.MethodButton.Enabled = true;
            
            switch self.MethodButton.Text
            case getMessageString('globalThreshold')
                self.ThresholdLabel.Enabled                         = false;
                self.ThresholdSlider.Enabled                        = false;
                self.ThresholdText.Enabled                          = false;
                self.SensitivityControl.LabelControl.Enabled        = false;
                self.SensitivityControl.SliderControl.Enabled       = false;
                self.SensitivityControl.EditControl.Enabled         = false;
                self.ForegroundPolarityLabel.Enabled                = false;
                self.ForegroundPolarityCombo.Enabled                = false;

            case getMessageString('manualThreshold')
                self.ThresholdLabel.Enabled                         = true;
                self.ThresholdSlider.Enabled                        = true;
                self.ThresholdText.Enabled                          = true;
                self.SensitivityControl.LabelControl.Enabled        = false;
                self.SensitivityControl.SliderControl.Enabled       = false;
                self.SensitivityControl.EditControl.Enabled         = false;
                self.ForegroundPolarityLabel.Enabled                = false;
                self.ForegroundPolarityCombo.Enabled                = false;

            case getMessageString('adaptiveThreshold')
                self.ThresholdLabel.Enabled                         = false;
                self.ThresholdSlider.Enabled                        = false;
                self.ThresholdText.Enabled                          = false;
                self.SensitivityControl.LabelControl.Enabled        = true;
                self.SensitivityControl.SliderControl.Enabled       = true;
                self.SensitivityControl.EditControl.Enabled         = true;
                self.ForegroundPolarityLabel.Enabled                = true;
                self.ForegroundPolarityCombo.Enabled                = true;

            otherwise
                assert(false, 'Incorrect threshold option')
            end

            self.ViewMgr.Enabled                                = true;
            self.ApplyCloseMgr.ApplyButton.Enabled              = true;
            self.ApplyCloseMgr.CloseButton.Enabled              = true;
            
        end
    end
    
end
