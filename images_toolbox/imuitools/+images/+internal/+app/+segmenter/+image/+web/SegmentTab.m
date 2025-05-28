classdef SegmentTab < handle
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
    properties (GetAccess = {?uitest.factory.Tester,?images.internal.app.segmenter.image.web.Toolstrip}, SetAccess = private)
        LoadImageSection
        LoadImageButton
        LoadMaskButton
        
        NewSegmentationSection
        NewSegmentationButton
        CloneSegmentationButton
        
        TextureSection
        TextureMgr
        KmeansButton
        
        MaskSection
        AddMaskSection
        RefineMaskSection
        DrawButton
        PaintButton
        RectangleButton
        EllipseButton
        PolygonButton
        GrabCutButton
        ThresholdButton
        GraphCutButton
        FindCirclesButton
        FloodFillButton
        MorphologyButton
        ActiveContoursButton
        ClearBorderButton
        FillHolesButton
        InvertMaskButton
        SAMAddToMaskButton
        SAMRefineMaskButton
        
        TechniqueGallery
        CreateGallery
        AddGallery
        RefineGallery
        
        ViewSection
        ViewMgr
        
        ExportSection
        ExportButton
        ExportFunction
        ExportButtonIsEnabled
        
        ShowBinaryButtonListener
        OpacitySliderListener
        
        ExportDialog
    end
    
    %%Draw Mode Containers
    properties
        FreeHandContainer
        PolygonContainer
        RectangleContainer
        EllipseContainer
    end
    
    %%Code generation
    properties
        IsDataNormalized
        IsInfNanRemoved
        IsDataAdjusted
    end
    
    %%Public API
    methods
        function self = SegmentTab(toolGroup, tabGroup, theToolstrip, theApp, varargin)
            
            if (nargin == 3)
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup,'segmentationTab');
            else
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup,'segmentationTab', varargin{:});
            end
            
            self.hAppContainer = toolGroup;
            self.hTabGroup = tabGroup;
            self.hToolstrip = theToolstrip;
            self.hApp = theApp;
            
            self.layoutTab()
            
            updateGalleryFavorites(self)
        end
        
        function show(self)
            self.hTabGroup.add(self.hTab)
            self.Visible = true;
        end
        
        function hide(self)
            if ~self.Visible
                return;
            end
            self.Visible = false;
            self.hTabGroup.remove(self.hTab)
        end
        
        function makeActive(self)
            self.hTabGroup.SelectedTab = self.hTab;
        end
        
        function setMode(self, mode)
            import images.internal.app.segmenter.image.web.AppMode;

            switch (mode)
                case AppMode.NoImageLoaded
                    self.disableAllButtons()
                    self.LoadImageButton.Enabled = true;
    
                case {AppMode.ImageLoaded, AppMode.NoMasks}
                    
                    %If the app enters a state with no mask, make sure we set
                    %the state back to unshow binary.
                    if self.ViewMgr.ShowBinaryButton.Value
                        self.reactToUnshowBinary();
                        self.hApp.unshowBinary()
                        self.hToolstrip.setMode(AppMode.UnshowBinary)
                        % This is needed to ensure that state is settled after
                        % unshow binary. 
                        drawnow;
                    end
                    
                    self.handleTextureState()
                    self.enableNoMaskButtons()
                    self.updateToolTipsForMaskControls(false)
                    self.ExportButton.Enabled = false;
                    self.ExportButtonIsEnabled = false;
                    self.TechniqueGallery.TextOverlay = '';
                    
                case {AppMode.ThresholdImage,...
                      AppMode.ActiveContoursIterationsDone,...
                      AppMode.FloodFillTabOpened, AppMode.MorphImage,...
                      AppMode.MorphTabOpened, AppMode.ActiveContoursTabOpened,...
                      AppMode.ActiveContoursNoMask, AppMode.GraphCutOpened,...
                      AppMode.FindCirclesOpened, AppMode.GrabCutOpened,...
                      AppMode.Drawing}
                    self.updateToolTipsForMaskControls(true)
    
                case AppMode.MasksExist
                    self.enableMaskButtons()
                    self.updateToolTipsForMaskControls(true)
                    
                    TF = ~self.hApp.hasPaintBrush;
                    self.ExportFunction.Enabled = TF;
    
                case {AppMode.ActiveContoursRunning, AppMode.FloodFillSelection}
                    self.disableAllButtons()
    
                case {AppMode.DrawingDone, AppMode.ActiveContoursDone,...
                      AppMode.FloodFillDone, AppMode.ThresholdDone,...
                      AppMode.MorphologyDone, AppMode.GraphCutDone,...
                      AppMode.FindCirclesDone, AppMode.GrabCutDone, ...
                      AppMode.SAMDone}
                    maskIsEmpty = self.checkIfMaskIsEmpty();
                    if maskIsEmpty
                        self.setMode(AppMode.NoMasks)
                    else
                        self.enableMaskButtons()
                    end
                    self.ExportButton.Enabled = self.ExportButtonIsEnabled;
    
                case AppMode.OpacityChanged
                    self.reactToOpacityChange()
    
                case AppMode.ShowBinary
                    self.reactToShowBinary()
    
                case AppMode.UnshowBinary
                    self.reactToUnshowBinary()
    
                case AppMode.HistoryIsEmpty
                    self.ExportButton.Enabled = false;
                    self.ExportButtonIsEnabled = false;
    
                case AppMode.HistoryIsNotEmpty
                    self.ExportButton.Enabled = true;
                    self.ExportButtonIsEnabled = true;
                    
                    TF = ~self.hApp.hasPaintBrush;
                    self.ExportFunction.Enabled = TF;
                    
                case AppMode.ToggleTexture
                        self.TextureMgr.updateTextureState(self.hApp.Session.UseTexture);

                otherwise
                    % App contains modes not relevant for this Tab
            end

        end
        
        function opacity = getOpacity(self)
            opacity = self.ViewMgr.Opacity / 100;
        end
        
        function TF = importImageData(self,im)
            
            TF = true;
            %Normalize image if it's floating point. Inform the user via a
            %dialog.
            if isfloat(im)
                self.hApp.App.Busy = false;
                [self,im] = normalizeFloatDataDlg(self,im);
                self.hApp.App.Busy = true;
                if isempty(im)
                    TF = false;
                    return;
                end
            end
            
            if ~self.hApp.wasRGB
                if isfloat(im)
                    if self.IsDataNormalized
                        % Floating point image had values outside [0 1] and
                        % was already adjusted in normalizeFloatDataDlg
                        askToAdjustData = false;
                    else
                        % Floating point image with values inside [0 1].
                        % Ask to adjsut image
                        askToAdjustData = true;
                    end
                else
                    % Integer data type. Ask to adjust this image.
                    askToAdjustData = true;
                end
            else
                % RGB image - Don't ask to adjust
                askToAdjustData = false;
            end
            
            if askToAdjustData
                % Ask to adjust grayscale image to data range
                self.hApp.App.Busy = false;
                im = adjustGrayscaleDataDlg(self,im);
                self.hApp.App.Busy = false;
            end
            
            self.hApp.createSessionFromImage(im, self.IsDataNormalized, self.IsInfNanRemoved, self.IsDataAdjusted);
            
            prepareForAssistedFreehand(self);
            
        end
        
        function prepareForAssistedFreehand(self)
        
            im = self.hApp.getImage();
            
            if self.hApp.Session.WasRGB
                im = im(:,:,1);
            end
            
            im = single(rescale(im));
                   
            images.roi.AssistedFreehand.prepareForAssistedFreehand(self.hApp.getScrollPanelImage,im);
        end
        
        function updateGalleryFavorites(self)
            
            s = settings;
            state = s.images.imagesegmentertool.GalleryFavorites.ActiveValue;
            
            if ~isempty(state)
                loadState(self.TechniqueGallery.Popup,state);
            end
            self.TechniqueGallery.TextOverlay = getString(message('images:imageSegmenter:galleryPrompt'));
                        
        end
        
    end
    
    %%Layout
    methods (Access = private)
        function layoutTab(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            % Add Sections to Segment Tab
            self.LoadImageSection           = self.hTab.addSection(getMessageString('loadImage'));
            self.LoadImageSection.Tag       = 'loadImage';
            self.NewSegmentationSection     = self.hTab.addSection(getMessageString('newSegmentation'));
            self.NewSegmentationSection.Tag = 'newSegmentation';
            self.TextureSection             = self.addTextureSection();
            self.MaskSection                = self.hTab.addSection(getMessageString('maskSection'));
            self.MaskSection.Tag            = 'maskSection';
            self.ViewSection                = self.addViewSection();
            self.ExportSection              = self.hTab.addSection(getMessageString('Export'));
            self.ExportSection.Tag          = 'Export';
            
            self.layoutLoadImageSection()
            self.layoutNewSegmentationSection()
            self.layoutMaskSection()
            self.layoutAddMaskSection()
            self.layoutRefineMaskSection()
            self.layoutGallery()
            self.layoutExportSection()

            self.Visible = true;
        end
        
        function layoutLoadImageSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;
            
            %Load Image Button
            self.LoadImageButton = matlab.ui.internal.toolstrip.SplitButton(getString(message('images:imageSegmenter:loadImageSplitButtonTitle')), ...
                matlab.ui.internal.toolstrip.Icon('import_data'));
            self.LoadImageButton.Tag = 'btnLoadImage';
            self.LoadImageButton.Description = getString(message('images:imageSegmenter:loadImageTooltip'));

            % Drop down list
            sub_popup = matlab.ui.internal.toolstrip.PopupList();
            
            sub_item1 = matlab.ui.internal.toolstrip.ListItem(getString(message('images:imageSegmenter:loadImageFromFile')));
            sub_item1.Icon = matlab.ui.internal.toolstrip.Icon('folder');
            sub_item1.Tag = 'LoadFromFile';
            sub_item1.ShowDescription = false;
            addlistener(sub_item1, 'ItemPushed', @self.loadImageFromFile);
            
            sub_item2 = matlab.ui.internal.toolstrip.ListItem(getString(message('images:imageSegmenter:loadImageFromWorkspace')));
            sub_item2.Icon = matlab.ui.internal.toolstrip.Icon('workspace');
            sub_item2.Tag = 'LoadFromWorkspace';
            sub_item2.ShowDescription = false;
            addlistener(sub_item2, 'ItemPushed', @self.loadImageFromWorkspace);
            
            sub_popup.add(sub_item1);
            sub_popup.add(sub_item2);
            
            self.LoadImageButton.Popup = sub_popup;
            self.LoadImageButton.Popup.Tag = 'Load Image Popup';
            addlistener(self.LoadImageButton, 'ButtonPushed', @(hobj,evt) self.loadImageFromFile(hobj,evt));
            
            %Load Mask Button
            self.LoadMaskButton = matlab.ui.internal.toolstrip.Button(getMessageString('loadMask'), Icon('import_binaryImageMask'));
            self.LoadMaskButton.Tag = 'btnLoadMask';
            self.LoadMaskButton.Description = getMessageString('maskTooltip');
            addlistener(self.LoadMaskButton, 'ButtonPushed', @(~,~) self.loadMaskFromWorkspace());
            
            %Layout
            c = self.LoadImageSection.addColumn();
            c.add(self.LoadImageButton);
            c2 = self.LoadImageSection.addColumn();
            c2.add(self.LoadMaskButton);
        end
        
        function section = addTextureSection(self)
            self.TextureMgr = images.internal.app.segmenter.image.web.TextureManager(self.hTab,self.hApp,self.hToolstrip);
            section = self.TextureMgr.Section;
        end
        
        function section = addViewSection(self)
            
            self.ViewMgr = images.internal.app.segmenter.image.web.ViewControlsManager(self.hTab);
            section = self.ViewMgr.Section;
            
            self.OpacitySliderListener = addlistener(self.ViewMgr.OpacitySlider, 'ValueChanged', @(~,~)self.opacitySliderMoved());
            self.ShowBinaryButtonListener = addlistener(self.ViewMgr.ShowBinaryButton, 'ValueChanged', @(hobj,~)self.showBinaryPress(hobj));
        end
        
        function layoutExportSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;
            
            %Load Image Button
            self.ExportButton = matlab.ui.internal.toolstrip.SplitButton(getString(message('images:imageSegmenter:Export')), ...
                Icon('export'));
            self.ExportButton.Tag = 'btnExport';
            self.ExportButton.Description = getString(message('images:imageSegmenter:exportButtonTooltip'));

            % Drop down list
            sub_popup = matlab.ui.internal.toolstrip.PopupList();
            
            sub_item1 = matlab.ui.internal.toolstrip.ListItem(getString(message('images:imageSegmenter:exportImages')));
            sub_item1.Icon = Icon('export_image');
            sub_item1.Tag = 'ExportToWorkspace';
            sub_item1.ShowDescription = false;
            addlistener(sub_item1, 'ItemPushed', @self.exportDataToWorkspace);
            
            self.ExportFunction = matlab.ui.internal.toolstrip.ListItem(getString(message('images:imageSegmenter:exportFunction')));
            self.ExportFunction.Icon = Icon('export_function');
            self.ExportFunction.Tag = 'ExportToFunction';
            self.ExportFunction.ShowDescription = false;
            addlistener(self.ExportFunction, 'ItemPushed', @self.generateCode);
            
            sub_popup.add(sub_item1);
            sub_popup.add(self.ExportFunction);
            
            self.ExportButton.Popup = sub_popup;
            self.ExportButton.Popup.Tag = 'Export Popup';
            addlistener(self.ExportButton, 'ButtonPushed', @(~,~) self.exportDataToWorkspace());
            
            %Layout
            c = self.ExportSection.addColumn();
            c.add(self.ExportButton);

        end
        
        function layoutNewSegmentationSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;
            
            %Load Image Button
            self.NewSegmentationButton = matlab.ui.internal.toolstrip.SplitButton(getString(message('images:imageSegmenter:newSegmentation')), ...
                matlab.ui.internal.toolstrip.Icon('add'));
            self.NewSegmentationButton.Tag = 'btnNewSegmentation';
            self.NewSegmentationButton.Description = getString(message('images:imageSegmenter:newSegmentationTooltip'));

            % Drop down list
            sub_popup = matlab.ui.internal.toolstrip.PopupList();
            
            sub_item1 = matlab.ui.internal.toolstrip.ListItem(getString(message('images:imageSegmenter:newSegmentation')));
            sub_item1.Icon = matlab.ui.internal.toolstrip.Icon('add');
            sub_item1.ShowDescription = false;
            addlistener(sub_item1, 'ItemPushed', @self.newSegmentation);
            
            sub_item2 = matlab.ui.internal.toolstrip.ListItem(getString(message('images:imageSegmenter:cloneSegmentation')));
            sub_item2.Icon = matlab.ui.internal.toolstrip.Icon('copy');
            sub_item2.ShowDescription = false;
            addlistener(sub_item2, 'ItemPushed', @self.cloneSegmentation);
            
            sub_popup.add(sub_item1);
            sub_popup.add(sub_item2);
            
            self.NewSegmentationButton.Popup = sub_popup;
            self.NewSegmentationButton.Popup.Tag = 'New Segmentation Popup';
            addlistener(self.NewSegmentationButton, 'ButtonPushed', @(hobj,evt) self.newSegmentation(hobj,evt));
            
            %Layout
            c = self.NewSegmentationSection.addColumn();
            c.add(self.NewSegmentationButton);
            
        end
        
        function layoutGallery(self)
            
            popup = matlab.ui.internal.toolstrip.GalleryPopup('FavoritesEnabled',true);
            popup.add(self.CreateGallery);
            popup.add(self.AddGallery);
            popup.add(self.RefineGallery);
            
            self.TechniqueGallery = matlab.ui.internal.toolstrip.Gallery(popup,'MaxColumnCount', 10, 'MinColumnCount', 2);
            self.TechniqueGallery.Tag = 'techniqueGallery';
            c = self.MaskSection.addColumn();
            c.add(self.TechniqueGallery);
            
        end
        
        function layoutMaskSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;
            
            featureCategory = GalleryCategory(getString(message('images:imageSegmenter:createSection')));
            featureCategory.Tag = 'CreateCategory';
            
            %Threshold Button
            self.ThresholdButton = GalleryItem(getMessageString('thresholdButtonTitle'), Icon('imageThreshold'));
            self.ThresholdButton.Tag = 'btnThreshold';
            self.ThresholdButton.Description = getMessageString('thresholdTooltip');
            addlistener(self.ThresholdButton, 'ItemPushed', @(~,~) self.showThresholdTab());
            featureCategory.add(self.ThresholdButton);
            
            % Graph Cut Button
            self.GraphCutButton = GalleryItem(getMessageString('graphCutTitle'), Icon('graphCut'));
            self.GraphCutButton.Tag = 'btnGraphCut';
            self.GraphCutButton.Description = getMessageString('graphCutTooltip');
            addlistener(self.GraphCutButton, 'ItemPushed', @(~,~) self.showGraphCutTab());
            featureCategory.add(self.GraphCutButton);
            
            % k-means Clustering
            self.KmeansButton = GalleryItem(getMessageString('kmeans'), Icon('autoCluster'));
            self.KmeansButton.Tag = 'btnKmeans';
            self.KmeansButton.Description = getMessageString('kmeansTooltip');
            addlistener(self.KmeansButton, 'ItemPushed', @(~,~) self.classifyKmeans());
            featureCategory.add(self.KmeansButton);
            
            % Find Circles Button
            self.FindCirclesButton = GalleryItem(getMessageString('findCirclesTitle'), Icon('findCircles'));
            self.FindCirclesButton.Tag = 'btnFindCircles';
            self.FindCirclesButton.Description = getMessageString('findCirclesTooltip');
            addlistener(self.FindCirclesButton, 'ItemPushed', @(~,~) self.showFindCirclesTab());
            featureCategory.add(self.FindCirclesButton);

            self.CreateGallery = featureCategory;
            
        end
        
        function layoutAddMaskSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;
            
            featureCategory = GalleryCategory(getString(message('images:imageSegmenter:addSection')));
            featureCategory.Tag = 'AddFeatureCategory';

            self.SAMAddToMaskButton = GalleryItem( getMessageString("segmentAnythingTab"), ...
                                                    Icon("magicWand") );
            self.SAMAddToMaskButton.Tag = 'btnSAMAddToMask';

            depString = getMessageString("samDependencies");
            samDesc = getMessageString("samAddMaskGalleryTooltip", depString);
            self.SAMAddToMaskButton.Description = samDesc; 
            addlistener( self.SAMAddToMaskButton, 'ItemPushed', ...
                                        @(~,~)self.showSAMAddTab() );
            featureCategory.add(self.SAMAddToMaskButton);

            self.GrabCutButton = GalleryItem(getMessageString('grabcut'), Icon('localGraphCut'));
            self.GrabCutButton.Tag = 'btnGrabCut';
            self.GrabCutButton.Description = getString(message('images:imageSegmenter:grabcutTooltip'));
            featureCategory.add(self.GrabCutButton);
            addlistener(self.GrabCutButton, 'ItemPushed', @(~,~) self.showGrabCutTab());
            
            self.FloodFillButton = GalleryItem(getMessageString('floodFillButtonTitle'), Icon('fill'));
            self.FloodFillButton.Tag = 'btnFloodFill';
            self.FloodFillButton.Description = getMessageString('floodFillTooltip');
            featureCategory.add(self.FloodFillButton);
            addlistener(self.FloodFillButton, 'ItemPushed', @(~,~) self.showFloodFillTab());
            
            self.DrawButton = GalleryItem(getString(message('images:imageSegmenter:drawROIs')), Icon('drawFreehand'));
            self.DrawButton.Tag = 'btnDrawROI';
            self.DrawButton.Description = getString(message('images:imageSegmenter:drawTooltip'));
            featureCategory.add(self.DrawButton);
            addlistener(self.DrawButton, 'ItemPushed', @(~,~) self.showROITab());
            
            self.PaintButton = GalleryItem(getString(message('images:imageSegmenter:paint')),...
                matlab.ui.internal.toolstrip.Icon('brush'));
            self.PaintButton.Tag = 'btnPaintBrush';
            self.PaintButton.Description = getString(message('images:imageSegmenter:paintTooltip'));
            featureCategory.add(self.PaintButton);
            addlistener(self.PaintButton, 'ItemPushed', @(~,~) self.showPaintTab());
            
            self.AddGallery = featureCategory;

        end
        
        function layoutRefineMaskSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import matlab.ui.internal.toolstrip.*;
            
            featureCategory = GalleryCategory(getString(message('images:imageSegmenter:refineSection')));
            featureCategory.Tag = 'RefineFeatureCategory';
            
            %Morphology Button
            self.MorphologyButton = GalleryItem(getMessageString('morphologyButtonTitle'), Icon('morphology'));
            self.MorphologyButton.Tag = 'btnMorphology';
            self.MorphologyButton.Description = getMessageString('morphologyTooltip');
            addlistener(self.MorphologyButton, 'ItemPushed', @(~,~) self.showMorphologyTab());
            featureCategory.add(self.MorphologyButton);
            
            %Active Contours Button
            self.ActiveContoursButton = GalleryItem(getMessageString('activeContourButtonTitle'), Icon('activeContours'));
            self.ActiveContoursButton.Tag = 'btnActiveContours';
            self.ActiveContoursButton.Description = getMessageString('activeContoursTooltip');
            addlistener(self.ActiveContoursButton,'ItemPushed', @(~,~)self.showActiveContoursTab());
            featureCategory.add(self.ActiveContoursButton);
            
            %Clear Border Button
            self.ClearBorderButton = GalleryItem(getMessageString('clearBorder'), Icon('clearBorder'));
            self.ClearBorderButton.Tag = 'btnClearBorder';
            self.ClearBorderButton.Description = getMessageString('clearBorderTooltip');
            addlistener(self.ClearBorderButton, 'ItemPushed', @(~,~)self.clearBorder());
            featureCategory.add(self.ClearBorderButton);
            
            %Fill Holes Button
            self.FillHolesButton = GalleryItem(getMessageString('fillHoles'), Icon('fillHoles'));
            self.FillHolesButton.Tag = 'btnFillHoles';
            self.FillHolesButton.Description = getMessageString('fillHolesTooltip');
            addlistener(self.FillHolesButton, 'ItemPushed', @(~,~)self.fillHoles());
            featureCategory.add(self.FillHolesButton);
            
            %Invert Mask Button
            self.InvertMaskButton = GalleryItem(getMessageString('invertMask'), Icon('invertImageMask'));
            self.InvertMaskButton.Tag = 'btnInvertMask';
            self.InvertMaskButton.Description = getMessageString('invertMaskTooltip');
            addlistener(self.InvertMaskButton, 'ItemPushed', @(~,~)self.invertMask());
            featureCategory.add(self.InvertMaskButton);
            
            % Refine using SAM Button
            self.SAMRefineMaskButton = GalleryItem( getMessageString("segmentAnythingTab"), ...
                                                    Icon("magicWand") );
            self.SAMRefineMaskButton.Tag = 'btnSAMRefineMask';
            depString = getMessageString("samDependencies");
            samDesc = getMessageString("samRefineMaskGalleryTooltip", depString);
            self.SAMRefineMaskButton.Description = samDesc; 
            addlistener( self.SAMRefineMaskButton, 'ItemPushed', ...
                @(~,~)self.showSAMRefineTab());
            featureCategory.add(self.SAMRefineMaskButton);
            
            self.RefineGallery = featureCategory;

        end
    end
    
    %%Callbacks
    methods (Access = private)
        
        function loadImageFromFile(self, ~, ~)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            user_cancelled_import = self.showImportingDataWillCauseDataLossDlg();
            if ~user_cancelled_import
                
                filename = imgetfile();
                if ispc() || ismac()
                    bringToFront(self.hApp.App)
                end
                if ~isempty(filename)
                    try
                        %Ignore all reader warnings
                        warnstate = warning('off','all');
                        resetWarningObj = onCleanup(@()warning(warnstate));
                        
                        if isdicom(filename)
                            im = dicomread(filename);
                        else
                            im = imread(filename);
                        end
                    catch ALL
                        uialert(getScrollPanelFigure(self.hApp),ALL.message, getMessageString('unableToReadTitle'),'CloseFcn',@(~,~) uiresume(getScrollPanelFigure(self.hApp)));
                        self.loadImageFromFile();
                        return;
                    end
                    
                    isValidType = images.internal.app.segmenter.image.web.Session.isValidImageType(im);
                    
                    wasRGB = ndims(im)==3 && size(im,3)==3;
                    isValidDim = ismatrix(im);
                    
                    if ~isValidType || (~wasRGB && ~isValidDim)
                        uialert(getScrollPanelFigure(self.hApp),getMessageString('nonGrayErrorDlgMessage'), getMessageString('nonGrayErrorDlgTitle'),'CloseFcn',@(~,~) uiresume(getScrollPanelFigure(self.hApp)));
                        self.loadImageFromFile();
                        return;
                        
                    elseif isValidType && (wasRGB || isValidDim)
                        self.hApp.wasRGB = wasRGB;
                        self.hApp.Session.WasRGB = wasRGB;
                        self.importImageData(im);
                        [~,fileName,fileExt] = fileparts(filename);
                        updateImageTitleDisplay(self.hApp,[fileName,fileExt]);
                    else
                        assert(false, 'Internal error: Invalid image');
                    end
                else %No file was selected and imgetfile returned an empty string. User hit Cancel.
                end
            end

            self.hApp.App.Busy = false;
        end
        
        function loadImageFromWorkspace(self,varargin)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            isRepeatAttempt = nargin > 1 && islogical(varargin{1}) && varargin{1};
            if ~isRepeatAttempt
                user_canceled_import = self.showImportingDataWillCauseDataLossDlg();
            else
                user_canceled_import = false;
            end
            
            if ~user_canceled_import
                 
                dlg = images.internal.app.utilities.VariableDialog(imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.hApp.App)...
                    ,getString(message('images:privateUIString:importFromWorkspace')),getString(message('images:segmenter:variables')),'grayOrRGBImage');
                wait(dlg);
                if ~dlg.Canceled
                    % While loading from workspace, image has to be
                    % grayscale.
                    im = evalin('base',dlg.SelectedVariable);
                    isValidType = images.internal.app.segmenter.image.web.Session.isValidImageType(im);                   
                    isValidDim = ismatrix(im);
                    wasRGB = ndims(im)==3 && size(im,3)==3;
                    if ispc() || ismac()
                        bringToFront(self.hApp.App)
                    end
                    if ~isValidType || (~wasRGB && ~isValidDim)
                        uialert(getScrollPanelFigure(self.hApp),getMessageString('nonGrayErrorDlgMessage'), getMessageString('nonGrayErrorDlgTitle'),'CloseFcn',@(~,~) uiresume(getScrollPanelFigure(self.hApp)));
                        isRepeatAttempt = true;
                        self.loadImageFromWorkspace(isRepeatAttempt);
                        return;
                    else
                        self.hApp.wasRGB = wasRGB;
                        self.hApp.Session.WasRGB = wasRGB;
                        self.importImageData(im);
                        updateImageTitleDisplay(self.hApp,dlg.SelectedVariable);
                    end
                else%No variable was selected and imgetvar returned an empty string. User hit Cancel.
                end
                
            end
            self.hApp.App.Busy = false;
        end
        
        function loadMaskFromWorkspace(self,varargin)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import images.internal.app.segmenter.image.web.blowAwaySegmentationDialog;
            
            isRepeatAttempt = nargin > 1 && islogical(varargin{1}) && varargin{1};
            if ~isRepeatAttempt
                mask = self.hApp.getCurrentMask;
                if any(mask(:))
                    self.hApp.CanClose = false;
                    user_load_mask = blowAwaySegmentationDialog(self.hApp.ScrollPanel.hFig);
                    self.hApp.CanClose = true;
                else
                    user_load_mask = true;
                end
            else
                user_load_mask = true;
            end
            
            if user_load_mask
                 
                dlg = images.internal.app.utilities.VariableDialog(imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.hApp.App)...
                    ,getString(message('images:privateUIString:importFromWorkspace')),getString(message('images:segmenter:variables')),'logicalImage');
                wait(dlg);
                if ~dlg.Canceled
                    % While loading from workspace, image has to be
                    % 2D logical and match image height-width.
                    mask = evalin('base',dlg.SelectedVariable);
                    isValidType = islogical(mask);
                    
                    imHeightWidth = size(self.hApp.getImage(),1:2);                    
                    isValidDim = isequal(size(mask), imHeightWidth);
                    if ispc() || ismac()
                        bringToFront(self.hApp.App)
                    end
                    if ~isValidType || ~isValidDim
                        uialert(getScrollPanelFigure(self.hApp),getMessageString('invalidMaskDlgText'), getMessageString('invalidMaskDlgTitle'),'CloseFcn',@(~,~) uiresume(getScrollPanelFigure(self.hApp)));
                        isRepeatAttempt = true;
                        self.loadMaskFromWorkspace(isRepeatAttempt);
                        return;
                    else
                        self.hApp.setTemporaryHistory(mask, ...
                            'Load Mask', {'BW = MASK;'});
                        self.hApp.setCurrentMask(mask);
                        self.hApp.addToHistory(mask,'Load Mask',{'BW = MASK;'});
                    end
                else%No variable was selected and imgetvar returned an empty string. User hit Cancel.
                end
                
            end
        end
        
        function newSegmentation(self, ~, ~)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.hApp.resetAxToolbarMode();
                        
            newIndex = self.hApp.Session.newSegmentation(self.hApp);
            self.hApp.Session.ActiveSegmentationIndex = newIndex;
            self.hApp.associateSegmentationWithBrowsers(newIndex)
            
            theSegmentation = self.hApp.Session.CurrentSegmentation();
            self.hApp.updateScrollPanelCommitted(theSegmentation.getMask())
            self.hApp.updateUndoRedoButtons()
            
            self.hToolstrip.setMode(AppMode.NoMasks)
            
            self.hApp.scrollSegmentationBrowserToEnd()
        end
        
        function cloneSegmentation(self, ~, ~)
            
            self.hApp.resetAxToolbarMode();
                        
            newIndex = self.hApp.Session.cloneCurrentSegmentation();
            self.hApp.Session.ActiveSegmentationIndex = newIndex;
            self.hApp.associateSegmentationWithBrowsers(newIndex)
            
            refreshHistoryBrowser(self.hApp)
            self.hApp.scrollSegmentationBrowserToEnd()
        end

        %%Mask 
        function drawFreehand(self, ~, ~)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.hToolstrip.setMode(AppMode.Drawing)
            self.hApp.DrawingROI = true;
            
            hAx = self.hApp.getScrollPanelAxes();
            self.FreeHandContainer = iptui.internal.ImfreehandModeContainer(hAx);
            self.FreeHandContainer.enableInteractivePlacement();
            
            addlistener(self.FreeHandContainer,'hROI','PostSet',@(~,evt)self.onDrawMouseUp(evt));
        end
        
        function drawRectangle(self, ~, ~)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.hToolstrip.setMode(AppMode.Drawing)
            self.hApp.DrawingROI = true;
            
            hAx = self.hApp.getScrollPanelAxes();
            self.RectangleContainer = iptui.internal.ImrectModeContainer(hAx);
            self.RectangleContainer.enableInteractivePlacement();
            
            addlistener(self.RectangleContainer,'hROI','PostSet',@(~,evt)self.onDrawMouseUp(evt));
        end
        
        function drawEllipse(self, ~, ~)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.hToolstrip.setMode(AppMode.Drawing)
            self.hApp.DrawingROI = true;
            
            hAx = self.hApp.getScrollPanelAxes();
            self.EllipseContainer = iptui.internal.ImellipseModeContainer(hAx);
            self.EllipseContainer.enableInteractivePlacement();
            
            addlistener(self.EllipseContainer,'hROI','PostSet',@(~,evt)self.onDrawMouseUp(evt));
        end
        
        function drawPolygon(self, ~, ~)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.hToolstrip.setMode(AppMode.Drawing)
            self.hApp.DrawingROI = true;
            
            hAx = self.hApp.getScrollPanelAxes();
            self.PolygonContainer = iptui.internal.ImpolyModeContainer(hAx);
            self.PolygonContainer.enableInteractivePlacement();
            
            addlistener(self.PolygonContainer,'hROI','PostSet',@(~,evt)self.onDrawMouseUp(evt));
        end
        
        function onDrawMouseUp(self, evt)
            % Set color and opacity of ROI's to Foreground Color and
            % Opacity.
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            src = evt.AffectedObject;
            % OR with current mask
            if ~isempty(src.hROI) && isvalid(src.hROI(end))
                roi = src.hROI(end);
                newMask = self.hApp.getCurrentMask() | roi.createMask();

                commandList = createDrawingCommand(src);
                
                self.hApp.addToHistory(newMask, ...
                    images.internal.app.segmenter.image.web.getMessageString('drawingComment', src.Kind), ...
                    commandList)
                self.hToolstrip.setMode(AppMode.DrawingDone);
            else
                self.hToolstrip.setMode(AppMode.DrawingDone);
            end
            
            % Disable interactive drawing
            src.disableInteractivePlacement()
            self.hApp.DrawingROI = false;
            
            % Delete container
            if isvalid(src)
                tools = src.hROI;
                tools = tools(isvalid(tools));
                for n = 1 : numel(tools)
                    delete(tools(n));
                end
            end
        end
        
        function classifyKmeans(self)
            
            self.hAppContainer.Busy = true;
            
            if self.hApp.Session.UseTexture
                im = self.hApp.Session.getTextureFeatures();
            else
                im = single(self.hApp.getImage());
            end

            % Save current rng state and reset to default rng to make
            % kmeans reproducible run to run
            rngState = rng;
            rng('default');
            
            L = imsegkmeans(im,2,'NumAttempts',2);
            BW = L == 2;
            
            % Restore previous rng state
            rng(rngState);
            
            if self.hApp.Session.UseTexture
                cmd{1} = 's = rng;';
                cmd{2} = 'rng(''default'');';
                cmd{3} = 'L = imsegkmeans(gaborX,2,''NumAttempts'',2);';
                cmd{4} = 'rng(s);';
                cmd{5} = 'BW = L == 2;';
                self.hApp.addToHistory(BW,images.internal.app.segmenter.image.web.getMessageString('kmeansTextureComment'),cmd)
            else
                cmd{1} = 's = rng;';
                cmd{2} = 'rng(''default'');';
                cmd{3} = 'L = imsegkmeans(single(X),2,''NumAttempts'',2);';
                cmd{4} = 'rng(s);';
                cmd{5} = 'BW = L == 2;';
                self.hApp.addToHistory(BW,images.internal.app.segmenter.image.web.getMessageString('kmeansComment'),cmd)
            end
            
            self.hAppContainer.Busy = false;
            
        end
        
        function showThresholdTab(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            import images.internal.app.segmenter.image.web.blowAwaySegmentationDialog;
            
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            self.hApp.resetAxToolbarMode();
                        
            mask = self.hApp.getCurrentMask;
            if any(mask(:))
                self.hApp.CanClose = false;
                openTab = blowAwaySegmentationDialog(self.hApp.ScrollPanel.hFig);
                self.hApp.CanClose = true;
                if ~openTab
                    return;
                end
            end
            
            if self.hApp.Session.WasRGB
                uialert(self.hApp.ScrollPanel.hFig,getString(message('images:imageSegmenter:convertToGrayDlgString')),...
                    getString(message('images:imageSegmenter:convertToGrayDlgName')));
            end
            
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showThresholdTab()
            self.hToolstrip.setMode(AppMode.ThresholdImage)
            
        end
        
        function showGraphCutTab(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            import images.internal.app.segmenter.image.web.blowAwaySegmentationDialog;
            
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            self.hApp.resetAxToolbarMode();
                        
            mask = self.hApp.getCurrentMask;
            if any(mask(:))
                self.hApp.CanClose = false;
                openTab = blowAwaySegmentationDialog(self.hApp.ScrollPanel.hFig);
                self.hApp.CanClose = true;
                if ~openTab
                    return;
                end
            end
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showGraphCutTab()
            self.hToolstrip.setMode(AppMode.GraphCutOpened)
        end
        
        function showGrabCutTab(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            import images.internal.app.segmenter.image.web.blowAwaySegmentationDialog;
            
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            self.hApp.resetAxToolbarMode();
                        
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showGrabCutTab()
            self.hToolstrip.setMode(AppMode.GrabCutOpened)
            
        end
        
        function showROITab(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            import images.internal.app.segmenter.image.web.blowAwaySegmentationDialog;
            
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            self.hApp.resetAxToolbarMode();
                        
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showROITab()
            self.hToolstrip.setMode(AppMode.Drawing)
            
        end
        
        function showPaintTab(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            import images.internal.app.segmenter.image.web.blowAwaySegmentationDialog;
            
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            self.hApp.resetAxToolbarMode();
                        
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showPaintTab()
            
        end
        
        function showFindCirclesTab(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            import images.internal.app.segmenter.image.web.blowAwaySegmentationDialog;
            
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            self.hApp.resetAxToolbarMode();
                        
            mask = self.hApp.getCurrentMask;
            if any(mask(:))
                self.hApp.CanClose = false;
                openTab = blowAwaySegmentationDialog(self.hApp.ScrollPanel.hFig);
                self.hApp.CanClose = true;
                if ~openTab
                    return;
                end
            end
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showFindCirclesTab()
            self.hToolstrip.setMode(AppMode.FindCirclesOpened)
        end

        function showSAMAddTab(self)
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            import images.internal.app.segmenter.image.web.AppMode;

            self.hApp.resetAxToolbarMode();
                        
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showSAMAddTab()
            self.hToolstrip.setMode(AppMode.SAMAddTabOpened)
        end

        function showSAMRefineTab(self)
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            import images.internal.app.segmenter.image.web.AppMode;

            self.hApp.resetAxToolbarMode();
                        
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showSAMRefineTab()
            self.hToolstrip.setMode(AppMode.SAMRefineTabOpened)
        end
        
        function showFloodFillTab(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            self.hApp.resetAxToolbarMode();
                        
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showFloodFillTab()
            self.hToolstrip.setMode(AppMode.FloodFillTabOpened)
        end
        
        function showMorphologyTab(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            self.hApp.resetAxToolbarMode();
                        
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showMorphologyTab()
            self.hToolstrip.setMode(AppMode.MorphTabOpened);
        end
        
        function showActiveContoursTab(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            % If the Segmentation tab is not visible, it implies it has
            % already been replaced. Hence, perform no further action.
            if ~self.Visible
                return;
            end

            self.hApp.resetAxToolbarMode();
                        
            self.hToolstrip.hideSegmentTab()
            self.hToolstrip.showActiveContourTab()
            self.hToolstrip.setMode(AppMode.ActiveContoursTabOpened);
        end
        
        function clearBorder(self)
            
            self.hApp.resetAxToolbarMode();
                        
            newMask = imclearborder(self.hApp.getCurrentMask());
            self.hApp.addToHistory(newMask, ...
                images.internal.app.segmenter.image.web.getMessageString('clearBorderComment'), ...
                {'BW = imclearborder(BW);'})
        end
        
        function fillHoles(self)
                        
            newMask = imfill(self.hApp.getCurrentMask(),'holes');
            self.hApp.addToHistory(newMask, ...
                images.internal.app.segmenter.image.web.getMessageString('fillHolesComment'), ...
                {'BW = imfill(BW, ''holes'');'}) 
        end
        
        function invertMask(self)
            
            self.hApp.resetAxToolbarMode();
            newMask = imcomplement(self.hApp.getCurrentMask());
            self.hApp.addToHistory(newMask, ...
                images.internal.app.segmenter.image.web.getMessageString('invertMaskComment'), ...
                {'BW = imcomplement(BW);'})
        end
        
        %%View
        function showBinaryPress(self,hobj)
            
            import images.internal.app.segmenter.image.web.AppMode;
            self.hApp.resetAxToolbarMode();
            
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
        
        function opacitySliderMoved(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.hApp.resetAxToolbarMode();
            
            newOpacity = self.ViewMgr.Opacity;
            self.hApp.updateScrollPanelOpacity(newOpacity)
            
            self.hToolstrip.setMode(AppMode.OpacityChanged)
        end
        
        %%Export
        function exportDataToWorkspace(self,~,~)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.hApp.resetAxToolbarMode();
                        
            maskedImage = self.hApp.Session.getImage(); % Get original RGB image
            if self.hApp.wasRGB
                maskedImage(repmat(~self.hApp.getCurrentMask(),[1 1 3])) = 0;
            else
                maskedImage(~self.hApp.getCurrentMask()) = 0;
            end
            
            %checkBoxLabels = {getMessageString('finalSegmentation'), getMessageString('maskedImage')};
            %defaultNames   = {'BW', 'maskedImage'};
            %export2wsdlg(checkBoxLabels, defaultNames, {self.hApp.getCurrentMask(), maskedImage});

            loc = imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.hApp.App);

            self.hApp.CanClose = false;
            self.ExportDialog = images.internal.app.utilities.ExportToWorkspaceDialog(loc,...
                string(getString(message("images:imExportToWorkspace:exportToWorkspace"))), ["BW","maskedImage"], [string(getMessageString('finalSegmentation')),string(getMessageString('maskedImage'))]);

            wait(self.ExportDialog);

            if ~self.ExportDialog.Canceled
                if self.ExportDialog.VariableSelected(1)
                    assignin('base',self.ExportDialog.VariableName(1),self.hApp.getCurrentMask());
                end
                if self.ExportDialog.VariableSelected(2)
                    assignin('base',self.ExportDialog.VariableName(2),maskedImage);
                end
            end
            self.hApp.CanClose = true;
            
        end
        
        function generateCode(self,~,~)            
            self.hApp.generateCode()
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
        
        function handleTextureState(self)
            self.TextureMgr.Selected = self.hApp.Session.UseTexture;
        end
        
        function disableAllButtons(self)
            self.LoadImageButton.Enabled            = false;
            self.LoadMaskButton.Enabled             = false;
            self.NewSegmentationButton.Enabled      = false;
            self.CloneSegmentationButton.Enabled    = false;
            self.DrawButton.Enabled                 = false;
            self.PaintButton.Enabled                = false;
            self.EllipseButton.Enabled              = false;
            self.RectangleButton.Enabled            = false;
            self.PolygonButton.Enabled              = false;
            self.ThresholdButton.Enabled            = false;
            self.GraphCutButton.Enabled             = false;
            self.GrabCutButton.Enabled              = false;
            self.FloodFillButton.Enabled            = false;
            self.MorphologyButton.Enabled           = false;
            self.ActiveContoursButton.Enabled       = false;
            self.ClearBorderButton.Enabled          = false;
            self.FillHolesButton.Enabled            = false;
            self.InvertMaskButton.Enabled           = false;
            self.ViewMgr.Enabled                    = false;
            self.ExportButton.Enabled               = false;
            self.FindCirclesButton.Enabled          = false;
            self.TextureMgr.Enabled                 = false;
            self.KmeansButton.Enabled               = false;
            self.SAMAddToMaskButton.Enabled         = false;
            self.SAMRefineMaskButton.Enabled        = false;
        end
        
        function enableNoMaskButtons(self)
            self.LoadImageButton.Enabled            = true;
            self.LoadMaskButton.Enabled             = true;
            self.NewSegmentationButton.Enabled      = true;
            self.CloneSegmentationButton.Enabled    = true;
            self.DrawButton.Enabled                 = true;
            self.PaintButton.Enabled                = true;
            self.EllipseButton.Enabled              = true;
            self.RectangleButton.Enabled            = true;
            self.PolygonButton.Enabled              = true;
            self.GrabCutButton.Enabled              = true;
            self.GraphCutButton.Enabled             = true;
            self.FloodFillButton.Enabled            = true;
            self.MorphologyButton.Enabled           = false;
            self.ActiveContoursButton.Enabled       = false;
            self.ClearBorderButton.Enabled          = false;
            self.FillHolesButton.Enabled            = false;
            self.InvertMaskButton.Enabled           = false;
            self.SAMAddToMaskButton.Enabled         = true;
            self.SAMRefineMaskButton.Enabled        = false;
            self.ViewMgr.Enabled                    = false;
            self.ExportButton.Enabled               = false;
            self.FindCirclesButton.Enabled          = true;
            self.TextureMgr.Enabled                 = true;
            self.KmeansButton.Enabled               = true;
            self.handleThresholdState();
        end
        
        function enableMaskButtons(self)
            self.LoadImageButton.Enabled            = true;
            self.LoadMaskButton.Enabled             = false;
            self.NewSegmentationButton.Enabled      = true;
            self.CloneSegmentationButton.Enabled    = true;
            self.DrawButton.Enabled                 = true;
            self.PaintButton.Enabled                = true;
            self.EllipseButton.Enabled              = true;
            self.RectangleButton.Enabled            = true;
            self.PolygonButton.Enabled              = true;
            self.GrabCutButton.Enabled              = true;
            self.GraphCutButton.Enabled             = false;
            self.FloodFillButton.Enabled            = true;
            self.MorphologyButton.Enabled           = true;
            self.ActiveContoursButton.Enabled       = true;
            self.ClearBorderButton.Enabled          = true;
            self.FillHolesButton.Enabled            = true;
            self.InvertMaskButton.Enabled           = true;
            self.ViewMgr.Enabled                    = true;
            self.ExportButton.Enabled               = true;
            self.FindCirclesButton.Enabled          = false;
            self.TextureMgr.Enabled                 = true;
            self.KmeansButton.Enabled               = false;
            self.ThresholdButton.Enabled            = false;
            self.SAMAddToMaskButton.Enabled         = true;

            rprops = regionprops(getScrollPanelCommitted(self.hApp), "BoundingBox");
            self.SAMRefineMaskButton.Enabled        = isscalar(rprops);
        end
        
        function enableAllButtons(self)
            self.LoadImageButton.Enabled            = true;
            self.LoadMaskButton.Enabled             = true;
            self.NewSegmentationButton.Enabled      = true;
            self.CloneSegmentationButton.Enabled    = true;
            self.DrawButton.Enabled                 = true;
            self.PaintButton.Enabled                = true;
            self.EllipseButton.Enabled              = true;
            self.RectangleButton.Enabled            = true;
            self.PolygonButton.Enabled              = true;
            self.GrabCutButton.Enabled              = true;
            self.GraphCutButton.Enabled             = true;
            self.FloodFillButton.Enabled            = true;
            self.MorphologyButton.Enabled           = true;
            self.ActiveContoursButton.Enabled       = true;
            self.ClearBorderButton.Enabled          = true;
            self.FillHolesButton.Enabled            = true;
            self.InvertMaskButton.Enabled           = true;
            self.ViewMgr.Enabled                    = true;
            self.ExportButton.Enabled               = true;
            self.FindCirclesButton.Enabled          = true;
            self.TextureMgr.Enabled                 = true;
            self.KmeansButton.Enabled               = true;
            self.SAMAddToMaskButton.Enabled         = true;
            self.SAMRefineMaskButton.Enabled        = true;
            self.handleThresholdState();
        end
        
        function handleThresholdState(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.ThresholdButton.Enabled        = true;
            self.ThresholdButton.Description    = getMessageString('thresholdMethodTooltip');
            
        end
        
        function user_canceled = showImportingDataWillCauseDataLossDlg(self)
            
            user_canceled = false;
            
            if ~isempty(self.hApp.wasRGB)
                
                self.hApp.CanClose = false;
                answer = uiconfirm(self.hApp.ScrollPanel.hFig,images.internal.app.segmenter.image.web.getMessageString('loadingNewImageMessage'),...
                    images.internal.app.segmenter.image.web.getMessageString('loadingNewImageTitle'),...
                    'Options',{getString(message('images:commonUIString:yes')),...
                    getString(message('images:commonUIString:cancel'))},...
                    'DefaultOption',1,'CancelOption',2);
                self.hApp.CanClose = true;
                
                if strcmp(answer,getString(message('images:commonUIString:yes')))
                    % TODO: Clean up existing image/figure handles.
                else
                    user_canceled = true;
                end

            end
        end
        
        function TF = checkIfMaskIsEmpty(self)
            mask = self.hApp.getCurrentMask();
            TF = ~any(mask(:));
        end
        
        function im = adjustGrayscaleDataDlg(self,im)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.IsDataAdjusted = false;
            self.hApp.CanClose = false;
            
            buttonname = uiconfirm(self.hApp.ScrollPanel.hFig,getMessageString('adjustDataDlgMessage'),...
                    getMessageString('adjustDataDlgTitle'),...
                    'Options',{getString(message('images:commonUIString:yes')),...
                    getString(message('images:commonUIString:no'))},...
                    'DefaultOption',1);
            
            self.hApp.CanClose = true;
            
            if strcmp(buttonname,getString(message('images:commonUIString:yes')))
                
                im = imadjust(im);
                self.IsDataAdjusted = true;
                
            end
                
        end
        
        function [self,im] = normalizeFloatDataDlg(self,im)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.IsDataNormalized = false;
            self.IsInfNanRemoved  = false;
            
            % Check if image has NaN,Inf or -Inf valued pixels.
            finiteIdx       = isfinite(im(:));
            hasNansInfs     = ~all(finiteIdx);
            
            % Check if image pixels are outside [0,1].
            isOutsideRange  = any(im(finiteIdx)>1) || any(im(finiteIdx)<0);
            
            % Offer the user the option to normalize and clean-up data if
            % either of these conditions is true.
            if isOutsideRange || hasNansInfs
                
                self.hApp.CanClose = false;
                buttonname = uiconfirm(self.hApp.ScrollPanel.hFig,getMessageString('normalizeDataDlgMessage'),...
                    getMessageString('normalizeDataDlgTitle'),...
                    'Options',{getMessageString('normalizeData'),...
                    getString(message('images:commonUIString:cancel'))},...
                    'DefaultOption',1,'CancelOption',2);
                self.hApp.CanClose = true;
                
                if strcmp(buttonname,getMessageString('normalizeData'))
                    
                    % First clean-up data by removing NaN's and Inf's.
                    if hasNansInfs
                        % Replace nan pixels with 0.
                        im(isnan(im)) = 0;
                        
                        % Replace inf pixels with 1.
                        im(im == Inf) = 1;
                        
                        % Replace -inf pixels with 0.
                        im(im == -Inf) = 0;
                        
                        self.IsInfNanRemoved = true;
                    end
                    
                    % Normalize data in [0,1] if outside range.
                    if isOutsideRange
                        imMax = max(im(:));
                        imMin = min(im(:));                       
                        if isequal(imMax,imMin)
                            % If imMin equals imMax, the scaling will return
                            % an image of all NaNs. Replace with zeros;
                            im = 0*im;
                        else
                            if hasNansInfs
                                % Only normalize the pixels that were finite.
                                im(finiteIdx) = (im(finiteIdx) - imMin) ./ (imMax - imMin);
                            else
                                im = (im-imMin) ./ (imMax - imMin);
                            end
                        end
                        self.IsDataNormalized = true;
                    end
                    
                else
                    im = [];
                end
                
            end
        end
        
        function updateToolTipsForMaskControls(self,maskIsPresent)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            if ~maskIsPresent
                % Refine Section
                msgstr = getMessageString('noMaskTooltip');
                self.MorphologyButton.Description = msgstr;
                self.ActiveContoursButton.Description = msgstr;
                self.ClearBorderButton.Description = msgstr;
                self.FillHolesButton.Description = msgstr;
                self.InvertMaskButton.Description = msgstr;
                self.SAMRefineMaskButton.Description = msgstr;
                
                % Create Section
                self.ThresholdButton.Description = getMessageString('thresholdTooltip');
                self.GraphCutButton.Description = getMessageString('graphCutTooltip');
                self.FindCirclesButton.Description = getMessageString('findCirclesTooltip');
                self.KmeansButton.Description = getMessageString('kmeansTooltip');
            else
                % Create Section
                msgstr = getMessageString('yesMaskTooltip');
                self.ThresholdButton.Description = msgstr;
                self.GraphCutButton.Description = msgstr;
                self.FindCirclesButton.Description = msgstr;
                self.KmeansButton.Description = msgstr;
                
                % Refine Section
                self.MorphologyButton.Description = getMessageString('morphologyTooltip');
                self.ActiveContoursButton.Description = getMessageString('activeContoursTooltip');
                self.ClearBorderButton.Description = getMessageString('clearBorderTooltip');
                self.FillHolesButton.Description = getMessageString('fillHolesTooltip');
                self.InvertMaskButton.Description = getMessageString('invertMaskTooltip');

                rprops = regionprops(getScrollPanelCommitted(self.hApp));
                if ~isempty(rprops) && isscalar(rprops)
                    depString = getMessageString("samDependencies");
                    samDesc = getMessageString("samRefineMaskGalleryTooltip", depString);
                else
                    samDesc = getMessageString("samRefineOnlyOneMaskTooltip");
                end
                self.SAMRefineMaskButton.Description = samDesc;
                self.SAMRefineMaskButton.Enabled = isscalar(rprops);
            end
            
        end
        
    end
    
end

function commandList = createDrawingCommand(modeContainer)

[X, Y] = modeContainer.getPolygonPoints();
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
