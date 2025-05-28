classdef ColorSegmentationTool < handle
    %
    
    %   Copyright 2013-2023 The MathWorks, Inc.
    
    properties (Hidden = true, SetAccess = private)
        
        % Handle to figures docked in toolstrip
        FigureHandles
        
        % Handle to DocumentGroup for Tabs
        hDocumentGroup
        
        % Handle to current figure docked in toolstrip
        hFigCurrent
        
        % binary image that current defines mask
        mask
        sliderMask
        clusterMask
        
        % Cached colorspace representations of image data
        imRGB
        
        % Image object holding the image axes
        ImageObj

        % Axes for the image object
        hAxes
        
        %Handle to mask opacity slider
        hMaskOpacitySlider
        
        % Image preview handle.
        ImagePreviewDisplay
        
        % Polygon ROIs
        hPolyROIs
        
        % Invert Mask Button
        hInvertMaskButton
        hHidePointCloud
        
        % Cache knowledge of whether we normalized double input data so
        % that we can have thresholds in "generate function" context match
        % image data. Do the same for massaging of image data to handle
        % Nans and Infs appropriately.
        normalizedDoubleData

        massageNansInfs
        
        StatusBar

        LightWeightMode
    end
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        
        % Tabs
        hTabGroup
        ThresholdTab
        ImageCaptureTab
        
        % Image Panel that contains image
        hImagePanel
        
        % Sections
        LoadImageSection
        ThresholdControlsSection
        ChooseProjectionSection
        ColorSpacesSection
        ManualSelectionSection
        ViewSegmentationSection
        ExportSection
        
        % Handles to buttons in toolstrip
        hColorSpacesButton
        hShowBinaryButton
        hOverlayColorButton
        hPointCloudBackgroundSlider
        isLiveUpdate
        
        % Handles to freehand * polygon axes toolbar button
        hFreehandButton
        hPolygonButton
        hProjPolygonButton 
        hProjRotateButton

        % Handles to buttons in toolstrip that are enabled/disabled based
        % on whether data has been loaded into app.
        hChangeUIComponentHandles
        lassoSensitiveComponentHandles
        
        % Cached knowledge of current opacity so that
        % we can flip back and forth from "Show Binary" toggle mode
        currentOpacity
        
        % We cache the listener for whether or not a colorspace has been
        % selected in images.internal.app.colorThresholderWeb.ColorSpaceMontageView so that we don't
        % continue listening for a color space selection if the
        % colorSegmentor app is destroyed.
        colorspaceSelectedListener
        
        % We cache listeners to state changed on buttons so that we can
        % disable/enable button listeners when a new image is loaded and we
        % restore the button states to an initialized state.
        binaryButonStateChangedListener
        invertMaskItemStateChangedListener
        sliderMovedListener
        pointCloudSliderMovedListener
        
        %Handle to current open images.internal.app.colorThresholderWeb.ColorSpaceMontageView
        %instance
        hColorSpaceMontageView
        hColorSpaceProjectionView
        
        % Handles of selected regions
        hFreehandROIs
        freehandManager
        polyManager
        
        % Listeners for selected regions
        hFreehandListener
        hPolyMovedListener
        hSliderMovedListener
        hPolyListener
        hFreehandMovedListener
        
        preLassoToolstripState
        
        % Size of image
        imSize
        
        % Logical used when deleting polygons
        isProjectionApplied
        
        % Background color of point cloud
        pointCloudColor
        maskColor
        
        % Logical to handle different states of app
        isFreehandApplied
        isManualDelete
        is3DView
        isFigClicked
        
        % Cached icons
        LoadImageIcon
        newColorspaceIcon
        hidePointCloudIcon
        liveUpdateIcon
        invertMaskIcon
        resetButtonIcon
        showBinaryIcon
        createMaskIcon
        freeIcon
        polyIcon
        rotateIcon
        rotatePointer

        ExportDialog
        
    end
    
    properties (Hidden=true, SetAccess=private)
        UseAppContainer
        App
    end
    
    
    methods
        
        function self = ColorSegmentationTool(varargin)
            
            self.UseAppContainer = true;
            
            uuid = matlab.lang.internal.uuid;
            appOptions.Tag = "colorThreshApp" + uuid;
            appOptions.Title = getString(message('images:colorSegmentor:appName'));
            appOptions.Product = "Image Processing Toolbox";
            appOptions.Scope = "Color Thresholder";
            appOptions.EnableTheming = true;
            self.App = matlab.ui.container.internal.AppContainer(appOptions);
            self.hTabGroup = matlab.ui.internal.toolstrip.TabGroup();
            self.hTabGroup.Tag = 'tabGroup';
            
            % Create Tabs
            self.ThresholdTab = self.hTabGroup.addTab(getString(message('images:colorSegmentor:thresholdTab')));
            self.ThresholdTab.Tag = getString(message('images:colorSegmentor:ThresholdTabName'));
            self.hTabGroup.SelectedTab = self.ThresholdTab;
            
            % Disable interactive tiling in app. We want to enforce layout
            % so that multiple color space segmentation documents cannot be
            % viewed at one time. An assumption of the design is that only
            % one colorspace panel is visible at a time.
            self.App.UserDocumentTilingEnabled = 0;
            
            % Add Sections to Threshold Tab
            self.LoadImageSection               = self.ThresholdTab.addSection(getString(message('images:colorSegmentor:loadImage')));
            self.LoadImageSection.Tag           = 'LoadImage';
            self.ColorSpacesSection             = self.ThresholdTab.addSection(getString(message('images:colorSegmentor:colorSpaces')));
            self.ColorSpacesSection.Tag         = 'ColorSection';
            self.ThresholdControlsSection       = self.ThresholdTab.addSection(getString(message('images:colorSegmentor:thresholdControls')));
            self.ThresholdControlsSection.Tag   = 'ThresholdControlsSection';
            self.ViewSegmentationSection        = self.ThresholdTab.addSection(getString(message('images:colorSegmentor:viewSegmentation')));
            self.ViewSegmentationSection.Tag    = 'ViewSegmentationSection';
            self.ManualSelectionSection         = self.ThresholdTab.addSection(getString(message('images:colorSegmentor:colorSelection')));
            self.ManualSelectionSection.Tag     = 'ManualSelectionSection';
            self.ChooseProjectionSection        = self.ThresholdTab.addSection(getString(message('images:colorSegmentor:pointCloud')));
            self.ChooseProjectionSection.Tag    = 'ChooseProjection';
            self.ExportSection                  = self.ThresholdTab.addSection(getString(message('images:colorSegmentor:export')));
            self.ExportSection.Tag              = 'Export';
            
            % Layout Panels/Buttons within each section
            self.loadAppIcons();
            self.layoutLoadImageSection();
            self.layoutColorSpacesSection();
            self.layoutManualSelectionSection();
            self.layoutThresholdControlsSection();
            self.layoutViewSegmentationSection();
            self.layoutExportSection();
            self.layoutChooseProjectionSection();
            
            % Add the tab group to  the App
            self.App.add(self.hTabGroup);

            % Initialize Background color with default
            self.pointCloudColor = 1 - repmat(self.hPointCloudBackgroundSlider.Value,1,3)/100;
            self.maskColor = [0 0 0];
            
            % Disable ui controls in app until data is loaded
            self.setControlsEnabled(false);
            self.hPointCloudBackgroundSlider.Enabled = false;
            
            % Setup status bar
            % Status Bar
            self.StatusBar = images.internal.app.utilities.StatusBar;
            self.App.add(self.StatusBar.Bar);
            
            % Initial layout of view
            [x,y,width,height] = imageslib.internal.apputil.ScreenUtilities.getInitialToolPosition();
            self.App.set('WindowBounds', [x,y,width,height]);
            
            imageslib.internal.apputil.manageToolInstances('add', 'colorThresholderWeb', self.App);
            
            self.isProjectionApplied = false;
            self.isFreehandApplied = false;
            self.isManualDelete = true;
            
            self.App.Visible = true;

            self.App.CanCloseFcn = @(~,~) doClosingSession(self);
            
            % If image data was specified, load it into the app
            self.LightWeightMode = false;
            if nargin > 0
                im = varargin{1};
                self.importImageData(im);
                if(nargin == 2)
                    self.LightWeightMode = varargin{2};
                end
            else
                self.hColorSpacesButton.Enabled = false;
            end
            
        end
        
    end
    
    methods (Hidden=true)
        
        function initializeAppWithRGBImage(self,im)
            % Initialize the class and the app with a RGB image.
            % This is used both by the app internally and is used in testing,
            % so it needs to be public
            
            % Cache knowledge of RGB representation of image.
            self.imRGB = im;
            
            % Initialize mask
            self.mask = true(size(im,1),size(im,2));
            
            % Enable colorspaces button
            self.hColorSpacesButton.Enabled = true;
            
        end
    end
    
    methods (Hidden=true)
        % Testing hooks
        function [h3DPoly, h2DPoly, h2DRotate] = getPointCloudButtonHandles(self)
            % getPointCloudButtonHandles - Get handles to buttons for
            % current figure window. Requires that a colorspace tab be the
            % current figure and not the "Choose a Color Space" tab
            h3DPoly = self.hProjPolygonButton;
            h2DPoly = self.hFreehandButton; 
            h2DRotate = self.hProjRotateButton;

        end

        function hButton = getMontageViewButtonHandle(self,csname)
            % getMontageViewButtonHandles - Get handles for buttons for the
            % four color spaces from the "Choose a Color Space" tab
            if self.hasCurrentValidMontageInstance()
                hButton = self.hColorSpaceMontageView.getButtonHandle(csname);
            else
                hButton = [];
            end
        end
    end
    
    % Assorted utility methods used by app
    methods (Access = private)
        
        function [self,im] = normalizeDoubleDataDlg(self,im)
            
            self.normalizedDoubleData = false;
            self.massageNansInfs      = false;
            
            % Check if image has NaN,Inf or -Inf valued pixels.
            finiteIdx       = isfinite(im(:));
            hasNansInfs     = ~all(finiteIdx);
            
            % Check if image pixels are outside [0,1].
            isOutsideRange  = any(im(finiteIdx)>1) || any(im(finiteIdx)<0);
            
            % Offer the user the option to normalize and clean-up data if
            % either of these conditions is true.
            if isOutsideRange || hasNansInfs
                
                msg = getString(message('images:colorSegmentor:normalizeDataDlgMessage'));
                title = getString(message('images:colorSegmentor:normalizeDataDlgTitle'));
                
                buttonname = uiconfirm(self.App, msg, title,...
                                       'Options',{getString(message('images:colorSegmentor:normalizeData')),...
                                       getString(message('images:commonUIString:cancel'))},...
                                       'DefaultOption', 1, 'CancelOption', 2);
                                   
                
                if strcmp(buttonname,getString(message('images:colorSegmentor:normalizeData')))
                    
                    % First clean-up data by removing NaN's and Inf's.
                    if hasNansInfs
                        % Replace nan pixels with 0.
                        im(isnan(im)) = 0;
                        
                        % Replace inf pixels with 1.
                        im(im== Inf)   = 1;
                        
                        % Replace -inf pixels with 0.
                        im(im==-Inf)   = 0;
                        
                        self.massageNansInfs = true;
                    end
                    
                    % Normalize data in [0,1] if outside range.
                    if isOutsideRange
                        im = mat2gray(im);
                        self.normalizedDoubleData = true;
                    end
                    
                else
                    im = [];
                end
                
            end
        end
        
        function cdata = computeColorspaceRepresentation(self,csname)
            
            switch (csname)
                
                case 'RGB'
                    cdata = self.imRGB;
                case 'HSV'
                    cdata = rgb2hsv(self.imRGB);
                case 'YCbCr'
                    cdata = rgb2ycbcr(self.imRGB);
                case 'L*a*b*'
                    cdata = rgb2lab(self.imRGB);
                otherwise
                    assert(false, 'Unknown colorspace name specified.');
            end
            
        end
        
        function TF = doClosingSession(self)
                
            if ~isvalid(self)
                TF = true;
                return;
            end

            imageslib.internal.apputil.manageToolInstances('remove', 'colorThresholderWeb', self.App);
            TF = true;
        end

        function TF = blockDocumentFromClosing(~)
            TF = false;
        end
        
        function TF = figureDocumentClose(self)
            
            appDeleted = ~isvalid(self) || ~isvalid(self.App);
            if ~appDeleted
                self.manageROIButtonStates()
                if (~self.validColorspaceFiguresInApp() ||...
                                            numel(self.App.getDocuments())==1)
                    self.setControlsEnabled(false);
                    if self.isTabShowing(getString(message('images:colorSegmentor:chooseColorspace')))
                        self.hPointCloudBackgroundSlider.Enabled = false;
                        self.hColorSpacesButton.Enabled = false;
                    else
                        self.hColorSpacesButton.Enabled = true;
                        self.hPointCloudBackgroundSlider.Enabled = false;
                    end
                end
            end
            TF = true;
        
        end
        
        function figureDocumentActivated(self, src, data)
            
            if(~strcmp(data.PropertyName, 'Selected'))
                return;
            end
            
            if(src.Selected~=1)
                return;
            end
            
            hFig = src.Figure;
            self.manageROIButtonStates()
                % Re-parent imagepanel to the activated figure.
                
                clientTitle = src.Title;
                existingTabs = cellfun(@(x)char(x.Title), self.App.getDocuments, 'UniformOutput', false);
                
                % Handle toolstrip state
                if strcmp(clientTitle,getString(message('images:colorSegmentor:chooseColorspace')))
                    self.hColorSpacesButton.Enabled = false;
                    self.setControlsEnabled(false);
                    self.hPointCloudBackgroundSlider.Enabled = true;
                elseif self.validColorspaceFiguresInApp()
                    self.setControlsEnabled(true);
                    if(self.LightWeightMode)
                        self.disablePointCloudControls();
                    end
                    self.hColorSpacesButton.Enabled = true;
                    if self.hHidePointCloud.Value
                        self.hPointCloudBackgroundSlider.Enabled = false;
                    else
                        self.hPointCloudBackgroundSlider.Enabled = true;
                    end
                end
                
                if self.validColorspaceFiguresInApp()
                    % This conditional is necessary because an event fires
                    % when the last figure in the desktop is closed and
                    % hFig is no longer valid.
                    
                    hLeftPanel = findobj(hFig,'tag','LeftPanel');
                    
                    if ~isempty(hLeftPanel)
                        layoutScrollpanel(self,hLeftPanel);
                        
                        % Need to know current colorspace representation of image
                        % here. Use appdata for now. This is making an extra copy
                        % of the CData that we will want to avoid.
                        hRightPanel = findobj(hFig,'tag','RightPanel');
                        histHandles = getappdata(hRightPanel,'HistPanelHandles');
                        hProjectionView = getappdata(hRightPanel,'ProjectionView');
                        self.hColorSpaceProjectionView = hProjectionView;
                        
                        % Update mask
                        self.hFigCurrent = hFig;
                        cData = getappdata(hRightPanel,'ColorspaceCData');
                        self.updateMask(cData,histHandles{:});
                        hPanel3D = findobj(hRightPanel,'tag','proj3dpanel');
                        
                        % Update logical indicating view state
                        if strcmp(get(hPanel3D,'Visible'),'on')
                            self.is3DView = true;
                        else
                            self.is3DView = false;
                        end
                        
                        % If point cloud visible, apply polygons to mask
                        if ~self.hHidePointCloud.Value
                            self.applyClusterROIs();
                        end
                        self.hideOtherROIs() ;
                    end
                end
        
        end
        
        function manageROIButtonStates(self)
            
            if ~isvalid(self) || ~isvalid(self.App)
                return
            end
            
            % First check if freehand or polygon tools were selected
            if ~isempty(self.freehandManager)
                self.resetLassoTool()
                self.freehandManager = [];
                self.hFreehandButton.Value = 0;
            end
            
            if ~isempty(self.polyManager)
                self.disablePolyRegion()
                self.polyManager = [];
                % Reset polygon button
                validHandles = self.FigureHandles(ishandle(self.FigureHandles));
                arrayfun(@(h) set(findobj(h,'Tag','PolyButton'),'Value',0),validHandles);
            end
            
        end
        
        
        function updateMask(self,cData,hChan1Hist,hChan2Hist,hChan3Hist)
            % updateMask - Updates the mask for the histogram sliders and
            % then combines with the mask from any polygons drawn on point
            % cloud
            
            channel1Lim = hChan1Hist.currentSelection;
            channel2Lim = hChan2Hist.currentSelection;
            channel3Lim = hChan3Hist.currentSelection;
            
            firstPlane  = cData(:,:,1);
            secondPlane = cData(:,:,2);
            thirdPlane  = cData(:,:,3);
            
            % The hue channel can have a min greater than max, so that
            % needs special handling. We could special case the H channel,
            % or we can build a mask treating every channel like H.
            if isa(hChan1Hist,'images.internal.app.colorThresholderWeb.InteractiveHistogramHue') && (channel1Lim(1) >= channel1Lim(2) )
                BW = bsxfun(@ge,firstPlane,channel1Lim(1)) | bsxfun(@le,firstPlane,channel1Lim(2));
            else
                BW = bsxfun(@ge,firstPlane,channel1Lim(1)) & bsxfun(@le,firstPlane,channel1Lim(2));
            end
            
            BW = BW & bsxfun(@ge,secondPlane,channel2Lim(1)) & bsxfun(@le,secondPlane,channel2Lim(2));
            BW = BW & bsxfun(@ge,thirdPlane,channel3Lim(1)) & bsxfun(@le,thirdPlane,channel3Lim(2));
            
            self.sliderMask = BW;
            
            % Combine with Cluster mask
            self.updateMasterMask();
            
        end
        
        function updateClusterMask(self,varargin)
            % updateClusterMask - Updates the mask from any polygons drawn
            % on point cloud and then combines with the mask from the
            % histogram sliders
            
            switch nargin
                case 1
                    % If no mask is input reset mask
                    self.clusterMask = true([size(self.imRGB,1) size(self.imRGB,2)]);
                case 2
                    self.clusterMask = varargin{1};
            end
            
            % Combine with Slider mask
            self.updateMasterMask();
            
        end
        
        function updateMasterMask(self)
            % updateMasterMask - Combines mask from polygons on point cloud
            % with mask from histogram sliders
            
            BW = self.sliderMask & self.clusterMask;
            
            if self.hInvertMaskButton.Value
                self.mask = ~BW;
            else
                self.mask = BW;
            end
            
            % Now update graphics in imagepanel.
            self.updateMaskOverlayGraphics();
            
        end
        
        function updatePointCloud(self,varargin)
            % updatePointCloud - Updates the 2D point cloud when sliders
            % are moved. Set TF = true when a new projection is created and
            % you need to reset the axes limits
            if self.LightWeightMode
                return;
            end
            % Find handles to objects
            hPanel = findobj(self.hFigCurrent, 'tag', 'RightPanel');
            hScat = findobj(hPanel,'Tag','ScatterPlot');
            
            % Set axes limit modes
            hScat.Parent.XLimMode = 'Manual';
            hScat.Parent.YLimMode = 'Manual';
            
            % Get data for point cloud
            BW = self.sliderMask(:);
            im = getappdata(hPanel,'TransformedCDataForCluster');
            xData = im(:,1);
            yData = im(:,2);
            
            % Reset axes limits for new projection
            if nargin > 1
                hScat.Parent.XLim = varargin{1};
                hScat.Parent.YLim = varargin{2};
            end
            
            % Remove points that are false in the slider mask
            xData = xData(BW);
            yData = yData(BW);
            
            % Remove points from the color data that are false in the
            % slider mask
            cData1 = self.imRGB(:,:,1);
            cData2 = self.imRGB(:,:,2);
            cData3 = self.imRGB(:,:,3);
            cData1 = cData1(self.sliderMask);
            cData2 = cData2(self.sliderMask);
            cData3 = cData3(self.sliderMask);
            cData = [cData1 cData2 cData3];
            
            set(hScat,'XData',xData,'YData',yData,'CData',cData);
            
        end
        
        function hidePointCloud(self)
            
            if self.hHidePointCloud.Value
                self.hPointCloudBackgroundSlider.Enabled = false;
                % Get handles to all valid figures
                validHandles = self.FigureHandles(ishandle(self.FigureHandles));
                % Update histogram panels for each figure based on the
                % color space
                for ii = 1:numel(validHandles)
                    hRightPanel = findobj(validHandles(ii), 'tag', 'RightPanel');
                    if ~isempty(hRightPanel) % Camera document has no RightPanel
                        if strcmp(hRightPanel.Parent.Tag,'HSV')
                            handleH = findobj(hRightPanel,'tag','H');
                            handleS = findobj(hRightPanel,'tag','S');
                            handleV = findobj(hRightPanel,'tag','V');
                            layoutPosition = getappdata(hRightPanel,'layoutPosition');
                            % H Panel
                            set(handleH,'Position',layoutPosition{4});
                            % S Panel
                            set(handleS,'Position',layoutPosition{5});
                            % V Panel
                            set(handleV,'Position',layoutPosition{6});
                        else
                            histHandles = findobj(hRightPanel,'tag','SlidersContainer');
                            arrayfun(@(h) set(h,'Position',[0 0 1 1]),histHandles);
                        end
                        % Hide point cloud panels
                        projHandles = findobj(hRightPanel,'tag','ColorProj','-or','tag','proj3dpanel');
                        arrayfun(@(h) set(h,'Visible','off'),projHandles);
                    end
                end
                self.updateClusterMask()
            else
                self.hPointCloudBackgroundSlider.Enabled = true;
                % Get handles to all valid figures
                validHandles = self.FigureHandles(ishandle(self.FigureHandles));
                % Update histogram panels for each figure based on the
                % color space
                for ii = 1:numel(validHandles)
                    hRightPanel = findobj(validHandles(ii), 'tag', 'RightPanel');
                    if ~isempty(hRightPanel) % Camera document has no RightPanel
                        if strcmp(hRightPanel.Parent.Tag,'HSV')
                            handleH = findobj(hRightPanel,'tag','H');
                            handleS = findobj(hRightPanel,'tag','S');
                            handleV = findobj(hRightPanel,'tag','V');
                            layoutPosition = getappdata(hRightPanel,'layoutPosition');
                            % H Panel
                            set(handleH,'Position',layoutPosition{1});
                            % S Panel
                            set(handleS,'Position',layoutPosition{2});
                            % V Panel
                            set(handleV,'Position',layoutPosition{3});
                        else
                            histHandles = findobj(hRightPanel,'tag','SlidersContainer');
                            arrayfun(@(h) set(h,'Position',[0 0.6 1 0.4]),histHandles);
                        end
                        % Show point cloud panels
                        if images.internal.app.colorThresholderWeb.hasValidROIs(validHandles(ii), self.hPolyROIs)
                            projHandles = findobj(hRightPanel,'tag','ColorProj');
                        else
                            projHandles = findobj(hRightPanel,'tag','proj3dpanel');
                        end
                        set(projHandles,'Visible','on');
                    end
                end
                
                if images.internal.app.colorThresholderWeb.hasValidROIs(self.hFigCurrent, self.hPolyROIs)
                    self.is3DView = false;
                else
                    self.is3DView = true;
                end
                
                self.updatePointCloud();
                self.applyClusterROIs();
            end
            
            
        end
        
        
        function updateMaskOverlayGraphics(self)
            
            if self.hShowBinaryButton.Value
                
                draw(self.ImageObj, self.mask, [], [], []);
            else

                self.ImageObj.Alpha = self.hMaskOpacitySlider.Value/100;
                
                L = double(~self.mask);
                cmap = zeros(256,3,'single');
                % Set the second row corresponding to label ID = 1 to
                % maskColor
                cmap(2,:) = self.maskColor;
                draw(self.ImageObj, self.imRGB, L, cmap, []);
            end
            
        end
        
        function manageControlsOnNewColorspace(self)
            % This method puts the Show Binary, Invert mask, and Opacity
            % Slider back to their default state whenever a new image is
            % loaded or a new colorspace document is created.
            self.hShowBinaryButton.Value = false;
            self.hInvertMaskButton.Value = false;
            self.hMaskOpacitySlider.Value  = 100;
            
        end
        
        
        function manageControlsOnImageLoad(self)
            % We can reuse logic from manageControlsOnNewColorspace, but we also have to disable
            % and re-enable listeners that are coupled to existence of
            % imagepanel, because imagepanel is blown away and recreated
            % when you load a new image.
            
            % Disable listeners
            self.binaryButonStateChangedListener.Enabled = false;
            self.invertMaskItemStateChangedListener.Enabled = false;
            self.sliderMovedListener.Enabled = false;
            
            self.manageControlsOnNewColorspace();
            
            % This drawnow is necessary to allow state of buttons to settle before
            % re-enabling the listeners.
            drawnow;
            
            % Enable listeners
            self.binaryButonStateChangedListener.Enabled = true;
            self.invertMaskItemStateChangedListener.Enabled = true;
            self.sliderMovedListener.Enabled = true;
            
        end
        
        
        function setControlsEnabled(self,TF)
            % This button manages the enabled/disabled state of UIControls
            % in the toolstrip based on whether or not an image has been
            % loaded into the app.
            for i = 1:length( self.hChangeUIComponentHandles )
                self.hChangeUIComponentHandles{i}.Enabled = TF;
            end
            
        end

        function disablePointCloudControls(self)
                self.hHidePointCloud.Enabled = false;
                self.hHidePointCloud.Value = true;
                self.hPointCloudBackgroundSlider.Enabled = false;
                self.isLiveUpdate.Enabled = false;
                self.isLiveUpdate.Value = false;
        end
        
        
    end
    
    % The following methods gets called from all import methods
    methods (Access = public)
        
        function importImageData(self,im)
            
            if isfloat(im)
                [self,im] = normalizeDoubleDataDlg(self,im);
                if isempty(im)
                    return;
                end
            end
             
            self.initializeAppWithRGBImage(im);
            
            [m,n,~] = size(im);
            self.imSize = m*n;
            
            % Set Live Updates on if image is small
            if self.imSize > 1e6
                self.isLiveUpdate.Value = false;
            else
                self.isLiveUpdate.Value = true;
            end
            
            % Bring up colorspace montage view
            self.compareColorSpaces();
            
        end
        
        function TF = hasCurrentValidMontageInstance(self)
            TF = isa(self.hColorSpaceMontageView,'images.internal.app.colorThresholderWeb.ColorSpaceMontageViewWeb') &&...
                isvalid(self.hColorSpaceMontageView) && isvalid(self.hColorSpaceMontageView.hFig);
        end
        
        function TF = validColorspaceFiguresInApp(self)
            
            TF = self.isTabShowing('RGB') ||...
                self.isTabShowing('HSV') ||...
                self.isTabShowing('YCbCr') ||...
                self.isTabShowing('L*a*b*');
            
        end
        
        function TF = isTabShowing(self, tabName)
            
            currentDocuments = self.App.getDocuments();
            names = cellfun(@(h) get(h,'Title'),currentDocuments);
            
            idx = strncmpi(tabName,names, 3);
            
            if(any(idx))
               TF = any(cellfun(@(figDoc)figDoc.Visible, currentDocuments(idx))); 
            else
                TF = false;
            end
        end
        
        function tabGroup = getTabGroup(self)
            tabGroup = self.hTabGroup;
        end
        
        % Method is used by both import from file and import from workspace
        % callbacks.
        function user_canceled = showImportingDataWillCauseDataLossDlg(self, msg, msgTitle)
            
            user_canceled = false;
            
            if self.validColorspaceFiguresInApp()
                
                buttonName = uiconfirm(self.App, msg, msgTitle,...
                                       'Options',{getString(message('images:commonUIString:yes')), getString(message('images:commonUIString:cancel'))},...
                                       'DefaultOption', 2, 'CancelOption', 2);
                
                if strcmp(buttonName,getString(message('images:commonUIString:yes')))
                    
                    % Each time a new colorspace document is added, we want to
                    % revert the Show Binary, Invert Mask, and Mask Opacity ui
                    % controls back to their initialized state.
                    self.manageControlsOnImageLoad();
                    self.hColorSpacesButton.Enabled = false;
                    
                    currentDocuments = self.App.getDocuments();
                   
                    cellfun(@(x)close(x), currentDocuments);
                    
                    self.FigureHandles = [];
                    
                    if self.hasCurrentValidMontageInstance()
                        self.hColorSpaceMontageView.delete();
                    end
                else
                    user_canceled = true;
                end
                
            end
        end
        
    end
    
    % Methods used to create each color space segmentation figure/document
    methods (Access = private)
        
        function hFig = createColorspaceSegmentationView(self,im,csname,tMat,camPosition,camVector)

            tabName = self.getFigName(csname);


            % Share 1 "Tabs" document across all the colorspaces
            % figures
            group = self.App.getDocumentGroup('Tabs');
            if isempty(group)
                group = matlab.ui.internal.FigureDocumentGroup();
                group.Title = "Tabs";
                group.Tag = "Tabs";
                self.App.add(group);
            end

            % Add a figure-based document
            figOptions.Title = tabName;
            figOptions.Tag = tabName;
            figOptions.DocumentGroupTag = group.Tag;

            document = matlab.ui.internal.FigureDocument(figOptions);
            document.CanCloseFcn = @(~,~)self.blockDocumentFromClosing();

            hFig = document.Figure;
            hFig.Colormap = gray(2);
            hFig.Tag = csname;
            hFig.AutoResizeChildren = 'on';

            self.App.add(document);

            hFig.WindowKeyPressFcn = @(~,~)[];
            hFig.WindowButtonDownFcn = @(~,~) self.buttonClicked(true);
            hFig.WindowButtonUpFcn = @(~,~) self.buttonClicked(false);

            self.FigureHandles(end+1) = hFig;

            
            iptPointerManager(hFig);
            
            
            if ~isempty(im)
                
                % Create grid layout for the main app. Left panel for the
                % image and the right panel for histograms and the point
                % cloud.
                hGrid = uigridlayout(hFig, [1 2]);
                
                hGrid.RowHeight={'1x'};
                hGrid.ColumnWidth={'3x','2x'};
                
                hLeftPanel = uigridlayout(hGrid, [1 1], "Tag", "LeftPanel");
                hLeftPanel.Layout.Row = 1;
                hLeftPanel.Layout.Column = 1;
                
                hRightPanel = uipanel('Parent',hGrid, 'Units', 'normalized', 'BorderType','none',...
                                                      'tag','RightPanel', 'Visible', 'off');
                
                hRightPanel.Layout.Row = 1;
                hRightPanel.Layout.Column = 2;
                
                hRightPanel.AutoResizeChildren = 'off';
                
                drawnow;
                layoutScrollpanel(self,hLeftPanel);
                drawnow;
                layoutInteractiveHistograms(self,hRightPanel,im,csname);
                drawnow;
                histHandles = getappdata(hRightPanel,'HistPanelHandles');
                drawnow;
                
                % Initialize masks
                [m,n,~] = size(im);
                self.sliderMask = true([m,n]);
                self.clusterMask = true([m,n]);
                self.updateMask(im,histHandles{:});
                self.updateClusterMask();
                
                % Prevent MATLAB graphics from being drawn in figures docked
                % within app.
                set(hFig,'HandleVisibility','callback');
                
                % Now that we are done setting up new color space figure,
                % set document callbacks to manage state as user
                % switches between existing figures.
                document.CanCloseFcn = @(~,~) figureDocumentClose(self);
                addlistener(document, 'PropertyChanged', @self.figureDocumentActivated );
                
                self.hFigCurrent = hFig;
                
                if(~self.LightWeightMode)            
                    self.getClusterProjection(camPosition,camVector)
                    layoutInteractiveColorProjection(self,hRightPanel,im,csname,tMat);
                end
                
                drawnow;
                
                if self.hHidePointCloud.Value
                    self.hidePointCloud()
                end
                
                hLeftPanel.Visible = 'on';
                hRightPanel.Visible = 'on';

                drawnow;
                
            else
                % Prevent MATLAB graphics from being drawn in figures docked
                % within app.
                set(hFig,'HandleVisibility','callback');
                
                self.hFigCurrent = hFig;
                
            end
            
        end
        
        function layoutScrollpanel(self,hLeftPanel)
            
            if isempty(self.hImagePanel) || ~ishandle(self.hImagePanel)
                
                self.hImagePanel = uipanel('Parent',hLeftPanel,...
                    'Tag','ImagePanel',...
                    'AutoResizeChildren', 'off',...
                    'BorderType', 'none');

                self.ImageObj = images.internal.app.utilities.Image(self.hImagePanel);
                drawnow;

                self.hImagePanel.SizeChangedFcn = @(~,~)self.reactToAppResize();
                draw(self.ImageObj, self.imRGB, [], [], []);
    
                self.ImageObj.Visible = true;
                self.ImageObj.Enabled = true;

                hAx   = self.ImageObj.AxesHandle;

                % Add draw polygon button to the axestoolbar
                tb = hAx.Toolbar;

                self.hFreehandButton = axtoolbarbtn(tb,'state', 'Tag', 'SelectButton','Tooltip',getString(message('images:colorSegmentor:addRegionTooltip')));

                self.hFreehandButton.Icon = self.freeIcon;
                self.hFreehandButton.ValueChangedFcn = @(~,~) self.lassoRegion();
                
                % Turn on axes visibility
                set(hAx,'Visible','on');
                
                % Initialize Overlay color by setting axes color.
                set(hAx,'Color',self.maskColor);
                
                % Turn off axes gridding
                set(hAx,'XTick',[],'YTick',[]);
                
                % Hide axes border
                set(hAx,'XColor','none','YColor','none');
                
                if(self.LightWeightMode)
                    self.hFreehandButton.Visible = 'off';
                end

                self.hAxes = hAx;
            else
                % If imagepanel has already been created, we simply want
                % to reparent it to the current figure that is being
                % created/in view.
                set(self.hImagePanel,'Parent',hLeftPanel);
            end
            
        end
        
        function [hChan1Hist,hChan2Hist,hChan3Hist] = layoutInteractiveHistograms(self,hPanel,im,csname)
            
            import images.internal.app.colorThresholderWeb.InteractiveHistogram;
            import images.internal.app.colorThresholderWeb.InteractiveHistogramHue;
            
            if(self.LightWeightMode)
                panelPos = [0 0.3 1 0.4];
            else
                panelPos = [0 0.6 1 0.4];
            end

            hHistPanel = uipanel('Parent', hPanel,...
                                 'Units', 'normalized',...
                                 'Position', panelPos);
            
            if(isequal(csname,'HSV'))
                hGridLayout = uigridlayout(hHistPanel, [2,2],...
                    "RowSpacing",0, "ColumnSpacing",0);
            else      
                hGridLayout = uigridlayout(hHistPanel, [3,1],...
                   "RowSpacing",0, "ColumnSpacing",0);
            end
            
            switch csname
                
                case 'RGB'
                    hChan1Hist = InteractiveHistogram(hGridLayout, im(:,:,1), 'ramp', {[0 0 0], [1 0 0]}, 'R');
                    hChan1Hist.hPanel.Layout.Row = 1;
                    hChan2Hist = InteractiveHistogram(hGridLayout, im(:,:,2), 'ramp', {[0 0 0], [0 1 0]}, 'G');
                    hChan2Hist.hPanel.Layout.Row = 2;
                    hChan3Hist = InteractiveHistogram(hGridLayout, im(:,:,3), 'ramp', {[0 0 0], [0 0 1]}, 'B');
                    hChan3Hist.hPanel.Layout.Row = 3;
                    
                case 'HSV'
                    
                    hChan1Hist = InteractiveHistogramHue(hGridLayout, im(:,:,1));
                    hChan1Hist.hPanel.Layout.Row = [1 2];
                    hChan1Hist.hPanel.Layout.Column = 1;
                    hChan2Hist = InteractiveHistogram(hGridLayout, im(:,:,2), 'saturation');
                    hChan2Hist.hPanel.Layout.Row = 1;
                    hChan2Hist.hPanel.Layout.Column = 2;
                    hChan3Hist = InteractiveHistogram(hGridLayout, im(:,:,3), 'BlackToWhite', 'V');
                    hChan3Hist.hPanel.Layout.Row = 2;
                    hChan3Hist.hPanel.Layout.Column = 2;
                    
                case 'L*a*b*'
                    hChan1Hist = InteractiveHistogram(hGridLayout, im(:,:,1), 'LStar', 'L*');
                    hChan1Hist.hPanel.Layout.Row = 1;
                    hChan2Hist = InteractiveHistogram(hGridLayout, im(:,:,2), 'aStar');
                    hChan2Hist.hPanel.Layout.Row = 2;
                    hChan3Hist = InteractiveHistogram(hGridLayout, im(:,:,3), 'bStar');
                    hChan3Hist.hPanel.Layout.Row = 3;
                    
                case 'YCbCr'
                    hChan1Hist = InteractiveHistogram(hGridLayout, im(:,:,1), 'BlackToWhite', 'Y');
                    hChan1Hist.hPanel.Layout.Row = 1;
                    hChan2Hist = InteractiveHistogram(hGridLayout, im(:,:,2), 'Cb');
                    hChan2Hist.hPanel.Layout.Row = 2;
                    hChan3Hist = InteractiveHistogram(hGridLayout, im(:,:,3), 'Cr');
                    hChan3Hist.hPanel.Layout.Row = 3;
                    
                otherwise
                    hChan1Hist = InteractiveHistogram(hGridLayout, im(:,:,1));
                    hChan1Hist.hPanel.Layout.Row = 1;
                    hChan2Hist = InteractiveHistogram(hGridLayout, im(:,:,2));
                    hChan2Hist.hPanel.Layout.Row = 2;
                    hChan3Hist = InteractiveHistogram(hGridLayout, im(:,:,3));
                    hChan3Hist.hPanel.Layout.Row = 3;
                    
            end
            
            if(~self.LightWeightMode)
                addlistener(hChan1Hist, 'SliderMoved', @(~,~)turnOffAxisInteractions(self));
                addlistener([hChan2Hist, hChan3Hist], 'SliderMoved', @(~,~)turnOffAxisInteractions(self));
            end
            
            addlistener(hChan1Hist,'currentSelection', 'PostSet',...
                @(~,~) updateClusterDuringSliderDrag(self, im, hChan1Hist, hChan2Hist, hChan3Hist));
            
            addlistener([hChan2Hist,hChan3Hist],'currentSelection', 'PostSet',...
                @(~,~) updateClusterDuringSliderDrag(self, im, hChan1Hist, hChan2Hist, hChan3Hist));
            
            histograms = {hChan1Hist, hChan2Hist, hChan3Hist};
            
            setappdata(hPanel,'HistPanelHandles',histograms);
            setappdata(hPanel,'ColorspaceCData',im);
            
        end
        
        function resetSliders(self)
            
            % Remove freehand ROIs from image
            self.clearFreehands()
            
            % Get histograms for current figure
            hRightPanel = findobj(self.hFigCurrent, 'tag', 'RightPanel');
            histHandles = getappdata(hRightPanel, 'HistPanelHandles');
            
            % Apply maximum values to current celection for each color
            % channel and update each histogram
            for ii = 1:3
                histHandles{ii}.currentSelection = histHandles{ii}.histRange;
                histHandles{ii}.updateHistogram()
            end

            im = getappdata(hRightPanel, 'ColorspaceCData');
            updateClusterAfterSliderDrag(self,[],[],im, histHandles{1:3});
            
        end
        
        function turnOffAxisInteractions(self)
           
            hScatter = findobj(self.hFigCurrent, 'Tag', 'scatteraxes');
            hScatter2d = findobj(self.hFigCurrent, 'Tag', 'scatter2daxes');
            hImageAx = findobj(self.hImagePanel,'type','axes');
            hScatter.InteractionContainer.CurrentMode = 'none';
            hScatter2d.InteractionContainer.CurrentMode = 'none';
            hImageAx.InteractionContainer.CurrentMode = 'none';
            
        end
        
        function updateClusterDuringSliderDrag(self, im, hChan1Hist, hChan2Hist, hChan3Hist)
            % updateClusterDuringSliderDrag - If image is small, update
            % mask and point cloud as the slider is dragged.
            
            % If image is large, update mask after finishing a drag. If
            % image is small, update mask as you drag
            
            if self.isLiveUpdate.Value
                self.updateCluster(im, hChan1Hist, hChan2Hist, hChan3Hist)
            elseif isempty(self.hSliderMovedListener)
                self.hSliderMovedListener = addlistener(self.hFigCurrent,'WindowMouseRelease',@(hObj,evt) self.updateClusterAfterSliderDrag(hObj, evt, im, hChan1Hist, hChan2Hist, hChan3Hist));
            end
            
        end
        
        function updateClusterAfterSliderDrag(self, ~, ~, im, hChan1Hist, hChan2Hist, hChan3Hist)
            % updateClusterAfterSliderDrag - Triggered after mouse is
            % released for large images. Update the mask and point cloud
            delete(self.hSliderMovedListener);
            self.hSliderMovedListener = [];
            self.updateCluster(im, hChan1Hist, hChan2Hist, hChan3Hist)
            
        end
        
        function updateCluster(self,im, hChan1Hist, hChan2Hist, hChan3Hist)
            % Update Mask
            if ~self.isFreehandApplied
                self.clearFreehands()
            end
            self.updateMask(im, hChan1Hist, hChan2Hist, hChan3Hist);
            if self.hHidePointCloud.Value
                return;
            end
            % Update Point Cloud
            if(~self.LightWeightMode)

                if self.is3DView
                    self.hColorSpaceProjectionView.updatePointCloud(self.sliderMask);
                else
                    self.updatePointCloud();
                end
            end
        end
        
        function hColorProj = layoutInteractiveColorProjection(self,hPanel,im,csname,tMat)
            
            RGB = self.imRGB;
            
            m = size(RGB,1);
            n = size(RGB,2);
            
            % Move colorData and RGB data into Mx3 feature vector representation
            im = reshape(im,[m*n 3]);
            RGB = reshape(RGB,[m*n 3]);
            
            im = double(im);
            
            % Change coordinates for given colorspace
            switch (csname)
                case 'HSV'
                    Xcoord = im(:,2).*im(:,3).*cos(2*pi*im(:,1));
                    Ycoord = im(:,2).*im(:,3).*sin(2*pi*im(:,1));
                    im(:,1) = Xcoord;
                    im(:,2) = Ycoord;
                case {'L*a*b*','YCbCr'}
                    temp = im(:,1);
                    im(:,1) = im(:,2);
                    im(:,2) = im(:,3);
                    im(:,3) = temp;
            end
            
            % Compute and apply transformation matrix for PCA. This is the
            % default projection that is applied when the user selects a
            % new colorspace and the third vector is used to define the
            % default projection
            shiftVec = mean(im,1);
            im = bsxfun(@minus, im, shiftVec); % Mean shift feature vector
            
            setappdata(hPanel,'ColorspaceCDataForCluster',im);
            setappdata(hPanel,'TransformationMat',tMat);
            setappdata(hPanel,'ShiftVector',shiftVec);
            
            tMat = tMat(1:2,:);
            im = [im ones(size(im,1),1)]';
            colorDataPCA = (tMat*im)';
            
            setappdata(hPanel,'TransformedCDataForCluster',colorDataPCA);
            
            hColorProj = uipanel('Parent',hPanel,'Units','Normalized',...
                                'Position',[0,0,1,0.6],'BorderType', 'none',...
                                'Tag','ColorProj');
            set(hColorProj,'Visible','off','BackgroundColor',self.pointCloudColor);
                
            g = uigridlayout(hColorProj, [2 3]);
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};


            hAx = axes('Parent',g); 
            hAx.PickableParts = 'visible';                

            s = scatter(hAx,colorDataPCA(:,1),colorDataPCA(:,2),6,im2double(RGB),'.','Tag','ScatterPlot');
            
            set(hAx,'XTick',[],'YTick',[],'ZTick',[]);
            set(hAx,'Color',self.pointCloudColor,'Box','off','Units','normalized','Position',[0.01,0.01,0.98,0.98]);
            set(hAx,'XColor',self.pointCloudColor,'YColor',self.pointCloudColor,'ZColor',self.pointCloudColor);
            set(hAx,'Visible','on');
            set(hAx, 'Tag', 'scatter2daxes');

            s.PickableParts = 'none';
            
            tb = axtoolbar(hAx,{});

            self.hProjRotateButton = axtoolbarbtn(tb,'push', 'Tag', 'RotateButton',...
                'Tooltip',getString(message('images:colorSegmentor:rotateButtonTooltip')));
            self.hProjRotateButton.Icon = self.rotateIcon;
            self.hProjRotateButton.ButtonPushedFcn = @(~,~) self.show3DViewState();

            self.hProjPolygonButton = axtoolbarbtn(tb,'state', 'Tag', 'PolyButton',...
                'Tooltip',getString(message('images:colorSegmentor:polygonButtonTooltip')));
            self.hProjPolygonButton.Icon = self.polyIcon;
            self.hProjPolygonButton.ValueChangedFcn = @(hobj,evt) self.polyRegionForClusters(hobj,evt);

            
            self.StatusBar.setStatus(...
                          getString(message('images:colorSegmentor:polygonHintMessage')));
            
        end

    end
    
    % Methods used to layout each section of app
    methods (Access = private)
        
        function loadAppIcons(self)
            
            self.LoadImageIcon = 'import_data';
            self.newColorspaceIcon = 'new_colorBar';
            self.hidePointCloudIcon = 'hide_pointCloud';
            self.liveUpdateIcon = 'check_time';
            self.invertMaskIcon = 'invertImageMask';
            self.resetButtonIcon = 'restore';
            self.showBinaryIcon = 'binaryImageMask';
            self.createMaskIcon = 'validated';
            % These are axes toolbar icons. These are not translated to SVG
            % because of no current support for SVG icons.
            self.freeIcon = setUIControlIcon(fullfile(matlabroot,'/toolbox/images/icons/DrawFreehand_16.png'));
            self.polyIcon = setUIControlIcon(fullfile(matlabroot,'/toolbox/images/icons/DrawPolygon_16.png'));
            self.rotateIcon = setUIControlIcon(fullfile(matlabroot,'/toolbox/images/icons/Rotate3D_16.png'));
            % Import rotate pointer
            mousePointer = load(fullfile(matlabroot,'/toolbox/images/icons/rotatePointer.mat'));
            self.rotatePointer = mousePointer.rotatePointer;
            
        end
        
        function layoutLoadImageSection(self)
            
            % Load Image Button
            loadImageButton = matlab.ui.internal.toolstrip.SplitButton(getString(message('images:colorSegmentor:loadImageSplitButtonTitle')), ...
                self.LoadImageIcon);
            loadImageButton.Tag = 'btnLoadImage';
            loadImageButton.Description = getString(message('images:colorSegmentor:loadImageTooltip'));
            
            % Drop down list
            sub_popup = matlab.ui.internal.toolstrip.PopupList();
            
            sub_item1 = matlab.ui.internal.toolstrip.ListItem(getString(message('images:colorSegmentor:loadImageFromFile')));
            sub_item1.Tag =  'btnLoadImageFromFile';
            sub_item1.Icon = 'folder';
            sub_item1.ShowDescription = false;
            addlistener(sub_item1, 'ItemPushed', @self.loadImageFromFile);
            
            sub_item2 = matlab.ui.internal.toolstrip.ListItem(getString(message('images:colorSegmentor:loadImageFromWorkspace')));
            sub_item2.Tag =  'btnLoadImageFromWS';
            sub_item2.Icon = 'workspace';
            sub_item2.ShowDescription = false;
            addlistener(sub_item2, 'ItemPushed', @self.loadImageFromWorkspace);
            
            sub_item3 = matlab.ui.internal.toolstrip.ListItem(getString(message('images:colorSegmentor:loadImageFromCamera')));
            sub_item3.Tag =  'btnLoadImageFromCamera';
            sub_item3.Icon = 'cameraTools';
            sub_item3.ShowDescription = false;
            addlistener(sub_item3, 'ItemPushed', @self.loadImageFromCamera);
            
            sub_popup.add(sub_item1);
            sub_popup.add(sub_item2);
            sub_popup.add(sub_item3);
            
            loadImageButton.Popup = sub_popup;
            loadImageButton.Popup.Tag = 'Load Image Popup';
            addlistener(loadImageButton, 'ButtonPushed', @self.loadImageFromFile);
            
            c = self.LoadImageSection.addColumn();
            c.add(loadImageButton);
            
            self.lassoSensitiveComponentHandles{end+1} = loadImageButton;
            
        end
        
        function layoutColorSpacesSection(self)
            
            self.hColorSpacesButton = matlab.ui.internal.toolstrip.Button(getString(message('images:colorSegmentor:newColorspace')), ...
                self.newColorspaceIcon);
            self.hColorSpacesButton.Tag = 'btnChooseColorSpace';
            self.hColorSpacesButton.Description = getString(message('images:colorSegmentor:addNewColorspaceTooltip'));
            addlistener(self.hColorSpacesButton, 'ButtonPushed', @(~,~) self.compareColorSpaces() );
            
            c = self.ColorSpacesSection.addColumn();
            c.add(self.hColorSpacesButton);
            
            self.lassoSensitiveComponentHandles{end+1} = self.hColorSpacesButton;
            
        end
        
        function layoutChooseProjectionSection(self)
            
            % Choose the pointcloud axes background color based on the MATLAB theme. 
            % The slider values are chosen on a scale of 0-100 translating
            % to the grayscale value of the background. 
            s=settings;
            if(strcmp(s.matlab.appearance.MATLABTheme.ActiveValue, 'Dark'))
                sliderVal = 70;
            else
                sliderVal = 6;
            end

            self.hPointCloudBackgroundSlider = matlab.ui.internal.toolstrip.Slider([0,100],sliderVal);
            self.hPointCloudBackgroundSlider.Ticks = 0;
            self.hPointCloudBackgroundSlider.Description = getString(message('images:colorSegmentor:pointCloudSliderTooltip'));
            self.pointCloudSliderMovedListener = addlistener(self.hPointCloudBackgroundSlider,'ValueChanged',@(hobj,evt) pointCloudSliderMoved(self,hobj,evt) );
            self.hPointCloudBackgroundSlider.Tag = 'sliderPointCloudBackground';
            
            pointCloudColorLabel = matlab.ui.internal.toolstrip.Label(getString(message('images:colorSegmentor:pointCloudSlider')));
            pointCloudColorLabel.Tag = 'labelPointCloudOpacity';
            
            self.hHidePointCloud = matlab.ui.internal.toolstrip.ToggleButton(getString(message('images:colorSegmentor:hidePointCloud')),self.hidePointCloudIcon);
            self.hHidePointCloud.Tag = 'btnHidePointCloud';
            self.hHidePointCloud.Description = getString(message('images:colorSegmentor:hidePointCloudTooltip'));
            addlistener(self.hHidePointCloud, 'ValueChanged', @(~,~) self.hidePointCloud() );

            c = self.ChooseProjectionSection.addColumn('HorizontalAlignment','center','Width',120);
            c.add(pointCloudColorLabel);
            c.add(self.hPointCloudBackgroundSlider);
            c2 = self.ChooseProjectionSection.addColumn();
            c2.add(self.hHidePointCloud);
            
            self.hChangeUIComponentHandles{end+1} = self.hPointCloudBackgroundSlider;
            self.lassoSensitiveComponentHandles{end+1} = self.hHidePointCloud;
            self.hChangeUIComponentHandles{end+1} = self.hHidePointCloud;

            if(self.LightWeightMode)
                self.hHidePointCloud.Enabled = false;
                self.hHidePointCloud.Value = true;
                self.hPointCloudBackgroundSlider.Enabled = false;
                self.hPointCloudBackgroundSlider.Value = false;
            end
            
        end
        
        function layoutManualSelectionSection(self)
            
            self.isLiveUpdate = matlab.ui.internal.toolstrip.ToggleButton(getString(message('images:colorSegmentor:liveUpdate')),self.liveUpdateIcon);
            self.isLiveUpdate.Description = getString(message('images:colorSegmentor:liveUpdateTooltip'));
            self.isLiveUpdate.Tag = 'btnLiveUpdate';
            
            c = self.ManualSelectionSection.addColumn();
            c.add(self.isLiveUpdate);
            
            self.hChangeUIComponentHandles{end+1} = self.isLiveUpdate;

            if(self.LightWeightMode)
                self.isLiveUpdate.Enabled = false;
                self.isLiveUpdate.Value = false;
            end
            
        end
        
        function layoutThresholdControlsSection(self)
            
            self.hInvertMaskButton = matlab.ui.internal.toolstrip.ToggleButton(getString(message('images:colorSegmentor:invertMask')),...
                self.invertMaskIcon);
            self.hInvertMaskButton.Tag = 'btnInvertMask';
            self.hInvertMaskButton.Description = getString(message('images:colorSegmentor:invertMaskTooltip'));
            self.invertMaskItemStateChangedListener = addlistener(self.hInvertMaskButton, 'ValueChanged', @self.invertMaskButtonPress);
            
            % Add reset button to reset slider positions
            resetButton = matlab.ui.internal.toolstrip.Button(getString(message('images:colorSegmentor:resetButton')), self.resetButtonIcon);
            resetButton.Tag = 'btnResetSliders';
            resetButton.Description = getString(message('images:colorSegmentor:resetButtonTooltip'));
            addlistener(resetButton, 'ButtonPushed', @(~,~) self.resetSliders());
            
            c = self.ThresholdControlsSection.addColumn();
            c.add(self.hInvertMaskButton);
            c2 = self.ThresholdControlsSection.addColumn();
            c2.add(resetButton);

            self.hChangeUIComponentHandles{end+1} = self.hInvertMaskButton;
            self.hChangeUIComponentHandles{end+1} = resetButton;
            self.lassoSensitiveComponentHandles{end+1} = resetButton;
            
        end
        
        function layoutViewSegmentationSection(self)
            
            self.hShowBinaryButton = matlab.ui.internal.toolstrip.ToggleButton(getString(message('images:colorSegmentor:showBinary')),...
                self.showBinaryIcon);
            self.binaryButonStateChangedListener = addlistener(self.hShowBinaryButton, 'ValueChanged', @self.showBinaryPress);
            self.hChangeUIComponentHandles{end+1} = self.hShowBinaryButton;
            self.hShowBinaryButton.Tag = 'btnShowBinary';
            self.hShowBinaryButton.Description = getString(message('images:colorSegmentor:viewBinaryTooltip'));
            
            self.hMaskOpacitySlider = matlab.ui.internal.toolstrip.Slider([0,100],100);
            self.hMaskOpacitySlider.Ticks = 0;
            self.sliderMovedListener = addlistener(self.hMaskOpacitySlider,'ValueChanged',@self.opacitySliderMoved);
            self.hChangeUIComponentHandles{end+1} = self.hMaskOpacitySlider;
            self.hMaskOpacitySlider.Tag = 'sliderMaskOpacity';
            self.hMaskOpacitySlider.Description = getString(message('images:colorSegmentor:sliderTooltip'));
            
            overlayColorLabel   = matlab.ui.internal.toolstrip.Label(getString(message('images:colorSegmentor:backgroundColor')));
            overlayColorLabel.Tag = 'labelOverlayColor';
            overlayOpacityLabel = matlab.ui.internal.toolstrip.Label(getString(message('images:colorSegmentor:backgroundOpacity')));
            overlayOpacityLabel.Tag = 'labelOverlayOpacity';
            
            % There is no MCOS interface to set the icon of a TSButton
            % directly from a uint8 buffer.
            self.hOverlayColorButton = matlab.ui.internal.toolstrip.Button();
            self.hOverlayColorButton.Icon = ...
                  matlab.ui.internal.toolstrip.Icon(zeros(16,16,3, 'uint8'));
            addlistener(self.hOverlayColorButton,'ButtonPushed',@self.chooseOverlayColor);
            self.hChangeUIComponentHandles{end+1} = self.hOverlayColorButton;
            self.hOverlayColorButton.Tag = 'btnOverlayColor';
            self.hOverlayColorButton.Description = getString(message('images:colorSegmentor:backgroundColorTooltip'));

            c = self.ViewSegmentationSection.addColumn('HorizontalAlignment','right');
            c.add(overlayColorLabel);
            c.add(overlayOpacityLabel);
            c2 = self.ViewSegmentationSection.addColumn('Width',80);
            c2.add(self.hOverlayColorButton);
            c2.add(self.hMaskOpacitySlider);
            c3 = self.ViewSegmentationSection.addColumn();
            c3.add(self.hShowBinaryButton);
            
        end
        
        function layoutExportSection(self)

            %Export Button
            exportButton = matlab.ui.internal.toolstrip.SplitButton(getString(message('images:colorSegmentor:export')), ...
                'export');
            exportButton.Tag = 'btnExport';
            exportButton.Description = getString(message('images:colorSegmentor:exportButtonTooltip'));

            % Drop down list
            sub_popup = matlab.ui.internal.toolstrip.PopupList();
            
            sub_item1 = matlab.ui.internal.toolstrip.ListItem(getString(message('images:colorSegmentor:exportImages')));
            sub_item1.Tag =  'btnExportImages';
            sub_item1.Icon = 'export';
            sub_item1.ShowDescription = false;
            addlistener(sub_item1, 'ItemPushed', @(~,~) self.exportDataToWorkspace);
            
            sub_item2 = matlab.ui.internal.toolstrip.ListItem(getString(message('images:colorSegmentor:exportFunction')));
            sub_item2.Tag =  'btnExportFunction';
            sub_item2.Icon = 'export_function';
            sub_item2.ShowDescription = false;
            addlistener(sub_item2, 'ItemPushed', @(~,~) images.internal.app.colorThresholderWeb.generateColorSegmentationCode(self));
            
            sub_popup.add(sub_item1);
            sub_popup.add(sub_item2);
            
            exportButton.Popup = sub_popup;
            exportButton.Popup.Tag = 'Export Popup';
            addlistener(exportButton, 'ButtonPushed', @(~,~) self.exportDataToWorkspace());
            
            %Layout
            c = self.ExportSection.addColumn();
            c.add(exportButton);
            
            self.hChangeUIComponentHandles{end+1} = exportButton;
            self.lassoSensitiveComponentHandles{end+1} = exportButton;
            
        end
        
    end
    
    % Region selection functionality
    methods (Access = private)
        
        %------------------------------------------------------------------
        function lassoRegion(self)
            % lassoRegion - Add freehand ROI to current colorspace figure.
            
            % If Select Colors tool has already been selected then delete
            if ~isempty(self.freehandManager)
                return
            end
            
            % If cluster selection tool has already been selected then exit out
            if ~isempty(self.polyManager)
                self.disablePolyRegion()
                self.polyManager = [];
                self.hProjPolygonButton.Value = 0;
            end
            
            self.hFreehandButton.Value = 1;
            
            % Keep track of the state of the toolstrip buttons, and disable
            % tools that could interfere with region selection.
            self.preLassoToolstripState = self.getStateOfLassoSensitiveTools();
            self.disableLassoSensitiveTools()
            
            hAx = findobj(self.hImagePanel, 'type', 'axes');
            self.freehandManager = iptui.internal.ImfreehandModeContainer(hAx);
            
            self.hFreehandListener = addlistener(self.freehandManager, 'hROI', 'PostSet', ...
                @(obj,evt) self.freehandedAdded(obj, evt) );
            addlistener(self.freehandManager,'DrawingAborted',@(~,~) self.freehandDrawingAborted());
            addlistener(self.freehandManager,'DrawingStarted',@(~,~)turnOffAxisInteractions(self));
            
            self.freehandManager.enableInteractivePlacement();
        end
        
        function polyRegionForClusters(self,varargin)
            % polyRegionForClusters - Add impoly ROI to current colorspace
            % figure.
            
            % If cluster selection tool has already been selected
            if ~isempty(self.polyManager)
                return;
            end
            
            % If Select Colors tool has already been selected then delete
            if ~isempty(self.freehandManager)
                self.resetLassoTool()
                self.freehandManager = [];
                self.hFreehandButton.Value = 0;
            end
            
            varargin{2}.Source.Value = 1;
            
            % Keep track of the state of the toolstrip buttons, and disable
            % tools that could interfere with region selection.
            self.preLassoToolstripState = self.getStateOfLassoSensitiveTools();
            self.disableLassoSensitiveTools()
            %self.clearStatusBar();
            % Get axes and set xlim and ylim to manual the user cannot
            % change limits accidentally
            hScat = findobj(self.hFigCurrent, 'Type','Scatter','Tag', 'ScatterPlot');
            hScat.Parent.XLimMode = 'Manual';
            hScat.Parent.YLimMode = 'Manual';
            self.polyManager = iptui.internal.ImpolyModeContainer(hScat.Parent);
            self.hPolyListener = addlistener(self.polyManager,'hROI','PostSet',@(obj,evt) self.polygonAddedForClusters(obj,evt));
            
            addlistener(self.polyManager,'DrawingAborted',@(~,~) self.polygonDrawingAborted());
            addlistener(self.polyManager,'DrawingStarted',@(~,~)turnOffAxisInteractions(self));
            addlistener(self.polyManager,'ROIMoving',@(~,~)turnOffAxisInteractions(self));
            
            % Blow away any custom mouse pointers(specifically rotate for
            % scatter3) as ROIs cache current mouse pointer as background
            % pointers            
            hAx = findobj(self.hColorSpaceProjectionView.hPanels,'type','axes');            
            iptSetPointerBehavior(hAx,[]);
            
            self.polyManager.enableInteractivePlacement();
            
        end
        
        %------------------------------------------------------------------
        function freehandedAdded(self, ~, ~)
            % freehandedAdded - Callback that fires when a hROI changes.
            
            % SelectButton = findobj(self.hFigCurrent,'Tag','SelectButton');
            self.hFreehandButton.Value = 0;
            
            self.resetLassoTool()
            
            % If image is large, update mask after finishing a drag. If
            % Image is small, update mask as you drag
            addlistener(self.freehandManager.hROI,'MovingROI',@(~,~) self.updateThresholdDuringROIDrag());
            
            hFree = self.freehandManager.hROI;
            self.freehandManager = [];
            
            self.addFreehandROIHandleToCollection(hFree)
            addlistener(hFree, 'DeletingROI', @(obj,evt) newFreehandDeleteFcn(self, obj) );
            
            self.applyROIs()
            
        end
        
        function polygonDrawingAborted(self)
            % Set PolyButton Value to 0, we have to do this explicitly as
            % the user can cancel polygon drawing either by pressing Esc
            % key or clicking outside the current axes.
            if isvalid(self) && isvalid(self.hFigCurrent)
                self.hProjPolygonButton.Value = 0;
                self.disablePolyRegion();
                self.polyManager = [];
            end
        end
        
        function freehandDrawingAborted(self)
            % Set PolyButton Value to 0, we have to do this explicitly as
            % the user can cancel polygon drawing either by pressing Esc
            % key or clicking outside the current axes.
            if isvalid(self) && isvalid(self.hFigCurrent)
                
                self.resetLassoTool()
                self.freehandManager = [];
                self.hFreehandButton.Value = 0;
                
            end
        end
        
        %------------------------------------------------------------------
        function polygonAddedForClusters(self, ~, ~)
            % polygonAddedForClusters - Callback that fires when a hROI
            % changes.
            
            self.hProjPolygonButton.Value = 0;
            
            self.disablePolyRegion()
            
            % If image is large, update mask after finishing a drag. If
            % Image is small, update mask as you drag
            addlistener(self.polyManager.hROI,'MovingROI',@(~,~) self.updateClusterDuringROIDrag());
            
            hFree = self.polyManager.hROI;
            self.polyManager = [];
            
            if size(hFree.Position,1) > 1
                self.addPolyROIHandleToCollection(hFree)
                addlistener(hFree, 'DeletingROI', @(obj,evt) newPolyDeleteFcn(self, obj) );
            else
                hFree.delete()
            end
            
            self.applyClusterROIs();
            
        end
        
        function updateClusterDuringROIDrag(self)
            
            % If image is large, update mask after finishing a drag. If
            % Image is small, update mask as you drag
            if self.isLiveUpdate.Value || ~self.isFigClicked
                self.applyClusterROIs()
            elseif isempty(self.hPolyMovedListener)
                % Check if listener has already been added for when the mouse
                % will be released
                self.hPolyMovedListener = addlistener(self.hFigCurrent,'WindowMouseRelease',@(~,~) self.updateClusterAfterROIDrag());
            end
            
        end
        
        function updateClusterAfterROIDrag(self)
            
            % Delete listener and update mask
            delete(self.hPolyMovedListener);
            self.hPolyMovedListener = [];
            self.applyClusterROIs();
            
        end
        
        function updateThresholdDuringROIDrag(self)
            
            % If image is large, update mask after finishing a drag. If
            % Image is small, update mask as you drag
            if self.isLiveUpdate.Value
                self.applyROIs()
            elseif isempty(self.hFreehandMovedListener)
                % Check if listener has already been added for when the mouse
                % will be released
                self.hFreehandMovedListener = addlistener(self.hFigCurrent,'WindowMouseRelease',@(~,~) self.updateThresholdAfterROIDrag());
            end
            
        end
        
        function updateThresholdAfterROIDrag(self)
            
            % Delete listener and update mask
            delete(self.hFreehandMovedListener);
            self.hFreehandMovedListener = [];
            self.applyROIs();
            
        end
        
        %------------------------------------------------------------------
        function disablePolyRegion(self)
            
            self.enableLassoSensitiveTools(self.preLassoToolstripState)
            delete(self.hPolyListener);
            self.hPolyListener = [];
            
        end
        
        function resetLassoTool(self)
            
            self.enableLassoSensitiveTools(self.preLassoToolstripState)
            self.hFreehandListener = [];
            
        end
        
        %------------------------------------------------------------------
        function newFreehandDeleteFcn(self, obj)
            
            if ~isvalid(self)
                % App is being destroyed...
                return
            end
            
            % (2) Remove the handle from the collection of imfreehand objects.
            % *Find the row in the table.
            figuresWithROIs = [self.hFreehandROIs{:,1}];
            idx = find(figuresWithROIs == self.hFigCurrent, 1);
            if isempty(idx)
                return
            end
            % Remove the handle from the row (or the whole row if the
            % figure is being deleted).
            if ~isvalid(self.hFigCurrent) || strcmpi(self.hFigCurrent.Name, getString(message('images:colorSegmentor:MainPreviewFigure')))
                self.hFreehandROIs(idx,:) = [];
                return
            end
            currentROIs = self.hFreehandROIs{idx,2};
            currentROIs(currentROIs == obj) = []; 
            obj.delete();
            self.hFreehandROIs{idx,2} = currentROIs;
            
            % If ROI was manually deleted, reapply any remaining ROIs if
            % applicable and update the mask. If ROI was programmatically
            % deleted (via resetThresholder or clearFreehands), do not
            % apply ROIs and update the mask
            if self.isManualDelete
                self.applyROIs()
            end
            
        end
        
        %------------------------------------------------------------------
        function newPolyDeleteFcn(self, obj)
            % newPolyDeleteFcn - Delete poly ROI and remove from collection.
            
            if ~isvalid(self)
                % App is being destroyed...
                return
            end
            
            % (2) Remove the handle from the collection of imfreehand objects.
            % *Find the row in the table.
            figuresWithROIs = [self.hPolyROIs{:,1}];
            idx = find(figuresWithROIs == self.hFigCurrent, 1);
            if isempty(idx)
                return
            end
            % Remove the handle from the row (or the whole row if the
            % figure is being deleted).
            if ~isvalid(self.hFigCurrent) || strcmpi(self.hFigCurrent.Name, getString(message('images:colorSegmentor:MainPreviewFigure')))
                self.hPolyROIs(idx,:) = [];
                return
            end
            currentROIs = self.hPolyROIs{idx,2};
            % Check for invalid polygons. These can happen by deleting each
            % vertex one at a time
            idxArray = arrayfun(@(h) ~isvalid(h), currentROIs);
            currentROIs(idxArray) = [];

            currentROIs(currentROIs == obj) = []; 
            obj.delete();
            
            self.hPolyROIs{idx,2} = currentROIs;
            % Update mask for clustering if figure still exists
            if isvalid(self.hFigCurrent) && ~self.isProjectionApplied
                self.applyClusterROIs()
            end
            
        end
        
        %------------------------------------------------------------------
        function addPolyROIHandleToCollection(self, newROIHandle)
            % addPolyROIHandleToCollection - Keep track of the new ROI.
            % Special case for first ROI of the app.
            if isempty(self.hPolyROIs)
                self.hPolyROIs = {self.hFigCurrent, newROIHandle};
                return
            end
            % Add this ROI's handle to a new or existing row in the table.
            idx = images.internal.app.colorThresholderWeb.findFigureIndexInCollection(self.hFigCurrent,self.hPolyROIs);
            if isempty(idx)
                self.hPolyROIs(end+1,:) = {self.hFigCurrent, newROIHandle};
            else
                self.hPolyROIs{idx,2} = [self.hPolyROIs{idx,2}, newROIHandle];
            end
            
        end
        
        %------------------------------------------------------------------
        function addFreehandROIHandleToCollection(self, newROIHandle)
            % addFreehandROIHandleToCollection - Keep track of the new ROI.
            % Special case for first ROI of the app.
            if isempty(self.hFreehandROIs)
                self.hFreehandROIs = {self.hFigCurrent, newROIHandle};
                return
            end
            % Add this ROI's handle to a new or existing row in the table.
            idx = images.internal.app.colorThresholderWeb.findFigureIndexInCollection(self.hFigCurrent,self.hFreehandROIs);
            if isempty(idx)
                self.hFreehandROIs(end+1,:) = {self.hFigCurrent, newROIHandle};
            else
                self.hFreehandROIs{idx,2} = [self.hFreehandROIs{idx,2}, newROIHandle];
            end
            
        end
        
        %------------------------------------------------------------------
        function applyROIs(self)
            
            self.isFreehandApplied = true;
            
            % Get the handles to the histograms.
            hRightPanel = findobj(self.hFigCurrent, 'tag', 'RightPanel');
            histHandles = getappdata(hRightPanel, 'HistPanelHandles');
            
            if ~images.internal.app.colorThresholderWeb.hasValidROIs(self.hFigCurrent,self.hFreehandROIs)
                self.resetSliders()
                self.isFreehandApplied = false;
                return
            end
            
            % Get the new selection from the ROI values.
            cData = getappdata(hRightPanel, 'ColorspaceCData');
            [lim1, lim2, lim3] = colorStats(self, cData);
            
            if (isempty(lim1) || isempty(lim2) || isempty(lim3))
                self.isFreehandApplied = false;
                return
            end
            
            % Update the histograms' current selection and mask.
            histHandles{1}.currentSelection = lim1;
            histHandles{1}.updateHistogram();
            histHandles{2}.currentSelection = lim2;
            histHandles{2}.updateHistogram();
            histHandles{3}.currentSelection = lim3;
            histHandles{3}.updateHistogram();
            
            
            if ~self.isLiveUpdate.Value
                delete(self.hSliderMovedListener);
                self.hSliderMovedListener = [];
                self.updateMask(cData, histHandles{:})
            end
            
            if ~self.hHidePointCloud.Value
                self.applyClusterROIs();
            end
            
            self.isFreehandApplied = false;
            
        end
        
        %------------------------------------------------------------------
        function applyClusterROIs(self)
            % applyClusterROIs - Apply all polygons drawn on 2D projection
            % to the mask
            
            % Get the handles to the Right Panel and point cloud
            hRightPanel = findobj(self.hFigCurrent, 'tag', 'RightPanel');
            im = getappdata(hRightPanel,'TransformedCDataForCluster');
            
            % Get the new selection from the ROI values
            if ~images.internal.app.colorThresholderWeb.hasValidROIs(self.hFigCurrent,self.hPolyROIs)
                self.updateClusterMask();
                if self.is3DView
                    self.hColorSpaceProjectionView.updatePointCloud(self.sliderMask);
                else
                    self.updatePointCloud();
                end
                return
            end
            
            % Get all ROIs for this figure
            hROIs = images.internal.app.colorThresholderWeb.findROIs(self.hFigCurrent,self.hPolyROIs);
            
            imgSize = size(self.imRGB);
            bw = false(imgSize(1:2));
            
            % Apply each valid ROI to mask
            for p = 1:numel(hROIs)
                % If polygon has 1-2 points, do not apply to mask
                if isvalid(hROIs(p))
                    hPoints = hROIs(p).Position;
                    % Handle polygon edge cases
                    if size(hPoints,1) == 1
                        % Don't allow any 1-vertex polygon.
                        delete(hROIs(p));
                        return
                    end
                    % Find points inside polygon and apply them to mask
                    in = images.internal.inpoly(im(:,1),im(:,2),hPoints(:,1),hPoints(:,2));
                    in = reshape(in,size(bw));
                    bw = bw | in;
                end
            end
            
            % Update mask with new mask created here
            self.updateClusterMask(bw);
            self.updatePointCloud();
            
        end
        
        %------------------------------------------------------------------
        function [lim1, lim2, lim3] = colorStats(self, cData)
            % colorStats - Compute limits of colors within ROIs
            
            % Create a mask of pixels under the ROIs.
            hROIs = images.internal.app.colorThresholderWeb.findROIs(self.hFigCurrent,self.hFreehandROIs);
            
            imgSize = size(cData);
            bw = false(imgSize(1:2));
            
            for p = 1:numel(hROIs)
                if isvalid(hROIs(p))
                    bw = bw | hROIs(p).createMask(cData);
                end
            end
            
            % Compute color min and max for pixels under the mask.
            samplesInROI = samplesUnderMask(cData, bw);
            
            lim1 = computeHLim(samplesInROI(:,1));
            lim2 = [min(samplesInROI(:,2)), max(samplesInROI(:,2))];
            lim3 = [min(samplesInROI(:,3)), max(samplesInROI(:,3))];
            
        end
        
        %------------------------------------------------------------------
        function hideOtherROIs(self)
            % hideOtherROIs - Hide ROIs not attached to current figure.
            
            % Hide ROIs that aren't part of the current figure.
            if ~isempty(self.hFreehandROIs)
                figuresWithROIs = [self.hFreehandROIs{:,1}];
                idx = figuresWithROIs == self.hFigCurrent;
                hROIs = self.hFreehandROIs(~idx,2);
                for p = 1:numel(hROIs)
                    tmp = hROIs{p};
                    for q = 1:numel(tmp)
                        if isvalid(tmp(q))
                            set(tmp(q), 'Visible', 'off')
                            set(tmp(q), 'FaceSelectable', false)
                        end
                    end
                end
                hROIs = self.hFreehandROIs(idx,2);
                for p = 1:numel(hROIs)
                    tmp = hROIs{p};
                    for q = 1:numel(tmp)
                        if isvalid(tmp(q))
                            set(tmp(q), 'Visible', 'on')
                            set(tmp(q), 'FaceSelectable', false)
                        end
                    end
                end
            end
            
        end
        
        %------------------------------------------------------------------
        function stateVec = getStateOfLassoSensitiveTools(self)
            vecLength = numel(self.lassoSensitiveComponentHandles);
            stateVec = false(1, vecLength);
            
            for idx = 1:vecLength
                stateVec(idx) = self.lassoSensitiveComponentHandles{idx}.Enabled;
            end
        end
        
        %------------------------------------------------------------------
        function disableLassoSensitiveTools(self)
            vecLength = numel(self.lassoSensitiveComponentHandles);
            
            for idx = 1:vecLength
                self.lassoSensitiveComponentHandles{idx}.Enabled = false;
            end
        end
        
        %------------------------------------------------------------------
        function enableLassoSensitiveTools(self, stateVec)
            vecLength = numel(self.lassoSensitiveComponentHandles);
            
            for idx = 1:vecLength
                self.lassoSensitiveComponentHandles{idx}.Enabled = stateVec(idx);
            end
        end
    end
    
    % Callback functions used by uicontrols in colorSegmentor app
    methods (Access = private)
        
        function loadImageFromFile(self,varargin)
            
            user_canceled_import = ...
                self.showImportingDataWillCauseDataLossDlg(...
                getString(message('images:colorSegmentor:loadingNewImageMessage')), ...
                getString(message('images:colorSegmentor:loadingNewImageTitle')));
            if ~user_canceled_import
                
                filename = imgetfile();

                self.bringToFront();
                if ~isempty(filename)
                    
                    im = imread(filename);
                    if ~images.internal.app.colorThresholderWeb.ColorSegmentationTool.isValidRGBImage(im)
                        
                        uialert(self.App, getString(message('images:colorSegmentor:nonTruecolorErrorDlgText')),...
                                 getString(message('images:colorSegmentor:nonTruecolorErrorDlgTitle')));
                        
                        return;
                    end
                    
                    self.importImageData(im);
                    
                end
            end
        end
        
        function loadImageFromWorkspace(self,varargin)
            
            user_canceled_import = ...
                self.showImportingDataWillCauseDataLossDlg(...
                getString(message('images:colorSegmentor:loadingNewImageMessage')), ...
                getString(message('images:colorSegmentor:loadingNewImageTitle')));
            
            if ~user_canceled_import
      
                dlg = images.internal.app.utilities.VariableDialog(imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.App)...
                    ,getString(message('images:privateUIString:importFromWorkspace')),getString(message('images:segmenter:variables')),'trueColorImage');
                wait(dlg);
                
                if ~dlg.Canceled
                    im = evalin('base',dlg.SelectedVariable);
                    self.importImageData(im);
                end
                
            end
            
        end
        
        function loadImageFromCamera(self, varargin)
            
            user_canceled_import = ...
                self.showImportingDataWillCauseDataLossDlg(...
                getString(message('images:colorSegmentor:loadingNewImageMessage')), ...
                getString(message('images:colorSegmentor:loadingNewImageTitle')));
            
            if ~user_canceled_import
                loc = imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.App); 
                dlgSize = [800 600];
                
                dlg =  images.internal.app.colorThresholderWeb.ImageCaptureDialog(dlgSize, loc);

                if isempty(dlg.FigureHandle)
                    return;
                end
                
                wait(dlg);

                if(~dlg.Canceled)
                    im = dlg.getCapturedImage();
                    self.importImageData(im);
                end
                
            end
            

        end
        
        function compareColorSpaces(self)
            % Bring up and setup the colorspace montage tab
            
            % Manage settings for Choose Color Space tab
            self.setControlsEnabled(false);
            self.hColorSpacesButton.Enabled = false;
            
            % Enable button to change background color
            if self.LightWeightMode
                self.hPointCloudBackgroundSlider.Enabled = false;
            else
                self.hPointCloudBackgroundSlider.Enabled = true;
            end
            
            % Check if current montage view already exists
            if self.hasCurrentValidMontageInstance()
                close(self.hColorSpaceMontageView.hFigDocument);
                self.hColorSpaceMontageView.delete();
            end
                
            % Create the colorspace montage view
            self.hColorSpaceMontageView = images.internal.app.colorThresholderWeb.ColorSpaceMontageViewWeb(self.App,self.imRGB,self.pointCloudColor,self.rotatePointer, self.StatusBar);
            % Setup the close function
            self.hColorSpaceMontageView.hFigDocument.CanCloseFcn = @(~,~)figureDocumentClose(self);
            % Add a listener for Property change event. This is done to
            % trigger toolstrip setup every time a new tab is activated 
            % (by listening on the document.Selected property)
            addlistener(self.hColorSpaceMontageView.hFigDocument, 'PropertyChanged', @self.figureDocumentActivated );

            % We maintain the reference to a listener for
            % SelectedColorSpace PostSet in ColorSegmentationTool to create
            % a new document tab when the color space is selected
            self.colorspaceSelectedListener = event.proplistener(self.hColorSpaceMontageView,...
                self.hColorSpaceMontageView.findprop('SelectedColorSpace'),...
                'PostSet',@(hobj,evt) self.colorSpaceSelectedCallback(evt));

            
        end
        
        function getClusterProjection(self,camPosition,camVector)
            
            % Get data needed for ColorSpaceProjectionView object
            csname = self.hFigCurrent.Tag;
            hPanel = findobj(self.hFigCurrent, 'tag', 'RightPanel');
            isHidden = self.hHidePointCloud.Value;
            
            hProjectionView = images.internal.app.colorThresholderWeb.ColorSpaceProjectionView(hPanel,self.hFigCurrent,self.imRGB,csname,camPosition,camVector,self.pointCloudColor,isHidden);
            
            tb = hProjectionView.hAxGamut.Toolbar;
            
            self.hPolygonButton = axtoolbarbtn(tb,'state', 'Tag', 'ProjectButton');
            self.hPolygonButton.Icon = self.polyIcon;
            self.hPolygonButton.ValueChangedFcn = @(hobj,evt) self.applyTransformation(hobj,evt);

            
            setappdata(hPanel,'ProjectionView',hProjectionView);
            self.hColorSpaceProjectionView = hProjectionView;
            
        end
        
        function changeViewState(self)
            
            % Change view state of 2D Panel
            hPanel = findobj(self.hFigCurrent,'Tag','ColorProj');
            if strcmp(get(hPanel,'Visible'),'off')
                set(hPanel,'Visible','on')
            else
                set(hPanel,'Visible','off')
            end
            
            % Change view state of 3D Panel
            self.hColorSpaceProjectionView.view3DPanel()
            
        end
        
        function colorSpaceSelectedCallback(self,evt)
            
            % Add another segmentation document to toolgroup
            selectedColorSpace = evt.AffectedObject.SelectedColorSpace;
            tMat = evt.AffectedObject.tMat;
            camPosition = evt.AffectedObject.camPosition;
            camVector = evt.AffectedObject.camVector;
            
            self.is3DView = true;
            
            selectedColorspaceData = self.computeColorspaceRepresentation(selectedColorSpace);
            self.createColorspaceSegmentationView(selectedColorspaceData,selectedColorSpace,tMat,camPosition,camVector);
            
            % Enable UI controls
            self.setControlsEnabled(true);
            if(self.LightWeightMode)
                self.disablePointCloudControls();
            end
            self.hColorSpacesButton.Enabled = true;
            self.hPointCloudBackgroundSlider.Enabled = ~self.hHidePointCloud.Value;
                        
            % Hide currently visible ROIs.
            self.hideOtherROIs()
            
        end
        
        function invertMaskButtonPress(self,~,~)
            
            self.mask = ~self.mask;
            
            % Now update graphics in imagepanel.
            self.updateMaskOverlayGraphics();
            
        end
        
        function showBinaryPress(self,hobj,~)
            
            if hobj.Value
                self.ImageObj.Alpha = 1;
                self.updateMaskOverlayGraphics();
                self.hMaskOpacitySlider.Enabled = false;
            else
                draw(self.ImageObj, self.imRGB, [], [], []);
                self.updateMaskOverlayGraphics();
                self.hMaskOpacitySlider.Enabled = true;
            end
            
        end
        
        function chooseOverlayColor(self,~,~)
            
            rgbColor = uisetcolor(getString(message('images:colorSegmentor:selectBackgroundColor')));
            
            colorSelectionCanceled = isequal(rgbColor, 0);
            if ~colorSelectionCanceled
                iconImage = zeros(16,16,3);
                iconImage(:,:,1) = rgbColor(1);
                iconImage(:,:,2) = rgbColor(2);
                iconImage(:,:,3) = rgbColor(3);
                iconImage = im2uint8(iconImage);
                
                self.hOverlayColorButton.Icon = ...
                                matlab.ui.internal.toolstrip.Icon(iconImage);

                % Set colorspace panel axes color to apply chosen overlay color.
                self.maskColor = rgbColor;
                self.updateMaskOverlayGraphics();
                
            end
            self.bringToFront();            
        end
        
        function pointCloudSliderMoved(self,~,~)
            
            self.pointCloudColor = 1 - repmat(self.hPointCloudBackgroundSlider.Value,1,3)/100;
            validHandles = self.FigureHandles(ishandle(self.FigureHandles));
            for ii = 1:numel(validHandles)
                % Use arrayfun to set background color for every client
                scatterPlots = findall(validHandles(ii),'Type','Scatter');
                arrayfun( @(h) set(h.Parent,'Color',self.pointCloudColor), scatterPlots);
                
                projHandles = findobj(validHandles(ii),'tag','ColorProj','-or','tag','proj3dpanel');
                arrayfun(@(h) set(h,'BackgroundColor',self.pointCloudColor),projHandles);
            end
            
            % Set background color for montage view if it exists
            if self.hasCurrentValidMontageInstance
                self.hColorSpaceMontageView.updateScatterBackground(self.pointCloudColor)
            end
            
        end
        
        function opacitySliderMoved(self,varargin)
            self.updateMaskOverlayGraphics();
        end
        
        % Used by exportMask button in export section
        function exportDataToWorkspace(self)
            
            maskedRGBImage = self.imRGB;
            
            % Set background pixels where BW is false to zero.
            maskedRGBImage(repmat(~self.mask,[1 1 3])) = 0;
            
            loc = imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.App); 
            
            self.ExportDialog = images.internal.app.utilities.ExportToWorkspaceDialog(loc,...
                string(getString(message("images:imExportToWorkspace:exportToWorkspace"))),...
                ["BW","maskedRGBImage", "inputImage"],...
                [string(getString(message('images:colorSegmentor:binaryMask'))),...
                string(getString(message('images:colorSegmentor:maskedRGBImage'))),...
                string(getString(message('images:colorSegmentor:inputRGBImage')))]);
            
            wait(self.ExportDialog);
            
            if ~self.ExportDialog.Canceled
                if self.ExportDialog.VariableSelected(1)
                    assignin('base',self.ExportDialog.VariableName(1),self.mask);
                end
                if self.ExportDialog.VariableSelected(2)
                    assignin('base',self.ExportDialog.VariableName(2),maskedRGBImage);
                end
                if self.ExportDialog.VariableSelected(3)
                    assignin('base',self.ExportDialog.VariableName(3),self.imRGB);
                end
            end
            
        end
        
        function reactToAppResize(self)
            if ~isempty(self.hImagePanel) && isvalid(self.hImagePanel)
                
                panelUnits = self.hImagePanel.Units;
                self.hImagePanel.Units = 'pixels';
                
                axToolbarHeight = 20;
                border = 10;
                panelSize = self.hImagePanel.Position([3,4]);

                axPos = [border border panelSize(1)-border panelSize(2)-axToolbarHeight-border];
                self.hAxes.Position = axPos;
                
                self.hImagePanel.Units = panelUnits;

                self.ImageObj.resize();
            end

        end
        
    end
    
    methods (Static)
        
        function deleteAllTools
            imageslib.internal.apputil.manageToolInstances('deleteAll', 'colorThresholderWeb');
        end
        
        function TF = isValidRGBImage(im)
            
            supportedDataType = isa(im,'uint8') || isa(im,'uint16') || isfloat(im);
            supportedAttributes = isreal(im) && all(isfinite(im(:))) && ~issparse(im);
            supportedDimensionality = (ndims(im) == 3) && size(im,3) == 3;
            
            TF = supportedDataType && supportedAttributes && supportedDimensionality;
            
        end
        
    end
    
    methods
        
        function tabName = getFigName(self,csname)
            
            currentDocuments = self.App.getDocuments();
            
            %validHandles = self.FigureHandles(ishandle(self.FigureHandles));
            
            names = cellfun(@(h) get(h,'Title'),currentDocuments);
            
            idx = strncmpi(csname,names, 3);
            
            if ~any(idx)
                tabName = csname;
            else
                inc = 2;
                while any(idx)
                    newname = [csname ' ' num2str(inc)];
                    idx = strcmpi(newname,names);
                    inc = inc+1;
                end
                tabName = newname;
            end
            
        end
        
        function applyTransformation(self,~,~)
            % applyTransformation - Apply current view to the 2D
            % projection
            
            % Catch double clicks
            if ~self.is3DView
                return
            end
            
            self.is3DView = false;
            
            hPanel = findobj(self.hFigCurrent, 'Tag', 'RightPanel');
            self.hProjPolygonButton.Value = 1;
            
            % Get new transformation matrix
            [tMat, xlim, ylim] = self.hColorSpaceProjectionView.customProjection();
            
            % Save new transformation matrix
            setappdata(hPanel,'TransformationMat',tMat);
            
            % Apply transformation matrix
            im = getappdata(hPanel,'ColorspaceCDataForCluster');
            tMat = tMat(1:2,:);
            im = [im ones(size(im,1),1)]';
            im = (tMat*im)';
            
            setappdata(hPanel,'TransformedCDataForCluster',im);
            
            % Update point cloud with new projection
            self.updatePointCloud(xlim, ylim);
            
            self.changeViewState()
            
            self.polyRegionForClusters()
                        
        end
        
        function show3DViewState(self)
            
            if images.internal.app.colorThresholderWeb.hasValidROIs(self.hFigCurrent,self.hPolyROIs)
                % Add dialog box to ensure user wants to remove polygons
                
                msg = getString(message('images:colorSegmentor:rotateColorSpaceMessage'));
                title = getString(message('images:colorSegmentor:removePolygons'));
                
                buttonName = uiconfirm(self.App, msg, title,...
                                       'Options',{getString(message('images:commonUIString:yes')),...
                                       getString(message('images:commonUIString:cancel'))},...
                                       'DefaultOption', 2, 'CancelOption', 2);
                                   
                
                if strcmp(buttonName,getString(message('images:commonUIString:yes')))
                    self.isProjectionApplied = true;
                    % Find the old ROIs for this figure and remove them
                    figuresWithROIs = [self.hPolyROIs{:,1}];
                    idx = find(figuresWithROIs == self.hFigCurrent, 1);
                    currentROIs = self.hPolyROIs{idx,2};
                    % Remove the handle from the row
                    currentROIs(1:end).delete();
                    self.isProjectionApplied = false;
                    
                    % Set the pointer to rotatePointer as as the point
                    % could can be rotated once all the polygon objects
                    % are deleted
                    hAx = findobj(self.hColorSpaceProjectionView.hPanels,'type','axes');
                    iptSetPointerBehavior(hAx,@(hObj,evt) set(hObj,'Pointer','custom','PointerShapeCData',self.rotatePointer));
                else
                    return
                end
            end
            
            self.is3DView = true;
            
            if ~isempty(self.polyManager)
                self.disablePolyRegion()
                self.polyManager = [];
            end
            
            self.hPolygonButton.Value = 0;
            
            % Update mask and point clouds
            self.updateClusterMask()
            self.hColorSpaceProjectionView.updatePointCloud(self.sliderMask);
            self.changeViewState()
            
        end
        
        function clearFreehands(self)
            % Clear all freehand ROIs
            % Turn isManualDelete off so the freehand delete function knows
            % to not update the sliders and mask
            self.isManualDelete = false;
            if images.internal.app.colorThresholderWeb.hasValidROIs(self.hFigCurrent,self.hFreehandROIs)
                figuresWithROIs = [self.hFreehandROIs{:,1}];
                idx = figuresWithROIs == self.hFigCurrent;
                hROIs = self.hFreehandROIs(idx,2);
                numFreehands = numel(hROIs);
                for p = 1:numFreehands
                    hFree = hROIs{numFreehands-p+1};
                    hFree.delete();
                end
            end
            self.isManualDelete = true;
            
        end
        
        function buttonClicked(self, TF)
            self.isFigClicked = TF;
        end

        function bringToFront(self)
            if ispc || ismac
                self.App.bringToFront();
            end
        end
        
    end
    
end

%--------------------------------------------------------------------------
function triples = samplesUnderMask(img, mask)

triples = zeros([nnz(mask) 3], 'like', img);

for channel=1:3
    theChannel = img(:,:,channel);
    triples(:,channel) = theChannel(mask);
end
end

%--------------------------------------------------------------------------
function hLim = computeHLim(hValues)

% Divide the problem space in half and use some heuristics to decide
% whether there is one region or if it's split around the discontinuity at
% zero.

switch (class(hValues))
    case {'single', 'double'}
        lowerRegion = hValues(hValues < 0.5);
        upperRegion = hValues(hValues >= 0.5);
        
        if isempty(lowerRegion) || isempty(upperRegion)
            bimodal = false;
        elseif (min(lowerRegion) > 0.04) || (max(upperRegion) < 0.96)
            bimodal = false;
        elseif (min(upperRegion) - max(lowerRegion)) > 1/3
            bimodal = true;
        else
            bimodal = false;
        end
        
    case {'uint8'}
        lowerRegion = hValues(hValues < 128);
        upperRegion = hValues(hValues >= 128);
        
        if isempty(lowerRegion) || isempty(upperRegion)
            bimodal = false;
        elseif (min(lowerRegion) > 10) || (max(upperRegion) < 245)
            bimodal = false;
        elseif (min(upperRegion) - max(lowerRegion)) > 255/3
            bimodal = true;
        else
            bimodal = false;
        end
        
    case {'uint16'}
        lowerRegion = hValues(hValues < 32896);
        upperRegion = hValues(hValues >= 32896);
        
        if isempty(lowerRegion) || isempty(upperRegion)
            bimodal = false;
        elseif (min(lowerRegion) > 2570) || (max(upperRegion) < 62965)
            bimodal = false;
        elseif (min(upperRegion) - max(lowerRegion)) > 65535/3
            bimodal = true;
        else
            bimodal = false;
        end
        
    otherwise
        assert(false,'Data type not supported');
end

if (bimodal)
    hLim = [min(upperRegion), max(lowerRegion)];
else
    hLim = [min(hValues), max(hValues)];
end
end

%------------------------------------------------------------------
function polyIcon = setUIControlIcon(filename)

% Set CData for uicontrol button from icon
[polyIcon,~,transparency] = imread(filename);
polyIcon = double(polyIcon)/255;
transparency = double(transparency)/255;
% 0.94 corresponds to the default background color for uicontrol buttons
polyIcon(:,:,1) = polyIcon(:,:,1) + (0.94-polyIcon(:,:,1)).*(1-transparency);
polyIcon(:,:,2) = polyIcon(:,:,2) + (0.94-polyIcon(:,:,2)).*(1-transparency);
polyIcon(:,:,3) = polyIcon(:,:,3) + (0.94-polyIcon(:,:,3)).*(1-transparency);
polyIcon(transparency == 0) = NaN;

end
