function enableGUI(this, enabState)
%ENABLEGUI Enable the GUI widgets

%   Copyright 2007-2018 The MathWorks, Inc.

hVideo = this.Application.Visual;

hUI = this.Application.getGUI;
hSP = hVideo.ScrollPanel;

% At initialization there is no scroll panel because the scope is not
% rendered yet.
if ishghandle(hSP)
    
    if this.ScrollPanel ~= hSP

        % We're getting a new scroll panel.  Cache it and set it up.
        this.ScrollPanel = hSP;
        % Overwrite the resize function of the scroll panel.  Pass the old function
        % in so that we can call it before executing fit to view.
        set(hSP, 'ResizeFcn', {@resizeFcn, this, get(hSP, 'ResizeFcn')});
        this.AppliedMode = 'off'; % Make sure we force react to update.
        
        % Add a "listener" to the NewMagnification "event" from the scroll
        % panel.  In order to remove this at destruct, we need to save its ID.
        hapi = iptgetapi(hSP);
        this.CallbackID = hapi.addNewMagnificationCallback(@(newMag) newMagnification(this, newMag));
    end

    % Set the magnification 
    hapi = iptgetapi(hSP);
    hapi.setMagnification(getPropertyValue(this, 'Magnification'));

    lclFitToView(this, hSP);
    
    % Set up the interface components.
    react(this);
end

if isempty(hUI)
    set(this.MaintainButton, 'Enable', enabState);
    set(this.MaintainMenu, 'Enable', enabState);
else
    set([hUI.findchild('Base/Toolbars/Main/Tools/Zoom/Mag/Maintain') ...
        hUI.findchild('Base/Menus/Tools/Zoom/Mag/Maintain')], 'Enable', enabState);
end

% -------------------------------------------------------------------------
function newMagnification(this, newMag)

if ~strcmp(this.Mode, 'FitToView')
    setPropertyValue(this, 'Magnification', newMag);
end
% Updates the magnification display widget
% along with zoom in and zoom out actions
this.Application.Visual.updateMagnification(newMag);

% -------------------------------------------------------------------------
function resizeFcn(hcbo, ev, this, oldResizeFcn)

% If we haven't changed the pixel position, don't bother calling the
% expensive resize functions.
newPosition = getpixelposition(hcbo);
if isequal(this.OldPosition, newPosition)
    return;
end

% Cache the new pixel position
this.OldPosition = newPosition;

% Call the built-in imscrollpanel's resize.
oldResizeFcn(hcbo, ev);

% When we are in 'FitToView' mode, update the magnification.
lclFitToView(this, hcbo);

% -------------------------------------------------------------------------
function lclFitToView(this, hSP)

if strcmpi(this.Mode, 'FitToView')
    hapi = iptgetapi(hSP);
    % This drawnow is necessary to address g995876.
    drawnow update
    hapi.setMagnification(hapi.findFitMag());
end

% [EOF]
