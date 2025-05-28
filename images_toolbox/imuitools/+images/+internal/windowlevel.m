function windowlevel(hImage, hCaller)
%WINDOWLEVEL Interactive Window/Level adjustment.
%   WINDOWLEVEL(HIMAGE, HCALLER) activates window/level interactivity on 
%   the target image. Clicking and dragging the mouse on the target image 
%   changes the image's window values. Dragging the mouse horizontally from
%   left to right changes the window width (i.e., contrast). Dragging the
%   mouse vertically up and down changes the window center (i.e.,
%   brightness). Holding down the CTRL key when clicking accelerates
%   changes. Holding down the SHIFT key slows the rate of change. Keys must
%   be pressed before clicking and dragging.
%   
%   HIMAGE is the handle to the target image. HCALLER is the handle to an
%   object that activates the WINDOWLEVEL behavior.  For instance, this may
%   be a button on another figure that turns on the WINDOWLEVEL behavior.
%   The windowlevel behavior is deactivated when HCALLER is deleted. 

%   Copyright 2005-2021 The MathWorks, Inc.

% Get handles to the parent axes and figure
[hIm, hImAx, hImFig] = imhandles(hImage);

isFloatingPointData = isfloat(get(hIm,'CData'));
histStruct = images.internal.getHistogramData(hIm);
origCLim = histStruct.histRange;

% Define variables for function scope
cbidMotion = [];
cbidUp = [];
cbidDelFcn = [];
emptyCallbackHandle = [];
motionStartAxes = [];
lastPointerPos = [];
WLSpeed = [];
wlMotionScale = getWLMotionScale(hIm);
newCLim = get(hImAx,'CLim');

if isFloatingPointData && (origCLim(1)>=0 && origCLim(2)<=1)
    valueFormatter = @(x) x;
else
    valueFormatter = @round;
end
    
% Start windowlevel action
wldown();

    %======================================================================
    function cancelWindowLevel(obj,evt)
        wlup();
    end %cancelWindowLevel

    %======================================================================
    function wldown(varargin)
        
        % Set the mouse event functions.
        setEmptyCallbackHandle();
        cbidMotion = addlistener(hImFig,'WindowMouseMotion', @wlmove);
        cbidUp = addlistener(hImFig,'WindowMouseRelease', @wlup);

        if nargin >= 3 && ~isempty(hCaller)
            % This prevents the windowlevel from functioning in the event that the
            % calling tool should close.  And also ensures that the appropriate
            % callbacks are detached from the image object's figure.
            cbidDelFcn = addlistener(hCaller, 'DeleteFcn', @cancelWindowLevel);
        else
            hCaller = hImFig;
        end

        % Keep track of values needed to adjust window/level.
        motionStartAxes = hImFig.CurrentAxes;
        lastPointerPos(1) = motionStartAxes.CurrentPoint(1,1);
        lastPointerPos(2) = motionStartAxes.CurrentPoint(1,2);

        % Figure out how quickly to change the window/level based on key
        % modifiers.
        WLSpeed = getWLSpeed(hImFig) * wlMotionScale;

    end % wldown


    %======================================================================
    function wlup(varargin)

        % Stop tracking mouse motion and button up.
        delete(cbidMotion);
        delete(cbidUp);
        delete(cbidDelFcn);
        clearEmptyCallbackHandle();
        
        % This is done so that the new clim is registered after the
        % figure's WindowButtonUpFcn is called.
        set(hImAx, 'CLim', newCLim);
        
    end %wlup


    %======================================================================
    function wlmove(varargin)
        
        if ~isequal(class(varargin{2}.HitObject),'matlab.graphics.primitive.Image')...
                || ~isequal(motionStartAxes,varargin{2}.HitObject.Parent)...
                || isModeManagerActive(motionStartAxes,hImFig)
                return
        end

        % Find out where the pointer has moved to.
        currentPos(1) = varargin{1}.CurrentAxes.CurrentPoint(1,1);
        currentPos(2) = varargin{1}.CurrentAxes.CurrentPoint(1,2);
        offset = currentPos - lastPointerPos;
        lastPointerPos = currentPos;

        % Determine the 
        % Get previous W/L.
        [windowWidth, windowCenter] = computeWindow(get(hImAx, 'CLim'));

        % Compute new window/level values and CLim endpoints.
        windowWidth = windowWidth + WLSpeed * offset(1);    % Contrast
        windowCenter = windowCenter + WLSpeed * offset(2);  % Brightness

        windowWidth = max(windowWidth, wlMotionScale);
        newCLim = zeros(1,2);
        [newCLim(1), newCLim(2)] = computeCLim(windowWidth, windowCenter);
                
        % Prevent endpoints from extending outside the bounds of the 
        % original CLim           
        newCLim(1) = max(newCLim(1), origCLim(1));
        newCLim(2) = min(newCLim(2), origCLim(2));
        
        newCLim = valueFormatter(newCLim);
        
        % Ensure that the new CLim is increasing i.e. clim(1) < clim(2)
        if (~isFloatingPointData && ((newCLim(2)-1) < newCLim(1)))
          newCLim = get(hImAx, 'CLim');
        elseif (isFloatingPointData && (newCLim(2)<=newCLim(1)))
          newCLim = get(hImAx, 'CLim');
        end                    
        
        % Change the axes CLim
        set(hImAx, 'CLim', newCLim);

    end % wlmove

    %--Set Empty Callback Handle---------------------------------------
    function setEmptyCallbackHandle()
        % Set callback for mouse button motion
        emptyCallbackHandle = @(~,~)emptyCallback();

        % Take control of figure motion and key press functions, only
        % if user hasn't set them already
        if isempty(hImFig.WindowButtonMotionFcn)
            hImFig.WindowButtonMotionFcn = emptyCallbackHandle;
        end

        if isempty(hImFig.KeyPressFcn)
            hImFig.KeyPressFcn = emptyCallbackHandle;
        end
    end % setEmptyCallbackHandle

    %--Clear Empty Callback Handle-------------------------------------
    function clearEmptyCallbackHandle()
        % Reset figure's motion and key press functions if the ROI's
        % emptyCallbackHandle is still there
        if isempty(hImFig)
            return;
        end
        if isequal(hImFig.WindowButtonMotionFcn,emptyCallbackHandle)
            hImFig.WindowButtonMotionFcn = [];
        end

        if isequal(hImFig.KeyPressFcn,emptyCallbackHandle)
            hImFig.KeyPressFcn = [];
        end
    end %clearEmptyCallbackHandle

    %--Empty Callback--------------------------------------------------
    function emptyCallback(varargin)
        % No-op callback
        % During interactive placement, the axes property CurrentPoint is
        % only updated when the figure's WindowButtonMotionFcn property is
        % not empty.

        % In the event that the user has not set the WindowButtonMotionFcn
        % property, we set it to this empty callback function to force the
        % CurrentPoint property to update whenever the mouse is moved
        % during drawing. If the user has set the WindowButtonMotionFcn
        % property, then there is no need to replace it.

        % Once the user has finished drawing, we check that the
        % WindowButtonMotionFcn property is this emptyCallback and, if
        % true, we set it to empty again. If the user has set the
        % WindowButtonMotionFcn property, then there is no impact on
        % their callback.
    end %emptyCallback

end % windowlevel

%==========================================================================
function [minPixel, maxPixel] = computeCLim(width, center)
%FINDWINDOWENDPOINTS   Process window and level values.
minPixel = (center - width/2);
maxPixel = minPixel + width;

end

%==========================================================================
function [width, center] = computeWindow(CLim)

width = CLim(2) - CLim(1);
center = CLim(1) + width ./ 2;

end

%==========================================================================
function scale = getWLMotionScale(hIm)

X = get(hIm, 'CData');

xMin = min(X(:));
xMax = max(X(:));

% Compute Histogram for the image.
switch (class(X))
        
    % Note: logical not supported in imcontrast, so we don't identify it as
    % a valid class(X).
    case {'int8','uint8'}
        scale = 1;
    case {'int16', 'uint16'}
        scale = 4;
    case {'int32','uint32'}
        scale = 4;
    case {'single','double'}
        % Images with double CData often don't work well with IMHIST.
        % Convert all images to be in the range [0,1] and convert back
        % later if necessary.
        if (xMin >= 0) && (xMax <= 1)
            scale = 1/255;
        else
            if ((xMax - xMin) > 1023)
                scale = 4;
            elseif ((xMax - xMin) > 255)
                scale = 2;
            else
                scale = 1;
            end
        end
        
    otherwise
        error(message('images:windowlevel:classNotSupported'))
        
end
end

%==========================================================================
function speed = getWLSpeed(hFig)

SelectionType = lower(get(hFig, 'SelectionType'));

switch (SelectionType)
    case {'normal', 'open'}
        speed = 1;
    case 'extend'
        speed = 0.5;
    case {'alternate', 'alt'}
        speed = 2;
end
end

%==========================================================================
function TF = isModeManagerActive(ax,fig)
TF = imageslib.internal.app.utilities.isAxesInteractionModeActive(ax,fig);
end
