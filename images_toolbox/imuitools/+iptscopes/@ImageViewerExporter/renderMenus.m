function renderMenus(this)
%

% Copyright 2017-2023 The MathWorks, Inc.

this.IVExporterMenu = uimenu( ...
    this.Application.Handles.fileMenu, ...
    'Tag','uimgr.uimenu_IVExporter', ...
    'Label', getString(message('images:implayUIString:exportToImageViewerMenuLabel')), ...
    'BusyAction', 'cancel', ...
    'Separator', 'on', ...
    'Accelerator', 'e', ...
    'Callback', @(hco,ev) lclExport(this));

enabState = get(this.IVExporterButton,'Enable');
if ~isempty(enabState)
    set(this.IVExporterMenu,'Enable',enabState)
end

% Place it right below the Configuration menu item
anchorMenu = findobj(this.Application.Parent, 'Tag', 'uimgr.uimenugroup_Configs');
% When Configuration Set Edit/Load/Save is disabled,
% the uimenugroup becomes a uimenu
if isempty(anchorMenu)
    anchorMenu = findobj(this.Application.Parent, 'Tag', 'uimgr.uimenu_Configs');
end
if ~isempty(anchorMenu)
    this.IVExporterMenu.Position = get(anchorMenu,'Position') + 1;
end
