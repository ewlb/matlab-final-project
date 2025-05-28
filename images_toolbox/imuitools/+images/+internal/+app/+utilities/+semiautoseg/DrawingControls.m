classdef DrawingControls < handle
% Class that manages the drawing controls available for Semi Automated
% Segmentation Techniques

    properties(Access=public)
        % Restricts clients to only draw points and not scribbles
        DrawOnlyPoints (1, 1) logical = false
    end

    properties(Access=public, Dependent)
        % Specify the drawing operation required. Supported operations are:
        % "fore", "back", "erase", "roi", "superpix", "superpixerase"
        EditMode

        % Size of the eraser
        EraserSize

        % ROI object to be drawn in "roi" mode
        % Client must configure and create the ROI instance. This class
        % will take care of drawing the object
        ROI images.roi.internal.ROI

        % Allow clients to specify if this class will listen to initial
        % mouse press to start drawing. It is possible for clients to have
        % custom mouse press listeners that do checks before commencing
        % drawing.
        DrawOnMousePress (1, 1) logical
    end


    properties(GetAccess=public, SetAccess=private, Dependent)
        % Nx2 vector containing list of all points drawn. This might
        % contain NaN values to indicate erased values. Clients must
        % eliminate NaN values before using them
        FGPoints
        BGPoints
    end

    properties(GetAccess=public, SetAccess=private)
        UIObjHandle

        % Used for super pixel drawing
        Brush (1, 1) images.roi.internal.PaintBrush;
    end

    properties(GetAccess=public, SetAccess=private, Hidden)
        % LINE objects that store the FG and BG Points Drawn
        FGLine = [];
        BGLine = [];

        % Linear indices of points drawn. Used by GrabCut/GraphCut
        BackgroundInd
        ForegroundInd
    end

    properties(Access=private)
        ImageSize

        ROIInternal images.roi.internal.ROI = images.roi.Rectangle.empty()
        EditModeInternal

        % Handle to the Axes containing the UI object provided by the
        % client
        AxesHandle

        % Handle to the figure containing the UI Object provided by client
        FigHandle

        ScribbleDrawingListener = [];
        SuperpixDrawingListener = [];
        ROIDrawingListener = [];

        DrawOnMousePressInternal (1, 1) logical = true
        EraserSizeInternal

        EditModeInAction
    end

    properties(Access=private, Constant)
        DefaultEraserSize = 0;
    end

    events
        ScribbleDone
        ROIDrawingStarted
        ROIDrawingDone
        SuperpixDrawingDone
    end

    methods(Access=public)
        function obj = DrawingControls(options)
            arguments
                options.DrawOnMousePress (1, 1) logical = true;
                options.DrawOnlyPoints (1, 1) logical = false;
            end

            obj.DrawOnMousePress = options.DrawOnMousePress;
            obj.DrawOnlyPoints = options.DrawOnlyPoints;

            % Create a PaintBrush object for later use
            obj.Brush = images.roi.internal.PaintBrush();
            obj.Brush.EraseColor = [1 1 1];
            obj.Brush.Color = [0 1 1];
        end

        function init(obj, hobj, imageSize)
            arguments
                obj
                hobj (1, 1) { mustBeA( hobj, ...
                                [ "matlab.graphics.primitive.Image", ...
                                  "matlab.graphics.axis.Axes"] ) }
                imageSize (1, :) double
            end

            obj.UIObjHandle = hobj;
            if isa(hobj, "matlab.graphics.axis.Axes")
                obj.AxesHandle = hobj;
            else
                obj.AxesHandle = hobj.Parent;
            end

            obj.FigHandle = ancestor(hobj, "figure", "toplevel");

            obj.SuperpixDrawingListener = addlistener( obj.FigHandle, ...
                            "WindowMousePress", ...
                            @(src, evt) respondToSuperpixDrawing(obj, src, evt) );
            obj.SuperpixDrawingListener.Enabled = false;

            obj.ScribbleDrawingListener = addlistener( obj.FigHandle, ...
                                "WindowMousePress", ...
                                @(src, evt) respondToScribbleDrawing(obj, src, evt) );
            obj.ScribbleDrawingListener.Enabled = false;

            obj.ROIDrawingListener = addlistener( obj.FigHandle, ...
                            "WindowMousePress", ...
                            @(src, evt) respondToROIDrawing(obj, src, evt) );
            obj.ROIDrawingListener.Enabled = false;
            obj.EditModeInternal = "none";

            obj.ImageSize = imageSize(1:2);

            obj.EraserSize = obj.DefaultEraserSize;
            
            obj.Brush.Parent = obj.AxesHandle;
            obj.Brush.ImageSize = obj.ImageSize;
            obj.Brush.Mask = false(obj.ImageSize);
        end

        function reset(obj)
            obj.UIObjHandle = [];
            obj.FigHandle = [];

            delete(obj.SuperpixDrawingListener)
            obj.SuperpixDrawingListener = [];

            delete(obj.ScribbleDrawingListener);
            obj.ScribbleDrawingListener = [];

            delete(obj.ROIDrawingListener);
            obj.ROIDrawingListener = [];

            obj.ImageSize = [];

            obj.EraserSize = 0;
            
            clearAllScribbles(obj);

            clearROI(obj);

            clearSuperpixels(obj);
        end

        function drawScribbles(obj, scribbleMode)
            ensureMousePressListenersDisabled(obj);
            drawScribblesImpl(obj, scribbleMode);
        end

        function drawROI(obj, startPoint)
            ensureMousePressListenersDisabled(obj);
            drawROIImpl(obj, startPoint);
        end

        function drawSuperpix(obj)
            ensureMousePressListenersDisabled(obj);
            drawSuperpixImpl(obj);
        end
        
        function clearFGScribbles(obj)
            obj.ForegroundInd = [];
            if ~isempty(obj.FGLine)
                delete(obj.FGLine)
                obj.FGLine = [];
            end
        end

        function clearBGScribbles(obj)
            obj.BackgroundInd = [];
            if ~isempty(obj.BGLine)
                delete(obj.BGLine)
                obj.BGLine = [];
            end
        end

        function clearAllScribbles(obj)
            clearFGScribbles(obj);
            clearBGScribbles(obj);
        end

        function clearROI(obj)
            if ~isempty(obj.ROI)
                delete(obj.ROI);
                obj.ROIInternal = images.roi.Rectangle.empty();
            end
        end

        function isValid = isROIValid(obj)
            isValid = checkROIValidity(obj.ROI);
        end

        function clearSuperpixels(obj)
            clear(obj.Brush);
            if ~isempty(obj.ImageSize)
                obj.Brush.ImageSize = obj.ImageSize;
                obj.Brush.Superpixels = [];
            end
            obj.Brush.OutlineVisible = false;
        end

        function updateSuperpixels(obj, L)
            obj.Brush.Superpixels = L;
            obj.Brush.OutlineVisible = ~isempty(L);
        end
    end

    % Getters/Setters
    methods
        function val = get.EditMode(obj)
            val = obj.EditModeInternal;
        end

        function set.EditMode(obj, val)
            arguments
                obj
                val (1, 1) string { mustBeMember(val, [ "fore", "back", ...
                                            "erase", "ROI", "none", ...
                                            "superpix", "superpixerase" ] ) }
            end

            assert( obj.DrawOnMousePress, ...
                    "Set DrawOnMousePress = TRUE to allow mouse click listeners to be enabled" );

            obj.EditModeInternal = val;

            if val == "ROI"
                assert( ~isempty(obj.ROI), "ROI Must Be Valid For Drawing It" );

                obj.SuperpixDrawingListener.Enabled = false;
                obj.ScribbleDrawingListener.Enabled = false;
                obj.ROIDrawingListener.Enabled = true;

            elseif ismember(val, ["superpix", "superpixerase"])
                obj.SuperpixDrawingListener.Enabled = true;
                obj.ScribbleDrawingListener.Enabled = false;
                obj.ROIDrawingListener.Enabled = false;

                if isprop(obj.UIObjHandle, "InteractionMode") && ...
                                    obj.UIObjHandle.InteractionMode == ""
                    obj.Brush.OutlineVisible = true;
                end
                obj.Brush.Erase = val == "superpixerase";

            elseif ismember(val, ["fore", "back"])
                obj.SuperpixDrawingListener.Enabled = false;
                obj.ScribbleDrawingListener.Enabled = true;
                obj.ROIDrawingListener.Enabled = false;
            elseif val == "none"
                obj.SuperpixDrawingListener.Enabled = false;
                obj.ScribbleDrawingListener.Enabled = false;
                obj.ROIDrawingListener.Enabled = false;
            end

        end

        function val = get.EraserSize(obj)
            val = obj.EraserSizeInternal;
        end

        function set.EraserSize(obj, val)
            if val == obj.DefaultEraserSize
                val = 1 + round(mean(obj.ImageSize)/100);
            end
            obj.EraserSizeInternal = val;
        end
        
        function roi = get.ROI(obj)
            roi = obj.ROIInternal;
        end

        function set.ROI(obj, roi)
            clearROI(obj);
            obj.ROIInternal = roi;
        end

        function val = get.DrawOnMousePress(obj)
            val = obj.DrawOnMousePressInternal;
        end
        
        function set.DrawOnMousePress(obj, isEnabled)
            if ~isEnabled
                % Disable all listeners
                if ~isempty(obj.ScribbleDrawingListener)
                    obj.ScribbleDrawingListener.Enabled = false;
                end

                if ~isempty(obj.ROIDrawingListener)
                    obj.ROIDrawingListener.Enabled = false;
                end

                if ~isempty(obj.SuperpixDrawingListener)
                    obj.SuperpixDrawingListener.Enabled = false;
                end
            end

            obj.DrawOnMousePressInternal = isEnabled;

            % Take no action if user wants to enable this class to start
            % drawing based on mouse press. Setting the EditMode will
            % decide which specific type of drawing is being requested.
        end
        
        function val = get.FGPoints(obj)
            if ~isempty(obj.FGLine)
                val = unique( [ obj.FGLine.XData' obj.FGLine.YData' ], ...
                            "rows", "stable" );
            else
                val = [];
            end
        end

        function val = get.BGPoints(obj)
            if ~isempty(obj.BGLine)
                val = unique( [ obj.BGLine.XData' obj.BGLine.YData' ], ...
                            "rows", "stable" );
            else
                val = [];
            end
        end
    end

    methods(Access=private)
        function TF = isClickOnObject(obj, evt)
            if ~isprop(evt, "HitObject")
                TF = true;
            else
                TF = (evt.HitObject == obj.UIObjHandle);
                if isprop(evt.HitObject, "InteractionMode")
                    TF = TF & (obj.UIObjHandle.InteractionMode == "");
                end
            end
        end
    end

    methods(Access=public, Hidden)
        function respondToScribbleDrawing(obj, src, evt)
            setDrawListenerState(obj, "scribble", false);

            clickLocation = src.CurrentPoint;
            axesPosition  = src.CurrentAxes.Position;
            if ~strcmp(src.SelectionType, 'normal') || ...
                    ~isClickOnObject(obj, evt) || ...
                    isClickOutsideAxes(clickLocation, axesPosition)
                setDrawListenerState(obj, "scribble", true);
                return;
            end

            drawScribblesImpl(obj, obj.EditMode);
        end

        function respondToROIDrawing(obj, src, evt)
            setDrawListenerState(obj, "roi", false);

            if ~strcmp(src.SelectionType, 'normal') || ...
                                            ~isClickOnObject(obj, evt)
                setDrawListenerState(obj, "roi", true);
                return;
            end

            notify(obj, "ROIDrawingStarted");

            startPoint = obj.UIObjHandle.Parent.CurrentPoint(1, 1:2);

            drawROIImpl(obj, startPoint);
        end
        
        function respondToSuperpixDrawing(obj, src, evt)
            setDrawListenerState(obj, "superpix", false);

            if ~strcmp(src.SelectionType, 'normal') || ...
                                            ~isClickOnObject(obj, evt)
                setDrawListenerState(obj, "superpix", true);
                return;
            end

            drawSuperpixImpl(obj);
        end

        function createForeLine(obj)
            colorSpec = [0.467 .675 0.188];
            obj.FGLine  = createScribbleLine(obj.AxesHandle, colorSpec);
        end

        function createBackLine(obj)
            colorSpec = [0.635 0.078 0.184];
            obj.BGLine = createScribbleLine(obj.AxesHandle, colorSpec);
        end
    end

    methods(Access=private)
        function setDrawListenerState(obj, drawType, state)
            switch(drawType)
                case "scribble"
                    obj.ScribbleDrawingListener.Enabled = state;
                case "roi"
                    obj.ROIDrawingListener.Enabled = state;
                case "superpix"
                    obj.SuperpixDrawingListener.Enabled = state;
                otherwise
                    assert(false, "Invalid Drawing Type");
            end
        end

        function drawScribblesImpl(obj, editMode)
            obj.EditModeInAction = editMode;

            hAx  = obj.AxesHandle;
            
            currentPoint = hAx.CurrentPoint;
            currentPoint = round(currentPoint(1,1:2));
            
            isPointOutsideROI = ~isempty(obj.ROI) && ...
                                checkROIValidity(obj.ROI) && ...
                                ~obj.ROI.inROI( currentPoint(1), ...
                                                        currentPoint(2) );
            
            if isPointOutsideROI
                currentPoint = [NaN, NaN];
            end
            
            switch obj.EditModeInAction
                case 'fore'
                   if isempty(obj.FGLine)
                       obj.createForeLine();
                       obj.FGLine.XData = currentPoint(1);
                       obj.FGLine.YData = currentPoint(2);
                       set(obj.FGLine,'Visible','on');
                   else
                       obj.FGLine.XData(end+1) = NaN;
                       obj.FGLine.YData(end+1) = NaN;
                   end
                case 'back'
                   if isempty(obj.BGLine)
                       obj.createBackLine();
                       obj.BGLine.XData = currentPoint(1);
                       obj.BGLine.YData = currentPoint(2);
                       set(obj.BGLine,'Visible','on');
                   else
                       obj.BGLine.XData(end+1) = NaN;
                       obj.BGLine.YData(end+1) = NaN;
                   end
            end
        
            if ~isempty(obj.FGLine)
                % Workaround for uistack(obj.hForline,'top')
                obj.FGLine.Parent = [];
                obj.FGLine.Parent = hAx;
            end
            
            if editMode ~= "erase" && obj.DrawOnlyPoints
                scribbleUp();
            else
                scribbleDrag
                obj.FigHandle.WindowButtonMotionFcn = @scribbleDrag;
                obj.FigHandle.WindowButtonUpFcn = @scribbleUp;
            end
            
        
            function scribbleDrag(~,~)
                imSize = obj.ImageSize;
                currentPoint = hAx.CurrentPoint;
                currentPoint = round(currentPoint(1,1:2));
                axesPosition  = [1, 1, imSize(2)-1, imSize(1)-1];
                
                isPointOutsideROI = ~isempty(obj.ROI) && ...
                                    checkROIValidity(obj.ROI) && ...
                                    ~obj.ROI.inROI( currentPoint(1), ...
                                                        currentPoint(2) );
                
                if isPointOutsideROI || ...
                        (isClickOutsideAxes(currentPoint, axesPosition))
                    currentPoint = [NaN, NaN];
                end
                
                switch obj.EditModeInAction
                    case 'fore'
                        obj.FGLine.XData(end+1) = currentPoint(1);
                        obj.FGLine.YData(end+1) = currentPoint(2);
                    case 'back'
                        obj.BGLine.XData(end+1) = currentPoint(1);
                        obj.BGLine.YData(end+1) = currentPoint(2);
                    case 'erase'
                        XMin = currentPoint(1) - obj.EraserSize;
                        XMax = currentPoint(1) + obj.EraserSize;
                        YMin = currentPoint(2) - obj.EraserSize;
                        YMax = currentPoint(2) + obj.EraserSize;
                        
                        if ~isempty(obj.FGLine)
                            QueryForeData = (obj.FGLine.XData > XMin) & ...
                                (obj.FGLine.XData < XMax) & ...
                                (obj.FGLine.YData > YMin) & ...
                                (obj.FGLine.YData < YMax);
                            
                            obj.FGLine.XData(QueryForeData) = NaN;
                            obj.FGLine.YData(QueryForeData) = NaN;
                        end
                        
                        if ~isempty(obj.BGLine)
                            QueryBackData = (obj.BGLine.XData > XMin) & ...
                                (obj.BGLine.XData < XMax) & ...
                                (obj.BGLine.YData > YMin) & ...
                                (obj.BGLine.YData < YMax);
                            
                            obj.BGLine.XData(QueryBackData) = NaN;
                            obj.BGLine.YData(QueryBackData) = NaN;
                        end
                end

            end
        
            function scribbleUp(~,~)
                scribbleDrag();
                
                if editMode ~= "erase" && obj.DrawOnlyPoints
                    % Without this, there is a delay in the points being
                    % drawn.
                    drawnow;
                end

                obj.FigHandle.WindowButtonMotionFcn = [];
                obj.FigHandle.WindowButtonUpFcn = [];
                
                emptyLinesBeforeDraw = isempty(obj.ForegroundInd) && ...
                                                isempty(obj.BackgroundInd);

                imSize = obj.ImageSize;
                
                if ~isempty(obj.FGLine)
                   cleanXData = obj.FGLine.XData(~isnan(obj.FGLine.XData));
                   cleanYData = obj.FGLine.YData(~isnan(obj.FGLine.YData));
                   obj.ForegroundInd = unique( sub2ind( imSize(1:2), ...
                                                cleanYData,cleanXData ) );
                end

                if ~isempty(obj.BGLine)
                   cleanXData = obj.BGLine.XData(~isnan(obj.BGLine.XData));
                   cleanYData = obj.BGLine.YData(~isnan(obj.BGLine.YData));
                   obj.BackgroundInd = unique( sub2ind( imSize(1:2), ...
                                                cleanYData, cleanXData ) );
                end
                
                emptyLinesAfterDraw = isempty(obj.ForegroundInd) && ...
                                            isempty(obj.BackgroundInd);
                noMarksAdded = emptyLinesBeforeDraw && emptyLinesAfterDraw;
                
                if obj.DrawOnMousePress
                    setDrawListenerState(obj, "scribble", true);
                end

                if noMarksAdded
                    % No scribbles before this draw interaction, no
                    % scribbles after. Nothing to do here.
                    return;
                end

                notify(obj, "ScribbleDone");
            end
        end

        function drawROIImpl(obj, startPoint)
            imageSize = obj.ImageSize;

            if startPoint(1) < 0.5
                startPoint(1) = 0.5;
            elseif startPoint(1) > imageSize(2) + 0.5
                startPoint(1) = imageSize(2) + 0.5;
            end
            
            if startPoint(2) < 0.5
                startPoint(2) = 0.5;
            elseif startPoint(2) > imageSize(1) + 0.5
                startPoint(2) = imageSize(1) + 0.5;
            end
            
            beginDrawingFromPoint(obj.ROI, startPoint);

            isValid = isROIValid(obj);
            evtData = images.internal.app.utilities.semiautoseg.events.DrawingEventData(isValid);

            if obj.DrawOnMousePress
                setDrawListenerState(obj, "roi", true);
            end

            notify(obj, "ROIDrawingDone", evtData);
        end

        function drawSuperpixImpl(obj)
            beginDrawing(obj.Brush);
            mask = obj.Brush.Mask;

            labelsInMask = unique(obj.Brush.Superpixels(mask));

            clear(obj.Brush);
            obj.Brush.Mask = mask;

            data = struct("Mask", mask, "LabelsInMask", labelsInMask);
            evtData = images.internal.app.utilities.semiautoseg.events.DrawingEventData(data);

            if obj.DrawOnMousePress
                setDrawListenerState(obj, "superpix", true);
            end

            notify(obj, "SuperpixDrawingDone", evtData);
        end

        function ensureMousePressListenersDisabled(obj)
            assert( ~obj.DrawOnMousePress, ...
                    "Set DrawOnMousePress = FALSE. " + ...
                    "Mouse press listeners must be disabled" );
        end
        
    end
end

function hl = createScribbleLine(hAx, colorSpec)
    hl = line( Parent=hAx, Color=colorSpec, Visible="off",...
               LineWidth=3, HitTest="off", Tag="scribbleLine",...
               PickableParts="none", HandleVisibility="off",...
               Marker=".", MarkerSize=20, MarkerEdgeColor=colorSpec,...
               MarkerFaceColor=colorSpec );
end

function TF = checkROIValidity(roi)
    if isempty(roi) || ~isvalid(roi) || isempty(roi.Position)
        % This is a universal requirement for roi validity
        TF = false;
    else
        % Now check specific requirements for roi validity
        switch roi.Type
            case "images.roi.rectangle"
                TF = roi.Position(3) > 0 && roi.Position(4) > 0;
            case "images.roi.polygon"
                TF = size(roi.Position,1) >= 3;
            otherwise
                assert(false, "Unsupported ROI shape");
                TF = false;
        end
    end
end

function TF = isClickOutsideAxes(clickLocation, axesPosition)
    TF = (clickLocation(1) < axesPosition(1)) || ...
         (clickLocation(1) > (axesPosition(1) + axesPosition(3))) || ...
         (clickLocation(2) < axesPosition(2)) || ...
         (clickLocation(2) > (axesPosition(2)+axesPosition(4)));
end

% Copyright 2023-2024 The MathWorks, Inc.
