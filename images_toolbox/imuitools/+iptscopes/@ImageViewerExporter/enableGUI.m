function enableGUI(this, enabState)
%ENABLEGUI Enable/disable the UI widgets.

%   Copyright 2007-2023 The MathWorks, Inc.

hui = getGUI(this.Application);
if isempty(hui)
    set([this.IVExporterMenu this.IVExporterButton], ...
        'Enable', enabState);
else
    set(hui.findchild('Base/Menus/File/Export/IVExporter'), 'Enable', enabState);
    set(hui.findchild('Base/Toolbars/Main/Export/IVExporter'), 'Enable', enabState);
end

% [EOF]