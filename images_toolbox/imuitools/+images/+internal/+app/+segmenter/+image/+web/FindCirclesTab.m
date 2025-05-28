classdef FindCirclesTab < handle
    %

    % Copyright 2016-2024 The MathWorks, Inc.
    
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
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        DiameterSection
        MinDiameterEditBox
        MinDiameterLabel
        MaxDiameterEditBox
        MaxDiameterLabel
        
        SensitivitySlider
        SensitivityLabel
        SensitivityEditBox
        
        MaxCirclesLabel
        MaxCirclesEditBox
        
        ObjectPolarityLabel
        ObjectPolarityCombo
        
        MeasureSection
        MeasureButton
        
        RunSection
        RunButton
        
        ViewSection
        ViewMgr
        
        ApplyCloseSection
        ApplyCloseMgr
        
        ImageSize
        
        OriginalPointerBehavior
        
        Timer
    end
    
    %%Algorithm
    properties
        MaxVal
        MinRadius = 25;
        MaxRadius = 75;
        Sensitivity = 0.85;
        ObjectPolarityItems = {'bright','dark'};
        
        Iterations = Inf;
        CurrentIteration
        
        MeasurementLine
        MeasurementDisplay

        ContinueSegmentationFlag
        StopSegmentationFlag
        DiscardSegmentation
        
        CurrentMask
    end
    
    %%Public API
    methods
        function self = FindCirclesTab(toolGroup, tabGroup, theToolstrip, theApp, varargin)

            if (nargin == 3)
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup, 'findCirclesTab');
            else
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup, 'findCirclesTab', varargin{:});
            end
            
            self.hAppContainer = toolGroup;
            self.hTabGroup = tabGroup;
            self.hToolstrip = theToolstrip;
            self.hApp = theApp;
            
            self.layoutTab();
            
            self.disableAllButtons();
            
            self.Timer = timer('TimerFcn',@(~,~) self.applyFindCircles(),...
                    'ObjectVisibility','off','ExecutionMode','singleShot',...
                    'Tag','ImageSegmenterFindCirclesTimer','StartDelay',0.01);
                
        end
        
        function show(self)
            
            self.hApp.disableBrowser();
            
            if (~self.isVisible())
                self.hTabGroup.add(self.hTab)
            end
                        
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
        
        function deleteTimer(self)
            if ~isempty(self.Timer) && isvalid(self.Timer)
                stop(self.Timer)
                delete(self.Timer)
            end
        end
        
        function setMode(self, mode)
            import images.internal.app.segmenter.image.web.AppMode;
            
            switch (mode)
            case AppMode.FindCirclesOpened
                 self.DiscardSegmentation = false;
                 self.ContinueSegmentationFlag = true;
                 self.ImageSize = size(self.hApp.getImage());
                 resetRadii(self);
                 self.enableAllButtons();
                 
            case AppMode.FindCirclesDone
                 self.MeasureButton.Value = false;
                 self.measureCallback();

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
            
            self.hApp.commitTemporaryHistory()
            self.disableApply();
            
        end
        
        function onClose(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            self.hApp.updateStatusBarText('');
            self.hApp.clearTemporaryHistory()
            
            % This ensures that zoom tools have settled down before the
            % marker pointer is removed.
            drawnow;
            
            self.hToolstrip.showSegmentTab()
            self.hToolstrip.hideFindCirclesTab()
            self.disableAllButtons();
            self.hToolstrip.setMode(AppMode.FindCirclesDone);
        end
    end
    
    %%Layout
    methods (Access = private)
        
        function layoutTab(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.MeasureSection      = self.hTab.addSection(getMessageString('measure'));
            self.MeasureSection.Tag  = 'Measure Section';
            self.DiameterSection     = self.hTab.addSection(getMessageString('parameters'));
            self.DiameterSection.Tag = 'Settings Section';
            self.RunSection          = self.hTab.addSection(getMessageString('find'));
            self.ViewSection         = self.addViewSection();
            self.ApplyCloseSection   = self.addApplyCloseSection();
            
            self.layoutMeasureSection();
            self.layoutDiameterSection();
            self.layoutRunSection();
            
        end
        
        function layoutDiameterSection(self)

            import images.internal.app.segmenter.image.web.getMessageString;
            import iptui.internal.utilities.setToolTipText;
            
            % Min Diameter
            self.MinDiameterEditBox = matlab.ui.internal.toolstrip.EditField(num2str(2*self.MinRadius));
            self.MinDiameterEditBox.Tag = 'btnMinDiameterEditBox';
            self.MinDiameterEditBox.Description = getMessageString('minDiameterTooltip');
            addlistener(self.MinDiameterEditBox,'ValueChanged', @(hobj,~) self.validateMinDiameter(hobj));
            
            % Min Label
            self.MinDiameterLabel = matlab.ui.internal.toolstrip.Label(getMessageString('minDiameter'));
            self.MinDiameterLabel.Tag = 'labelMinDiameter';
            self.MinDiameterLabel.Description = getMessageString('minDiameterTooltip');
            
            % Max Label
            self.MaxDiameterLabel = matlab.ui.internal.toolstrip.Label(getMessageString('maxDiameter'));
            self.MaxDiameterLabel.Tag = 'labelMaxDiameter';
            self.MaxDiameterLabel.Description = getMessageString('maxDiameterTooltip');
            
            % Max Diameter
            self.MaxDiameterEditBox = matlab.ui.internal.toolstrip.EditField(num2str(2*self.MaxRadius));
            self.MaxDiameterEditBox.Tag = 'btnMaxDiameterEditBox';
            self.MaxDiameterEditBox.Description = getMessageString('maxDiameterTooltip');
            addlistener(self.MaxDiameterEditBox, 'ValueChanged', @(hobj,~) self.validateMaxDiameter(hobj));
            
            % Polarity Label
            self.ObjectPolarityLabel = matlab.ui.internal.toolstrip.Label(getMessageString('fgPolarity'));
            self.ObjectPolarityLabel.Tag = 'labelObjPolarity';
            self.ObjectPolarityLabel.Description = getMessageString('fgPolarityTooltip');
            
            % Polarity Combo Box
            self.ObjectPolarityCombo = matlab.ui.internal.toolstrip.DropDown({getMessageString('bright');getMessageString('dark')});
            self.ObjectPolarityCombo.SelectedIndex = 1;
            self.ObjectPolarityCombo.Tag = 'comboObjPolarity';
            self.ObjectPolarityCombo.Description = getMessageString('fgPolarityTooltip');
            
            % Did not use 'iptui.internal.SliderEditControl' as it is not
            % possible to get /100 value for edit box from slider value.
            % Sensitivity for imfindcircles is in the range [0 1]
            % Sensitivity Label
            self.SensitivityLabel = matlab.ui.internal.toolstrip.Label(getMessageString('sensitivity'));
            self.SensitivityLabel.Tag = 'labelSensitivity';
            self.SensitivityLabel.Description = getMessageString('sensitivityFindCirclesTooltip');
            
            % Sensitivity Slider
            self.SensitivitySlider = matlab.ui.internal.toolstrip.Slider([0,100],self.Sensitivity * 100);
            self.SensitivitySlider.Ticks = 0;
            self.SensitivitySlider.Compact = true;
            self.SensitivitySlider.Tag = 'btnSensitivitySlider';
            self.SensitivitySlider.Description = getMessageString('sensitivityFindCirclesTooltip');
            addlistener(self.SensitivitySlider, 'ValueChanged', @(hobj,~)self.sensitivityValueChanged(hobj));
            
            % Sensitivity
            self.SensitivityEditBox = matlab.ui.internal.toolstrip.EditField(num2str(self.Sensitivity));
            self.SensitivityEditBox.Tag = 'btnSensitivityEditBox';
            self.SensitivityEditBox.Description = getMessageString('sensitivityFindCirclesTooltip');
            addlistener(self.SensitivityEditBox, 'ValueChanged', @(hobj,~) self.sensitivityValueChanged(hobj));
            
            % Max Number of Circles Label
            self.MaxCirclesLabel = matlab.ui.internal.toolstrip.Label(getMessageString('maxCircles'));
            self.MaxCirclesLabel.Tag = 'labelMaxCircles';
            self.MaxCirclesLabel.Description = getMessageString('maxCirclesTooltip');
            
            % Max Number of Circles
            self.MaxCirclesEditBox = matlab.ui.internal.toolstrip.EditField(num2str(self.Iterations));
            self.MaxCirclesEditBox.Tag = 'btnMaxCirclesEditBox';
            self.MaxCirclesEditBox.Description = getMessageString('maxCirclesTooltip');
            addlistener(self.MaxCirclesEditBox, 'ValueChanged', @(hobj,~) self.validateMaxCircles(hobj));
            

            % Layout
            c = self.DiameterSection.addColumn('HorizontalAlignment','right');
            c.add(self.MinDiameterLabel);
            c.add(self.MaxDiameterLabel);
            
            c2 = self.DiameterSection.addColumn('width',45);
            c2.add(self.MinDiameterEditBox);
            c2.add(self.MaxDiameterEditBox);
            self.DiameterSection.addColumn('width',15);
            
            c3 = self.DiameterSection.addColumn('HorizontalAlignment','right');
            c3.add(self.MaxCirclesLabel);
            c3.add(self.ObjectPolarityLabel);
            
            c4 = self.DiameterSection.addColumn('width',60);
            c4.add(self.MaxCirclesEditBox);
            c4.add(self.ObjectPolarityCombo);
            self.DiameterSection.addColumn('width',5);
            
            c5 = self.DiameterSection.addColumn('width',100, 'HorizontalAlignment','center');
            c5.add(self.SensitivityLabel);
            c5.add(self.SensitivitySlider);
            
            c6 = self.DiameterSection.addColumn('width',50);
            c6.addEmptyControl();
            c6.add(self.SensitivityEditBox);
            
        end
        
       function layoutMeasureSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;

            % Run Button
            self.MeasureButton = matlab.ui.internal.toolstrip.ToggleButton(getMessageString('measureDiameter'), Icon('ruler'));
            self.MeasureButton.Tag = 'btnRuler';
            self.MeasureButton.Description = getMessageString('measureDiameterTooltip');     
            addlistener(self.MeasureButton, 'ValueChanged', @(~,~) self.measureCallback());
            
            % Layout
            c = self.MeasureSection.addColumn();
            c.add(self.MeasureButton);
            
        end
        
        function layoutRunSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;
            
            % Run Button
            self.RunButton = matlab.ui.internal.toolstrip.Button(getMessageString('findCircles'), matlab.ui.internal.toolstrip.Icon('playControl'));
            self.RunButton.Tag = 'btnRun';
            self.RunButton.Description = getMessageString('runTooltip');
            addlistener(self.RunButton, 'ButtonPushed', @(~,~) self.updateSegmentState());
            
            % Layout
            c7 = self.RunSection.addColumn();
            c7.add(self.RunButton);

        end
        
        function section = addViewSection(self)
            
            self.ViewMgr = images.internal.app.segmenter.image.web.ViewControlsManager(self.hTab);
            section = self.ViewMgr.Section;
            
            addlistener(self.ViewMgr.OpacitySlider, 'ValueChanged', @(~,~)self.opacitySliderMoved());
            addlistener(self.ViewMgr.ShowBinaryButton, 'ValueChanged', @(hobj,~)self.showBinaryPress(hobj));
        end
        
        function section = addApplyCloseSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            tabName = getMessageString('findCirclesTab');
            
            useApplyAndClose = true;
            
            self.ApplyCloseMgr = iptui.internal.ApplyCloseManager(self.hTab, tabName, useApplyAndClose);
            section = self.ApplyCloseMgr.Section;
            
            addlistener(self.ApplyCloseMgr.ApplyButton,'ButtonPushed',@(~,~)self.applyAndClose());
            addlistener(self.ApplyCloseMgr.CloseButton,'ButtonPushed',@(~,~)self.onClose());
        end
    end
    
    %%Algorithm
    methods (Access = private)
        
        function applyFindCircles(self)      
            
            import images.internal.app.segmenter.image.web.AppMode;
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.MeasureButton.Value = false;
            self.measureCallback();
            self.disableAllButtons();
            self.disableApply();
            self.hApp.updateStatusBarText(getMessageString('detectingCircles'));
            
            self.StopSegmentationFlag = false;
            self.updateSegmentButtonIcon('stop')
            drawnow;
            self.hApp.clearTemporaryHistory()
            
            % Ignore all warnings
            warnstate = warning('off','all');
            resetWarningObj = onCleanup(@()warning(warnstate));

            idx = self.ObjectPolarityCombo.SelectedIndex;
            objectPolarity  = self.ObjectPolarityItems{idx};
                        
            [centers,radii,~] = imfindcircles(self.hApp.getRGBImage(),...
                [self.MinRadius self.MaxRadius],...
                'ObjectPolarity',objectPolarity,'Sensitivity',self.Sensitivity);
            
            % Flush event queue for listeners in view to process and
            % update graphics in response to changes in mask and
            % current iteration count.
            drawnow();
            
            if ~isvalid(self.hApp)
                return;
            end
                
            if self.StopSegmentationFlag
                self.hApp.updateStatusBarText('');
                self.updateSegmentButtonIcon('segment');
                self.enableAllButtons();
                return;
            end
            
            mask = false(self.ImageSize(1:2));
                
            if ~isempty(centers) && ~self.StopSegmentationFlag
                mask = self.createMaskFromCircles(mask,centers,radii);
                if ~isvalid(self.hApp)
                    return;
                end
                self.hToolstrip.setMode(AppMode.MasksExist)
                self.hApp.showLegend();
                if ~self.DiscardSegmentation
                    self.hApp.setTemporaryHistory(mask, ...
                         getMessageString('findCirclesComment'), self.getCommandsForHistory(objectPolarity));
                end
                self.hApp.ScrollPanel.resetCommittedMask();
                self.enableApply();
                self.hApp.updateStatusBarText('');
            else
                self.hApp.updateStatusBarText(getMessageString('noCircles'));
                self.hToolstrip.setMode(AppMode.NoMasks)
                self.disableApply();
                self.hApp.ScrollPanel.resetPreviewMask();
            end
            
            self.updateSegmentButtonIcon('segment')
            self.enableAllButtons();
            
                                    
        end
        
        function mask = createMaskFromCircles(self,mask,centers,radii)

            import images.internal.app.segmenter.image.web.getMessageString;
            
            numCircles = min(self.Iterations, length(radii));
            mask = circles2mask(centers(1:numCircles,:),radii(1:numCircles),size(mask));
            self.hApp.updateScrollPanelPreview(mask);
            self.hApp.updateStatusBarText(getMessageString('numCircles', num2str(self.CurrentIteration)));
            
        end
        
        function updateSegmentState(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            if self.ContinueSegmentationFlag
                start(self.Timer);
            else
                self.stopSegmentationAlgorithm();
            end
        end
        
        function updateSegmentButtonIcon(self, name)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            switch name
                case 'segment'
                    self.RunButton.Icon =  matlab.ui.internal.toolstrip.Icon('playControl');
                    self.RunButton.Text = getMessageString('findCircles');
                    self.ContinueSegmentationFlag = true;
                case 'stop'
                    self.RunButton.Icon =  matlab.ui.internal.toolstrip.Icon('stop');
                    self.RunButton.Text = getMessageString('stopSegmentation');
                    self.ContinueSegmentationFlag = false;
            end
        end
        
        function stopSegmentationAlgorithm(self)
            self.StopSegmentationFlag = true;
        end
        
        function stopSegmentationAlgorithmAndDiscard(self)
            self.stopSegmentationAlgorithm()
            self.DiscardSegmentation = true;
        end
        
        function resetRadii(self)
            
            self.MaxVal = round(hypot(self.ImageSize(1),self.ImageSize(2))/2);
            if self.MaxRadius > self.MaxVal
                self.MaxRadius = self.MaxVal;
                self.MaxDiameterEditBox.Value = num2str(2*self.MaxVal);
            end
            if self.MinRadius > self.MaxVal
                self.MinRadius = self.MaxVal;
                self.MinDiameterEditBox.Value = num2str(2*self.MaxVal);
            end
            
        end

    end
    
    %%Callbacks
    methods (Access = private)
        
        function measureCallback(self)
            drawnow;
            
            if self.MeasureButton.Value
                self.updateMeasurementInteraction();
            else
                self.removePointer();
                delete(self.MeasurementLine)
                self.MeasurementLine = [];
                delete(self.MeasurementDisplay)
                self.MeasurementDisplay = [];
                drawnow;
            end
            
        end
        
        function validateMinDiameter(self,obj)
            value = round(str2double(obj.Value)/2);
            if ~isfinite(value) || ~isreal(value) || value <= 0
                self.MinDiameterEditBox.Value = num2str(2*self.MinRadius);
                return;
            end

            if value > self.MaxVal
                value = self.MaxVal;
            end
            
            if value > self.MaxRadius
                value = self.MaxRadius;
            end
            
            self.MinRadius = value;
            self.MinDiameterEditBox.Value = num2str(2*value);
            
        end
        
        function validateMaxDiameter(self,obj)
            value = round(str2double(obj.Value)/2);
            if ~isfinite(value) || ~isreal(value) || value <= 0
                self.MaxDiameterEditBox.Value = num2str(2*self.MaxRadius);
                return;
            end
            
            if value > self.MaxVal
                value = self.MaxVal;
            end
            
            if value < self.MinRadius
                value = self.MinRadius;
            end

            self.MaxRadius = value;
            self.MaxDiameterEditBox.Value = num2str(2*value);
            
        end
        
        function sensitivityValueChanged(self,obj)
            
            % If slider was moved, update text.
            if isa(obj, 'matlab.ui.internal.toolstrip.Slider')
                value = obj.Value/100;
                self.SensitivityEditBox.Value = num2str(value);
                self.Sensitivity = value;

            % If text was edited, update slider.
            elseif isa(obj, 'matlab.ui.internal.toolstrip.EditField')
                value = str2double(obj.Value);
                if ~isfinite(value) || ~isreal(value)
                    self.SensitivityEditBox.Value = num2str(self.Sensitivity);
                    self.SensitivitySlider.Value = self.Sensitivity *100;
                    return;
                end
                
                if value > 1
                    value = 1;
                end

                if value < 0
                    value = 0;
                end
                
                self.Sensitivity = value;
                self.SensitivitySlider.Value = value*100;
                self.SensitivityEditBox.Value = num2str(value);
            end
        end
        
        function validateMaxCircles(self,obj)
            value = round(str2double(obj.Value));
            
            %If user has deleted all the text, default to Inf
            if(isempty(obj.Value))
                self.Iterations = Inf;
                self.MaxCirclesEditBox.Value = num2str(self.Iterations);
                return
            end
            
            %The minimum value for Max circles should be 1
            if ~isreal(value) || isnan(value)
                self.MaxCirclesEditBox.Value = num2str(self.Iterations);
                return;
            end
            
            if(value<1)
                value = 1;
            end
                
            self.MaxCirclesEditBox.Value = num2str(value);
            self.Iterations = value;
            
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
        
        function respondToClick(self,src)
            
            if ~strcmp(src.SelectionType, 'normal')
                return;
            end
            
            clickLocation = src.CurrentPoint;
            axesPosition  = src.CurrentAxes.Position;
            if (isClickOutsideAxes(clickLocation, axesPosition))
                return;
            end
            
            hAx  = self.hApp.getScrollPanelAxes();
            hFig = self.hApp.getScrollPanelFigure();
            
            currentPoint = hAx.CurrentPoint;
            currentPoint = round(currentPoint(1,1:2));
            
            if isempty(self.MeasurementLine)
                self.MeasurementLine = line('Parent',hAx,'Color',[0 0 0],'Visible','off',...
                    'LineWidth',3,'HitTest','off','tag','scribbleLine',...
                    'PickableParts','none','HandleVisibility','off',...
                    'Marker','.','MarkerSize',20,'MarkerEdgeColor',[1 1 1],...
                    'MarkerFaceColor',[1 1 1]);
                self.MeasurementLine.XData = currentPoint(1);
                self.MeasurementLine.YData = currentPoint(2);
                set(self.MeasurementLine,'Visible','on');
            end
            
            set(self.MeasurementLine,'XData',currentPoint(1),'YData',currentPoint(2));
            
            if isempty(self.MeasurementDisplay)
                self.MeasurementDisplay = text('Parent',hAx,'String','0',...
                    'Visible','off','Color',[0 0 0],'EdgeColor',[0 0 0],...
                    'BackgroundColor',[1 1 1],'Position',currentPoint,...
                    'HandleVisibility','off','PickableParts','none',...
                    'HitTest','off');
                set(self.MeasurementDisplay,'Visible','on')
            end    
            
            scribbleDrag();
            hFig.WindowButtonMotionFcn = @scribbleDrag;
            hFig.WindowButtonUpFcn = @scribbleUp;
        
            function scribbleDrag(~,~)
                
                currentPoint = hAx.CurrentPoint;
                currentPoint = round(currentPoint(1,1:2));
                axesPosition  = [1, 1, self.ImageSize(2)-1, self.ImageSize(1)-1];
                
                if (isClickOutsideAxes(currentPoint, axesPosition))
                    return;
                end
                
                self.MeasurementLine.XData(2) = currentPoint(1);
                self.MeasurementLine.YData(2) = currentPoint(2);
                
                diam = hypot((self.MeasurementLine.XData(2)-self.MeasurementLine.XData(1)),...
                    self.MeasurementLine.YData(2)-self.MeasurementLine.YData(1));
                
                midpoints = [(self.MeasurementLine.XData(2)+self.MeasurementLine.XData(1))/2, (self.MeasurementLine.YData(2)+self.MeasurementLine.YData(1))/2];
                
                set(self.MeasurementDisplay,'Position',midpoints,'String',sprintf('%0.2f pixels',diam));

            end
        
            function scribbleUp(~,~)
                scribbleDrag();
                hFig.WindowButtonMotionFcn = [];
                hFig.WindowButtonUpFcn = [];
            end
            
        end
        
    end
    
     %%Helpers
    methods (Access = private)
        
        function reactToOpacityChange(self)
            % We move the opacity slider to reflect a change in opacity
            % level coming from a different tab.            
            newOpacity = self.hApp.getScrollPanelOpacity();
            self.ViewMgr.Opacity = 100*newOpacity;
            
        end
        
        function reactToShowBinary(self)
            self.ViewMgr.OpacitySlider.Enabled  = false;
            self.ViewMgr.ShowBinaryButton.Value = true;
        end
        
        function reactToUnshowBinary(self)
            self.ViewMgr.OpacitySlider.Enabled  = true;
            self.ViewMgr.ShowBinaryButton.Value = false;
        end
        
        function TF = isVisible(self)
            TF = ~isempty(self.hAppContainer.SelectedToolstripTab) && strcmp(self.hAppContainer.SelectedToolstripTab.title, self.hTab.Title);
        end
        
        function enableAllButtons(self)

            self.ApplyCloseMgr.CloseButton.Enabled              = true;
            self.MinDiameterEditBox.Enabled                     = true;
            self.MaxDiameterEditBox.Enabled                     = true;
            self.SensitivitySlider.Enabled                      = true;
            self.SensitivityEditBox.Enabled                     = true;
            self.MaxCirclesEditBox.Enabled                      = true;
            self.ObjectPolarityCombo.Enabled                    = true;
            self.MeasureButton.Enabled                          = true;
            
        end
        
        function disableAllButtons(self)

            self.ApplyCloseMgr.ApplyButton.Enabled              = false;
            self.ApplyCloseMgr.CloseButton.Enabled              = false;
            self.MinDiameterEditBox.Enabled                     = false;
            self.MaxDiameterEditBox.Enabled                     = false;
            self.SensitivitySlider.Enabled                      = false;
            self.SensitivityEditBox.Enabled                     = false;
            self.MaxCirclesEditBox.Enabled                      = false;
            self.ObjectPolarityCombo.Enabled                    = false;
            self.MeasureButton.Enabled                          = false;
            
        end
            
        function enableApply(self)
            self.ApplyCloseMgr.ApplyButton.Enabled = true;
        end
        
        function disableApply(self)
            self.ApplyCloseMgr.ApplyButton.Enabled = false;
        end
        
        function updateMeasurementInteraction(self)
            self.installPointer()
        end
        
        function installPointer(self)
            
            self.hApp.resetAxToolbarMode();
            
            hFig = self.hApp.getScrollPanelFigure();
            
            % Install new pointer behavior
            self.hApp.MousePointer = 'roi';
            
            % Add listener to button up
            hFig.WindowButtonDownFcn = @(src,~) self.respondToClick(src);
            
        end
        
        function removePointer(self)
            
            self.hApp.resetAxToolbarMode();
        
            self.hApp.MousePointer = 'arrow';
            
            % Reset button up function to default.
            hFig = self.hApp.getScrollPanelFigure();
            hFig.WindowButtonDownFcn = '';
        end
        
        function commands = getCommandsForHistory(self,polarity)
        
           if self.hApp.wasRGB
               varname = 'RGB';
           else
               varname = 'X';
           end
           
           self.Sensitivity = self.SensitivitySlider.Value / 100;

           commands = {};
           commands{end+1} = sprintf('[centers,radii,~] = imfindcircles(%s,[%d %d],''ObjectPolarity'',''%s'',''Sensitivity'',%0.2f);',...
               varname,self.MinRadius,self.MaxRadius,polarity,self.Sensitivity);
           commands{end+1} = sprintf('max_num_circles = %g;',self.Iterations);
           commands{end+1} = 'if max_num_circles < length(radii)';
           commands{end+1} = '    centers = centers(1:max_num_circles,:);';
           commands{end+1} = '    radii = radii(1:max_num_circles);';
           commands{end+1} = 'end';
           commands{end+1} = sprintf('BW = circles2mask(centers,radii,size(%s,1:2));',varname); 
        end

        
    end
    
end

function TF = isClickOutsideAxes(clickLocation, axesPosition)
TF = (clickLocation(1) < axesPosition(1)) || ...
     (clickLocation(1) > (axesPosition(1) + axesPosition(3))) || ...
     (clickLocation(2) < axesPosition(2)) || ...
     (clickLocation(2) > (axesPosition(2)+axesPosition(4)));
end