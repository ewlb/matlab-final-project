function hfigure = imcontrastWebImpl(handle,rsetMode)
%IMCONTRAST Adjust Contrast tool.
%   IMCONTRAST creates an Adjust Contrast tool in a separate figure that is
%   associated with the grayscale image in the current figure, called the
%   target image. The Adjust Contrast tool is an interactive contrast and
%   brightness adjustment tool that you can use to adjust the
%   black-to-white mapping used to display the image. The tool works by
%   modifying the CLim property.
%
%   Note: The Adjust Contrast tool can handle grayscale images of class
%   double and single with data ranges that extend beyond the default
%   display range, which is [0 1]. For these images, IMCONTRAST sets the
%   histogram limits to fit the image data range, with padding at the upper
%   and lower bounds.
%
%   IMCONTRAST(H) creates an Adjust Contrast tool associated with the image
%   specified by the handle H. H can be an image, axes, uipanel, or figure
%   handle. If H is an axes or figure handle, IMCONTRAST uses the first
%   image returned by FINDOBJ(H,'Type','image').
%
%   HFIGURE = IMCONTRAST(...) returns a handle to the Adjust Contrast tool
%   figure.
%
%   Remarks
%   -------
%   The Adjust Contrast tool presents a scaled histogram of pixel values
%   (overly represented pixel values are truncated for clarity). Dragging
%   on the left red bar in the histogram display changes the minimum value.
%   The minimum value (and any value less than the minimum) displays as
%   black. Dragging on the right red bar in the histogram changes the
%   maximum value. The maximum value (and any value greater than the
%   maximum) displays as white. Values in between the red bars display as
%   intermediate shades of gray.
%
%   Together the minimum and maximum values create a "window". Stretching
%   the window reduces contrast. Shrinking the window increases contrast.
%   Changing the center of the window changes the brightness of the image.
%   It is possible to manually enter the minimum, maximum, width, and
%   center values for the window. Changing one value automatically updates
%   the other values and the image.
%
%   Window/Level Interactivity
%   --------------------------
%   Clicking and dragging the mouse within the target image interactively
%   changes the image's window values. Dragging the mouse horizontally from
%   left to right changes the window width (i.e., contrast). Dragging the
%   mouse vertically up and down changes the window center (i.e.,
%   brightness). Holding down the CTRL key when clicking accelerates
%   changes. Holding down the SHIFT key slows the rate of change. Keys must
%   be pressed before clicking and dragging.
%
%   Example
%   -------
%
%       imshow('pout.tif')
%       imcontrast(gca)
%
%    See also IMADJUST, IMTOOL, STRETCHLIM.

%   Undocumented syntaxes
%   ---------------------
%   IMCONTRAST(H, rsetMode) disables the "Adjust Data" button and gray
%   samplers (eyedroppers) if rsetMode is true. The default is false.

%   Copyright 1993-2023 The MathWorks, Inc.

% Do sanity checking on handles and take care of the zero-argument case.
% rsetMode = false;
% 
% switch nargin
%     case 0
%         handle = get(0, 'CurrentFigure');
%         if isempty(handle)
%             error(message('images:common:notAFigureHandle', upper( mfilename )))
%         end
%     case 2
%         rsetMode = varargin{1};
%         validateattributes(rsetMode, {'logical'}, {'scalar', 'nonempty'})
% end

% iptcheckhandle(handle, {'figure', 'axes', 'image', 'uipanel'},...
%     mfilename, 'H', 1);

[imageHandle, ~, figHandle] = imhandles(handle);

if (isempty(imageHandle))
    error(message('images:common:noImageInFigure'))
end

% Find and validate target image/axes.
imageHandle = imageHandle(1);
axHandle = ancestor(imageHandle,'axes');
imgModel = validateImage(imageHandle);

% Install pointer manager in the figure containing the target image.
iptPointerManager(figHandle);

% Display the original image.
figure(figHandle);

% Open a new figure or bring up an existing one
hFig = getappdata(axHandle, 'imcontrastFig');
if ~isempty(hFig)
    figure(hFig);
    if nargout > 0
        hfigure = hFig;
    end
    return
end

% The default display range for double images is [0 1].  This default
% setting does not work for double images that are really outside this
% range; users would not even see the draggable window on the histogram
% (g227671).  In these cases, we throw a warning and set the display range
% to include the image data range.
badDisplayRange = isDisplayRangeOutsideDataRange(imageHandle,axHandle);
if badDisplayRange
    cdata = get(imageHandle, 'CData');
    imageRange = [double(min(cdata(:))) double(max(cdata(:)))];
    response = displayWarningDialog(get(axHandle,'Clim'), imageRange);
    if strcmpi(getString(message('images:commonUIString:ok')),response)
        % User hit 'Ok' on adjust display range dialog.
        set(axHandle,'Clim', imageRange);
        hHistFig = createHistogramPalette(imageHandle, imgModel, rsetMode);
    else
        % User hit 'Cancel' on adjust display range dialog.  Exit.
        hHistFig = [];
        if nargout > 0
            hfigure = hHistFig;
        end
        return
    end
else
    % Display range is valid.
    hHistFig = createHistogramPalette(imageHandle, imgModel, rsetMode);
end

% Install pointer manager in the contrast tool figure.
iptPointerManager(hHistFig);

% Align window with target figure
iptwindowalign(figHandle, 'left', hHistFig, 'left');
iptwindowalign(figHandle, 'bottom', hHistFig, 'top');

% Display figure and return
set(hHistFig, 'visible', 'on');
if nargout > 0
    hfigure = hHistFig;
end

end % imcontrast


%============================================================
function hFig = createHistogramPalette(imageHandle, imgModel, rsetMode)

hImageAx = ancestor(imageHandle, 'axes');
hImageFig = ancestor(imageHandle, 'figure');

isCallerIMTOOL = strcmp(get(hImageFig,'tag'),'imtool');

% initializing variables for function scope
cbk_id_cell = {};
isDoubleOrSingleData = false;
[undoMenu,redoMenu,undoAllMenu,originalImagePointerBehavior,...
    hAdjustButton,editBoxAPI,scalePanelAPI,windowAPI,hStatusLabel,...
    origBtnDwnFcn,winLevelCbkStartId,winLevelCbkStopId,hFigFlow,...
    hPanelHist,histStruct,hHistAx,newClim,clipPanelAPI,editBoxAPI,...
    scalePanelAPI] = deal(gobjects(0));

% variables used for enabling keeping a history of changes
climHistory = [];
currentHistoryIndex = 0;

% boolean variable used to prevent recursing through the event handler
% and duplicate entries in the history
blockEventHandler = false;

% boolean variable used to indicate if window level operation has started
% so that we know when to save the clim.
startedWindowLevel = false;

hFig = uifigure('visible', 'off', ...
    'toolbar', 'none', ...
    'menubar', 'none', ...
    'IntegerHandle', 'off', ...
    'NumberTitle', 'off', ...
    'Name', images.internal.imcontrast.createFigureName(getString(message('images:commonUIString:adjustContrast')),hImageFig), ...
    'HandleVisibility', 'callback', ...
    'units', 'pixels', ...
    'Tag','imcontrast');

images.internal.legacyui.utils.suppressPlotTools(hFig);

fig_pos = get(hFig,'Position');
set(hFig,'Position',[fig_pos(1:2) 560 300]);

% keep the figure name up to date
images.internal.imcontrast.linkToolName(hFig,hImageFig,getString(message('images:commonUIString:adjustContrast')));

setappdata(hImageAx, 'imcontrastFig', hFig);

createMenubar;

% create a blank uitoolbar to get docking arrow on the mac as a workaround
% to g222793.
if ismac
    h = uitoolbar(hFig);
end

margin = 5;
hFigFlow = uigridlayout(...
    'Parent', hFig, ...
    'ColumnWidth', {'1x'},...
    'RowHeight', {'fit', '1x', 'fit'},...
    'Padding', margin,...
    'RowSpacing', margin,...
    'ColumnSpacing', margin);

% Create panel that contains data range, window edit boxes, and auto
% scaling
[backgroundColor, clipPanelAPI, windowClipPanelWidth] = ...
    images.internal.imcontrast.createWindowClipPanel(hFigFlow, imgModel, rsetMode);
editBoxAPI = clipPanelAPI.editBoxAPI;
scalePanelAPI = clipPanelAPI.scalePanelAPI;
figureWidth = windowClipPanelWidth;

% initialize tool contents
initializeContrastTool;

% adjust colors
set(hFig,'Color', backgroundColor);
iptui.internal.setChildColorToMatchParent(hPanelHist, hFig);

% Enable window/leveling through the mouse if not in imtool
origBtnDwnFcn = get(imageHandle, 'ButtonDownFcn');
[winLevelCbkStartId, winLevelCbkStopId] = ...
    attachWindowLevelMouseActions;

% reset figure width
fig_pos = get(hFig,'Position');
set(hFig,'Position',[fig_pos(1:2) figureWidth 350]);
set(hFig, 'DeleteFcn', @closeHistFig);

% setup clim history with initial value
updateAllAndSaveInHistory(newClim);

% React to changes in target image cdata
images.internal.legacyui.utils.reactToImageChangesInFig(imageHandle,hFig,@reactDeleteFcn,...
    @reactRefreshFcn);
images.internal.imcontrast.registerModularToolWithManager(hFig,imageHandle);


%==============================
    function initializeContrastTool
        
        % set image property values
        isDoubleOrSingleData = any(strmatch(getClassType(imgModel),...
            {'double','single'})); %#ok<MATCH2>
        
        % reset CLim if we are out of range
        badDisplayRange = isDisplayRangeOutsideDataRange(imageHandle,hImageAx);
        if badDisplayRange
            cdata = get(imageHandle, 'CData');
            imageRange = [double(min(cdata(:))) double(max(cdata(:)))];
            set(hImageAx,'Clim', imageRange);
        end
        newClim = getClim;
        
        % Create HistogramPanel.
        hPanelHist = images.internal.imcontrast.imhistpanel(hFigFlow,imageHandle);
        set(hPanelHist, 'Tag','histogram panel');
        
        % Turn off HitTest of the histogram so it doesn't intercept button
        % down events - g330176,g412094
%         hHistogram = findobj(hPanelHist, 'type', 'hggroup','-or',...
%             'type','line');
        hHistogram = findobj(hPanelHist, 'type', 'stem');
        set(hHistogram, 'HitTest', 'off');
        
        % Create Draggable Clim Window on the histogram.
        hHistAx = findobj(hPanelHist,'type','axes');
        hHistAx.Toolbar = [];
        histStruct = images.internal.getHistogramData(imageHandle);
        maxCounts = max(histStruct.counts);
        windowAPI = images.internal.imcontrast.createClimWindowOnAxes(hHistAx,newClim,maxCounts);
        
        % Create Bottom Panel
        hStatusLabel = createBottomPanel(hFigFlow);
        
        setUpCallbacksOnDraggableWindow;
        setUpCallbacksOnWindowWidgets;
        setUpCallbacksOnAutoScaling;
        
        % react to changes in targe image axes clim
        setupCLimListener;
        % react to changes in targe image cdatamapping
        setupCDataMappingListener;
        
    end

%===============================
    function reactDeleteFcn(obj,evt) %#ok<INUSD>
        if ishghandle(hFig)
            delete(hFig);
        end
    end


%================================
    function reactRefreshFcn(~,~)
        
        % close tool if the target image cdata is empty
        if isempty(get(imageHandle,'CData'))
            reactDeleteFcn();
            return;
        end
        
        % remove old appdata
        if ~isempty(getappdata(imageHandle,'imagemodel'))
            rmappdata(imageHandle, 'imagemodel');
        end
        if ~isempty(getappdata(hFig,'ClimListener'))
            rmappdata(hFig,'ClimListener');
        end
        
        % refresh image model if it's valid, otherwise exit
        try
            imgModel = validateImage(imageHandle);
        catch ex %#ok<NASGU>
            reactDeleteFcn;
            return;
        end
        clipPanelAPI.updateImageModel(imgModel);
        
        % wipe old histogram data
        if ~isempty(getappdata(imageHandle,'HistogramData'))
            rmappdata(imageHandle, 'HistogramData');
        end
        
        % wipe old histogram panel and bottom panel
        delete(hPanelHist);
        hBottomPanel = findobj(hFig,'tag','bottom panel');
        delete(hBottomPanel);
        
        % create new panels and refresh tool
        initializeContrastTool;
        clearClimHistory;
        updateAllAndSaveInHistory(getClim);
        drawnow expose
    end


%=========================
    function setupCLimListener
        
        % Update the window if the CLIM changes from outside the tool.
        ClimListener = iptui.iptaddlistener(hImageAx, 'CLim', ...
            'PostSet', @updateTool);
        
        %===========================
        function updateTool(~,evt)
            
%             disp('updatetool - blocked')
            if blockEventHandler
                return
            end
            
%             disp('updatetool')
            % Branch to account for changes to post set listener eventdata
            new_clim = get(evt.AffectedObject,'CLim');
            
            if startedWindowLevel
                updateAll(new_clim);
%                 disp('updateall');
            else
                updateAllAndSaveInHistory(new_clim);
%                 disp('updateallhistory');
            end
        end
        
        setappdata(hFig, 'ClimListener', ClimListener);
        clear ClimListener;
    end


%=================================
    function setupCDataMappingListener
        
        % Update the window if the CDataMapping changes.
        cdm_listener = iptui.iptaddlistener(imageHandle,'CDataMapping', ...
            'PostSet', @reactRefreshFcn);
        setappdata(hFig, 'CDataMappingListener', cdm_listener);
        clear cdm_listener;
    end


%======================================================================
    function [winLevelCbkStartId,winLevelCbkStopId] = ...
            attachWindowLevelMouseActions
        
        % we want to use these flags to track the buttondown/up in all
        % contexts, including imtool so that window leveling gestures only
        % register as a single event in the imcontrast undo queue.
        winLevelCbkStartId = iptaddcallback(imageHandle,...
            'ButtonDownFcn',@winLevelStarted);
        
        winLevelCbkStopId = iptaddcallback(hImageFig,...
            'WindowButtonUpFcn',@winLevelStopped);
        
        if ~isCallerIMTOOL
            
            % Attach window/level mouse actions.
            iptaddcallback(imageHandle,...
                'ButtonDownFcn', @(hobj,evt)(images.internal.windowlevel(imageHandle, hFig)));
            
            % Change the pointer to window/level when over the image.
            % Remember the original pointer behavior so we can restore it
            % later in closeHistFig.
            originalImagePointerBehavior = iptGetPointerBehavior(imageHandle);
            enterFcn = @(f,cp) set(f, 'Pointer', 'custom', ...
                'PointerShapeCData', getWLPointer,...
                'PointerShapeHotSpot',[8 8]);
            iptSetPointerBehavior(imageHandle, enterFcn);
        end
        
        %========================================
        function PointerShapeCData = getWLPointer
            iconRoot = ipticondir;
            cdata = images.internal.app.utilities.makeToolbarIconFromPNG(fullfile(iconRoot, ...
                'cursor_contrast.png'));
            PointerShapeCData = cdata(:,:,1) + 1;
            
        end
        
        %================================
        function winLevelStarted(~,~)
            startedWindowLevel = true;
        end
        
        %================================
        function winLevelStopped(~,~)
            startedWindowLevel = false;
            % Update imcontrast GUI including Edit menu history when window
            % level interaction stops.
            updateAllAndSaveInHistory(hImageAx.CLim);
        end
    end

%===================================
    function closeHistFig(~,~)
        
        if blockEventHandler
            return;
        end
        if isappdata(hImageAx, 'imcontrastFig')
            rmappdata(hImageAx, 'imcontrastFig');
        end
        targetListeners = getappdata(hFig, 'TargetListener');
        delete(targetListeners);
        
        if ~isCallerIMTOOL
            % Restore original image pointer behavior.
            iptSetPointerBehavior(imageHandle, originalImagePointerBehavior);
            % Restore original image button down function
            set(imageHandle, 'ButtonDownFcn', origBtnDwnFcn);
        end
        
        iptremovecallback(imageHandle, ...
            'ButtonDownFcn', winLevelCbkStartId);

        iptremovecallback(hImageFig,...
            'WindowButtonUpFcn', winLevelCbkStopId);
        
        deleteCursorChangeOverDraggableObjs(cbk_id_cell);
    end

%=====================
    function createMenubar
        
        filemenu = uimenu(hFig, ...
            'Label', getString(message('images:commonUIString:fileMenubarLabel')), ...
            'Tag', 'file menu');
        editmenu = uimenu(hFig, ...
            'Label', getString(message('images:commonUIString:editMenubarLabel')), ...
            'Tag', 'edit menu');
        
        matlab.ui.internal.createWinMenu(hFig);
        
        % File menu
        uimenu(filemenu, ...
            'Label', getString(message('images:commonUIString:closeMenubarLabel')), ...
            'Tag','close menu item',...
            'Accelerator', 'W', ...
            'Callback', @(varargin) close(hFig));
        
        % Edit menu
        undoMenu = uimenu(editmenu, ...
            'Label', getString(message('images:imcontrastUIString:undoMenubarLabel')), ...
            'Accelerator', 'Z', ...
            'Tag', 'undo menu item', ...
            'Callback', @undoLastChange);
        redoMenu = uimenu(editmenu, ...
            'Label', getString(message('images:imcontrastUIString:redoMenubarLabel')), ...
            'Accelerator', 'Y', ...
            'Tag', 'redo menu item', ...
            'Callback',@redoLastUndo);
        undoAllMenu = uimenu(editmenu, ...
            'Label', getString(message('images:imcontrastUIString:undoAllMenubarLabel')), ...
            'Separator', 'on', ...
            'Tag', 'undo all menu item', ...
            'Callback', @undoAllChanges);
        
        % Help menu
        if ~isdeployed
            helpmenu = uimenu(hFig, ...
                'Label', getString(message('images:commonUIString:helpMenubarLabel')), ...
                'Tag', 'help menu');
            
            invokeHelp = @(varargin) ...
                helpview("images", "imtool_imagecontrast_help");
            
            uimenu(helpmenu, ...
                'Label', getString(message('images:imcontrastUIString:adjustContrastHelpMenubarLabel')), ...
                'Tag', 'help menu item', ...
                'Callback', invokeHelp);
            images.internal.legacyui.utils.iptstandardhelp(helpmenu);
        end
    end % createMenubar

%=======================================
    function setUpCallbacksOnDraggableWindow
        
        buttonDownTable = {
            windowAPI.centerLine.handle  @centerPatchDown;
            windowAPI.centerPatch.handle @centerPatchDown;
            windowAPI.maxLine.handle     @minMaxLineDown;
            windowAPI.minLine.handle     @minMaxLineDown;
            windowAPI.minPatch.handle    @minMaxPatchDown;
            windowAPI.maxPatch.handle    @minMaxPatchDown;
            windowAPI.bigPatch.handle    @bigPatchDown
            };
        
        for k = 1 : size(buttonDownTable,1)
            h = buttonDownTable{k,1};
            callback = buttonDownTable{k,2};
            set(h, 'ButtonDownFcn', callback);
        end
        
        draggableObjList = [buttonDownTable{1:end-1,1}];
        cbk_id_cell = initCursorChangeOverDraggableObjs(hFig, draggableObjList);
        
        %====================================
        function minMaxLineDown(src,varargin)
            
            if src == windowAPI.maxLine.handle
                isMaxLine = true;
            else
                isMaxLine = false;
            end
            
            idButtonMotion = iptaddcallback(hFig, 'WindowButtonMotionFcn', ...
                @minMaxLineMove);
            idButtonUp = iptaddcallback(hFig, 'WindowButtonUpFcn', ...
                @minMaxLineUp);
            
            % Disable pointer manager.
            iptPointerManager(hFig, 'disable');
            
            %==============================
            function minMaxLineUp(varargin)
                
                acceptChanges(idButtonMotion, idButtonUp);
            end
            
            %====================================
            function minMaxLineMove(~,varargin)
                
                xpos = images.internal.app.utilities.getCurrentPoint(hHistAx);
                if isMaxLine
                    newMax = xpos;
                    newMin = windowAPI.minLine.get();
                else
                    newMin = xpos;
                    newMax = windowAPI.maxLine.get();
                end
                newClim = validateClim([newMin newMax]);
                if isequal(newClim(1), xpos) || isequal(newClim(2), xpos)
                    updateAll(newClim);
                end
            end
        end %lineButtonDown
        
        %=================================
        function centerPatchDown(varargin)
            
            idButtonMotion = iptaddcallback(hFig, 'WindowButtonMotionFcn', ...
                @centerPatchMove);
            idButtonUp = iptaddcallback(hFig, 'WindowButtonUpFcn', @centerPatchUp);
            
            % Disable pointer manager.
            iptPointerManager(hFig, 'disable');
            
            startX = images.internal.app.utilities.getCurrentPoint(hHistAx);
            oldCenterX = windowAPI.centerLine.get();
            
            %===============================
            function centerPatchUp(varargin)
                
                acceptChanges(idButtonMotion, idButtonUp);
            end
            
            %=================================
            function centerPatchMove(varargin)
                
                newX = images.internal.app.utilities.getCurrentPoint(hHistAx);
                delta = newX - startX;
                
                % Set the window endpoints.
                centerX = oldCenterX + delta;
                minX = windowAPI.minLine.get();
                maxX = windowAPI.maxLine.get();
                width = maxX - minX;
                [newMin, newMax] = computeClim(width, centerX);
                newClim = validateClim([newMin newMax]);
                updateAll(newClim);
            end
        end %centerPatchDown
        
        %======================================
        function minMaxPatchDown(src, varargin)
            
            if isequal(src, windowAPI.minPatch.handle)
                srcLine = windowAPI.minLine;
                minPatchMoved = true;
            else
                srcLine = windowAPI.maxLine;
                minPatchMoved = false;
            end
            
            startX = images.internal.app.utilities.getCurrentPoint(hHistAx);
            oldX = srcLine.get();
            
            idButtonMotion = iptaddcallback(hFig, 'WindowButtonMotionFcn', ...
                @minMaxPatchMove);
            idButtonUp = iptaddcallback(hFig, 'WindowButtonUpFcn', ...
                @minMaxPatchUp);
            
            % Disable pointer manager.
            iptPointerManager(hFig, 'disable');
            
            %===============================
            function minMaxPatchUp(varargin)
                
                acceptChanges(idButtonMotion, idButtonUp);
            end
            
            %======================================
            function minMaxPatchMove(~, varargin)
                
                newX = images.internal.app.utilities.getCurrentPoint(hHistAx);
                delta = newX - startX;
                
                % Set the window endpoints.
                if minPatchMoved
                    minX = oldX + delta;
                    maxX = windowAPI.maxLine.get();
                else
                    maxX = oldX + delta;
                    minX = windowAPI.minLine.get();
                end
                newClim = validateClim([minX maxX]);
                updateAll(newClim);
            end
        end %minMaxPatchDown
        
        %==============================
        function bigPatchDown(varargin)
            
            idButtonMotion = iptaddcallback(hFig, 'windowButtonMotionFcn', ...
                @bigPatchMove);
            idButtonUp = iptaddcallback(hFig, 'WindowButtonUpFcn', @bigPatchUp);
            
            % Disable pointer manager.
            iptPointerManager(hFig, 'disable');
            
            startX = get(hHistAx, 'CurrentPoint');
            oldMinX = windowAPI.minLine.get();
            oldMaxX = windowAPI.maxLine.get();
            
            %============================
            function bigPatchUp(varargin)
                
                acceptChanges(idButtonMotion, idButtonUp);
            end
            
            %===========================
            function bigPatchMove(varargin)
                
                newX = images.internal.app.utilities.getCurrentPoint(hHistAx);
                delta = newX(1) - startX(1);
                
                % Set the window endpoints.
                newMin = oldMinX + delta;
                newMax = oldMaxX + delta;
                
                % Don't let window shrink when dragging the window patch.
                origWidth = getWidthOfWindow;
                histRange = histStruct.histRange;
                
                if newMin < histRange(1)
                    newMin = histRange(1);
                    newMax = newMin + origWidth;
                end
                
                if newMax > histRange(2)
                    newMax = histRange(2);
                    newMin = newMax - origWidth;
                end
                newClim = validateClim([newMin newMax]);
                updateAll(newClim);
            end
        end %bigPatchDown
        
        %=================================================
        function acceptChanges(idButtonMotion, idButtonUp)
            
            iptremovecallback(hFig, 'WindowButtonMotionFcn', idButtonMotion);
            iptremovecallback(hFig, 'WindowButtonUpFcn', idButtonUp);
            
            % Enable the figure's pointer manager.
            iptPointerManager(hFig, 'enable');
            
            updateAllAndSaveInHistory(getClim);
            
        end
        
        %================================
        function width = getWidthOfWindow
            width = editBoxAPI.widthEdit.get();
        end
        
    end % setUpCallbacksOnDraggableWindow

%=====================================
    function setUpCallbacksOnWindowWidgets
        
        callbackTable = {
            editBoxAPI.centerEdit  @actOnCenterChange;
            editBoxAPI.widthEdit   @actOnWidthChange;
            editBoxAPI.maxEdit     @actOnMinMaxChange;
            editBoxAPI.minEdit     @actOnMinMaxChange;
            };
        
        for m = 1 : size(callbackTable,1)
            h = callbackTable{m,1}.handle;
            callback = callbackTable{m,2};
            set(h, 'ValueChangedFcn', callback);
        end
        
        eyedropperAPI = clipPanelAPI.eyedropperAPI;
        droppers = [eyedropperAPI.minDropper.handle ...
            eyedropperAPI.maxDropper.handle];
        
        set(droppers, 'ButtonPushedFcn', @eyedropper);
        
        %===================================
        function actOnMinMaxChange(varargin)
            
            areEditBoxStringsValid = checkEditBoxStrings;
            if areEditBoxStringsValid
                newMax = editBoxAPI.maxEdit.get();
                newMin = editBoxAPI.minEdit.get();
                [newClim] = validateClim([newMin newMax]);
                updateAllAndSaveInHistory(newClim);
            else
                resetEditValues;
                return;
            end
        end
        
        %==================================
        function actOnWidthChange(varargin)
            
            areEditBoxStringsValid = checkEditBoxStrings;
            if areEditBoxStringsValid
                centerValue = editBoxAPI.centerEdit.get();
                widthValue = editBoxAPI.widthEdit.get();
                
                [newMin, newMax] = computeClim(widthValue, centerValue);
                newClim = validateClim([newMin newMax]);
                
                % do not allow the center to move on width changes
                newCenter = mean(newClim);
                newWidth = diff(newClim);
                diffCenter = newCenter - centerValue;
                if diffCenter ~= 0
                    widthValue = newWidth - 2 * abs(diffCenter);
                    [newMin, newMax] = computeClim(widthValue, centerValue);
                    newClim = validateClim([newMin newMax]);
                end
                
                updateAllAndSaveInHistory(newClim);
            else
                resetEditValues;
                return
            end
        end
        
        %===================================
        function actOnCenterChange(varargin)
            
            areEditBoxStringsValid = checkEditBoxStrings;
            if areEditBoxStringsValid
                centerValue = editBoxAPI.centerEdit.get();
                widthValue = editBoxAPI.widthEdit.get();
                [newMin, newMax] = computeClim(widthValue, centerValue);
                XLim = get(hHistAx,'XLim');
                
                % React to a center change that makes the newMin or
                % newMax go outside of the XLim, but keep the center
                % that the user requested.
                if ((newMin < XLim(1)) && (newMax > XLim(2)))
                    newMin = XLim(1);
                    newMax = XLim(2);
                elseif (newMin < XLim(1))
                    newMin = XLim(1);
                    newMax = newMin + 2 * (centerValue - newMin);
                elseif (newMax > XLim(2))
                    newMax = XLim(2);
                    newMin = newMax - 2 * (newMax - centerValue);
                end
                newClim = validateClim([newMin newMax]);
                
                % make sure our center value is not adjusted based on the
                % buffer in the axes xlim
                newCenter = mean(newClim);
                newWidth = diff(newClim);
                diffCenter = newCenter - centerValue;
                if diffCenter ~= 0
                    widthValue = newWidth - 2 * abs(diffCenter);
                    [newMin, newMax] = computeClim(widthValue, centerValue);
                    newClim = validateClim([newMin newMax]);
                end
                
                updateAllAndSaveInHistory(newClim);
            else
                resetEditValues;
                return
            end
        end
        
        %=======================
        function resetEditValues
            
            Clim = getClim;
            for k = 1 : size(callbackTable,1)
                callbackTable{k,1}.set(Clim);
            end
        end
        
        %=================================
        function eyedropper(src, varargin)
            
            if isequal(src, eyedropperAPI.minDropper.handle)
                editBox = editBoxAPI.minEdit;
                dropper = eyedropperAPI.minDropper;
            else
                editBox = editBoxAPI.maxEdit;
                dropper = eyedropperAPI.maxDropper;
            end
            
            % Prevent ui* objects from issuing callbacks before dropper is done.
            parent = ancestor(editBox.handle, 'uigridlayout', 'toplevel');
            editChildren = findall(parent, 'Type', 'uieditfield'); 
            buttonChildren = findall(parent, 'Type', 'uibutton'); 
            radioButtonChildren = findall(parent, 'Type', 'uiradiobutton');
            children = [editChildren;buttonChildren;radioButtonChildren];
            origEnable = get(children, 'Enable');
            set(children, 'Enable', 'off');
            
            % W/L mouse action sometimes conflicts afterward.  Turn it off briefly.
            origBDF = get(imageHandle, 'ButtonDownFcn');
            set(imageHandle, 'ButtonDownFcn', '');
            
            % Change the pointer to an eyedropper over the image.
            origPointerBehavior = iptGetPointerBehavior(imageHandle);
            enterFcn = @(f,cp) set(f, 'Pointer', 'custom', ...
                'PointerShapeCData', ...
                getEyedropperPointer(dropper.get), ...
                'PointerShapeHotSpot', [16 1]);
            iptSetPointerBehavior(imageHandle, enterFcn);
            
            % Change the status text.
            origMsg = get(hStatusLabel, 'Text');
            if(strcmp(dropper.get,'minimum'))
                set(hStatusLabel, 'Text', getString(message('images:imcontrastUIString:minimalStatusText')));
            else
                % maximal
                set(hStatusLabel, 'Text', getString(message('images:imcontrastUIString:maximalStatusText')));
            end
            set(hStatusLabel, 'Enable', 'on');
            % Take care to undo all of these actions if the
            % adjustment tool closes.
            origCloseRequestFcn = get(hFig, 'CloseRequestFcn');
            set(hFig, 'CloseRequestFcn', @closeDuringEyedropper)
            
            value = images.internal.imcontrast.graysampler(imageHandle);
            
            % Set the edit text box.
            if ~isempty(value)
                editBox.set([value value]);
                areValid = checkEditBoxStrings;
                
                if areValid
                    newClim = [editBoxAPI.minEdit.get(), ...
                        editBoxAPI.maxEdit.get()];
                    newClim = validateClim(newClim);
                    updateAllAndSaveInHistory(newClim);
                else
                    resetEditValues;
                end
            end
            
            undoEyedropperChanges;
            
            % we manually call the "climChanged" listener function here to
            % make sure our 'Adjust Data' button label is updated if the
            % undoEyedropperChanges function blew away a valid update
            if ~isempty(value)
                climChanged;
            end
            
            %=====================================================
            function PointerShapeCData = getEyedropperPointer(tag)
                
                iconRoot = ipticondir;
                if strcmp(tag,'minimum')
                    cursor_filename = fullfile(iconRoot, ...
                        'cursor_eyedropper_black.png');
                else
                    cursor_filename = fullfile(iconRoot, ...
                        'cursor_eyedropper_white.png');
                end
                
                cdata = images.internal.app.utilities.makeToolbarIconFromPNG(cursor_filename);
                PointerShapeCData = cdata(:,:,1)+1;
            end
            
            %=============================
            function undoEyedropperChanges
                
                % Change the pointer back.
                if ishghandle(imageHandle)
                    iptSetPointerBehavior(imageHandle, origPointerBehavior);
                    
                    % Force pointer manager update.
                    iptPointerManager(ancestor(imageHandle, 'figure'));
                end
                
                % Change the message back.
                if ishghandle(hStatusLabel)
                    set(hStatusLabel, 'Text', origMsg);
                end
                
                % Turn the W/L mouse action back on if necessary.
                if ishghandle(imageHandle)
                    set(imageHandle, 'ButtonDownFcn', origBDF);
                end
                
                % Reenable other uicontrols.
                for p = 1:numel(origEnable)
                    if ishghandle(children(p))
                        set(children(p), 'Enable', origEnable{p});
                    end
                end
            end
            
            %=======================================
            function closeDuringEyedropper(varargin)
                
                undoEyedropperChanges;
                if ((~isempty(origCloseRequestFcn)) && ...
                        (~isequal(origCloseRequestFcn, 'closereq')))
                    feval(origCloseRequestFcn);
                end
                
                if ishghandle(hFig)
                    delete(hFig)
                end
            end
            
        end %eyedropper
        
        %======================================
        function areValid = checkEditBoxStrings
            
            centerValue = editBoxAPI.centerEdit.get();
            maxValue    = editBoxAPI.maxEdit.get();
            minValue    = editBoxAPI.minEdit.get();
            widthValue  = editBoxAPI.widthEdit.get();
            
            areValid = true;
            
            % Validate data.
            % - If invalid: display dialog, reset to last good value, stop.
            % - If valid: go to other callback processor.
            isValueEmpty = any([isempty(minValue), isempty(maxValue),...
                isempty(widthValue), isempty(centerValue)]);
            
            isValueString = any([ischar(minValue), ischar(maxValue),...
                ischar(widthValue), ischar(centerValue)]);
            
            isValueNonScalar = (numel(minValue) + numel(maxValue) +...
                numel(widthValue) + numel(centerValue) ~= 4);
            
            if (isValueEmpty || isValueString || isValueNonScalar)
                
                areValid = false;
                errordlg({getString(message('images:imcontrastUIString:invalidWindowValueDlgText'))}, ...
                    getString(message('images:imcontrastUIString:invalidWindowValueDlgTitle')), ...
                    'modal')
                
            elseif (minValue >= maxValue)
                
                areValid = false;
                errordlg(getString(message('images:imcontrastUIString:minValueLessThanMaxDlgText')), ...
                    getString(message('images:imcontrastUIString:invalidWindowValueDlgTitle')), ...
                    'modal')
                
            elseif (((widthValue < 1) && (~isDoubleOrSingleData)) || ...
                    (widthValue <= 0))
                
                areValid = false;
                errordlg(getString(message('images:imcontrastUIString:windowWidthGreaterThanZeroDlgText')), ...
                    getString(message('images:imcontrastUIString:invalidWindowValueDlgTitle')), ...
                    'modal')
                
            elseif ((floor(centerValue * 2) ~= centerValue * 2) && (~isDoubleOrSingleData))
                
                areValid = false;
                errordlg(getString(message('images:imcontrastUIString:windowCenterIntegerDlgText')), ...
                    getString(message('images:imcontrastUIString:invalidWindowValueDlgTitle')), ...
                    'modal')
            end
        end % validateEditBoxStrings
        
    end % setUpCallbacksOnWindowWidgets

%===================================
    function setUpCallbacksOnAutoScaling
        
        set(scalePanelAPI.percentEdit.handle, ...
            'ValueChangedFcn', @changeScaleDisplay, ...
            'ValueChangingFcn', @changeScaleDisplay);

        set(scalePanelAPI.scaleDisplayBtn.handle, ...
            'ButtonPushedFcn', @autoScaleApply);
        
        % make matchDataRangeBtn selected by default.
        scalePanelAPI.matchDataRangeBtn.set(true);
        scalePanelAPI.elimRadioBtn.set(false);
        
        %========================================
        function changeScaleDisplay(src, varargin)
            
            if isequal(src, scalePanelAPI.matchDataRangeBtn.handle)
                scalePanelAPI.matchDataRangeBtn.set(true);
                scalePanelAPI.elimRadioBtn.set(false);
            else
                scalePanelAPI.matchDataRangeBtn.set(false);
                scalePanelAPI.elimRadioBtn.set(true);
            end
        end
        
        %================================
        function autoScaleApply(varargin)
            
            % Verify the percent and use it if box is checked.
            outlierPct = scalePanelAPI.percentEdit.get();
            
            matchDataRange = ...
                isequal(scalePanelAPI.matchDataRangeBtn.get(), true);
            
            CData = get(imageHandle, 'CData');
            minCData = min(CData(:));
            maxCData = max(CData(:));
            
            if matchDataRange
                
                localNewClim = [double(minCData) double(maxCData)];
                
            else
                % eliminate Outliers.
                if isempty(outlierPct) || outlierPct > 100 || outlierPct < 0
                    errordlg({getString(message('images:imcontrastUIString:percentageOutOfRangeText'))}, ...
                        getString(message('images:imcontrastUIString:percentageOutOfRangeTitle')), ...
                        'modal')
                    scalePanelAPI.percentEdit.set('2');
                    return;
                end
                
                outlierPct = outlierPct / 100;
                
                % Double image data not in default range must be scaled and
                % shifted to the range [0,1] for STRETCHLIM to do
                % the right thing.
                doubleImageOutsideDefaultRange = isDoubleOrSingleData && ...
                    (minCData < 0 || maxCData > 1);
                
                if doubleImageOutsideDefaultRange
                    % Keep track of old CData range for reconversion.
                    CData = mat2gray(CData);
                end
                
                localNewClim = stretchlim(CData, outlierPct / 2);
                
                if isequal(localNewClim, [0;1])
                    if outlierPct > 0.02
                        errordlg({getString(message('images:imcontrastUIString:percentageTooGreatTextLine1')), ...
                            getString(message('images:imcontrastUIString:percentageTooGreatTextLine2'))}, ...
                            getString(message('images:imcontrastUIString:percentageTooGreatTitle')), ...
                            'modal')
                        return;
                    elseif outlierPct ~= 0
                        errordlg({getString(message('images:imcontrastUIString:cannotEliminateOutliersLine1')),...
                            getString(message('images:imcontrastUIString:cannotEliminateOutliersLine2'))},...
                            getString(message('images:imcontrastUIString:cannotEliminateOutliersTitle')),...
                            'modal')
                        return;
                    end
                end
                
                % Scale the Clim from STRETCHLIM's [0,1] to match the range
                % of the data.
                if ~isDoubleOrSingleData
                    imgClass = class(CData);
                    localNewClim = double(intmax(imgClass)) * localNewClim;
                elseif doubleImageOutsideDefaultRange
                    localNewClim = localNewClim * (maxCData - minCData);
                    localNewClim = localNewClim + minCData;
                end
            end
            
            newClim = validateClim(localNewClim);
            updateAllAndSaveInHistory(newClim);
            
        end % autoScaleApply
    end % setUpCallbacksOnAutoScaling

%====================================
    function newClim = validateClim(clim)
        
        % Prevent new endpoints from exceeding the min and max of the
        % histogram range, which is a little less than the xlim endpoints.
        % Don't want to get to the actual endpoints because there is a
        % problem with the painters renderer and patches at the edge
        % (g298973).  histStruct is a variable calculated in the beginning
        % of createHistogramPalette.
        histRange = histStruct.histRange;
        newMin = max(clim(1), histRange(1));
        newMax = min(clim(2), histRange(2));
        
        if ~isDoubleOrSingleData
            % If the image has an integer datatype, don't allow the new endpoints
            % to exceed the min or max of that datatype.  For example, We don't
            % want to allow this because it wouldn't make sense to set the clim
            % of a uint8 image beyond 255 or less than 0.
            minOfDataType = double(intmin(getClassType(imgModel)));
            maxOfDataType = double(intmax(getClassType(imgModel)));
            newMin = max(newMin, minOfDataType);
            newMax = min(newMax, maxOfDataType);
        end
        
        % Keep min < max
        if ( ((newMax - 1) < newMin) && ~isDoubleOrSingleData )
            
            % Stop at limiting value.
            Clim = getClim;
            newMin = Clim(1);
            newMax = Clim(2);
            
            %Made this less than or equal to as a possible workaround to g226780
        elseif ( (newMax <= newMin) && isDoubleOrSingleData )
            
            % Stop at limiting value.
            Clim = getClim;
            newMin = Clim(1);
            newMax = Clim(2);
        end
        
        newClim = [newMin newMax];
    end


%================================================
    function hStatusLabel = createBottomPanel(parent)
        
        hBottomPanel = uipanel('Parent', parent, ...
            'Units', 'pixels', ...
            'Tag', 'bottom panel',...
            'BorderType', 'none');
        
        hBottomPanelFlow = uigridlayout(...
            'Parent', hBottomPanel, ...
            'ColumnWidth', {'1x', 'fit', 'fit', 'fit'},...
            'RowHeight', {'fit'});
        
        buttonText = getString(message('images:imcontrastUIString:adjustDataButtonText'));
        
        % Status Label
        if isCallerIMTOOL
            defaultMessage = sprintf('%s\n%s', ...
                getString(message('images:imcontrastUIString:adjustTheHistogramAbove')),...
                getString(message('images:imcontrastUIString:clickToAdjust',buttonText)));
        else
            defaultMessage = sprintf('%s\n%s', ...
                getString(message('images:imcontrastUIString:adjustTheHistogramAboveNotImtool')),...
                getString(message('images:imcontrastUIString:clickToAdjust',buttonText)));
        end
        
        % TODO: what about units?
        hStatusLabel = uilabel('parent', hBottomPanelFlow, ...
            'Text', defaultMessage,...
            'tag', 'status text',...
            'HorizontalAlignment', 'left');
        
        hAdjustButton = uibutton(...
            'Text', buttonText,...
            'Tag','adjust data button',...
            'Parent',hBottomPanelFlow,...
            'Enable','off',...
            'ButtonPushedFcn',@adjustButtonCallback);
        
        hAdjustButton.Layout.Column = 4;
        hAdjustButton.Layout.Row = 1;
        % Call 'climChanged' listener function manually to update the
        % state of the 'Adjust Data' button, when the axis clim value
        % differs from the original data range.
        histRange = histStruct.histRange;
        imageAxClim = get(hImageAx,'CLim');
        if ~isequal(histRange,imageAxClim)
            climChanged;
        end
        
        % enable the button on changes to axes clim
        setappdata(hAdjustButton,'climListener',...
            iptui.iptaddlistener(hImageAx, 'CLim',...
            'PostSet', @climChanged));
        
        %=====================================
        function adjustButtonCallback(~,~)
            % get original image data
            origCData = get(imageHandle,'CData');
            defaultRange = getrangefromclass(origCData);
            
            % find new min and max
            clim = get(hImageAx,'Clim');
            if isfloat(origCData)
                % Normalize floating point to 0-1
                origCData = (origCData-clim(1))/diff(clim);
                clim = [ 0 1];
            end
            clim = (clim-defaultRange(1))/diff(defaultRange);
            % apply contrast adjustment
            newCData = imadjust(origCData, clim, [0, 1]);
            
            % restore image display range to default
            set(hImageAx,'CLim',defaultRange)
            
            % update image data
            set(imageHandle,'CData',newCData)
            
            % Explicitly create an image model for the image.
            imgModel = getimagemodel(imageHandle);
            
            % Set original class type of imgmodel before image object is created.
            setImageOrigClassType(imgModel,class(newCData));
            
        end % adjustButtonCallback        
              
    end % createBottomPanel

%============================
    function climChanged(~,~)
        histRange = histStruct.histRange;
        % the image could have been closed here
        if ishghandle(hImageAx)
            new_clim = get(hImageAx,'CLim');
            if ~isequal(histRange,new_clim) && ~rsetMode
                set(hAdjustButton,'Enable','on');
            else
                set(hAdjustButton,'Enable','off');
            end
        end
    end

%======================
    function updateEditMenu
        
%         disp('updateeditmenu')
        % enable the undo menus when the clim gets its first change
        if currentHistoryIndex >= 2 && ~strcmpi(get(undoMenu, 'Enable'),'on')
            set([undoMenu, undoAllMenu], 'Enable', 'on');
%             disp('here enable')
        elseif currentHistoryIndex == 1
            set([undoMenu, undoAllMenu], 'Enable', 'off');
        end
        
        % enable the redo menu when the length of the history is greater
        % than the current index
        historyLength = size(climHistory, 1);
        if historyLength > currentHistoryIndex
            set(redoMenu, 'Enable', 'on');
        elseif historyLength == currentHistoryIndex
            set(redoMenu, 'Enable', 'off');
        end
    end % updateEditMenu

%===============================
    function undoLastChange(~,~)
        currentHistoryIndex = max(1,  currentHistoryIndex - 1);
        updateAll(climHistory(currentHistoryIndex,:));
        updateEditMenu
    end

%=============================
    function redoLastUndo(~,~)
        historyLength = size(climHistory, 1);
        currentHistoryIndex = min(historyLength, currentHistoryIndex + 1);
        updateAll(climHistory(currentHistoryIndex,:));
        updateEditMenu
    end

%===============================
    function undoAllChanges(~,~)
        currentHistoryIndex = 1;
        updateAll(climHistory(currentHistoryIndex,:));
        updateEditMenu
    end

%==========================
    function clearClimHistory()
        climHistory = [];
        currentHistoryIndex = 0;
    end

%==========================================
    function updateAllAndSaveInHistory(newClim)
        % get the length of entries in the history
        historyLength = size(climHistory,1);
        
        % increment current index by one to indicate the new entry's
        % position.
        currentHistoryIndex = currentHistoryIndex + 1;
        
        % if the length of entries in the history is longer that the
        % current index we discard all entries after the current index.
        if historyLength > currentHistoryIndex
            climHistory(currentHistoryIndex,:) = [];
        end
        climHistory(currentHistoryIndex,:) = [newClim(1), newClim(2)];
        
        updateAll(newClim);
        updateEditMenu;
    end

%==========================
    function updateAll(newClim)
        
        % Update edit boxes with new values.
        updateEditBoxes(newClim);
        
        % Update patch display.
        updateHistogram(newClim);
        
        % we don't want the clim event handler executed to prevent
        % duplicate entries in the history.
        blockEventHandler = true;
        
        % Update image Clim.
        updateImage(hImageAx, newClim);
        
        blockEventHandler = false;
    end

%===============================
    function updateEditBoxes(newClim)
        
        names = fieldnames(editBoxAPI);
        for k = 1 : length(names)
            editBoxAPI.(names{k}).set(newClim);
        end
    end

%================================
    function updateHistogram(newClim)
        
        names = fieldnames(windowAPI);
        for k = 1 : length(names)
            windowAPI.(names{k}).set(newClim);
        end
    end % updateHistogram

%===================================
    function updateImage(hImageAx, clim)
        
        if clim(1) >= clim(2)
            error(message('images:imcontrast:internalError'))
        end
        set(hImageAx, 'clim', clim);
    end

%======================
    function clim = getClim
        clim = get(hImageAx,'Clim');
    end

end % createHistogramPalette

%=========================================================
function [minPixel, maxPixel] = computeClim(width, center)
%FINDWINDOWENDPOINTS   Process window and level values.

minPixel = (center - width/2);
maxPixel = minPixel + width;

end

%=====================================
function imgModel = validateImage(hIm)

imgModel = getimagemodel(hIm);
if ~strcmp(getImageType(imgModel),'intensity')
    error(message('images:imcontrast:unsupportedImageType'))
end

cdata = get(hIm,'cdata');
if isempty(cdata)
    error(message('images:imcontrast:invalidImage'))
end

end

%==========================================================================
function cbk_id_cell = initCursorChangeOverDraggableObjs(client_fig, drag_objs)
% initCursorChangeOverDraggableObjs

% initialize variables for function scope
num_of_drag_objs    = numel(drag_objs);

enterFcn = @(f,cp) setptr(f, 'lrdrag');
iptSetPointerBehavior(drag_objs, enterFcn);

% Add callback to turn on flag indicating that dragging has stopped.
stop_drag_cbk_id = iptaddcallback(client_fig, ...
    'WindowButtonUpFcn', @stopDrag);

obj_btndwn_fcn_ids = zeros(1, num_of_drag_objs);

% Add callback to turn on flag indicating that dragging has started
for n = 1 : num_of_drag_objs
    obj_btndwn_fcn_ids(n) = iptaddcallback(drag_objs(n), ...
        'ButtonDownFcn', @startDrag);
end

cbk_id_cell = {client_fig, 'WindowButtonUpFcn', stop_drag_cbk_id;...
    drag_objs,  'ButtonDownFcn', obj_btndwn_fcn_ids};


%==========================
    function startDrag(~,~)
        % Disable the pointer manager while dragging.
        iptPointerManager(client_fig, 'disable');
    end

%========================
    function stopDrag(~,~)
        % Enable the pointer manager.
        iptPointerManager(client_fig, 'enable');
    end

end % initCursorChangeOverDraggableObjs


%==========================================================================
function deleteCursorChangeOverDraggableObjs(cbk_id)

rows = size(cbk_id, 1);
for n = 1 : rows
    id_length = length(cbk_id{n,1});
    for m = 1 : id_length
        iptremovecallback(cbk_id{n,1}(m), cbk_id{n,2}, cbk_id{n,3}(m));
    end
end
end % deleteCursorChangeOverDraggableObjs


%===========================================================================
function wdlg = displayWarningDialog(curClim, imDataLim)

formatValue = @(v) sprintf('%0.0f', v);

str{1}= getString(message('images:imcontrastUIString:outOfRangeWarn',...
    formatValue(curClim(1)),...
    formatValue(curClim(2)),...
    formatValue(imDataLim(1)),...
    formatValue(imDataLim(2))));

lastLineStr = strcat('\n',getString(message('images:imcontrastUIString:outOfRangeLastLine')));

str{2} = sprintf(lastLineStr);
wdlg = questdlg(str, ...
    getString(message('images:imcontrastUIString:invalidDisplayRange')),...
    getString(message('images:commonUIString:ok')),...
    getString(message('images:commonUIString:cancel')),...
    getString(message('images:commonUIString:ok')));
end

%==========================================================
function badValue = isDisplayRangeOutsideDataRange(him,hax)

% Checking to see if the display range is outside the image's data range.
% clim = get(hax,'Clim');
% histStruct = getHistogramData(him);
% histRange = histStruct.histRange;
% badValue = true;


% The calculated histogram range can be negative because of wiggle room at
% the ends.
% if ((clim(1) < histRange(1)) && (clim(2) < histRange(2))) || ...
%         ((clim(1) > histRange(1)) && (clim(2) > histRange(2))) || ...
%         ((clim(1) > histRange(1)) && (clim(2) < histRange(2)))
%     badValue = true;
% end

% if ((clim(1) <= histRange(1)) && (clim(2) >= histRange(2)))
%      badValue = false;
% end

% clim = get(hax,'Clim');
% histRange = [min(him.CData(:)), max(him.CData(:))];
% badValue = true;
%
% if ((clim(1) <= histRange(1)) && (clim(2) >= histRange(2)))
%      badValue = false;
% end

clim = get(hax,'Clim');
histStruct = images.internal.getHistogramData(him);
histRange = histStruct.histRange;
badValue = false;

if ((clim(1) < histRange(1)) || (clim(2) > histRange(2)))
    badValue = true;
end

end


