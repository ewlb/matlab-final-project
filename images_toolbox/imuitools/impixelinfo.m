function hpanel = impixelinfo(varargin)

[h,parent] = parseInputs(varargin{:});

if strcmp(get(parent,'Type'),'figure')
    parentIsFigure = true;
else
    parentIsFigure = false;
end

imageHandles = imhandles(h);

if isempty(imageHandles)
    error(message('images:impixelinfo:noImageInFigure'))
end

hPixInfoPanel = createPanel;

images.internal.legacyui.utils.reactToImageChangesInFig(imageHandles,hPixInfoPanel,@reactDeleteFcn,[]);
registerModularToolWithManager(hPixInfoPanel,imageHandles);

if isequal(parent,ancestor(imageHandles,'figure')) && ...
        strcmp(get(parent,'Visible'),'on')
    figure(parent);
end

if nargout > 0
    hpanel = hPixInfoPanel;
end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function reactDeleteFcn(obj,evt) %#ok<INUSD>
        if ishghandle(hPixInfoPanel)
            delete(hPixInfoPanel);
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function hPixInfoPanel = createPanel

        units = 'pixels';
        posPanel = [1 1 300 20];
        visibility = 'off';

        if parentIsFigure
            backgrndColor = get(parent,'Color');
        else
            backgrndColor = get(parent,'BackgroundColor');
        end

        fudge = 2;

        hPixInfoPanel = uipanel('Parent',parent,...
            'Units',units,... 
            'Tag','pixelinfo panel',...
            'Visible',visibility,...
            'Bordertype','none',...
            'BackgroundColor', backgrndColor);
        matlab.ui.internal.PositionUtils.setDevicePixelPosition(hPixInfoPanel, posPanel);

        set(hPixInfoPanel,'Visible','on');  % must be in this function.

        hPixelInfoLabel = uicontrol('Parent',hPixInfoPanel,...
            'Style','text',...
            'String',getString(message('images:impixelinfoUIString:pixelInfoLabel')), ...
            'Tag','pixelinfo label',...
            'Units',units,...
            'Visible',visibility,...
            'BackgroundColor',backgrndColor);
                
        labelExtent = matlab.ui.internal.PositionUtils.getDevicePixelExtent(hPixelInfoLabel);
        posLabel = [posPanel(1) posPanel(2) labelExtent(3) labelExtent(4)];
        matlab.ui.internal.PositionUtils.setDevicePixelPosition(hPixelInfoLabel,posLabel);

        % initialize uicontrol that will contain the pixel info values.
        hPixelInfoValue = impixelinfoval(hPixInfoPanel,imageHandles);
        posPixInfoValue = matlab.ui.internal.PositionUtils.getDevicePixelPosition(hPixelInfoValue);
        matlab.ui.internal.PositionUtils.setDevicePixelPosition(hPixelInfoValue,...
            [posLabel(1)+posLabel(3) posPanel(2) posPixInfoValue(3) posPixInfoValue(4)]);
        posPixInfoValue = matlab.ui.internal.PositionUtils.getDevicePixelPosition(hPixelInfoValue);

        % link visibility of hPixInfoPanel and its children 
        hlink = linkprop([hPixInfoPanel hPixelInfoLabel hPixelInfoValue],...
            'Visible');
        setappdata(hPixInfoPanel,'linkToChildren',hlink);

        newPanelWidth = posPixInfoValue(1)+posPixInfoValue(3)+fudge;
        newPanelHeight = max([posLabel(4) posPixInfoValue(4)]) + 2*fudge;
        matlab.ui.internal.PositionUtils.setDevicePixelPosition(hPixInfoPanel,...
            [posPanel(1) posPanel(2) newPanelWidth newPanelHeight]);



    end

end  %main function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [h,parent] = parseInputs(varargin)

narginchk(0,2);

switch nargin
    case 0
        %IMPIXELINFO
        h = get(0, 'CurrentFigure');
        if isempty(h)
            error(message('images:impixelinfo:noImageInFigure'))
        end
        parent = h;

    case 1
        h = varargin{1};
        if ~ishghandle(h)
            error(message('images:impixelinfo:invalidGraphicsHandle', 'H'))
        end
        parent = ancestor(h,'Figure');

    case 2
        parent = varargin{1};
        if ishghandle(parent)
            type = get(parent,'type');
            if ~strcmp(type,'uipanel') && ~strcmp(type,'uicontainer') && ...
                    ~strcmp(type,'figure')
                error(message('images:impixelinfo:invalidParent'))
            end
        else
            error(message('images:impixelinfo:invalidGraphicsHandle', 'HPARENT'))
        end

        h = varargin{2};
        images.internal.legacyui.utils.checkImageHandleArray(h,mfilename);
end

end

%   Copyright 1993-2023 The MathWorks, Inc.
