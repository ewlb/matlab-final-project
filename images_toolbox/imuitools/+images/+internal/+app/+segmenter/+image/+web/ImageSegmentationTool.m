classdef ImageSegmentationTool < handle
    %

    % Copyright 2014-2024, The MathWorks, Inc.
    
    properties
        App
        DataBrowser
        ScrollPanel
        Session
        wasRGB
    end
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        AppTester
        DataBrowserTester
        ScrollPanelTester
        SessionTester
    end
        
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)

        Toolstrip
        StatusBar
        
        UndoButton
        RedoButton
        HelpButton
        
    end
    
    properties (Dependent = true)
        CurrentSegmentation
    end

    properties
        ActiveContoursIsRunning = false;
        DrawingROI = false;
        MousePointer = 'arrow';
        CanClose (1,1) logical = true;
    end
    
    properties (Access = private)
        CloseRequested (1,1) logical = false;
    end
    
    methods
        function self = ImageSegmentationTool(varargin)
            
            import images.internal.app.segmenter.image.web.*;
            
            appOptions.Title = images.internal.app.segmenter.image.web.getMessageString('appName');
            appOptions.Tag = "ImageSegmenter" + "_" + matlab.lang.internal.uuid;
            [x,y,width,height] = imageslib.internal.app.utilities.ScreenUtilities.getInitialToolPosition();
            appOptions.Icon = fullfile(matlabroot,'toolbox','images','icons','imageSegmenter_AppIcon_24.png');
            appOptions.WindowBounds = [x,y,width,height];
            appOptions.Product = "Image Processing Toolbox";
            appOptions.Scope = "Image Segmenter";
            appOptions.ShowSingleDocumentTab = false;
            appOptions.OfferDocumentMaximizeButton = 'false';
            appOptions.EnableTheming = true;
            self.App = matlab.ui.container.internal.AppContainer(appOptions);
                        
            self.App.CanCloseFcn = @(~) blockAppFromClosing(self);
            
            self.createToolstrip()
            self.createDataBrowser()
            self.Toolstrip.setMode(AppMode.NoImageLoaded)
            
            self.setupDocumentArea()
            
            hGroup = matlab.ui.internal.FigureDocumentGroup();
            hGroup.Title = "Figure";
            hGroup.Tag = "SegmenterFigure";
            self.App.add(hGroup);
            
            self.ScrollPanel = images.internal.app.segmenter.image.web.TwoMaskScrollPanel(self.App);            
                        
            % Show the app
            self.App.Visible = true;
            self.App.Busy = true;

            if self.App.State ~= matlab.ui.container.internal.appcontainer.AppState.RUNNING
                waitfor(self.App,'State');
            end

            if ~isvalid(self.App) || self.App.State == matlab.ui.container.internal.appcontainer.AppState.TERMINATED
                return;
            end

            drawnow;
                        
            if (nargin > 0)
                im = varargin{1};
                
                if nargin>1
                    self.wasRGB = varargin{2};
                end
                imageLoadSuccess = self.Toolstrip.loadImageInSegmentTab(im);
                if imageLoadSuccess
                    self.Toolstrip.setMode(AppMode.ImageLoaded)
                    updateImageTitleDisplay(self,varargin{3});
                else
                    self.Session = [];
                end
                
            else
                self.Session = [];
            end
            
            drawnow;
            
            set(getSegmentationFigure(self.DataBrowser),'SizeChangedFcn',@(~,~) resize(getSegmentationBrowser(self.DataBrowser)));
            set(getHistoryFigure(self.DataBrowser),'SizeChangedFcn',@(~,~) resize(getHistoryBrowser(self.DataBrowser)));
            set(self.ScrollPanel.hFig,'SizeChangedFcn',@(~,~) resize(self.ScrollPanel));
            
            drawnow;
            
            resize(self.DataBrowser);
            resize(self.ScrollPanel);
            
            % We want to destroy the current app instance if a user
            % interactively closes the toolgroup associated with this
            % instance.
            self.App.CanCloseFcn = @(~,~) doClosingSession(self);
            
            if self.CloseRequested
               close(self.App);
            end
            
            self.App.Busy = false;
            
        end
        
        function TF = blockAppFromClosing(self)
            TF = false;
            if self.CanClose
                self.CloseRequested = true;
            end
        end
        
        function updateImageTitleDisplay(self,name)
            setFigureName(self.ScrollPanel,name);
            self.App.Title = [images.internal.app.segmenter.image.web.getMessageString('appName'),' - ', name];
        end
                
        function delete(self)
            if isa(self.ScrollPanel,'TwoMaskScrollPanel')
                delete(self.ScrollPanel);
            end
            % Remove timers from find circles and active contour
            drawnow; drawnow;
            self.Toolstrip.deleteTimers();
            delete(self.Toolstrip);
            close(self.App);
            delete(self);
        end
        
        function createSessionFromImage(self, im, isDataNormalized, isInfNanRemoved, isDataAdjusted)
            
            import images.internal.app.segmenter.image.web.*;
            
            if isempty(self.wasRGB)
                self.Session = images.internal.app.segmenter.image.web.Session(im, self);
            else
                self.Session = images.internal.app.segmenter.image.web.Session(im, self, self.wasRGB);
            end
            
            self.Session.WasNormalized = isDataNormalized;
            self.Session.HadInfNanRemoved = isInfNanRemoved;
            self.Session.IsDataAdjusted = isDataAdjusted;
                        
            self.buildScrollPanel(im);
            self.ScrollPanel.AlphaMaskOpacity = self.Toolstrip.getOpacity();

            self.associateSegmentationWithBrowsers(self.Session.ActiveSegmentationIndex);
            self.addUndoRedoKeyListeners();
            drawnow;
            self.Toolstrip.setMode(AppMode.ImageLoaded)
            self.Toolstrip.setMode(AppMode.NoMasks)
        end
        
        function im = getImage(self)
            if self.wasRGB
                im = self.Session.getLabImage();
            else
                im = self.Session.getImage();
            end
        end
        
        function im = getRGBImage(self)
            im = self.Session.getImage();
        end
        
        function mask = getCurrentMask(self)
            activeSegmentation = self.Session.CurrentSegmentation();
            mask = activeSegmentation.getMask();
        end
        
        function setCurrentMask(self, newMask)
            activeSegmentation = self.Session.CurrentSegmentation();
            activeSegmentation.setCurrentMask_(newMask)
            self.ScrollPanel.updatePreviewMask(newMask)

        end
        
        function updateStatusBarText(self, text)
            if isvalid(self)
                self.StatusBar.setStatus(text);
            end
        end
        
        function hAx = getScrollPanelAxes(self)
            hAx = self.ScrollPanel.Image.AxesHandle;
        end
        
        function hFig = getScrollPanelFigure(self)
            hFig = self.ScrollPanel.hFig;
        end

        function hImObj = getScrollPanelImageObj(self)
            hImObj = self.ScrollPanel.Image;
        end

        function hIm = getScrollPanelImage(self)
            hIm = self.ScrollPanel.Image.ImageHandle;
        end
        
        function hPreview = getScrollPanelPreview(self)
            hPreview = self.ScrollPanel.PreviewMask;
        end
        
        function hCommitted = getScrollPanelCommitted(self)
            hCommitted = self.ScrollPanel.CommittedMask;
        end
        
        function showLegend(self)
            if ~isempty(self.ScrollPanel) && isvalid(self.ScrollPanel)
                self.ScrollPanel.addLegend();
            end
        end
        
        function hideLegend(self)
            if ~isempty(self.ScrollPanel) && isvalid(self.ScrollPanel)
                self.ScrollPanel.removeLegend();
            end
        end
        
        function disableBrowser(self)
            if ~isempty(self.DataBrowser)
                disable(self.DataBrowser);
            end
        end
        
        function enableBrowser(self)
            if ~isempty(self.DataBrowser)
                enable(self.DataBrowser);
            end
        end
        
        function showBinary(self)
            self.ScrollPanel.showBinary()
        end
        
        function unshowBinary(self)
            self.ScrollPanel.unshowBinary()
        end
        
        function opacity = getScrollPanelOpacity(self)
            opacity = self.ScrollPanel.AlphaMaskOpacity;
        end
        
        function updateScrollPanelPreview(self, newMask)
            if (~isempty(self.ScrollPanel))
                self.ScrollPanel.resetCommittedMask()
                self.ScrollPanel.updatePreviewMask(newMask)
            end
        end
        
        function updateScrollPanelCommitted(self, newMask)
            if (~isempty(self.ScrollPanel))
                self.ScrollPanel.resetPreviewMask()
                self.ScrollPanel.updateCommittedMask(newMask)
            end
        end
        
        function updateScrollPanelOpacity(self, newPercentage)
            self.ScrollPanel.AlphaMaskOpacity = newPercentage/100;
        end
        
        function current = get.CurrentSegmentation(self)
            if isempty(self.Session)
                current = [];
            else
                current = self.Session.CurrentSegmentation();
            end
        end

        function TF = isClickOnImage(self,evt)
            % Returns true if click was on the axes, no interaction mode is
            % enabled, and the click was not on other objects
            TF = evt.HitObject == self.ScrollPanel.Image.ImageHandle && ...
                strcmp(self.ScrollPanel.Image.ImageHandle.InteractionMode,'');
        end


        function TF = isClickValid(self)
            TF = strcmp(self.ScrollPanel.Image.ImageHandle.InteractionMode,'');
        end
        
        function generateCode(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            generator = iptui.internal.CodeGenerator();
            
            % Add items from the history.
            activeSegmentation = self.Session.CurrentSegmentation();
            serializedHistory = activeSegmentation.export();
            
            % Check for Load Mask
            idx = strcmpi(serializedHistory(:,1),'Load Mask');
            if any(idx)
                wasMaskLoaded = true;
            else
                wasMaskLoaded = false;
            end
            
            % Add function definition and help.
            self.addFunctionDeclaration(generator,wasMaskLoaded)
            generator.addReturn()
            generator.addHeader('imageSegmenter');
            
            if (self.Session.WasRGB)
                var = 'RGB';
            else
                var = 'X';
            end
            
            % Add code to remove Infs/NaNs if needed.
            if (self.Session.HadInfNanRemoved)
                if (self.Session.WasNormalized)
                    generator.addComment(getString(message('images:imageSegmenter:getIndicesComment')))
                    generator.addLine(sprintf('finiteIdx = isfinite(%s(:));',var))
                end
                
                generator.addComment(getString(message('images:imageSegmenter:nanZeroComment')));
                generator.addLine(sprintf('%s(isnan(%s)) = 0;',var,var));
                
                generator.addComment(getString(message('images:imageSegmenter:infOneComment')));
                generator.addLine(sprintf('%s(%s==Inf) = 1;',var,var));
                
                generator.addComment(getString(message('images:imageSegmenter:infMinusOneComment')));
                generator.addLine(sprintf('%s(%s==-Inf) = 0;',var,var));
            end
            
            % Add code to normalize image if needed.
            if (self.Session.WasNormalized)
                generator.addComment(getString(message('images:imageSegmenter:normalizeDataComment')))
                generator.addLine(sprintf('%smin = min(%s(:));',var,var))
                generator.addLine(sprintf('%smax = max(%s(:));',var,var))
                generator.addLine(sprintf('if isequal(%smax,%smin)',var,var))
                generator.addLine(sprintf('    %s = 0*%s;',var,var))
                generator.addLine('else')
                if self.Session.HadInfNanRemoved
                    generator.addLine(sprintf('    %s(finiteIdx) = (%s(finiteIdx) - %smin) ./ (%smax - %smin);',var,var,var,var,var))
                else
                    generator.addLine(sprintf('    %s = (%s - %smin) ./ (%smax - %smin);',var,var,var,var,var))
                end
                generator.addLine('end')
            end
            
            if (self.Session.IsDataAdjusted)
                generator.addComment(getString(message('images:imageSegmenter:adjustDataComment')))
                generator.addLine(sprintf('%s = imadjust(%s);',var,var))
            end
            
            % Add code to convert to Lab if needed.
            if (self.Session.WasRGB)
                generator.addComment(getString(message('images:imageSegmenter:convertLabComment')))
                generator.addLine('X = rgb2lab(RGB);')
            end
            
            % Add items from the history.
            activeSegmentation = self.Session.CurrentSegmentation();
            serializedHistory = activeSegmentation.export();
            
            numHistoryItems = size(serializedHistory, 1);
            isGaborNeeded = false;
            
            for idx = 2:numHistoryItems
                isGaborNeeded = isGaborNeeded | any(strcmp(serializedHistory{idx,1},...
                    {getMessageString('graphCutTextureComment'),getMessageString('kmeansTextureComment'),...
                    getMessageString('floodFillTextureComment'),getMessageString('activeContoursTextureComment')}));
            end
            
            if isGaborNeeded
                generator.addLine('gaborX = createGaborFeatures(X);')
            end

            isThresholdMethod = ismember(serializedHistory{2,1}, ...
                {getMessageString('globalThresholdComment'), ...
                getMessageString('manualThresholdComment'), ...
                getMessageString('adaptiveThresholdComment')});
            
            isPreallocationNeeded = ~any(strcmp(serializedHistory{2,1},...
                {getMessageString('findCirclesComment'),getMessageString('graphCutComment'),...
                getMessageString('graphCutTextureComment'),getMessageString('kmeansComment'),...
                getMessageString('kmeansTextureComment')})) && ...
                ~isThresholdMethod;
            
            isGraphCutAppliedOnRGB = self.Session.WasRGB && (any(cellfun(@(x) strcmp(x,getMessageString('graphCutComment')),serializedHistory(:,1))) || ...
                any(cellfun(@(x) strcmp(x,getMessageString('grabcutComment')),serializedHistory(:,1))));
            
            % Add function to create initial mask.
            if isPreallocationNeeded
                generator.addComment(getString(message('images:imageSegmenter:loadMaskComment')))
                if (self.Session.WasRGB)
                    generator.addLine('BW = false(size(RGB,1),size(RGB,2));');
                else
                    generator.addLine('BW = false(size(X,1),size(X,2));');
                end

            end
            
            for operationIndex = 2:numHistoryItems
                description = serializedHistory{operationIndex, 1};
                commands = serializedHistory{operationIndex, 2};
                
                generator.addComment(description)

                numberOfCommands = numel(commands);
                for commandIndex = 1:numberOfCommands
                    generator.addLine(commands{commandIndex})
                end
            end
            
            % Create masked image.
            generator.addComment('Create masked image.')
            if (self.Session.WasRGB)
                generator.addLine('maskedImage = RGB;')
                generator.addLine('maskedImage(repmat(~BW,[1 1 3])) = 0;')
            else
                generator.addLine('maskedImage = X;')
                generator.addLine('maskedImage(~BW) = 0;')
            end
            
            generator.addLine('end')
            generator.addReturn()
            
            if isGaborNeeded
                addGaborSubfunction(generator);
            end
            
            if isGraphCutAppliedOnRGB || isGaborNeeded
                addPrepLabSubfunction(generator);
            end
            
            generator.addReturn()

            if (self.Session.WasRGB)
                % If the input image was RGB, the code generator includes a
                % line that converts the input to LAB using rgb2lab,
                % storing the result in the variable 'X', before adding
                % specific code from the command history. For some
                % operations, however, the LAB conversion result is unused.
                % If the code includes an assignment to X but does not
                % otherwise use X, then strip out the rgb2lab conversion
                % and the associated comment. See g28942613.
                if images.internal.app.segmenter.image.web.isAssignedVariableUnused(generator.codeString,'X')
                    generator.codeString = images.internal.app.segmenter.image.web.stripLabConversionCode(generator.codeString);
                end
            end

            % Add SAM Auto Seg Post Prcoessing function to the generated
            % code
            if contains(generator.codeString, "imsegsam")
                codeStr = generator.codeString;
                fn = which("images.internal.app.segmenter.image.web.sam.refineBorders");
                refineCodeStr = fileread(fn);
                locs = strfind(refineCodeStr, "end");
                locs = locs(end);
                refineCodeStr = refineCodeStr(1:locs+2);
                generator.codeString = [codeStr refineCodeStr];
                generator.addReturn();
            end
            generator.putCodeInEditor()
        end
        
        function returnToSegmentTab(self)
            idx = self.Toolstrip.findVisibleTabs();
            self.Toolstrip.closeTab(idx)
        end
        
        function applyCurrentTabSettings(self)
            idx = self.Toolstrip.findVisibleTabs();
            self.Toolstrip.applyCurrentSettings(idx)
        end
        
        function discardCurrentTabSettings(self)
            idx = self.Toolstrip.findVisibleTabs();
            self.Toolstrip.closeTab(idx)
        end
        
        function updateModeOnSegmentationChange(self)
            
            activeSegmentation = self.CurrentSegmentation;
            if (activeSegmentation.CurrentMaskIsEmpty)
                self.Toolstrip.setMode(images.internal.app.segmenter.image.web.AppMode.NoMasks)
            else
                self.Toolstrip.setMode(images.internal.app.segmenter.image.web.AppMode.MasksExist)
            end
        end
        
        function stopActiveContours(self)
            self.Toolstrip.stopActiveContours()
        end
        
        function resetAxToolbarMode(self)
            hFig = self.getScrollPanelFigure();
            
            prop = isprop(hFig,'ModeManager');
            
            if ~isempty(prop) && prop && ~isempty(hFig.ModeManager.CurrentMode)
                hFig.ModeManager.CurrentMode = [];
            end
        end
        
    end
    
    % History-related
    methods
        function addToHistory(self, newMask, description, command)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            activeSegmentation = self.CurrentSegmentation;
            activeSegmentation.addToHistory_(newMask, description, command)
            
            self.clearTemporaryHistory()
            
            self.Toolstrip.setMode(AppMode.HistoryIsNotEmpty)
            
            self.updateScrollPanelCommitted(newMask)
            
            self.refreshSegmentationBrowserThumbnail(newMask)
            
            if (maskHasRegions(newMask))
                self.Toolstrip.setMode(AppMode.MasksExist)
            else
                self.Toolstrip.setMode(AppMode.NoMasks)
            end
            
            self.enableUndoActionQABButton(true)
            self.enableRedoActionQABButton(false)
        end
        
        function setTemporaryHistory(self, newMask, description, command)
            import images.internal.app.segmenter.image.web.AppMode;
            
            activeSegmentation = self.CurrentSegmentation;
            activeSegmentation.setTemporaryHistory_(newMask, description, command)
            
            self.ScrollPanel.updatePreviewMask(newMask)
        end
        
        function commitTemporaryHistory(self)
            activeSegmentation = self.CurrentSegmentation;
            [mask, description, command] = activeSegmentation.getTemporaryHistory_();
            self.addToHistory(mask.getMask(), description, command)
        end
        
        function clearTemporaryHistory(self)
            activeSegmentation = self.CurrentSegmentation;
            activeSegmentation.clearTemporaryHistory_()
            
            self.updateScrollPanelCommitted(self.getCurrentMask())
        end
        
        function updateUndoRedoButtons(self)
            activeSegmentation = self.CurrentSegmentation;
            self.enableUndoActionQABButton(activeSegmentation.HasUndoItems)
            self.enableRedoActionQABButton(activeSegmentation.HasRedoItems)            
        end
        
        function setCurrentHistoryItem(self, historyItemIndex)
            activeSegmentation = self.CurrentSegmentation;
            activeSegmentation.setCurrentHistoryItem(historyItemIndex)
            
            if (activeSegmentation.CurrentMaskIsEmpty)
                self.Toolstrip.setMode(images.internal.app.segmenter.image.web.AppMode.NoMasks)
            else
                self.Toolstrip.setMode(images.internal.app.segmenter.image.web.AppMode.MasksExist)
            end
            
            self.refreshSegmentationBrowserThumbnail(self.getCurrentMask())
            self.updateScrollPanelCommitted(self.getCurrentMask())
        end
        
        function undoHandler(self, ~, ~)
            activeSegmentation = self.CurrentSegmentation;
            if (activeSegmentation.HasUndoItems)
                hBrowser = self.getHistoryBrowser();
                hBrowser.stepBackward()
            end
        end
        
        function redoHandler(self, ~, ~)
            activeSegmentation = self.CurrentSegmentation;
            if (activeSegmentation.HasRedoItems)
                hBrowser = self.getHistoryBrowser();
                hBrowser.stepForward()
            end
        end
        
        function helpHandler(~, ~, ~)
            doc('imageSegmenter');
        end
        
        function TF = hasPaintBrush(self)
            activeSegmentation = self.CurrentSegmentation;            
            TF = activeSegmentation.HasPaintBrush;
        end
    end
    
    % Data Browser-related
    methods
        function hBrowser = getHistoryBrowser(self)
            hBrowser = self.DataBrowser.getHistoryBrowser();
        end
        
        function hBrowser = getSegmentationBrowser(self)
            hBrowser = self.DataBrowser.getSegmentationBrowser();
        end
        
        function initializeHistoryBrowser(self, im)
            activeSegmentation = self.CurrentSegmentation;
            activeSegmentation.addToHistory_(false(size(im)), ...
                images.internal.app.segmenter.image.web.getMessageString('loadImage'), '')
        end
        
        function initializeSegmentationBrowser(self, ~)
            %TODO: These next items shouldn't need to happen.
            activeSegmentation = self.CurrentSegmentation;
            activeSegmentation.Name = 'Segmentation 1';
            
            theBrowser = self.getSegmentationBrowser();
            theBrowser.setSelection(1)
            self.refreshSegmentationBrowser()
        end
        
        function associateSegmentationWithBrowsers(self, segmentationIndex)
            segmentationDetailsCell = self.Session.convertToDetailsCell();
            
            theSegmentationBrowser = self.getSegmentationBrowser();
            theSegmentationBrowser.setContent(segmentationDetailsCell, ...
                segmentationIndex)
        end
        
        function refreshHistoryBrowser(self)
            activeSegmentation = self.Session.CurrentSegmentation();
            activeSegmentation.refreshHistoryBrowser()
        end
        
        function scrollHistoryBrowserToEnd(self)
            hBrowser = self.getHistoryBrowser();
            hBrowser.scrollToEnd()
        end
        
        function scrollSegmentationBrowserToEnd(self)
            hBrowser = self.getSegmentationBrowser();
            hBrowser.scrollToEnd()
        end
    end
    
    methods (Static)
        function deleteAllTools(~)
            imageslib.internal.apputil.manageToolInstances('deleteAll', 'imageSegmenterWeb');
            T1 = timerfindall('Tag','ImageSegmenterFindCirclesTimer');
            T2 = timerfindall('Tag','ImageSegmenterActiveContourTimer');
            delete(T1);
            delete(T2);
        end
    end
    
    methods (Access = private)
        
        function createToolstrip(self)
            self.Toolstrip = images.internal.app.segmenter.image.web.Toolstrip(self.App, self);
            self.Toolstrip.hideActiveContourTab()
            self.Toolstrip.hideFloodFillTab()
            self.Toolstrip.hideMorphologyTab()
            self.Toolstrip.hideThresholdTab()
            self.Toolstrip.hideGraphCutTab()
            self.Toolstrip.hideFindCirclesTab()
            self.Toolstrip.hideGrabCutTab()
            self.Toolstrip.hideROITab()
            self.Toolstrip.hidePaintTab()
            self.Toolstrip.hideSAMAddTab();
            self.Toolstrip.hideSAMRefineTab();
        end
        
        function createDataBrowser(self)
            self.DataBrowser = images.internal.app.segmenter.image.web.DataBrowser(self);
        end
        
        function setupDocumentArea(self)
            
            self.addUndoRedoCallbacksToQAB()

            imageslib.internal.apputil.manageToolInstances('add', 'imageSegmenterWeb', self);
                       
            % Setup space to report progress
            self.StatusBar = images.internal.app.utilities.StatusBar;
            self.App.add(self.StatusBar.Bar);
            
        end
        
        function buildScrollPanel(self, im)
            updateScrollPanel(self.ScrollPanel,im);
            self.updateScrollPanelOpacity(self.Toolstrip.getOpacity)
            self.ScrollPanel.updateCommittedMask(false([size(im,1) size(im,2)]))
            self.ScrollPanel.Visible = 'on';
            
            images.roi.internal.IPTROIPointerManager(self.ScrollPanel.hFig,[]);
            addlistener(self.ScrollPanel.hFig,'WindowMouseMotion',@(src,evt) self.mousePointerCallback(src,evt));
        end
        
        function mousePointerCallback(self,~,evt)
            
            hFig = getScrollPanelFigure(self);
            hIm = getScrollPanelImage(self);
            
            if (isprop(hFig,'IPTROIPointerManager') && ~hFig.IPTROIPointerManager.Enabled) ||...
                    isempty(hIm) || ~isvalid(hIm)
                return;
            end
            
            if wasClickOnAxesToolbar(self,evt)
                images.roi.setBackgroundPointer(hFig,'arrow');
            elseif isa(evt.HitObject,'matlab.graphics.primitive.Image')
                if isprop(evt.HitObject,'InteractionMode')
                    switch evt.HitObject.InteractionMode
                        case ''
                            setPointer(self,hFig);
                        case 'pan'
                            images.roi.setBackgroundPointer(hFig,'custom',matlab.graphics.interaction.internal.getPointerCData('pan_both'),[16,16]);
                        case 'zoomin'
                            images.roi.setBackgroundPointer(hFig,'custom',matlab.graphics.interaction.internal.getPointerCData('zoomin_unconstrained'),[16,16]);
                        case 'zoomout'
                            images.roi.setBackgroundPointer(hFig,'custom',matlab.graphics.interaction.internal.getPointerCData('zoomout_both'),[16,16]);
                    end
                else
                    images.roi.setBackgroundPointer(hFig,'arrow');
                end
            elseif isa(evt.HitObject,'matlab.graphics.axis.Axes')
                images.roi.setBackgroundPointer(hFig,'arrow');
            elseif isa(evt.HitObject,'matlab.ui.container.Panel')
                images.roi.setBackgroundPointer(hFig,'arrow');
            end
            
        end
        
        function setPointer(self,hFig)
            
            switch self.MousePointer
                
                case 'arrow'
                    images.roi.setBackgroundPointer(hFig,'arrow');
                case 'paint'
                    images.roi.setBackgroundPointer(hFig,'paintcan');
                case 'fore'
                    set(hFig,'Pointer','custom','PointerShapeCData',loadPencilPointerImage(),'PointerShapeHotSpot',[16 1]);
                case 'back'
                    pointer = loadPencilPointerImage()';
                    images.roi.setBackgroundPointer(hFig,'custom',pointer,[16 1]);
                case 'eraser'
                    set(hFig,'Pointer','custom','PointerShapeCData',loadEraserPointerImage(),'PointerShapeHotSpot',[8,8]);
                case 'roi'
                    images.roi.setBackgroundPointer(hFig,'crosshair');
                case 'brush'
                    images.roi.setBackgroundPointer(hFig,'dot');
                    
            end
            
        end
        
        function TF = wasClickOnAxesToolbar(~,evt)
            % Determine if the HitObject in event data is a descendant of
            % the Axes Toolbar. This indicates whether or not the user just
            % clicked on the Axes Toolbar.
            TF = ~isempty(ancestor(evt.HitObject,'matlab.graphics.controls.AxesToolbar'));
        end
        
        function TF = doClosingSession(self)
            import images.internal.app.segmenter.image.web.AppMode;
            if ~isvalid(self)
                TF = true;
                return;
            end
            
            TF = self.CanClose;

            if ~TF
                return;
            end
            
            self.Toolstrip.setMode(AppMode.AppClosing)

            imageslib.internal.apputil.manageToolInstances('remove', 'imageSegmenterWeb', self);
        end
        
        function addUndoRedoCallbacksToQAB(self)
            
            self.HelpButton = matlab.ui.internal.toolstrip.qab.QABHelpButton();
            self.HelpButton.ButtonPushedFcn = @(varargin) helpHandler(self);
            
            self.UndoButton = matlab.ui.internal.toolstrip.qab.QABUndoButton();
            self.UndoButton.ButtonPushedFcn = @(varargin) undoHandler(self);
            
            self.RedoButton = matlab.ui.internal.toolstrip.qab.QABRedoButton();
            self.RedoButton.ButtonPushedFcn = @(varargin) redoHandler(self);
            
            % Add the button to your app
            self.App.add(self.HelpButton);
            self.App.add(self.RedoButton);
            self.App.add(self.UndoButton);

        end
        
        function addUndoRedoKeyListeners(self)
            hFig = self.getScrollPanelFigure();
            hHistory = getHistoryFigure(self.DataBrowser);
            hSeg = getSegmentationFigure(self.DataBrowser);
            set(hFig, 'WindowKeyPressFcn', @self.keypressHandler);
            set(hHistory, 'WindowKeyPressFcn', @self.keypressHandler);
            set(hSeg, 'WindowKeyPressFcn', @self.keypressHandler);
        end
        
        function keypressHandler(self, ~, evt)
            if numel(evt.Modifier) ~= 1
                return
            end
            
            switch (evt.Modifier{1})
            case 'control'
                switch (evt.Key)
                case {'z', 'Z'}
                    self.undoHandler()
                case {'y', 'Y'}
                    self.redoHandler()
                otherwise
                    return
                end
                
            otherwise
                return
            end
        end
        
        function enableUndoActionQABButton(self, TF)
            self.UndoButton.Enabled = TF;
        end
        
        function enableRedoActionQABButton(self, TF)
            self.RedoButton.Enabled = TF;
        end
        
        function refreshSegmentationBrowser(self)
            numSegmentations = self.Session.NumberOfSegmentations;
            segmentationListCell = cell(numSegmentations, 2);
            
            for i = 1:numSegmentations
                thisSegmentation = self.Session.getSegmentationByIndex(i);
                
                theMask = thisSegmentation.getMask();
                segmentationListCell{i, 1} = images.internal.app.segmenter.image.web.createThumbnail(theMask);
                segmentationListCell{i, 2} = thisSegmentation.Name;
            end
            
            theBrowser = self.getSegmentationBrowser();
            theBrowser.setContent(segmentationListCell, theBrowser.getSelection())
        end
        
        function refreshSegmentationBrowserThumbnail(self, theMask)
            newThumbnailFilename = images.internal.app.segmenter.image.web.createThumbnail(theMask);
            hBrowser = self.getSegmentationBrowser();
            hBrowser.updateActiveThumbnail(newThumbnailFilename)
        end
        
        function addFunctionDeclaration(self, generator, wasMaskLoaded)
            fcnName = 'segmentImage';
            if (self.Session.WasRGB)
                inputs = {'RGB'};
            else
                inputs = {'X'};
            end
            if (wasMaskLoaded)
                inputs{2} = 'MASK'; 
            end
            
            outputs = {'BW', 'maskedImage'};
            
            h1Line  = getString(message('images:imageSegmenter:h1Line'));
            
            description = getString(message('images:imageSegmenter:codeDescription',inputs{1}));
            
            generator.addFunctionDeclaration(fcnName, inputs, outputs, h1Line);
            generator.addSyntaxHelp(fcnName, description, inputs, outputs);
        end
    end
    
    methods
        
        function obj = get.AppTester(self)
            obj = self.App;
        end
        
        function obj = get.DataBrowserTester(self)
            obj = self.DataBrowser;
        end
        
        function obj = get.ScrollPanelTester(self)
            obj = self.ScrollPanel;
        end
        function obj = get.SessionTester(self)
            obj = self.Session;
        end
        
    end
    
end

function addGaborSubfunction(generator)

generator.addLine('function gaborFeatures = createGaborFeatures(im)');
generator.addReturn()
generator.addLine('if size(im,3) == 3');
generator.addLine('    im = prepLab(im);');
generator.addLine('end');
generator.addReturn()
generator.addLine('im = im2single(im);');
generator.addReturn()
generator.addLine('imageSize = size(im);');
generator.addLine('numRows = imageSize(1);');
generator.addLine('numCols = imageSize(2);');
generator.addReturn()
generator.addLine('wavelengthMin = 4/sqrt(2);');
generator.addLine('wavelengthMax = hypot(numRows,numCols);');
generator.addLine('n = floor(log2(wavelengthMax/wavelengthMin));');
generator.addLine('wavelength = 2.^(0:(n-2)) * wavelengthMin;');
generator.addReturn()
generator.addLine('deltaTheta = 45;');
generator.addLine('orientation = 0:deltaTheta:(180-deltaTheta);');
generator.addReturn()
generator.addLine('g = gabor(wavelength,orientation);');
generator.addLine('gabormag = imgaborfilt(im(:,:,1),g);');
generator.addReturn()
generator.addLine('for i = 1:length(g)');
generator.addLine('    sigma = 0.5*g(i).Wavelength;');
generator.addLine('    K = 3;');
generator.addLine('    gabormag(:,:,i) = imgaussfilt(gabormag(:,:,i),K*sigma);');
generator.addLine('end');
generator.addComment('Increases liklihood that neighboring pixels/subregions are segmented together');
generator.addLine('X = 1:numCols;');
generator.addLine('Y = 1:numRows;');
generator.addLine('[X,Y] = meshgrid(X,Y);');
generator.addLine('featureSet = cat(3,gabormag,X);');
generator.addLine('featureSet = cat(3,featureSet,Y);');
generator.addLine('featureSet = reshape(featureSet,numRows*numCols,[]);');
generator.addComment('Normalize feature set');
generator.addLine('featureSet = featureSet - mean(featureSet);');
generator.addLine('featureSet = featureSet ./ std(featureSet);');
generator.addReturn()
generator.addLine('gaborFeatures = reshape(featureSet,[numRows,numCols,size(featureSet,2)]);');
generator.addComment('Add color/intensity into feature set');
generator.addLine('gaborFeatures = cat(3,gaborFeatures,im);');
generator.addReturn()
generator.addLine('end');
generator.addReturn()
end

function addPrepLabSubfunction(generator)

generator.addLine('function out = prepLab(in)');
generator.addComment('Convert L*a*b* image to range [0,1]');
generator.addLine('out = in;');
generator.addLine('out(:,:,1) = in(:,:,1) / 100;  % L range is [0 100].');
generator.addLine('out(:,:,2) = (in(:,:,2) + 86.1827) / 184.4170;  % a* range is [-86.1827,98.2343].');
generator.addLine('out(:,:,3) = (in(:,:,3) + 107.8602) / 202.3382;  % b* range is [-107.8602,94.4780].');
generator.addReturn()
generator.addLine('end');

end

function TF = maskHasRegions(mask)

TF = any(mask(:));

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

function pointer = loadEraserPointerImage()

pointer = NaN(16);
pointer(5:12,5:12) = 1;
pointer(6:11,6:11) = 2;

end
