function launch(this)
%LAUNCH Launch pixel region tool.

%   Copyright 2007-2015 The MathWorks, Inc.

% To launch PixelRegionTool, we first pause the scope if it's running
%
% Engage listener on PauseMethod event:
pause(this.Application, @(h,e) localPixelRegion(this));


function localPixelRegion(this)

hScope = this.Application;

% Launch PixelRegion tool
h = this.hPixelRegion;  % get existing PixelRegion widget handle
if ~ishghandle(h)
    
    hFig = hScope.Parent;
    
    % Create new pixel region tool
    this.hPixelRegion = impixelregion(hFig);

    % When impixelregion closes, disable the extension.  Turn off listeners.
    this.CloseListener = iptui.iptaddlistener(this.hPixelRegion, ...
        'ObjectBeingDestroyed', @(h,e) disable(this));
    this.VisibleListener = iptui.iptaddlistener(hFig, 'Visible', 'PostSet', ...
        @(h,e) disable(this));
else
    % Bring existing figure to front and center the view
    figure(h);
    pixelRegionPanel = findobj(this.hPixelRegion,'Tag','imscrollpanel');
    pixelRegionPanelAPI = getappdata(pixelRegionPanel,'impixelregionpanelAPI');
    pixelRegionPanelAPI.centerRectInViewport();

end

% [EOF]
