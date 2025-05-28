classdef Overview < matlab.mixin.SetGet
% Helper class that displays the Image Overview for the ImageViewer app

% Copyright 2023 The MathWorks, Inc.
    
    properties(Access=public, Dependent)
        IsEnabled (1, 1) logical
    end

    properties(Access=private)
    IsEnabledInternal (1, 1) logical
    end

    properties (GetAccess = ?imtest.apptest.imageViewerTest.PropertyAccessProvider)
        OverviewImage = [];
        OverviewRect = [];
        ParentFigPanel = [];
    end

    properties(Access=private, Constant)
        Margin = 10
    end

    events
        OverviewRectMoving
    end

    methods

        %------------------------------------------------------------------
        % Overview
        %------------------------------------------------------------------
        function obj = Overview(app)
            createPanel(obj, app);
        end

        function draw(obj, im, label, cmap, contrastLimits)
            if ~isempty(obj.ParentFigPanel)
                draw(obj.OverviewImage, im, label, cmap, contrastLimits)
            end
        end

        function resize(obj)
            if ~isempty(obj.ParentFigPanel)
                parentPanel = obj.OverviewImage.AxesHandle.Parent;
                parentFig = parentPanel.Parent;
                parentPanel.Position = [1 1 parentFig.Position(3:4)];
                resize(obj.OverviewImage);
            end
        end


        function updatePosition(obj, xLim, yLim)
            if ~isempty(obj.ParentFigPanel)
                obj.OverviewRect.Position = [ xLim(1), yLim(1), ...
                                              xLim(2) - xLim(1), ...
                                              yLim(2) - yLim(1) ];
                if isRectOnBoundary(obj, xLim, yLim)
                    obj.OverviewRect.LineWidth = 6;
                else
                    obj.OverviewRect.LineWidth = 3;
                end
            end
        end
    end

    % Setters/Getters
    methods
        function set.IsEnabled(obj, tf)
            obj.IsEnabledInternal = tf;

            if tf
                if isempty(obj.ParentFigPanel)
                    createPanel(obj);
                end
                obj.ParentFigPanel.Opened = true;
            else
                if ~isempty(obj.ParentFigPanel)
                    obj.ParentFigPanel.Opened = false;
                end
            end
        end

        function tf = get.IsEnabled(obj)
            tf = obj.IsEnabledInternal;
        end
    end

    % Callbacks
    methods(Access=private)
        function reactToWindowKeyPress(obj, evt)
            stepSize = 3;
            pos = obj.OverviewRect.Position;
            
            xstart = pos(1); ystart = pos(2);
            rectWidth = pos(3); rectHeight = pos(4);

            xlim = obj.OverviewImage.AxesHandle.XLim;
            ylim = obj.OverviewImage.AxesHandle.YLim;

            switch(evt.Key)
                case "uparrow"
                    ystart = max(ylim(1), ystart - stepSize);
                    startPos = [xstart ystart];

                case "downarrow"
                    yend = min(ylim(2), ystart + stepSize + rectHeight);
                    ystart = yend - rectHeight;
                    startPos = [xstart ystart];

                case "leftarrow"
                    xstart = max(xlim(1), xstart - stepSize);
                    startPos = [xstart ystart];

                case "rightarrow"
                    xend = min(xlim(2), xstart + stepSize + rectWidth);
                    xstart = xend - rectWidth;
                    startPos = [xstart ystart];

                otherwise
                    startPos = pos(1:2);
            end

            newPos = [startPos rectWidth rectHeight];

            if ~isequal(newPos, obj.OverviewRect.Position)
                obj.OverviewRect.Position = newPos;
                notifyROIMoved(obj, newPos);
            end
        end

        function reactToMovingROI(obj, evt)
            notifyROIMoved(obj, evt.CurrentPosition);
        end
    end

    % Helper functions
    methods (Access = private)
        function createPanel(obj, app)
            panelOptions.Title = ...
                    getString(message("images:commonUIString:overview"));
            panelOptions.Tag = "OverviewPanel";
            panelOptions.Region = "left";
            figPanel = matlab.ui.internal.FigurePanel(panelOptions);

            set( figPanel.Figure,...
                 Units ="pixels",...
                 HandleVisibility="off",...
                 AutoResizeChildren="off" );

            addlistener( figPanel.Figure, "WindowKeyPress", ...
                         @(~, evt) reactToWindowKeyPress(obj, evt) );

            pos = [ 1 1 ...
                    figPanel.Figure.Position(3:4) ];
            imagePanel = uipanel( Parent=figPanel.Figure, ...
                            Units="pixels", ...
                            Position=pos, ...
                            BorderType="none", ...
                            Tag="OverviewPanel", ...
                            AutoResizeChildren="off" );

            obj.OverviewImage = images.internal.app.utilities.Image(imagePanel);
            obj.OverviewImage.XBorder = [5, 5];
            obj.OverviewImage.YBorder = [5, 5];
            obj.OverviewImage.ImageHandle.MaxRenderedResolution = 512;
            obj.OverviewImage.Visible = true;
            obj.OverviewImage.Enabled = true;
            obj.OverviewImage.AxesHandle.Toolbar.Visible = false;

            obj.OverviewRect = images.roi.Rectangle( FaceAlpha=0, ...
                                Parent=obj.OverviewImage.AxesHandle, ...
                                InteractionsAllowed="translate", ...
                                LineWidth=5, ...
                                Deletable=false, ...
                                ContextMenu=[] );
            setMarkersVisible(obj.OverviewRect, "off");
            addlistener( obj.OverviewRect, "MovingROI", ...
                         @(~, evt) reactToMovingROI(obj, evt) );

            app.add(figPanel);

            figPanel.Figure.SizeChangedFcn = @(~,~) resize(obj);
            obj.ParentFigPanel = figPanel;

            obj.IsEnabledInternal = true;
        end
    
        function notifyROIMoved(obj, pos)
            evtData = images.internal.app.viewer.ViewerEventData(pos);

            notify(obj, "OverviewRectMoving", evtData);
        end

        function tf = isRectOnBoundary(obj, xLim, yLim)
            tf = all(obj.OverviewImage.AxesHandle.XLim == xLim) && ...
                    all(obj.OverviewImage.AxesHandle.YLim == yLim);
        end
    end
end