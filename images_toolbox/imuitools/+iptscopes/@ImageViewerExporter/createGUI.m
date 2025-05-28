function plugInGUI = createGUI(this)
%CreateGUI Build and cache UI plug-in for ImageViewer Export plug-in.
%   This adds the button and menu to the scope.
%   No install/render needs to be done here.

%   Copyright 2007-2023 The MathWorks, Inc.

% Place=1 for each of these within their respective Export groups
mExport = uimgr.uimenu('IVExporter',...
    getString(message('images:implayUIString:exportToImageViewerMenuLabel')));

mExport.setWidgetPropertyDefault(...
    'busyaction', 'cancel', ...
    'separator', 'on', ...
    'accel',     'e', ...
    'callback',  @(hco, ev) lclExport(this));

% Add the Export to ImageViewer toolbar button.
bExport = uimgr.uipushtool('IVExporter');
bExport.IconAppData = 'export_to_imtool';
bExport.setWidgetPropertyDefault(...
    'busyaction',    'cancel', ...
    'interruptible', 'off', ...
    'tooltip', getString(message('images:implayUIString:exportToImageViewerTooltip')), ...
    'click', @(hco, ev) lclExport(this));

% Create plug-in installer
plan = {mExport, 'Base/Menus/File/Export'; ...
        bExport, 'Base/Toolbars/Main/Export'};
plugInGUI = uimgr.Installer(plan);

function lclExport(this)

try
    export(this);
catch ME
    uiscopes.errorHandler(ME.message);
end

% [EOF]