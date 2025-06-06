function tools = navToolFactory(toolbar)
%navToolFactory Add navigational toolbar buttons to toolbar.
%   TOOLS = navToolFactory(TOOLBAR) returns TOOLS, a structure containing
%   handles to navigational tools. Tools for zoom in, zoom out, and pan are
%   added the TOOLBAR.
%
%   Note: navToolFactory does not set up callbacks for the tools.
%
%   Example
%   -------
%
%       hFig = figure('Toolbar','none',...
%                     'Menubar','none');
%       hIm = imshow('tissue.png'); 
%       hSP = imscrollpanel(hFig,hIm);
% 
%       toolbar = uitoolbar(hFig);
%       tools = navToolFactory(toolbar)
%
%   See also UITOGGLETOOL, UITOOLBAR.

%   Copyright 2005-2023 The MathWorks, Inc.  

[iconRoot, iconRootMATLAB] = ipticondir;

% Common properties
s.toolConstructor            = @uitoggletool;
s.properties.Parent          = toolbar;

% zoom in
s.iconConstructor            = @images.internal.legacyui.utils.makeToolbarIconFromGIF;
s.iconRoot                   = iconRootMATLAB;    
s.icon                       = 'view_zoom_in.gif';
s.properties.TooltipString   = getString(message('images:imtoolUIString:zoomInTooltipString'));
s.properties.Tag             = 'zoom in toolbar button';
tools.zoomInTool = images.internal.legacyui.utils.makeToolbarItem(s);

% zoom out
s.iconConstructor            = @images.internal.legacyui.utils.makeToolbarIconFromGIF;
s.iconRoot                   = iconRootMATLAB;    
s.icon                       = 'view_zoom_out.gif';
s.properties.TooltipString   = getString(message('images:imtoolUIString:zoomOutTooltipString'));
s.properties.Tag             = 'zoom out toolbar button';
tools.zoomOutTool = images.internal.legacyui.utils.makeToolbarItem(s);

% pan
s.iconConstructor            = @images.internal.app.utilities.makeToolbarIconFromPNG;
s.iconRoot                   = iconRoot;    
s.icon                       = 'tool_hand.png';
s.properties.TooltipString   = getString(message('images:imtoolUIString:panTooltipString'));
s.properties.Tag             = 'pan toolbar button';
tools.panTool = images.internal.legacyui.utils.makeToolbarItem(s);

