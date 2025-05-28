classdef Histogram < handle & matlab.mixin.SetGet
    %
    
    % Copyright 2020-2023 The MathWorks, Inc.
    
    events
        ContrastChanged
    end
    
    properties(Access=public, Dependent)
        SelectedHistRange (1, 2) double

        % Number of bins used to compute the Histogram
        NumBins {mustBePositive, mustBeInteger}
    end

    properties
        Interactive (1,1) logical = false
        Visible (1,1) logical = true

        % Specify whether the hist range specified by the user OR data
        % bounds are to be used as limits when creating the interaction
        % handles. Each client of this module has different requirements
        UseDataBoundsAsDefaultInteractionLimits (1, 1) logical = true

        % Specify the minimum gap that must be present between the min and
        % max markers
        MinGapBetweenMinMaxMarkers (1, 1) double = 0;
    end

    properties (SetAccess = private, ...
                GetAccess = {?uitest.factory.Tester,...
                             ?images.uitest.TesterFactory.Tester, ...
                             ?imtest.apptest.imageViewerTest.PropertyAccessProvider}, Hidden, Transient)
        Panel matlab.ui.container.Panel
        Axes
        HistogramObject matlab.graphics.chart.primitive.Histogram
        
        hPatch matlab.graphics.primitive.Patch
        hPatchLeft matlab.graphics.primitive.Patch
        hPatchRight matlab.graphics.primitive.Patch
        hMarkerMin matlab.graphics.primitive.Rectangle
        hMarkerMax matlab.graphics.primitive.Rectangle
        
        InteractionHandles
        Tag = 'Histogram';
    end
    
    
    properties (Access = private, Hidden, Transient)
        
        FullHistRange (1,2) double = [0,0];
        
        MaxBinCount (1,1) double {mustBeNonnegative} = 0;
        PrevDragX (1,1) double
        MinMaxMarkerWidth (1,1) double
        
        MouseMotionListener
        MouseReleaseListener
        
        MainPatchMovedListener
        MinMarkedMovedListener
        MaxMarkerMovedListener

    end
    
    
    properties (Access=private)
        SelectedHistRangeInternal (1,2) double = [0 0];

        % Implementation of the user visible NumBins property. An empty
        % value indicates user has not specified any value.
        NumBinsInternal double {mustBePositive, mustBeInteger} = []
    end
    
    
    properties (Transient)
        Enable
    end
    

    methods
        
        function self = Histogram(hfig, options)
            arguments
                hfig
                options.NumBins (1, 1) double {mustBePositive, mustBeInteger}
            end
            % Use desktop theme for figure
            matlab.graphics.internal.themes.figureUseDesktopTheme(hfig);
            
            pos = [1 1 hfig.Position(3), hfig.Position(4)];

            self.Panel = uipanel('Parent',hfig,...
                'BorderType','line',...
                'Units','pixels',...
                'HandleVisibility','off',...
                'Position',pos,...
                'Tag','HistogramPanel',...
                'Visible','off',...
                'AutoResizeChildren','off',...
                'SizeChangedFcn',@(~,~) self.reactToAppResize());

            % Border in pixels
            panelSize = self.Panel.Position([3 4]);
            pos = getHistAxesPosition(panelSize);
            
            self.Axes = axes('Parent',self.Panel,...
                'Units','pixels',...
                'XTick',[],...
                'YTick',[],...
                'ZTick',[],...
                'Tag','HistogramAxes',...
                'HandleVisibility','off',...
                'Position',pos);
            
            if ~isfield(options, "NumBins")
                % Indicates the number of bins is not specified during
                % construction
                self.HistogramObject = histogram(ones(100),'Parent',self.Axes,...
                    'BinMethod','auto',...
                    'EdgeColor',[0 0 0],...
                    'FaceColor',[0 0 0],...
                    'HandleVisibility','off',...
                    'Tag','HistogramObject');
                self.NumBinsInternal = [];
            else
                % Use the number of bins specified during construction to
                % create the histogram
                self.HistogramObject = histogram(ones(100), options.NumBins, ...
                    'Parent',self.Axes,...
                    'BinMethod','auto',...
                    'EdgeColor',[0 0 0],...
                    'FaceColor',[0 0 0],...
                    'HandleVisibility','off',...
                    'Tag','HistogramObject');
                self.NumBinsInternal = options.NumBins;
            end
                        
            xlabel(self.Axes, getString(message('images:histogramDisplay:intensity')));
            self.Axes.FontSize = 8;
            
            self.Axes.Toolbar = [];
            disableDefaultInteractivity(self.Axes);

            addlistener(hfig,'ThemeChanged',@(src,~) self.onThemeChanged(src));
            
        end
        
        function delete(self)
            delete(self.InteractionHandles);
            delete(self.HistogramObject);
            delete(self);
        end
        
        function reset(self, dataLimits)
            self.HistogramObject.BinLimits = dataLimits + [-0.5 0.5];
            self.FullHistRange = dataLimits;
            self.MinGapBetweenMinMaxMarkers = 0;
            
            self.Interactive = false;
            
            if isgraphics(self.InteractionHandles)
                delete(self.InteractionHandles);
                self.InteractionHandles = [];
            end
            
            self.Enable = 'on';
        end
        
        function resize(self)
            if isvalid(self.Panel)
                hfig = ancestor(self.Panel,'figure');
                if isa(getCanvas(self.Panel),'matlab.graphics.primitive.canvas.HTMLCanvas')
                    self.Panel.Position([3,4]) = [hfig.InnerPosition(3), hfig.InnerPosition(4)];
                else
                    self.Panel.Position([3,4]) = [hfig.Position(3)*0.3, hfig.Position(4)];
                end

                pos = getHistAxesPosition(self.Panel.Position(3:4));
                self.Axes.Position = pos;
            end
        end
        
        function update(self, band)
            self.HistogramObject.Data = band;
            if isempty(self.NumBinsInternal)
                % Indicates client has not specified number of bins
                self.HistogramObject.BinMethod = 'auto';
            else
                % Use the client specified number of bins.
                % Setting the NumBins property changes the BinMethod to
                % "manual". Hence using separate code paths.
                self.HistogramObject.NumBins = self.NumBinsInternal;
            end
            self.MaxBinCount = max(self.HistogramObject.BinCounts);

            % Floating point data is in the range [0, 1]. So adding 0.5 to
            % the axes limits leaves a lot of white space. Specify the axes
            % limits based on the datatype
            if isfloat(band)
                self.Axes.XLim = self.FullHistRange + [-1 1]*eps('double');
            else
                self.Axes.XLim = self.FullHistRange + [-1 1]*0.5;
            end
            
            if self.Interactive
                self.Axes.YLim(2) = self.MaxBinCount;
                self.updatePatchHeight()
            end
            
        end
        
        function snapToCurrentBand(self)
            [histRangeMin, histRangeMax] = bounds(self.HistogramObject.Data(:));
            self.updateAllInteractionHandles(histRangeMin, histRangeMax);
        end

        function onThemeChanged(self,src)
            self.Axes.XColor = src.Theme.BaseTextColor;
            self.Axes.YColor = src.Theme.BaseTextColor;
            if isequal(self.Enable,'on')
                self.HistogramObject.EdgeColor = src.Theme.BaseTextColor;
                self.HistogramObject.FaceColor = src.Theme.BaseTextColor;
            else
                self.HistogramObject.EdgeColor = src.Theme.ContainerColor;
                self.HistogramObject.FaceColor = src.Theme.ContainerColor;
            end
        end

    end
    
    
    % Set/Get 
    methods
        
        function set.Interactive(self, TF)
            
            if TF
                self.Interactive = true;
                if isempty(self.InteractionHandles) %#ok<*MCSUP>
                    self.createInteractionPatch();
                end
                self.enableInteractions();
                
            else
                self.Interactive = false;
                if isgraphics(self.InteractionHandles)
                    self.disableInteractions();
                end
                
            end
        end
        
        function set.Enable(self, enable)
            hFig = ancestor(self.Axes,'figure');
            if isequal(enable, 'on')
                self.Axes.XColor = hFig.Theme.BaseTextColor;
                self.Axes.YColor = hFig.Theme.BaseTextColor;
                self.HistogramObject.EdgeColor = hFig.Theme.BaseTextColor;
                self.HistogramObject.FaceColor = hFig.Theme.BaseTextColor;
                self.HistogramObject.PickableParts = 'visible';
                if self.Interactive
                    self.enableInteractions();
                end
            else
                self.HistogramObject.EdgeColor = hFig.Theme.ContainerColor;
                self.HistogramObject.FaceColor = hFig.Theme.ContainerColor;
                self.HistogramObject.PickableParts = 'none';
                if isgraphics(self.InteractionHandles)
                    self.disableInteractions();
                end
            end
            
            self.Enable = enable;
        end
        
        function set.Visible(self, TF)
            
            if TF
                self.Panel.Visible = 'on';
            else
                self.Panel.Visible = 'off';
            end
            self.Visible = TF;
        end

        function set.SelectedHistRange(self, hrange)
            arguments
                self (1, 1) images.internal.app.utilities.Histogram
                hrange (1, 2) {mustBeReal, mustBeFinite}
            end

            validateattributes(hrange, "numeric", "increasing");

            self.SelectedHistRangeInternal = hrange;

            if ~isempty(self.hPatch)
                self.updateAllInteractionHandles(hrange(1), hrange(2), false);
            end

        end

        function hrange = get.SelectedHistRange(self)
            hrange = self.SelectedHistRangeInternal;
        end

        function set.NumBins(self, numBins)
            % Store the user specified numBins value
            self.NumBinsInternal = numBins;

            % This is a mechanism for the user to reset the binning method
            % to the default value.
            if isempty(numBins)
                self.HistogramObject.BinMethod = "auto";
            else
                self.HistogramObject.NumBins = numBins;
            end
        end

        function numBins = get.NumBins(self)
            numBins = self.HistogramObject.NumBins;
        end
    end
    
    
    % Interaction Patch
    methods (Access = private, Hidden)
        
        function createInteractionPatch(self)
            
            %      -------------------------------------------------------
            %     |               |                         |             |
            %     |              {|} -> MinMarker           |             |
            %     |               |                         |             |
            %     |   LeftPatch   |       Main Patch        | Right Patch |
            %     |               |                         |             |
            %     |               |           MaxMarker <- {|}            |
            %     |               |                         |             |
            %      -------------------------------------------------------
            
            yLim = self.Axes.YLim;
            faceAlpha = 0.1; % If FaceAlpha is 0, 'Hit' event is not fired
            edgeAlpha = 0.4;
            selectorBorderThickness = 3;
            
            binLimits = self.HistogramObject.BinLimits + [0.5 -0.5];
            
            if self.UseDataBoundsAsDefaultInteractionLimits
                [minCurrentBand, maxCurrentBand] = bounds(self.HistogramObject.Data(:));
            else
                minCurrentBand = self.SelectedHistRangeInternal(1);
                maxCurrentBand = self.SelectedHistRangeInternal(2);
            end
            
            self.SelectedHistRangeInternal = [minCurrentBand, maxCurrentBand];
            self.MaxBinCount = max(self.HistogramObject.BinCounts);
            
            % X and Y cordinates of all the patches are as follows:
            %
            % 2------3
            % |      |
            % |      |
            % |      |
            % 1------4
            
            self.hPatch = patch([minCurrentBand, minCurrentBand, maxCurrentBand, maxCurrentBand],...
                [0, max(yLim(2),self.MaxBinCount), max(yLim(2),self.MaxBinCount), 0],...
                [1,1,1],...
                'Parent',self.Axes,...
                'LineWidth', selectorBorderThickness, ...
                'EdgeColor',[0 0 0],...
                'EdgeAlpha', edgeAlpha,...
                'FaceAlpha', faceAlpha,...
                'PickableParts','visible',...
                'Tag', 'HistogramMainPatch');
            
            deselectedFaceColor = [0 0 0];
            deselectedFaceAlpha = 0.2;
            
            self.hPatchLeft = patch([binLimits(1), binLimits(1), minCurrentBand-1, minCurrentBand-1],...
                [0, max(yLim(2),self.MaxBinCount), max(yLim(2),self.MaxBinCount), 0],...
                deselectedFaceColor,...
                'Parent', self.Axes, ...
                'EdgeColor', deselectedFaceColor, ...
                'EdgeAlpha', deselectedFaceAlpha, ...
                'FaceAlpha', deselectedFaceAlpha, ...
                'PickableParts','visible',...
                'Tag','DeselectedLeftPatch');

            self.hPatchRight = patch([maxCurrentBand+1, maxCurrentBand+1, binLimits(2), binLimits(2)],...
                [0,max(yLim(2),self.MaxBinCount), max(yLim(2),self.MaxBinCount), 0],...
                deselectedFaceColor,...
                'Parent', self.Axes, ...
                'EdgeColor', deselectedFaceColor, ...
                'EdgeAlpha', deselectedFaceAlpha, ...
                'FaceAlpha', deselectedFaceAlpha, ...
                'PickableParts','visible',...
                'Tag','DeselectedRightPatch');

            minMaxMarkerHeight = 0.2 * self.MaxBinCount;
            minMaxMarkerWidth = 0.02 * diff(binLimits);
            
            minHandleYLoc = 0.45 * self.MaxBinCount - (minMaxMarkerHeight/2);
            maxHandleYLoc = 0.7 * self.MaxBinCount - (minMaxMarkerHeight/2);
            
            blueSlectionColor = '#0095ff';
            self.hMarkerMin = rectangle('Parent',self.Axes,...
                'Curvature',0.2,...
                'Position',[minCurrentBand-minMaxMarkerWidth, minHandleYLoc, 2*minMaxMarkerWidth, minMaxMarkerHeight],...
                'FaceColor',blueSlectionColor,...
                'PickableParts','visible',...
                'Tag','HistogramMinMarker');
            
            self.hMarkerMax = rectangle('Parent',self.Axes,...
                'Curvature',0.2,...
                'Position',[maxCurrentBand-minMaxMarkerWidth, maxHandleYLoc, 2*minMaxMarkerWidth, minMaxMarkerHeight],...
                'FaceColor',blueSlectionColor,...
                'PickableParts','visible',...
                'Tag','HistogramMaxMarker');
            
            % Store all handles related to contrast interactions in an
            % array for easily toggling the visibility
            self.InteractionHandles = [self.hPatch, self.hPatchLeft,...
                self.hPatchRight, self.hMarkerMin, self.hMarkerMax];
            
            hfig = ancestor(self.Axes,'figure');
            hfig.WindowButtonMotionFcn = @(~,~) self.emptyCallback();
            
            self.MouseMotionListener = addlistener(hfig, 'WindowMouseMotion', @(src,evt) self.managePointer(src,evt));
            self.MouseMotionListener.Enabled = false;
            
            addlistener(self.hPatch, 'Hit', @(~,evt) self.mainPatchClicked(evt));
            addlistener(self.hMarkerMin, 'Hit', @(~,~) self.minMarkerClicked());
            addlistener(self.hMarkerMax, 'Hit', @(~,~) self.maxMarkerClicked());
            
            self.MainPatchMovedListener = addlistener(hfig, 'WindowMouseMotion', @(~,evt) self.mainPatchMoved(evt));
            self.MinMarkedMovedListener = addlistener(hfig, 'WindowMouseMotion', @(~,evt) self.minMarkerMoved(evt));
            self.MaxMarkerMovedListener = addlistener(hfig, 'WindowMouseMotion', @(~,evt) self.maxMarkerMoved(evt));
            self.MainPatchMovedListener.Enabled = false;
            self.MinMarkedMovedListener.Enabled = false;
            self.MaxMarkerMovedListener.Enabled = false;
            
            self.MouseReleaseListener = addlistener(hfig, 'WindowMouseRelease', @(~,~) self.mouseRelease());
            self.MouseReleaseListener.Enabled = false;
        end
        
        function enableInteractions(self)
            % Update interaction handles to reflect the current band
            histRangeMin = self.SelectedHistRangeInternal(1);
            histRangeMax = self.SelectedHistRangeInternal(2);
            
            self.updateAllInteractionHandles(histRangeMin, histRangeMax);
            
            set(self.InteractionHandles, 'Visible','on');
            self.MouseMotionListener.Enabled = true;
        end
        
        function disableInteractions(self)
            % Update interaction handles to reflect the current band
            
            set(self.InteractionHandles, 'Visible','off');
            self.MouseMotionListener.Enabled = false;
        end
        
    end
    
    
    % Callbacks
    methods (Access = private, Hidden)
        
        function managePointer(self, src, evt)
            % TODO : Rip out all the pointer management for the App to the
            % view level
            
            % Implementation leak: The Histogram also has to manager
            % 'BandPicker' pointer management and vice versa as both of
            % them reside in the same figure. Histogram has to check for
            % primitive line objects from BandPicker. Moving all the
            % pointer management to view should fix this design
            
            if isOnAxesToolbar(self,evt)
                images.roi.setBackgroundPointer(src,'arrow');
                
            elseif isa(evt.HitObject,'matlab.graphics.chart.primitive.Line') && ~isModeManagerActive(self)
                images.roi.setBackgroundPointer(src,'east');
                
            elseif (isequal(evt.HitObject.Tag, 'HistogramMinMarker') ||...
                    isequal(evt.HitObject.Tag, 'HistogramMaxMarker')) && ~isModeManagerActive(self)
                images.roi.setBackgroundPointer(src,'east');
                
            elseif isequal(evt.HitObject.Tag, 'HistogramMainPatch') && ~isModeManagerActive(self)
                images.roi.setBackgroundPointer(src,'drag');
                
            else
                images.roi.setBackgroundPointer(src,'arrow');
            end
            
        end

        function mainPatchClicked(self, evt)
            self.MouseMotionListener.Enabled = false;
            
            hfig = ancestor(evt.Source, 'figure');
            self.PrevDragX = hfig.CurrentAxes.CurrentPoint(1);
            self.MainPatchMovedListener.Enabled = true;
            
            self.MouseReleaseListener.Enabled = true;
            
        end
        
        function minMarkerClicked(self)
            self.MouseMotionListener.Enabled = false;
            
            self.MinMarkedMovedListener.Enabled = true;
            
            self.MouseReleaseListener.Enabled = true;
            
        end
        
        function maxMarkerClicked(self)
            self.MouseMotionListener.Enabled = false;
            
            self.MaxMarkerMovedListener.Enabled = true;
            
            self.MouseReleaseListener.Enabled = true;
            
        end
        
        function mainPatchMoved(self, evt)
            
            minX = self.SelectedHistRangeInternal(1);
            maxX = self.SelectedHistRangeInternal(2);
            
            newX = evt.Source.CurrentAxes.CurrentPoint(1);
            deltaX = newX - self.PrevDragX;
            self.PrevDragX = newX;
            
            newMinX = minX + deltaX;
            newMaxX = maxX + deltaX;
            
            if newMinX < self.FullHistRange(1)
                newMinX = self.FullHistRange(1);
                newMaxX = newMinX + (maxX - minX);
            end
            
            if newMaxX > self.FullHistRange(2)
                newMaxX = self.FullHistRange(2);
                newMinX = newMaxX - (maxX - minX);
            end
            
            self.updateAllInteractionHandles(newMinX, newMaxX);
            
        end
        
        function minMarkerMoved(self, evt)
            
            minAllowed = self.HistogramObject.BinLimits(1) + 0.5;
            maxAllowed = self.SelectedHistRangeInternal(2) - self.MinGapBetweenMinMaxMarkers;
            
            xPos = evt.Source.CurrentAxes.CurrentPoint(1);
            
            if xPos > maxAllowed
                xPos = maxAllowed;
            end
            
            if xPos < minAllowed
                xPos = minAllowed;
            end
            
            self.updateAllInteractionHandles(xPos, self.SelectedHistRangeInternal(2));
            
        end
        
        function maxMarkerMoved(self, evt)
            
            minAllowed = self.SelectedHistRangeInternal(1) + self.MinGapBetweenMinMaxMarkers;
            maxAllowed = self.HistogramObject.BinLimits(2) - 0.5;
            
            xPos = evt.Source.CurrentAxes.CurrentPoint(1);
            
            if xPos > maxAllowed
                xPos = maxAllowed;
            end
            
            if xPos < minAllowed
                xPos = minAllowed;
            end
            
            self.updateAllInteractionHandles(self.SelectedHistRangeInternal(1), xPos);
            
        end
        
        function mouseRelease(self)
            self.MainPatchMovedListener.Enabled = false;
            self.MinMarkedMovedListener.Enabled = false;
            self.MaxMarkerMovedListener.Enabled = false;
            self.MouseReleaseListener.Enabled = false;
            
            self.MouseMotionListener.Enabled = true;
        end
        
        function reactToAppResize(self)
            
            if isvalid(self.Panel)
                axToolbarHeight = 20; %pixels
                border = 30; %pixels
                panelSize = self.Panel.Position([3 4]);
                
                axBottomStart = 1.5*border;
                posAx = [border, axBottomStart, (panelSize(1)-(2*border)),...
                    panelSize(2)-axToolbarHeight-axBottomStart-border/2];
                posAx = max(posAx,1);
                self.Axes.Position = posAx;
            end
        end
        
    end
    
    
    % Utility Intercation Patch
    methods (Access = private, Hidden)
        
        function updateAllInteractionHandles(self, histRangeMin, histRangeMax, isNotify)
            arguments
                self (1, 1) images.internal.app.utilities.Histogram
                histRangeMin (1, 1)
                histRangeMax (1, 1)
                isNotify (1, 1) logical = true
            end
            
            histRangeMin = double(histRangeMin);
            histRangeMax = double(histRangeMax);

            self.hPatch.XData = [histRangeMin, histRangeMin, histRangeMax, histRangeMax];
            self.hPatchRight.XData(1:2) = [histRangeMax, histRangeMax];
            self.hPatchLeft.XData(3:4) = [histRangeMin, histRangeMin];
            self.hMarkerMin.Position(1) = histRangeMin - (self.hMarkerMin.Position(3)/2);
            self.hMarkerMax.Position(1) = histRangeMax - (self.hMarkerMax.Position(3)/2);
            
            self.SelectedHistRangeInternal = [histRangeMin histRangeMax];

            if isNotify
                evtData = images.internal.app.utilities.events.ContrastAdjustEventData(self.SelectedHistRangeInternal);
                self.notify('ContrastChanged', evtData)
            end
            
        end
        
        function updatePatchHeight(self)
            axesHeight = self.Axes.YLim(2);
            
            self.hPatch.YData(2:3) = [axesHeight, axesHeight];
            self.hPatchRight.YData(2:3) = [axesHeight, axesHeight];
            self.hPatchLeft.YData(2:3) = [axesHeight, axesHeight];
            
            minMaxMarkerHeight = 0.2 * self.MaxBinCount;
            minHandleYLoc = 0.45 * axesHeight - (minMaxMarkerHeight/2);
            maxHandleYLoc = 0.70 * axesHeight - (minMaxMarkerHeight/2);
            
            self.hMarkerMin.Position([2,4]) = [minHandleYLoc, minMaxMarkerHeight];
            self.hMarkerMax.Position([2,4]) = [maxHandleYLoc, minMaxMarkerHeight];
        end
        
    end
    
  % Utility
    methods(Access = private)
        
        function TF = isModeManagerActive(self)
            hManager = uigetmodemanager(ancestor(self.Axes,'figure'));
            hMode = hManager.CurrentMode;
            TF = isobject(hMode) && isvalid(hMode) && ~isempty(hMode);
        end
        
        function TF = isOnAxesToolbar(~,evt)
            TF = ~isempty(ancestor(evt.HitObject,'matlab.graphics.controls.AxesToolbar'));
        end
        
        function emptyCallback(~)
            % No-op callback During interactions, the axes property
            % CurrentPoint is only updated when the figure's
            % WindowButtonMotionFcn property is not empty.

            % We set the WindowButtonMotionFcn property to this empty
            % callback function to force the CurrentPoint property to
            % update whenever the mouse is moved during drawing.
        end
        
    end
    
end

function pos = getHistAxesPosition(panelSize)
    borderTop = 10;
    borderBottom = 30;
    borderLeft = 30;
    borderRight = 10;


    pos = [ borderLeft borderBottom ...
            (panelSize(1)-borderLeft-borderRight) ...
            (panelSize(2)-borderBottom-borderTop) ];

    if pos(3) <= 0
        pos(3) = panelSize(1);
    end

    if pos(4) <= 0
        pos(4) = panelSize(2);
    end
end
