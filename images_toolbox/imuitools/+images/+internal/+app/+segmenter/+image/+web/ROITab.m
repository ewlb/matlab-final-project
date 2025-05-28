classdef ROITab < handle
    %

    % Copyright 2018-2024 The MathWorks, Inc.
    
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
        
        HideDataBrowser = false;
    end
    
    %%UI Controls
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        FreehandSection
        ShapeSection
        
        AssistedFreehandButton
        FreehandButton
        PolygonButton
        RectangleButton
        EllipseButton
        CircleButton
        
        ViewSection
        ViewMgr
        
        OpacitySliderListener
        ShowBinaryButtonListener
        
        ApplyCloseSection
        ApplyCloseMgr

        EditMode
    end
    
    %%Algorithm
    properties
                
        ROI
        ImageProperties
        
    end
    
    %%Public API
    methods
        function self = ROITab(toolGroup, tabGroup, theToolstrip, theApp, varargin)

            if (nargin == 5)
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup, 'drawROITab');
            else
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup, drawROITab, varargin{:});
            end
            
            self.hAppContainer = toolGroup;
            self.hTabGroup = tabGroup;
            self.hToolstrip = theToolstrip;
            self.hApp = theApp;
            
            self.layoutTab();
            
            self.disableAllButtons();
            self.EditMode = 'AssistedFreehand';
            self.AssistedFreehandButton.Value = true;
            
        end
        
        function setMode(self, mode)
            import images.internal.app.segmenter.image.web.AppMode;
            
            switch (mode)
            case AppMode.Drawing
                self.enableAllButtons();
                self.installPointer();
                
            case AppMode.DrawingDone
                hIm  = self.hApp.getScrollPanelImage();
                hFig = self.hApp.getScrollPanelFigure();
                set(hFig,'Pointer','arrow');
                % Reset button up function to default.
                hIm.ButtonDownFcn = [];
                
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
        
        function onApply(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            currentMask = self.hApp.getCurrentMask();
            m = self.ImageProperties.ImageSize(1);
            n = self.ImageProperties.ImageSize(2);
            
            if isempty(currentMask)
                currentMask = false([m,n]);
            end
            
            for idx = 1:numel(self.ROI)
                if isvalid(self.ROI(idx))
                    currentMask = currentMask | createMask(self.ROI(idx),m,n);
                end
            end

            commandForHistory = self.getCommandsForHistory();
            
            self.hApp.setTemporaryHistory(currentMask, ...
                 'ROIs', {commandForHistory});
            
            self.hApp.setCurrentMask(currentMask);
            
            self.ApplyCloseMgr.ApplyButton.Enabled = false;
            self.hApp.addToHistory(currentMask,getMessageString('drawROIsComment'),commandForHistory);
            
            self.clearAll();
        end
        
        function onClose(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            self.hApp.clearTemporaryHistory()
                        
            % This ensures that zoom tools have settled down before the
            % marker pointer is removed.
            drawnow;
            
            % ROITab doesn't have a removePointer method, so set the
            % pointer to 'arrow' on close
            self.hApp.MousePointer = 'arrow';
            
            delete(self.ROI);
            self.ROI = [];
            
            self.hToolstrip.showSegmentTab()
            self.hToolstrip.hideROITab()
            self.disableAllButtons();
            self.hToolstrip.setMode(AppMode.DrawingDone);
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
        
        function layoutTab(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;

            self.FreehandSection        = self.hTab.addSection(getMessageString('addFreehand'));
            self.FreehandSection.Tag    = 'Freehand ROIs';
            self.ShapeSection        = self.hTab.addSection(getMessageString('shapes'));
            self.ShapeSection.Tag    = 'Shape ROIs';
            self.ViewSection        = self.addViewSection();
            self.ApplyCloseSection  = self.addApplyCloseSection();
            
            self.layoutFreehandSection();
            self.layoutShapeSection();
            
        end
        
        function layoutFreehandSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;
            
            % Assisted Freehand button        
            self.AssistedFreehandButton = matlab.ui.internal.toolstrip.ToggleButton(getMessageString('addAssistedFreehand'),Icon('drawAssistedFreehand'));
            self.AssistedFreehandButton.Tag = 'btnDrawAssistedFreehand';
            self.AssistedFreehandButton.Description = getMessageString('addAssistedTooltip');
            addlistener(self.AssistedFreehandButton, 'ValueChanged', @(~,~)self.drawAssistedFreehand());
            
            % Freehand button        
            self.FreehandButton = matlab.ui.internal.toolstrip.ToggleButton(getMessageString('addFreehand'),Icon('drawFreehand'));
            self.FreehandButton.Tag = 'btnDrawFreehand';
            self.FreehandButton.Description = getMessageString('addFreehandTooltip');
            addlistener(self.FreehandButton, 'ValueChanged', @(~,~)self.drawFreehand());
            
            % Layout
            c = self.FreehandSection.addColumn();
            c.add(self.AssistedFreehandButton);
            c2 = self.FreehandSection.addColumn();
            c2.add(self.FreehandButton);

        end
        
        function layoutShapeSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;
            
            % Polygon button        
            self.PolygonButton = matlab.ui.internal.toolstrip.ToggleButton(getMessageString('addPolygon'),Icon('drawPolygon'));
            self.PolygonButton.Tag = 'btnDrawPolygon';
            self.PolygonButton.Description = getMessageString('addPolygonTooltip');
            addlistener(self.PolygonButton, 'ValueChanged', @(~,~)self.drawPolygon());
            
            % Rectangle button        
            self.RectangleButton = matlab.ui.internal.toolstrip.ToggleButton(getMessageString('addRectangle'),Icon('drawRectangle'));
            self.RectangleButton.Tag = 'btnDrawRectangle';
            self.RectangleButton.Description = getMessageString('addRectangleTooltip');
            addlistener(self.RectangleButton, 'ValueChanged', @(~,~)self.drawRectangle());
            
            % Ellipse button        
            self.EllipseButton = matlab.ui.internal.toolstrip.ToggleButton(getMessageString('addEllipse'),Icon('drawEllipse'));
            self.EllipseButton.Tag = 'btnDrawEllipse';
            self.EllipseButton.Description = getMessageString('addEllipseTooltip');
            addlistener(self.EllipseButton, 'ValueChanged', @(~,~)self.drawEllipse());
            
            % Circle button        
            self.CircleButton = matlab.ui.internal.toolstrip.ToggleButton(getMessageString('addCircle'),Icon('drawCircle'));
            self.CircleButton.Tag = 'btnDrawCircle';
            self.CircleButton.Description = getMessageString('addCircleTooltip');
            addlistener(self.CircleButton, 'ValueChanged', @(~,~)self.drawCircle());    

            % Layout
            c = self.ShapeSection.addColumn();
            c.add(self.PolygonButton);
            c2 = self.ShapeSection.addColumn();
            c2.add(self.RectangleButton);
            c3 = self.ShapeSection.addColumn();
            c3.add(self.EllipseButton);
            c4 = self.ShapeSection.addColumn();
            c4.add(self.CircleButton);
            
        end
        
        function section = addViewSection(self)
            
            self.ViewMgr = images.internal.app.segmenter.image.web.ViewControlsManager(self.hTab);
            section = self.ViewMgr.Section;
            
            self.OpacitySliderListener = addlistener(self.ViewMgr.OpacitySlider, 'ValueChanged', @(~,~)self.opacitySliderMoved());
            self.ShowBinaryButtonListener = addlistener(self.ViewMgr.ShowBinaryButton, 'ValueChanged', @(hobj,~)self.showBinaryPress(hobj));
        end
        
        function section = addApplyCloseSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            tabName = getMessageString('drawROITab');
            
            useApplyAndClose = false;
            self.ApplyCloseMgr = iptui.internal.ApplyCloseManager(self.hTab, tabName, useApplyAndClose);
            section = self.ApplyCloseMgr.Section;
            
            addlistener(self.ApplyCloseMgr.ApplyButton,'ButtonPushed',@(~,~)self.onApply());
            addlistener(self.ApplyCloseMgr.CloseButton,'ButtonPushed',@(~,~)self.onClose());
        end

    end
    
    %%Callbacks
    methods (Access = protected)
        
        function drawAssistedFreehand(self)
            
            if self.AssistedFreehandButton.Value
                self.FreehandButton.Value = false;
                self.PolygonButton.Value = false;
                self.RectangleButton.Value = false;
                self.EllipseButton.Value = false;
                self.CircleButton.Value = false;              
                self.EditMode = 'AssistedFreehand';
            elseif ~self.isDrawStateValid()
                self.AssistedFreehandButton.Value = true;
            end
            
            self.updateInteraction();
            
        end
        
        function drawFreehand(self)
            
            if self.FreehandButton.Value
                self.AssistedFreehandButton.Value = false;
                self.PolygonButton.Value = false;
                self.RectangleButton.Value = false;
                self.EllipseButton.Value = false;
                self.CircleButton.Value = false;              
                self.EditMode = 'Freehand';
            elseif ~self.isDrawStateValid()
                self.FreehandButton.Value = true;
            end
            
            self.updateInteraction();
            
        end
        
        function drawPolygon(self)
            
            if self.PolygonButton.Value
                self.AssistedFreehandButton.Value = false;
                self.FreehandButton.Value = false;
                self.RectangleButton.Value = false;
                self.EllipseButton.Value = false;
                self.CircleButton.Value = false;              
                self.EditMode = 'Polygon';
            elseif ~self.isDrawStateValid()
                self.PolygonButton.Value = true;
            end
            
            self.updateInteraction();
            
        end
        
        function drawRectangle(self)
            
            if self.RectangleButton.Value
                self.AssistedFreehandButton.Value = false;
                self.FreehandButton.Value = false;
                self.PolygonButton.Value = false;
                self.EllipseButton.Value = false;
                self.CircleButton.Value = false;              
                self.EditMode = 'Rectangle';
            elseif ~self.isDrawStateValid()
                self.RectangleButton.Value = true;
            end
            
            self.updateInteraction();
            
        end
        
        function drawEllipse(self)
            
            if self.EllipseButton.Value
                self.AssistedFreehandButton.Value = false;
                self.FreehandButton.Value = false;
                self.PolygonButton.Value = false;
                self.RectangleButton.Value = false;
                self.CircleButton.Value = false;              
                self.EditMode = 'Ellipse';
            elseif ~self.isDrawStateValid()
                self.EllipseButton.Value = true;
            end
            
            self.updateInteraction();
            
        end
        
        function drawCircle(self)
            
            if self.CircleButton.Value
                self.AssistedFreehandButton.Value = false;
                self.FreehandButton.Value = false;
                self.PolygonButton.Value = false;
                self.RectangleButton.Value = false;
                self.EllipseButton.Value = false;              
                self.EditMode = 'Circle';
            elseif ~self.isDrawStateValid()
                self.CircleButton.Value = true;
            end
            
            self.updateInteraction();
            
        end
        
        function TF = isDrawStateValid(self)
            TF = any([self.AssistedFreehandButton.Value,...
                self.FreehandButton.Value,...
                self.PolygonButton.Value,...
                self.RectangleButton.Value,...
                self.EllipseButton.Value,...
                self.CircleButton.Value]);
        end
        
        function clearAll(self)
            
            delete(self.ROI);
            self.ROI = [];

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
            
            if ~isempty(self.ROI)
                set(self.ROI,'FaceAlpha',self.hApp.getScrollPanelOpacity());
            end
            
        end
        
        function reactToShowBinary(self)
            self.ViewMgr.OpacitySlider.Enabled  = false;
            self.ViewMgr.ShowBinaryButton.Value = true;
            
            if ~isempty(self.ROI)
                set(self.ROI,'Color',[1 1 1],'FaceAlpha',1);
            end
        end
        
        function reactToUnshowBinary(self)
            self.ViewMgr.OpacitySlider.Enabled  = true;
            self.ViewMgr.ShowBinaryButton.Value = false;
            
            if ~isempty(self.ROI)
                set(self.ROI,'Color',[0 1 1],'FaceAlpha',self.hApp.getScrollPanelOpacity());
            end
        end
        
        function updateInteraction(self)
            self.installPointer()
        end
        
        function installPointer(self)
            
            hIm  = self.hApp.getScrollPanelImage();
            self.hApp.MousePointer = 'roi';
            
            hFig = getScrollPanelFigure(self.hApp);
            images.roi.setBackgroundPointer(hFig,'crosshair');

            hIm.ButtonDownFcn = @(~,evt) self.drawCallback();

        end
        
        function drawCallback(self)
            
            if ~isClickValid(self.hApp)
                return;
            end

            self.disableAllButtons();
            
            hAx  = self.hApp.getScrollPanelAxes();
            cp = hAx.CurrentPoint(1,1:2);
            area = [0.5, 0.5, self.ImageProperties.ImageSize(2), self.ImageProperties.ImageSize(1)];
            
            if cp(1) < 0.5
                cp(1) = 0.5;
            elseif cp(1) > self.ImageProperties.ImageSize(2) + 0.5
                cp(1) = self.ImageProperties.ImageSize(2) + 0.5;
            end
            
            if cp(2) < 0.5
                cp(2) = 0.5;
            elseif cp(2) > self.ImageProperties.ImageSize(1) + 0.5
                cp(2) = self.ImageProperties.ImageSize(1) + 0.5;
            end
            
            if self.ViewMgr.ShowBinaryButton.Value
                alpha = 1;
                color = [1 1 1];
            else
                alpha = self.hApp.getScrollPanelOpacity();
                color = [0 1 1];
            end
            
            switch self.EditMode
                
                case 'AssistedFreehand'
                    h = images.roi.AssistedFreehand('Image',self.hApp.getScrollPanelImage,'Color',color,...
                        'FaceAlpha',alpha);
                    
                case 'Freehand'
                    h = images.roi.Freehand('DrawingArea',area,'Color',color,'Parent',self.hApp.getScrollPanelAxes,...
                        'FaceAlpha',alpha);
                    
                case 'Polygon'
                    h = images.roi.Polygon('DrawingArea',area,'Color',color,'Parent',self.hApp.getScrollPanelAxes,...
                        'FaceAlpha',alpha,...
                        'MinimumNumberOfPoints',3);
                    
                case 'Rectangle'
                    h = images.roi.Rectangle('DrawingArea',area,'Color',color,'Parent',self.hApp.getScrollPanelAxes,...
                        'FaceAlpha',alpha);
                    
                case 'Ellipse'
                    h = images.roi.Ellipse('DrawingArea',area,'Color',color,'Parent',self.hApp.getScrollPanelAxes,...
                        'FaceAlpha',alpha);
                    
                case 'Circle'
                    h = images.roi.Circle('DrawingArea',area,'Color',color,'Parent',self.hApp.getScrollPanelAxes,...
                        'FaceAlpha',alpha);
                    
            end
            
            h.beginDrawingFromPoint(cp);
            
            if ~isvalid(self.hApp)
                return;
            end
            
            if checkROIValidity(h)
                % Add valid ROI to array
                addlistener(h,'DeletingROI',@(src,evt) self.deleteROI(src,evt));
                roiHandles = self.ROI;
                self.ROI = [roiHandles, h];
            else
                % Delete ROI
                delete(h)
            end
                
            self.enableAllButtons();
            
        end
        
        function deleteROI(self,src,~)
            
            idx = find(self.ROI == src, 1);
            
            if ~isempty(idx)
                h = self.ROI(idx);
                self.ROI(idx) = [];
                delete(h);
            end
            
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

            self.ViewMgr.Enabled                                = true;
            self.ApplyCloseMgr.CloseButton.Enabled              = true;
            self.AssistedFreehandButton.Enabled                 = true;
            self.FreehandButton.Enabled                         = true;
            self.PolygonButton.Enabled                          = true;
            self.RectangleButton.Enabled                        = true;
            self.EllipseButton.Enabled                          = true;
            self.CircleButton.Enabled                           = true;
            self.ApplyCloseMgr.ApplyButton.Enabled              = true;

        end
        
        function disableAllButtons(self)

            self.ViewMgr.Enabled                                = false;
            self.ApplyCloseMgr.ApplyButton.Enabled              = false;
            self.ApplyCloseMgr.CloseButton.Enabled              = false;
            self.AssistedFreehandButton.Enabled                 = false;
            self.FreehandButton.Enabled                         = false;
            self.PolygonButton.Enabled                          = false;
            self.RectangleButton.Enabled                        = false;
            self.EllipseButton.Enabled                          = false;
            self.CircleButton.Enabled                           = false;
            
        end
        
        function commands = getCommandsForHistory(self)
            
            commands = {};
            commandBuffer = {''};
            
            for idx = 1:numel(self.ROI)
                if isvalid(self.ROI(idx))
                    commandList = createDrawingCommand(self.ROI(idx));
                    commands = [commands commandBuffer commandList]; %#ok<AGROW>
                end
            end

        end
        
    end
    
end

function commandList = createDrawingCommand(roi)

switch roi.Type
    case {'images.roi.rectangle','images.roi.ellipse','images.roi.circle'}
        pos = roi.Vertices;
    case {'images.roi.polygon', 'images.roi.freehand', 'images.roi.assistedfreehand'}
        pos = roi.Position;
end

X = pos(:,1)';
Y = pos(:,2)';

[X, Y] = removeSequentiallyRepeatedPoints(X, Y);

xString = sprintf('%0.4f ', X);
xString(end) = '';
commandList{1} = sprintf('xPos = [%s];', xString);

yString = sprintf('%0.4f ', Y);
yString(end) = '';
commandList{2} = sprintf('yPos = [%s];', yString);

commandList{3} = 'm = size(BW, 1);';
commandList{4} = 'n = size(BW, 2);';
commandList{5} = 'addedRegion = poly2mask(xPos, yPos, m, n);';
commandList{6} = 'BW = BW | addedRegion;';

end

function [X, Y] = removeSequentiallyRepeatedPoints(X, Y)

xDiff = abs(diff(X));
yDiff = abs(diff(Y));

sameAsNext = ((xDiff + yDiff) == 0);
sameAsNext(end+1) = false;

X(sameAsNext) = [];
Y(sameAsNext) = [];

end

function TF = checkROIValidity(roi)

if ~isvalid(roi) && isempty(roi.Position)
    % This is a universal requirement for roi validity
    TF = false;
    
else
    % Now check specific requirements for roi validity
    switch roi.Type
        
        case 'images.roi.rectangle'
            TF = roi.Position(3) > 0 && roi.Position(4) > 0;
        case {'images.roi.polygon', 'images.roi.freehand', 'images.roi.assistedfreehand'}
            TF = size(roi.Position,1) >= 3;
        case 'images.roi.ellipse'
            TF = roi.SemiAxes(1) > 0 && roi.SemiAxes(2) > 0;
        case 'images.roi.circle'
            TF = roi.Radius > 0;
    end

end

end
