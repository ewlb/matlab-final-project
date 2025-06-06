function renderToolbars(this)
%

% Copyright 2017 The MathWorks, Inc.

hSrc = this.Application.DataSource;
if isempty(hSrc) || ~isDataLoaded(hSrc)
    enab = 'off';
else
    enab = 'on';
end

% Moved from @VideoVisual/renderToolbars
this.VideoInfoButton = uipushtool( ...
    this.Application.Handles.mainToolbar, ...
    'Tag', 'uimgr.uipushtool_VideoInfo', ...
    'BusyAction', 'cancel', ...
    'TooltipString', getString(message('Spcuilib:scopes:ToolTipVidInf')), ...
    'ClickedCallback', @(hco,ev) show(this.Application.Visual.VideoInfo, true), ...
    'CData', this.Application.getIcon('info'), ...
    'Separator','on');

this.PixelRegionButton = uipushtool( ...
    this.Application.Handles.mainToolbar, ...
    'Tag', 'uimgr.uipushtool_PixelRegion', ...
    'BusyAction', 'cancel', ...
    'Tooltip', getString(message('images:imtoolUIString:pixelRegionTooltipString')), ...
    'Click', @(hco,ev) launch(this), ...
    'Enable', enab, ...
    'CData', this.Application.getIcon('pixel_region'));
