function hout = imoverview(varargin)

narginchk(1, 1);
himage = varargin{1};

iptcheckhandle(himage,{'image'},mfilename,'HIMAGE',1)
hScrollpanel = images.internal.legacyui.utils.checkimscrollpanel(himage,mfilename,'HIMAGE');
apiScrollpanel = iptgetapi(hScrollpanel);

hScrollpanelFig = ancestor(hScrollpanel,'figure');
hScrollpanelIm  = himage;
hScrollpanelAxes = ancestor(himage,'axes');

hOverviewFig = figure('Menubar','none',...
    'IntegerHandle','off',...
    'HandleVisibility','Callback',...
    'NumberTitle','off',...
    'Name',createFigureName(getString(message('images:commonUIString:overview')),hScrollpanelFig), ...
    'Tag','imoverview',...
    'Colormap',colormap(hScrollpanelAxes),...
    'Visible','off',...
    'DeleteFcn',@deleteOverviewFig,...
    'WindowStyle',get(0,'FactoryFigureWindowStyle'));

images.internal.legacyui.utils.suppressPlotTools(hOverviewFig);

% keep the figure name up to date
linkToolName(hOverviewFig,hScrollpanelFig,getString(message('images:commonUIString:overview')));

% set figure size
fig_pos = get(hOverviewFig,'Position');
curUnits = get(hOverviewFig,'Units');
set(hOverviewFig,'Units','Pixels');
set(hOverviewFig,'Position',[fig_pos(1:2) 200 200]);
set(hOverviewFig,'Units',curUnits);

% drawnow is a workaround to geck 268506
drawnow;

% use same renderer as parent
set(hOverviewFig,'Renderer',get(hScrollpanelFig,'Renderer'));

% create overview panel
hOverviewPanel = imoverviewpanel(hOverviewFig,hScrollpanelIm);
hOverviewAxes = findall(hOverviewPanel,'type','Axes');

% customize overview figure toolbar and menubar
toolbarOld = findall(hOverviewFig,'type','uitoolbar');
delete(toolbarOld);
[zoomInButton,zoomOutButton] = createToolbar(hOverviewFig,apiScrollpanel);
createMenubar(hOverviewFig,apiScrollpanel);

% link colormap to target image axes's colormap
linkFig = linkprop([hScrollpanelAxes.ColorSpace hOverviewAxes.ColorSpace],'Colormap');
setappdata(hOverviewFig, 'OverviewListeners', linkFig);

% Position the overview figure to the upper left and make visible.
iptwindowalign(hScrollpanelFig, 'left', hOverviewFig, 'right');
iptwindowalign(hScrollpanelFig, 'top', hOverviewFig, 'top');
set(hOverviewFig,'Visible','on')

% Set up wiring so zoom buttons enable/disable according to
% magnification of main image.
updateZoomButtons(apiScrollpanel.getMagnification())
magCallbackID = apiScrollpanel.addNewMagnificationCallback(@updateZoomButtons);

% create listeners and register tool handle
images.internal.legacyui.utils.reactToImageChangesInFig(himage,hOverviewFig,...
    @reactDeleteFcn,@reactRefreshFcn);
registerModularToolWithManager(hOverviewFig,himage);

if (nargout==1)
    hout = hOverviewFig;
end


    %------------------------------
    function updateZoomButtons(mag)
        
        if ishghandle(hOverviewFig)
            
            if mag <= apiScrollpanel.getMinMag();
                set(zoomOutButton,'Enable','off')
            else
                set(zoomOutButton,'Enable','on')
            end
            
            % arbitrary big choice, 1024 screen pixels for one image
            % pixel, same as in imtool.m
            if mag>=1024
                set(zoomInButton,'Enable','off')
            else
                set(zoomInButton,'Enable','on')
            end
        end
        
    end


    %-------------------------------
    function reactDeleteFcn(obj,evt) %#ok<INUSD>
        
        if ishghandle(hOverviewFig)
            delete(hOverviewFig);
        end
        
    end


    %-------------------------------
    function reactRefreshFcn(obj,evt) %#ok<INUSD>
        
        % close tool if the target image cdata is empty
        if isempty(get(himage,'CData'))
            reactDeleteFcn();
        end
        
    end


    %-----------------------------------
    function deleteOverviewFig(varargin)
        
        apiScrollpanel.removeNewMagnificationCallback(magCallbackID);
        
    end

end % imoverview


%---------------------------------------------------------------------------------
function [zoomInButton,zoomOutButton] = createToolbar(hOverviewFig,apiScrollpanel)

toolbar =  uitoolbar(hOverviewFig);

[iconRoot,iconRootMATLAB] = ipticondir;

zoomInIcon = images.internal.app.utilities.makeToolbarIconFromPNG(fullfile(iconRoot,...
    'overview_zoom_in.png'));
zoomInButton = createToolbarPushItem(toolbar,zoomInIcon,...
    {@zoomIn},...
    getString(message('images:commonUIString:zoomInTooltip')),...
    'zoom in');

zoomOutIcon = images.internal.app.utilities.makeToolbarIconFromPNG(fullfile(iconRoot,...
    'overview_zoom_out.png'));
zoomOutButton = createToolbarPushItem(toolbar,zoomOutIcon,...
    {@zoomOut},...
    getString(message('images:commonUIString:zoomOutTooltip')),...
    'zoom out');

if ~isdeployed
    helpIcon = images.internal.legacyui.utils.makeToolbarIconFromGIF(fullfile(iconRootMATLAB, 'helpicon.gif'));
    createToolbarPushItem(toolbar,...
        helpIcon,...
        @showOverviewHelp,...
        getString(message('images:commonUIString:help')),...
        'help');
end

    %------------------------
    function zoomIn(varargin)
        
        newMag = images.internal.findZoomMag('in',apiScrollpanel.getMagnification());
        apiScrollpanel.setMagnification(newMag)
        
    end % zoomIn


    %-------------------------
    function zoomOut(varargin)
        
        newMag = images.internal.findZoomMag('out',apiScrollpanel.getMagnification());
        apiScrollpanel.setMagnification(newMag)
        
    end %zoomOut


end % createToolbar


%--------------------------------------------------
function createMenubar(hOverviewFig,apiScrollpanel)

filemenu = uimenu(hOverviewFig,...
    'Label',getString(message('images:commonUIString:fileMenubarLabel')),...
    'Tag','file menu');

editmenu = uimenu(hOverviewFig,...
    'Label',getString(message('images:commonUIString:editMenubarLabel')),...
    'Tag','edit menu');



matlab.ui.internal.createWinMenu(hOverviewFig);

% File menu
uimenu(filemenu,...
    'Label',getString(message('images:commonUIString:printToFigureMenubarLabel')),...
    'Tag','print to figure menu item',...
    'Callback',@(varargin) images.internal.legacyui.utils.printImageToFigure(hOverviewFig));

uimenu(filemenu,...
    'Label',getString(message('images:commonUIString:closeMenubarLabel')),...
    'Accelerator','W',...
    'Tag','close menu item',...
    'Callback',@(varargin) close(hOverviewFig));

% Edit menu
uimenu(editmenu,...
    'Label', getString(message('images:commonUIString:copyPositionMenubarLabel')),...
    'Callback', @(varargin) clipboard('copy', apiScrollpanel.getVisibleImageRect()),...
    'Tag', 'copy position menu item');


% Help menu
if ~isdeployed
    
    helpmenu = uimenu(hOverviewFig,...
        'Label',getString(message('images:commonUIString:helpMenubarLabel')),...
        'Tag','help menu');
    
    uimenu(helpmenu,...
        'Label',getString(message('images:imoverviewUIString:overviewHelpMenubarLabel')),...
        'Tag','help menu item',...
        'Callback',@showOverviewHelp);
    
    images.internal.legacyui.utils.iptstandardhelp(helpmenu);
end

end % createMenubar


%-------------------------------------------------------------------
function item = createToolbarPushItem(toolbar,icon,callback,tooltip,tagString)

% The tagString parameter was added to ensure that clients can pass a
% string that won't be localized for purposes of testing.

item = uipushtool(toolbar,...
    'Cdata',icon,...
    'TooltipString',tooltip,...
    'Tag',strcat(tagString,' toolbar button'),...
    'ClickedCallback',callback);

end % createToolbarPushItem


%---------------------------------
function showOverviewHelp(obj,evt) %#ok<INUSD>

helpview("images", "overview_tool_help");

end % showOverviewHelp

%   Copyright 2003-2023 The MathWorks, Inc.

