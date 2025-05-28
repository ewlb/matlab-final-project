function [hGrid,hImOvLeft,hImOvRight] = leftRightImoverviewpanel(parent,hImLeft,hImRight,webImpl)
%leftRightImoverviewpanel Display two images side-by-side in overview panels.
%   [hPanel,hOvLeft,hOvRight] = ...
%      leftRightImoverviewpanel(PARENT,hImLeft,hImRight) displays side-by-side
%   overview panels associated with hImLeft and hImRight. The handles hImLeft
%   and hImRight must refer to image objects that are each in and image scroll
%   panel. PARENT is a handle to an object that can contain a uigridcontainer.
%
%   Arguments returned include:
%      hPanel     - Handle to grid layout panel containing two overview panels
%      hImOvLeft  - Handle to image in left overview panel
%      hImOvRight - Handle to image in right overview panel
%

%   Copyright 2005-2021 The MathWorks, Inc.


% Create an overview panel for left image
hOvLeft = imoverviewpanel(parent,hImLeft);

% Create an overview panel for right image
hOvRight = imoverviewpanel(parent,hImRight);

set([hOvLeft hOvRight],'BorderType','etchedin')

if webImpl
    hGrid = uigridlayout(parent,[1 2]);
    hGrid.ColumnSpacing = 0;
    hGrid.Padding = 0;
    hPanelLeft  = uipanel('Parent',hGrid,'BorderType','none');
    hPanelRight = uipanel('Parent',hGrid,'BorderType','none');
else
    hGrid = uipanel('Parent',parent,'Position',[0 0 1 1],'BorderType','none');
    hPanelLeft  = uipanel('Parent',hGrid,'Position',[0 0 0.5 1],'BorderType','none');
    hPanelRight = uipanel('Parent',hGrid,'Position',[0.5 0 0.5 1],'BorderType','none');
end

hFig = iptancestor(hOvLeft,'Figure');
iptui.internal.setChildColorToMatchParent([hOvLeft,hOvRight,hGrid,hPanelLeft,hPanelRight],hFig);
                     
% Reparent hOvLeft and hOvRight
set(hOvLeft,'parent',hPanelLeft)
set(hOvRight,'parent',hPanelRight)

% Tag components for testing
set(hOvLeft,'Tag','LeftOverviewPanel')
set(hOvRight, 'Tag','RightOverviewPanel')  

hImOvLeft  = findobj(hOvLeft,'Type','image');
hImOvRight = findobj(hOvRight,'Type','image');

