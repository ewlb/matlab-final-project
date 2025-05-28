function panel = getPropsSchema(hCfg, hDlg) %#ok<INUSD>
%GetPropsSchema Construct dialog panel for ImageViewer properties.

%   Copyright 2007-2023 The MathWorks, Inc.

imageviewer_exp.Name           = getString(message('images:imageViewer:exportFromClients'));
imageviewer_exp.Tag            = 'NewImageViewer';
imageviewer_exp.Type           = 'checkbox';
imageviewer_exp.Source         = hCfg.Configuration.PropertySet; 
imageviewer_exp.ObjectProperty = 'NewImageViewer';
imageviewer_exp.RowSpan        = [1 1];
imageviewer_exp.ColSpan        = [1 1];

panel.Type       = 'group';
panel.Name       = getString(message('images:imageViewer:optionsPanelForClients'));
panel.LayoutGrid = [2 1];
panel.RowStretch = [0 1];
panel.ColStretch = 0;
panel.Items      = {imageviewer_exp};

% [EOF]