function renderWidgets(this)
%

% Copyright 2017-2021 The MathWorks, Inc.

if ispc
    w = 80;
else
    w = 104;
end

this.DimsStatus = spcwidgets.Status( ...
    this.Application.Handles.statusBar, ...
    'Tag', [sprintf('%s Dims', class(this)) 'Status'], ...
    'Width', w);
this.Magnification = spcwidgets.Status( ...
    this.Application.Handles.statusBar, ...
    'Tag', [sprintf('%s Magnify', class(this)) 'Status'], ...
    'Width', w);
keyGroup = getString(message('Spcuilib:scopes:TitleVideo'));
this.Application.addKeyPress( ...
    'colormap', ...
    keyGroup, ...
    'C', ...
    @(h,ev) showColormapDialog(this), ...
    getString(message('Spcuilib:scopes:LabelChangeColorMap')));
this.Application.addKeyPress( ...
    'videoinfo', ...
    keyGroup, ...
    'V', ...
    @(h,ev) show(this.VideoInfo, true), ...
    getString(message('Spcuilib:scopes:LabelDisplayVideoInfo')));
    
setup(this, this.Application.Handles.visualizationPanel);

%--------------------------------------------------------------------------
function showColormapDialog(this)

hSrc = this.Application.DataSource;
if ~isempty(hSrc) && isDataLoaded(hSrc) && ~this.isRGB(hSrc)
    show(this.ColorMap, true)
end
