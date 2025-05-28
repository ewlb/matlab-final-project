classdef GrabCutTab < images.internal.app.segmenter.image.web.GraphCutBaseTab
    %

    % Copyright 2017-2024 The MathWorks, Inc.
    
    %%UI Controls
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        ROISection
        TutorialDialog
        
        ROIStyle = 'Rectangle'
        isGrabCutInitialized

        LastCommittedMask
        
    end
    
    %%Public API
    methods
        function self = GrabCutTab(toolGroup, tabGroup, theToolstrip, theApp, varargin)

            % Call base class constructor
            self@images.internal.app.segmenter.image.web.GraphCutBaseTab(toolGroup, tabGroup, theToolstrip, theApp, 'grabcutTab', varargin{:})
            self.HideDataBrowser = false;

            addlistener( self.DrawCtrls, "ROIDrawingStarted", ...
                            @(~, ~) self.reactToROIDrawingStarted() );

            addlistener( self.DrawCtrls, "ROIDrawingDone", ...
                            @(~, evt) self.reactToROIDrawingDone(evt) );
        end
        
        function setMode(self, mode)
            import images.internal.app.segmenter.image.web.AppMode;
            
            switch (mode)
            case AppMode.GrabCutOpened
                
                self.initializeGraphCut();
                if self.ShowSuperpixelButton.Value
                    self.hApp.ScrollPanel.Image.Superpixels = self.SuperpixelLabelMatrix;
                    redraw(self.hApp.ScrollPanel);
                end
                self.disableApply();
                self.hApp.hideLegend();
                self.LastCommittedMask = self.hApp.getCurrentMask();
                
                % Message Panes
                self.MessageStatus = true;
                self.showMessagePane();
                
                % Set tool to start marking
                clearAll(self)         
                self.showSuperpixelBoundaries();

                self.CommonTSCtrls.ROIButton.Value = true;
                self.updateEditMode("ROI");
                
                drawnow;
                self.createTutorialDialog()
                
            case AppMode.GrabCutDone
                reset(self.DrawCtrls);
                self.resetAppState();

            case AppMode.NoImageLoaded
                reset(self.DrawCtrls);
                
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
            
            currentMask = self.GraphCutter.Mask | self.LastCommittedMask;
            self.hApp.setCurrentMask(currentMask);
            self.LastCommittedMask = self.hApp.getCurrentMask();
            
            self.ApplyCloseMgr.ApplyButton.Enabled = false;
            self.hApp.addToHistory(currentMask,getMessageString('grabcutComment'),self.getCommandsForHistory());
            
            self.clearAll();
        end
        
        function onClose(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            self.hApp.clearTemporaryHistory()
            
            % This ensures that zoom tools have settled down before the
            % marker pointer is removed.
            drawnow;
            
            self.hideMessagePane()
            self.DrawCtrls.clearFGScribbles()
            self.DrawCtrls.clearBGScribbles()
            
            if self.hApp.ScrollPanel.Image.SuperpixelsVisible
                self.hApp.ScrollPanel.Image.Superpixels = [];
                redraw(self.hApp.ScrollPanel);
            end
            
            clearROI(self.DrawCtrls);
            
            self.hToolstrip.showSegmentTab()
            self.hToolstrip.hideGrabCutTab()
            self.disableAllButtons();
            self.hToolstrip.setMode(AppMode.GrabCutDone);
        end
        
    end
    
    %%Layout
    methods (Access = protected)
        function ctrl = createCommonTSControls(~)
            ctrl = images.internal.app.utilities.semiautoseg.TSControls();
        end

        function layoutTab(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;

            self.ROISection        = self.hTab.addSection(getMessageString('roi'));
            self.ROISection.Tag    = 'ROI Tools';
            self.DrawSection        = self.hTab.addSection(getMessageString('markerTools'));
            self.DrawSection.Tag    = 'Draw Tools';
            self.ClearSection       = self.hTab.addSection(getMessageString('clearTools'));
            self.ClearSection.Tag   = 'Clear Markings';
            self.SuperpixelSection  = self.hTab.addSection(getMessageString('superpixelSettings'));
            self.SuperpixelSection.Tag  = 'Superpixel Settings';
            self.ViewSection        = self.addViewSection();
            self.ApplyCloseSection  = self.addApplyCloseSection();
            
            self.layoutROISection();
            self.layoutDrawSection();
            self.layoutClearTools(self.ClearSection);
            self.layoutSuperpixelSection();
            
        end

        function layoutROISection(self)
            
            addROIControls( self.CommonTSCtrls, self.ROISection, ...
                            ["rectangle", "polygon"] );
            
            addlistener( self.CommonTSCtrls, "RectangleROISelected", ...
                            @(~,~) self.setRectangleStyleSelection() );

            addlistener( self.CommonTSCtrls, "PolygonROISelected", ...
                            @(~,~) self.setPolygonStyleSelection() );

            addlistener( self.CommonTSCtrls, "ROIButtonPressed", ...
                                                @(~,evt) self.reactToROIButtonPressed(evt) );
        end
        
        function section = addApplyCloseSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            tabName = getMessageString('grabcutTab');
            
            useApplyAndClose = false;
            self.ApplyCloseMgr = iptui.internal.ApplyCloseManager(self.hTab, tabName, useApplyAndClose);
            section = self.ApplyCloseMgr.Section;
            
            addlistener(self.ApplyCloseMgr.ApplyButton,'ButtonPushed',@(~,~)self.onApply());
            addlistener(self.ApplyCloseMgr.CloseButton,'ButtonPushed',@(~,~)self.onClose());
        end
    end
    
    %%Algorithm
    methods (Access = protected)
        function reactToROIDrawingStarted(self)
            self.hApp.resetAxToolbarMode();
            
            self.disableAllButtons();
            self.hApp.DrawingROI = true;
        end

        function reactToROIDrawingDone(self, evt)
            self.hApp.DrawingROI = false;

            if evt.Data
                wireGrabCutListeners(self,self.DrawCtrls.ROI);
                self.isGrabCutInitialized = false;

                [mask, maskSrc] = self.applySegmentation();
                self.setTempHistory(mask, maskSrc);
                
                self.enableContinueButtons();
                self.CommonTSCtrls.ForegroundButton.Value = true;
                self.CommonTSCtrls.ROIButton.Value = false;
                self.addForegroundScribble();
                
                myptr = loadPencilPointerImage();
                hFig = self.hApp.getScrollPanelFigure();
                hFig.IPTROIPointerManager.Pointer = {'Pointer', 'custom', ...
                        'PointerShapeCData', myptr, ...
                        'PointerShapeHotSpot', [16 1] };
                
            else
                % ROIs can be invalid when drawn interactively.
                clearROI(self.DrawCtrls);
                self.enableStartButtons();

            end
        end
        
        function reactToScribbleDone(self)
            self.doSegmentationAndUpdateApp();
        end

        function [mask, maskSrc] = applySegmentation(self)      
            
            import images.internal.app.segmenter.image.web.getMessageString;
                       
            % Default parameters
            conn = 8; % node connectivity
            maxIters = 5; % maximum iterations
            imageSize = self.ImageProperties.ImageSize;
            
            self.hApp.updateStatusBarText(getMessageString('applyingGraphCut'));
            self.showAsBusy()
                     
            if ~self.isGraphBuilt
                % If the graph must be rebuilt, then grabcut must also be
                % initialized below
                self.isGrabCutInitialized = false;
                if self.hApp.wasRGB
                self.GraphCutter = images.graphcut.internal.grabcut(prepLab(self.hApp.getImage()), ...
                    self.SuperpixelLabelMatrix,self.NumSuperpixels,conn,maxIters);
                else
                self.GraphCutter = images.graphcut.internal.grabcut(self.hApp.getImage(), ...
                    self.SuperpixelLabelMatrix,self.NumSuperpixels,conn,maxIters);
                end
            end
            
            fgInds = self.DrawCtrls.ForegroundInd;
            bgInds = self.DrawCtrls.BackgroundInd;
            if ~self.isGrabCutInitialized
                roiMask = createMask(self.DrawCtrls.ROI, imageSize(1), imageSize(2));
                self.GraphCutter = self.GraphCutter.addHardConstraints(fgInds, bgInds);
                self.GraphCutter = self.GraphCutter.addBoundingBox(roiMask);

            elseif (self.NumSuperpixels > 1)
                self.GraphCutter = self.GraphCutter.addHardConstraints(fgInds,bgInds);
                self.GraphCutter = self.GraphCutter.segment();
                if (isempty(fgInds) && isempty(bgInds)) && max(self.GraphCutter.Mask(:)) == 0
                    % Special case when there are no foreground/background
                    % marks AND grabcut segmentation fails (resulting in
                    % what would be an empty mask).
                    roiMask = createMask( self.DrawCtrls.ROI, ...
                                            imageSize(1), imageSize(2) );
                    self.GraphCutter = self.GraphCutter.addBoundingBox(roiMask);
                end
            end
            
            mask = self.GraphCutter.Mask;
            maskSrc = 'Local Graph Cut';
            
            self.hApp.showLegend();
                            
            self.isGraphBuilt = true;
            self.isGrabCutInitialized = true;
            
            self.enableApply();
            
            self.hApp.updateStatusBarText('');
            self.unshowAsBusy()
            
        end
        
        function TF = isUserDrawingValid(self)
            TF = isROIValid(self.DrawCtrls);
        end
    end
    
    %%Callbacks
    methods (Access = protected)
        
        function reactToROIButtonPressed(self, evt)
            if evt.Data
                self.DrawCtrls.ForegroundButton.Value = false;
                self.DrawCtrls.BackgroundButton.Value = false;
                self.DrawCtrls.EraseButton.Value = false;
                self.configureROI();
            else
                evt.DrawCtrls.ROIButton.Value = true;
            end
        end

        function configureROI(self)
            self.hApp.MousePointer = 'roi';

            self.createROI();
            self.updateEditMode("ROI");
        end
        
        function setRectangleStyleSelection(self)
            self.ROIStyle = 'Rectangle';
            self.createROI();
        end
        
        function setPolygonStyleSelection(self)
            self.ROIStyle = 'Polygon';
            self.createROI();
        end
        
        function cleanupAfterClearAll(self)
            
            self.DrawCtrls.clearROI();

            self.isGrabCutInitialized = false;
            self.cleanupAfterClear();
            
            enableStartButtons(self);

            self.CommonTSCtrls.ROIButton.Value = true;
            self.CommonTSCtrls.ForegroundButton.Value = false;
            self.CommonTSCtrls.BackgroundButton.Value = false;
            self.CommonTSCtrls.EraseButton.Value = false;
            
            self.createROI();
            self.updateEditMode("ROI");
        end
        
        function cleanupAfterClear(self, ~)
            
            if self.isUserDrawingValid()
                [mask, maskSrc] = self.applySegmentation();
                self.setTempHistory(mask, maskSrc);
            else
                self.hApp.ScrollPanel.resetPreviewMask();
                self.hApp.hideLegend();
                self.disableApply();
                self.showMessagePane();
                redraw(self.hApp.ScrollPanel);
            end
        end

        function createROI(self)
            imageSize = self.ImageProperties.ImageSize;
            area = [0.5, 0.5, imageSize(2), imageSize(1)];

            hAx  = self.hApp.getScrollPanelAxes();

            switch self.ROIStyle
                case 'Rectangle'
                    selectedROI = images.roi.Rectangle('Parent',hAx,'DrawingArea',area,...
                        'FaceSelectable',false,'FaceAlpha',0);
                case 'Polygon'
                    selectedROI = images.roi.Polygon('Parent',hAx,'DrawingArea',area,'FaceAlpha',0,...
                        'FaceSelectable',false,'MinimumNumberOfPoints',3);
            end

            self.DrawCtrls.ROI = selectedROI;
        end
        
        function modifyROICallback(self)
            self.isGrabCutInitialized = false;
            [mask, maskSrc] = self.applySegmentation();
            self.setTempHistory(mask, maskSrc);
        end
        
        function wireGrabCutListeners(self,selectedROI)
            if strcmp(self.ROIStyle,'Polygon')
                addlistener(selectedROI, 'VertexAdded', @(~,~) self.modifyROICallback());
                addlistener(selectedROI, 'VertexDeleted', @(~,~) self.modifyROICallback());
            end
            addlistener(selectedROI, 'DeletingROI', @(~,~) self.clearAll());
            addlistener(selectedROI, 'ROIMoved', @(~,~) self.modifyROICallback());
        end
        
    end
    
     %%Helpers
    methods (Access = protected)
        function enableStartButtons(self)

            self.TextureMgr.Enabled                             = true;
            self.ViewMgr.Enabled                                = true;
            self.ApplyCloseMgr.CloseButton.Enabled              = true;
            self.CommonTSCtrls.ForegroundButton.Enabled         = false;
            self.CommonTSCtrls.BackgroundButton.Enabled         = false;
            self.CommonTSCtrls.EraseButton.Enabled              = false;
            self.CommonTSCtrls.ClearButton.Enabled              = false;
            self.ShowSuperpixelButton.Enabled                   = true;
            self.SuperpixelDensityButton.Enabled                = true;
            self.CommonTSCtrls.ROIButton.Enabled                = true;
            self.CommonTSCtrls.ROIStyleButton.Enabled           = true;
            
        end
        
        function enableContinueButtons(self)

            self.TextureMgr.Enabled                             = true;
            self.ViewMgr.Enabled                                = true;
            self.ApplyCloseMgr.CloseButton.Enabled              = true;
            self.CommonTSCtrls.ForegroundButton.Enabled         = true;
            self.CommonTSCtrls.BackgroundButton.Enabled         = true;
            self.CommonTSCtrls.EraseButton.Enabled              = true;
            self.CommonTSCtrls.ClearButton.Enabled              = true;
            self.ShowSuperpixelButton.Enabled                   = true;
            self.SuperpixelDensityButton.Enabled                = true;
            self.ApplyCloseMgr.ApplyButton.Enabled              = true;
            self.CommonTSCtrls.ROIButton.Enabled                = false;
            self.CommonTSCtrls.ROIStyleButton.Enabled           = false;
            
        end
        
        function disableAllButtons(self)

            self.TextureMgr.Enabled                             = false;
            self.ViewMgr.Enabled                                = false;
            self.ApplyCloseMgr.ApplyButton.Enabled              = false;
            self.ApplyCloseMgr.CloseButton.Enabled              = false;
            self.ShowSuperpixelButton.Enabled                   = false;
            self.SuperpixelDensityButton.Enabled                = false;
            disableAllControls(self.CommonTSCtrls);
            
        end 
        
        function commands = getCommandsForHistory(self)
            
            pos = self.DrawCtrls.ROI.Position;
            if strcmp(self.ROIStyle,'Rectangle')
                x = [pos(1), pos(1)+pos(3),pos(1)+pos(3),pos(1)];
                y = [pos(2), pos(2), pos(2)+pos(4), pos(2)+pos(4)];
            else
                x = pos(:,1)';
                y = pos(:,2)';
            end
            
            xString = sprintf('%0.4f ', x);
                yString = sprintf('%0.4f ', y);
                commands{1} = sprintf('xPos = [%s];',xString);
                commands{2} = sprintf('yPos = [%s];',yString);
                commands{3} = 'm = size(BW, 1);';
                commands{4} = 'n = size(BW, 2);';
                commands{5} = sprintf('ROI = poly2mask(xPos,yPos,m,n);');
            
            foreInd = self.DrawCtrls.ForegroundInd;
            backInd = self.DrawCtrls.BackgroundInd;
            fString = sprintf('%d ', foreInd);
            bString = sprintf('%d ', backInd);
            
            if isempty(foreInd)
                commands{6} = sprintf('foregroundInd = [];');
            elseif isscalar(foreInd)
                commands{6} = sprintf('foregroundInd = %s;', fString);
            else
                commands{6} = sprintf('foregroundInd = [%s];', fString);
            end
            
            if isempty(backInd)
                commands{7} = sprintf('backgroundInd = [];');
            elseif isscalar(backInd)
                commands{7} = sprintf('backgroundInd = %s;', bString);
            else
                commands{7} = sprintf('backgroundInd = [%s];', bString);
            end

            if self.hApp.wasRGB
                commands{8} = sprintf('L = superpixels(X,%d,''IsInputLab'',true);',self.NumRequestedSuperpixels);
                commands{9} = '';
                commands{10} = ['% ',getString(message('images:imageSegmenter:convertLab'))];
                commands{11} = 'scaledX = prepLab(X);';
                commands{12} = sprintf('BW = BW | grabcut(scaledX,L,ROI,foregroundInd,backgroundInd);');
            else
                commands{8} = sprintf('L = superpixels(X,%d);',self.NumRequestedSuperpixels);
                commands{9} = sprintf('BW = BW | grabcut(X,L,ROI,foregroundInd,backgroundInd);');
            end
            
        end
        
        function showMessagePane(~)
            % No-op
        end
        
        function hideMessagePane(self)
            showMessagePane(self.hApp.ScrollPanel,false);
        end
        
    end
    
    methods (Access = private)
        
         function createTutorialDialog(self)
            
            s = settings;
            
            messageStrings = {getString(message('images:imageSegmenter:grabcutTutorialStep1')),...
                getString(message('images:imageSegmenter:grabcutTutorialStep2')),...
                getString(message('images:imageSegmenter:grabcutTutorialStep3')),...
                getString(message('images:imageSegmenter:grabcutTutorialStep4'))};
            
            titleString = getString(message('images:imageSegmenter:grabcutTutorialTitle'));
            
            imagePaths = {fullfile(matlabroot,'toolbox','images','imuitools','+images','+internal','+app','+segmenter','+image','+web','+images','GraphCut_1.png'),...
                fullfile(matlabroot,'toolbox','images','imuitools','+images','+internal','+app','+segmenter','+image','+web','+images','GraphCut_2.png'),...
                fullfile(matlabroot,'toolbox','images','imuitools','+images','+internal','+app','+segmenter','+image','+web','+images','GraphCut_3.png'),...
                fullfile(matlabroot,'toolbox','images','imuitools','+images','+internal','+app','+segmenter','+image','+web','+images','GraphCut_4.png')};
            
            self.hApp.CanClose = false;
            self.TutorialDialog = images.internal.app.utilities.TutorialDialog(imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.hApp.App),...
                imagePaths,messageStrings,titleString,s.images.imagesegmentertool.showGrabCutTutorialDialog);
            
            if ~self.TutorialDialog.IsAborted
                wait(self.TutorialDialog);
            end
            self.hApp.CanClose = true;
            
        end
        
    end
    
end

function pointer = loadPencilPointerImage()

pointer = [NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN;
    NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,1,1,NaN,NaN,NaN;
    NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,1,2,2,1,NaN,NaN;
    NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,1,2,1,2,2,1,NaN;
    NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,1,2,1,2,1,2,1,NaN;
    NaN,NaN,NaN,NaN,NaN,NaN,NaN,1,2,2,2,1,2,1,NaN,NaN;
    NaN,NaN,NaN,NaN,NaN,NaN,1,2,2,2,2,2,1,NaN,NaN,NaN;
    NaN,NaN,NaN,NaN,NaN,1,2,2,2,2,2,1,NaN,NaN,NaN,NaN;
    NaN,NaN,NaN,NaN,1,2,2,2,2,2,1,NaN,NaN,NaN,NaN,NaN;
    NaN,NaN,NaN,1,2,2,2,2,2,1,NaN,NaN,NaN,NaN,NaN,NaN;
    NaN,NaN,1,1,2,2,2,2,1,NaN,NaN,NaN,NaN,NaN,NaN,NaN;
    NaN,NaN,1,2,1,2,2,1,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN;
    NaN,1,2,2,2,1,1,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN;
    NaN,1,2,2,1,1,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN;
    1,2,1,1,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN;
    1,1,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN];

end

function out = prepLab(in)
%prepLab - Convert L*a*b* image to range [0,1]

out = in;
out(:,:,1) = in(:,:,1) / 100;  % L range is [0 100].
out(:,:,2) = (in(:,:,2) + 86.1827) / 184.4170;  % a* range is [-86.1827,98.2343].
out(:,:,3) = (in(:,:,3) + 107.8602) / 202.3382;  % b* range is [-107.8602,94.4780].

end
