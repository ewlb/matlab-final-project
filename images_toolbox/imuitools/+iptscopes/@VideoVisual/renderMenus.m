function renderMenus(this)
%

% Copyright 2017-2021 The MathWorks, Inc.

toolsMenu = this.Application.Handles.toolsMenu;
this.VideoInfoMenu = uimenu( ...
    this.Application.Handles.toolsMenu, ...
    'Tag', 'uimgr.uimenu_VideoInfo', ...
    'Label', getString(message('Spcuilib:scopes:MenuVidInfo')), ...
    'Callback', @(hco,ev) show(this.VideoInfo, true));

hSource = this.Application.DataSource;
if isempty(hSource) || ~isDataLoaded(hSource) || this.isRGB(hSource)
    ena = 'off';
else
    ena = 'on';
end

this.ColormapMenu = uimenu( ...
    this.Application.Handles.toolsMenu, ...
    'Tag', 'uimgr.uimenu_Colormap', ...
    'Label', getString(message('Spcuilib:scopes:MenuColorMap')), ...
    'Enable', ena, ...
    'Callback', @(hco,ev) show(this.ColorMap, true));

% Magnification
magItem = uimenu(toolsMenu,...
    'Text',getString(message('images:imtoolUIString:magnification')));

% Common properties for all Children menu for magnification
m1.Parent = magItem;
m1.MenuSelectedFcn = @(src,event)magnify(src,event,this);

% Fit to Window
m1.Label = getString(message('images:imtoolUIString:magnifyFitToWindow'));
m1.Tag = 'fit';
uimenu(m1);
% Magnify by 33%
m1.Label = '33%';
m1.Tag = 'mag33';
uimenu(m1);
% Magnify by 50%
m1.Label = '50%';
m1.Tag = 'mag50';
uimenu(m1);
% Magnify by 67%
m1.Label = '67%';
m1.Tag = 'mag67';
uimenu(m1);
% Magnify by 100%
m1.Label = '100%';
m1.Tag = 'mag100';
uimenu(m1);
% Magnify by 200%
m1.Label = '200%';
m1.Tag = 'mag200';
uimenu(m1);
% Magnify by 400%
m1.Label = '400%';
m1.Tag = 'mag400';
uimenu(m1);
% Magnify by 800%
m1.Label = '800%';
m1.Tag = 'mag800';
uimenu(m1);
end


function magnify(s,~,this)

hSP  = this.ScrollPanel;
spAPI = iptgetapi(hSP);

switch s.Text
    case getString(message('images:imtoolUIString:magnifyFitToWindow'))
        newMag = spAPI.findFitMag();
    case '33%'
        newMag = 0.33;
    case '50%'
        newMag = 0.5;
    case '67%'
        newMag = 0.67;
    case '100%'
        newMag = 1;
    case '200%'
        newMag = 2;
    case '400%'
        newMag = 4;
    case '800%'
        newMag = 8;
end

% Update scrollpanel with New magnification
currentMag = spAPI.getMagnification();

% Make sure input data exists
if (~isempty(currentMag) && ~isempty(newMag))
    % Only call setMagnification if the magnification changed.
    if images.internal.magPercentsDiffer(currentMag, newMag)
        spAPI.setMagnification(newMag);
    end
end
updateMagnification(this,newMag);

end