function [backgroundColor, API, windowClipPanelWidth] = ...
    createWindowClipPanel(hFlow, imgModel, rsetMode)
%createWindowClipPanel Create windowClipPanel in imcontrast tool
%   outputs =
%   createWindowClipPanel(hFig,imageRange,imgHasLessThan5Levels,imgModel)
%   creates the WindowClipPanel (top panel in contrast tool) in the contrast
%   tool. Outputs are used to set up display and callbacks in imcontrast.
%
%   This function is used by IMCONTRAST.

%   Copyright 2005-2023 The MathWorks, Inc.


% Global scope
[getEditBoxValue, formatEditBoxString] = getFormatFcns(imgModel);
[hImMinEdit, hImMaxEdit] = deal(gobjects(0));

% Create panel.
hWindowClipPanel = uipanel('parent', hFlow, ...
    'Units', 'pixels', ....
    'BorderType', 'none', ...
    'Tag', 'window clip panel');

hWindowClipPanel.Layout.Row = 1;
hWindowClipPanel.Layout.Column = 1;

backgroundColor = get(hWindowClipPanel,'BackgroundColor');

hWindowClipPanelMargin = 5;
hWindowClipPanelFlow = uigridlayout(...
    'Parent', hWindowClipPanel,...
    'RowHeight',{130},...
    'ColumnWidth',{'fit','fit','fit'},...
    'Padding',hWindowClipPanelMargin,...
    'ColumnSpacing',hWindowClipPanelMargin,...
    'RowSpacing',hWindowClipPanelMargin);

fudge = 40;

imDataRangePanelWH = createImDataRangePanel;

[editBoxAPI, eyedropperAPI, windowPanelWH] = ...
    createWindowPanel;

[scalePanelAPI, scaleDisplayPanelWH] = createScaleDisplayPanel;

API.editBoxAPI = editBoxAPI;
API.scalePanelAPI = scalePanelAPI;
API.eyedropperAPI = eyedropperAPI;
API.updateImageModel = @updateImageModel;

windowClipPanelWidth = imDataRangePanelWH(1) + windowPanelWH(1) + ...
    scaleDisplayPanelWH(1) + fudge;

if (rsetMode)
    API.eyedropperAPI.minDropper.handle.Enable = 'off';
    API.eyedropperAPI.maxDropper.handle.Enable = 'off';
end

%==============================================================
    function updateImageModel(newImageModel)
        % update format functions
        [getEditBoxValue, formatEditBoxString] = ...
            getFormatFcns(newImageModel);
        
        % update min/max image intensities
        set(hImMinEdit,'Value',...
            formatEditBoxString(getMinIntensity(imgModel)));
        set(hImMaxEdit,'Value',...
            formatEditBoxString(getMaxIntensity(imgModel)));
    end

%==============================================================
    function imDataRangePanelWH = createImDataRangePanel
        
        hImDataRangePanel = uipanel('Parent', hWindowClipPanelFlow,...
            'Tag', 'data range panel',...
            'Title', getString(message('images:privateUIString:dataRangePanelTitle')));
        
        hImIntGridMgr = uigridlayout(...
            'Parent', hImDataRangePanel,...
            'RowHeight', {'fit','fit'},...
            'ColumnWidth', {'fit', 80});
        
        hImMin = uilabel('Parent', hImIntGridMgr,...
            'HorizontalAlignment', 'left',...
            'Tag','min data range label',...
            'Tooltip', getString(message('images:privateUIString:createWindowClipPanelMinTooltip')),...
            'Text', getString(message('images:privateUIString:createWindowClipPanelMinimum')));
        
        hImMinEdit = uieditfield('Parent',hImIntGridMgr,...
            'Value', formatEditBoxString(getMinIntensity(imgModel)),...
            'Tag', 'min data range edit',...
            'Tooltip', getString(message('images:privateUIString:createWindowClipPanelMinTooltip')), ...
            'HorizontalAlignment', 'right',...
            'Enable', 'off');
        
        hImMax = uilabel('Parent', hImIntGridMgr,...
            'Text', getString(message('images:privateUIString:createWindowClipPanelMaximum')),...
            'Tag','max data range label',...
            'HorizontalAlignment', 'left');
        
        hImMaxEdit = uieditfield('Parent',hImIntGridMgr,...
            'Value', formatEditBoxString(getMaxIntensity(imgModel)),...
            'Tag', 'max data range edit',...
            'Tooltip', getString(message('images:privateUIString:createWindowClipPanelMaxTooltip')), ...
            'HorizontalAlignment', 'right',...
            'Enable', 'off');
        
        imDataRangePanelWH = calculateWHOfPanel;
        
        %======================================
        function panelWH = calculateWHOfPanel
            
            % Calculate width and height limits of the panel.
            [topRowWidth, topRowHeight] = ...
                getTotalWHofControls([hImMin hImMinEdit]);
            [botRowWidth, botRowHeight] = ...
                getTotalWHofControls([hImMax hImMaxEdit]);
            
            maxWidth = max([topRowWidth botRowWidth]) + 2 * fudge;
            maxHeight = topRowHeight + botRowHeight + fudge;
            panelWH = [maxWidth maxHeight];
        end
        
    end

%======================================================================
    function [editBoxAPI, eyedropperAPI, windowPanelWH] = ...
            createWindowPanel
        
        hWindowPanel = uipanel('Parent', hWindowClipPanelFlow,...
            'Tag', 'window panel',...
            'BackgroundColor', backgroundColor,...
            'Title', getString(message('images:privateUIString:windowPanelTitle')));
                
        hWindowPanelFlow = uigridlayout(...
            'Parent', hWindowPanel,...
            'RowHeight', {'fit','fit'},...
            'ColumnWidth', {'fit',80,30,4,'fit',100}); % '1x','0.5x','0.1x','fit','1x'});
                
        hMinLabel = uilabel('parent', hWindowPanelFlow, ...
            'Text',getString(message('images:privateUIString:createWindowClipPanelMinimum')), ...
            'Tag','window min label',...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', backgroundColor);
        
        hMinEdit = uieditfield('parent', hWindowPanelFlow, ...
            'Tag', 'window min edit', ...
            'HorizontalAlignment', 'right', ...
            'BackgroundColor', [1 1 1], ...
            'Tooltip', getString(message('images:privateUIString:createWindowClipPanelWinMinTooltip')));
        
        iconRoot = ipticondir;
        iconCdata = images.internal.app.utilities.makeToolbarIconFromPNG(fullfile(iconRoot, ...
            'tool_eyedropper_black.png'));
        
        hMinDropper = uibutton('parent', hWindowPanelFlow, ...
            'Text', '',...
            'Icon', iconCdata, ...
            'Tooltip', getString(message('images:privateUIString:selectMinValTooltip')), ...
            'tag', 'min eye dropper button', ...
            'HorizontalAlignment', 'center');
        
        hMaxLabel = uilabel('parent', hWindowPanelFlow, ...
            'Text', getString(message('images:privateUIString:createWindowClipPanelMaximum')), ...
            'Tag','window max label',...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', backgroundColor);
        
        hMaxLabel.Layout.Row = 2;
        hMaxLabel.Layout.Column = 1;
        
        hMaxEdit = uieditfield('parent', hWindowPanelFlow, ...
            'Tag', 'window max edit', ...
            'HorizontalAlignment', 'right', ...
            'BackgroundColor', [1 1 1],...
            'Tooltip', getString(message('images:privateUIString:createWindowClipPanelWinMaxTooltip')));
        
        iconCdata = images.internal.app.utilities.makeToolbarIconFromPNG(fullfile(iconRoot, ...
            'tool_eyedropper_white.png'));
        
        hMaxDropper = uibutton('parent', hWindowPanelFlow, ...
            'Text', '',...
            'Icon', iconCdata, ...
            'Tooltip', getString(message('images:privateUIString:selectMaxValTooltip')), ...
            'tag', 'max eye dropper button',...
            'HorizontalAlignment', 'center');
        
        spacing1 = uilabel('Parent', hWindowPanelFlow, ...
            'Text', ' ',...
            'Tag','spacing');
        spacing1.Layout.Row = 1;
        spacing1.Layout.Column = 4;
        
        hWidthLabel = uilabel('parent', hWindowPanelFlow, ...
            'Text', getString(message('images:privateUIString:winPanelWidth')), ...
            'Tag','window width label',...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', backgroundColor);
        
        hWidthLabel.Layout.Row = 1;
        hWidthLabel.Layout.Column = 5;
        
        hWidthEdit = uieditfield('parent', hWindowPanelFlow, ...
            'Tag', 'window width edit', ...
            'HorizontalAlignment', 'right', ...
            'BackgroundColor', [1 1 1], ...
            'Tooltip', getString(message('images:privateUIString:windowWidthTooltip')));
        
        hWidthEdit.Layout.Row = 1;
        hWidthEdit.Layout.Column = 6;
                
        spacing2 = uilabel('Parent', hWindowPanelFlow,...
            'Text', ' ',...
            'tag', 'spacing');
        
        spacing2.Layout.Row = 2;
        spacing2.Layout.Column = 4;
        
        hCenterLabel = uilabel('parent', hWindowPanelFlow, ...
            'Text', getString(message('images:privateUIString:winPanelCenter')), ...
            'tag','window center label',...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', backgroundColor);
        hCenterLabel.Layout.Row = 2;
        hCenterLabel.Layout.Column = 5;
        
        hCenterEdit = uieditfield('parent', hWindowPanelFlow, ...
            'Tag', 'window center edit', ...
            'HorizontalAlignment', 'right', ...
            'BackgroundColor', [1 1 1], ...
            'Tooltip', getString(message('images:privateUIString:windowCenterTooltip')));
        
        hCenterEdit.Layout.Row = 2;
        hCenterEdit.Layout.Column = 6;
        
        windowPanelWH = calculateWHOfPanel;
        
        %============================================
        function windowPanelWH = calculateWHOfPanel
            
            topRow = [hMinLabel hMinEdit hMinDropper spacing1 hWidthLabel ...
                hWidthEdit];
            [topRowWidth, topRowHeight] = getTotalWHofControls(topRow);
            
            botRow = [hMaxLabel hMaxEdit hMaxDropper hCenterLabel ...
                spacing2 hCenterEdit];
            [botRowWidth, botRowHeight] = getTotalWHofControls(botRow);
            
            panelWidth = max([topRowWidth botRowWidth]) + 7 * fudge;
            panelHeight = sum([topRowHeight botRowHeight]) + fudge;
            windowPanelWH = [panelWidth panelHeight];
        end
        
        [editBoxAPI, eyedropperAPI] = createWindowWidgetAPI;
        
        
        %==========================================================
        function [editBoxAPI, eyedropperAPI] = createWindowWidgetAPI
            
            editBoxAPI.centerEdit.handle = hCenterEdit;
            editBoxAPI.centerEdit.set    = @setCenter;
            editBoxAPI.centerEdit.get    = @() getEditValue(hCenterEdit);
            
            editBoxAPI.maxEdit.handle = hMaxEdit;
            editBoxAPI.maxEdit.set    = @setMaxValue;
            editBoxAPI.maxEdit.get    = @() getEditValue(hMaxEdit);
            
            editBoxAPI.minEdit.handle = hMinEdit;
            editBoxAPI.minEdit.set    = @setMinValue;
            editBoxAPI.minEdit.get    = @() getEditValue(hMinEdit);
            
            editBoxAPI.widthEdit.handle  = hWidthEdit;
            editBoxAPI.widthEdit.set     = @setWidthEdit;
            editBoxAPI.widthEdit.get     = @() getEditValue(hWidthEdit);
            
            eyedropperAPI.minDropper.handle = hMinDropper;
            eyedropperAPI.minDropper.set    = '';
            eyedropperAPI.minDropper.get    = 'minimum';
            
            eyedropperAPI.maxDropper.handle = hMaxDropper;
            eyedropperAPI.maxDropper.set    = '';
            eyedropperAPI.maxDropper.get    = 'maximum';
            
            %=========================
            function setMinValue(clim)
                set(hMinEdit, 'Value', formatEditBoxString(clim(1)));
            end
            
            %=========================
            function setMaxValue(clim)
                set(hMaxEdit, 'Value', formatEditBoxString(clim(2)));
            end
            
            %=======================
            function setWidthEdit(clim)
                width = computeWindow(clim);
                set(hWidthEdit, 'Value', formatEditBoxString(width));
            end
            
            %=======================
            function setCenter(clim)
                [~, center] = computeWindow(clim);
                set(hCenterEdit,'Value', formatEditBoxString(center));
            end
        end %createWindowWidgetAPI
        
        %=============================================
        function [width, center] = computeWindow(CLim)
            width = CLim(2) - CLim(1);
            center = CLim(1) + width ./ 2;
        end
        
    end %createWindowPanel

%======================================================================
    function [scalePanelAPI,scaleDisplayPanelWH] = ...
            createScaleDisplayPanel
        
        enablePropValue = 'on';
        defaultOutlierValue = '2';
        
        hScaleDisplayPanel = uibuttongroup('Parent', hWindowClipPanelFlow,...
            'Tag', 'scale display range panel', ...
            'BackgroundColor', backgroundColor, ...
            'Title', getString(message('images:privateUIString:scaleDisplayPanelTitle')));
        
        hScaleDisplayPanel.Layout.Row = 1;
        hScaleDisplayPanel.Layout.Column = 3;
        
        % uiradiobutton cannot be placed inside a uigridlayout (g1981566).
        % Therefore, place uiradiobutton objects at specific locations by
        % setting their 'Position' property.
        xLoc = 3;
        yLoc = 109;
        width = 131;
        height = 20;
        hMatchDataRangeBtn = uiradiobutton('Parent', hScaleDisplayPanel,...
            'Enable', enablePropValue, ...
            'Text', getString(message('images:privateUIString:scaleDisplayMatchRange')),...
            'Tag', 'match data range radio',...
            'Position',[xLoc yLoc-10-height width height]);
        
        hElimRadioBtn = uiradiobutton('Parent', hScaleDisplayPanel,...
            'Text', getString(message('images:privateUIString:scaleDisplayEliminateOutliers')),...
            'Enable', enablePropValue, ...
            'Tag', 'eliminate outliers radio',...
            'Position',[xLoc yLoc-20-2*height width height]);
        
        widthEdit = 30;
        hPercentEdit = uieditfield('Parent', hScaleDisplayPanel,...
            'Value',defaultOutlierValue,...
            'Enable', enablePropValue, ...
            'Background', 'w', ...
            'Tag', 'outlier percent edit',...
            'HorizontalAlignment', 'right',...
            'Position',[xLoc+width+10 yLoc-20-2*height widthEdit height]);
        
        hPercentText = uilabel('Parent', hScaleDisplayPanel,...
            'Text', '%',...
            'Enable', enablePropValue, ...
            'Tag','% string',...
            'Position',[xLoc+width+10+widthEdit+2 yLoc-20-2*height 10 height]);
        
        hScaleDisplayBtn = uibutton('Parent', hScaleDisplayPanel,...
            'Text', getString(message('images:privateUIString:scaleDisplayApply')),...
            'Tag', 'apply button',...
            'Tooltip', getString(message('images:privateUIString:scaleDisplayApplyTooltip')),...
            'Enable', enablePropValue,...
            'Position',[xLoc yLoc-30-3*height 60 height]);
        
        % Explicit assignment in parent function is required if variable is
        % intended to be shared among parent and nested functions
        scaleDisplayPanelHeight = 1;
        scaleDisplayPanelWidth = 1;
        
        scaleDisplayPanelWH = calculateWHOfPanel;
        
        %==================================
        function pWH = calculateWHOfPanel
            
            [~, topRowHeight] = ...
                getTotalWHofControls(hMatchDataRangeBtn);
            
            midRow = [hElimRadioBtn hPercentEdit hPercentText];
            [midRowWidth, midRowHeight] = getTotalWHofControls(midRow);
            
            [~, botRowHeight] = getTotalWHofControls(hScaleDisplayBtn);
            
            scaleDisplayPanelWidth = midRowWidth + 2 * fudge;
            scaleDisplayPanelHeight = topRowHeight + midRowHeight + ...
                botRowHeight + fudge;
            pWH = [scaleDisplayPanelWidth scaleDisplayPanelHeight];
        end
        
        scalePanelAPI = createScalePanelAPI;
        
        %=========================================
        function scalePanelAPI = createScalePanelAPI
            
            scalePanelAPI.elimRadioBtn.handle = hElimRadioBtn;
            scalePanelAPI.elimRadioBtn.set = ...
                @(v) set(hElimRadioBtn, 'Value', v);
            scalePanelAPI.elimRadioBtn.get = ...
                @() get(hElimRadioBtn, 'Value');
            
            scalePanelAPI.matchDataRangeBtn.handle = hMatchDataRangeBtn;
            scalePanelAPI.matchDataRangeBtn.set = ...
                @(v) set(hMatchDataRangeBtn, 'Value', v);
            scalePanelAPI.matchDataRangeBtn.get = ...
                @() get(hMatchDataRangeBtn, 'Value');
            
            scalePanelAPI.percentEdit.handle = hPercentEdit;
            scalePanelAPI.percentEdit.set = ...
                @(s) set(hPercentEdit, 'Value', s);
            scalePanelAPI.percentEdit.get = ...
                @() getEditValue(hPercentEdit);
            
            scalePanelAPI.scaleDisplayBtn.handle = hScaleDisplayBtn;
            scalePanelAPI.scaleDisplayBtn.set = '';
            scalePanelAPI.scaleDisplayBtn.get = '';
        end
        
    end %createScaleDisplayPanel

%===============================
    function value = getEditValue(h)
        value = getEditBoxValue(sscanf(get(h, 'Value'), '%f'));
    end

%==================================================================
    function [totalWidth, totalHeight] = getTotalWHofControls(hControls)
        position = cell(numel(hControls),1);
        for idx = 1:numel(hControls)
            position{idx} = hControls(idx).Position;
        end
        
        position = [position{:}];
        totalWidth = sum(position(3:4:end));
        totalHeight = max(position(4:4:end));
    end
end % createWindowClipPanel

%==========================================================================
function [getEditBoxValue, formatEditBoxString] = getFormatFcns(imgModel)

[~, imgContainsFloat, imgNeedsExponent] = getNumberFormatFcn(imgModel);

isIntegerData = ~strcmp(getClassType(imgModel),'double');

if isIntegerData
    getEditBoxValue = @round;
    formatEditBoxString = @(val) sprintf('%0.0f', val);
    
else
    getEditBoxValue = @(x) x;
    if imgNeedsExponent
        formatEditBoxString = @createStringForExponents;
    elseif imgContainsFloat
        formatEditBoxString = @(val) sprintf('%0.4f', val);
    else
        % this case handles double data that contains integers, e.g., eye(100), int16
        % data, etc.q
        formatEditBoxString = @(val) sprintf('%0.0f', val);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function string = createStringForExponents(value)
        
        string = sprintf('%1.1E', value);
    end
end
