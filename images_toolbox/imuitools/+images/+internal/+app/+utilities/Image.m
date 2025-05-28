classdef Image < handle & matlab.mixin.SetGet
    % For internal use only.
    
    % images.internal.app.utilities.Image - Use this class as a display
    % object for images when you want to allow zooming and panning to fill
    % the entire container panel.
    %
    % The current implementation expects a uipanel to be passed in the the
    % object for this class to use. This class also expects that the
    % uipanel must be the direct child of the figure.
    %
    % hfig = uifigure;
    % hpanel = uipanel('Parent',hfig);
    % images.internal.app.utilities.Image(hpanel);
    %
    % This class DOES NOT manage the scroll behavior. To manage the scroll
    % behavior, you should wire up listeners to all figures in your app/ui,
    % and determine where the mouse is located. If the mouse is hovering
    % over the figure with this image, then call the scroll method.
    %
    % This class DOES NOT manage pointer behavior when you click on a
    % toolbar item. You should include this logic wherever you manage
    % points for the entire app.
    %
    % Example classdef to create image and wire up scroll and mouse pointer
    % control:
    %
    % classdef ExampleApp < handle
    %
    %     % h = ExampleApp(uifigure, uifigure)
    %     % displayImage(h, imread('peppers.png'))
    %     % % You may need to resize figure 2 to have the image show up
    %
    %     properties
    %
    %         HitObject
    %         FigureWithImage
    %         OtherFigure
    %         Image
    %
    %     end
    %
    %     methods
    %         function app = ExampleApp(hfig1,hfig2)
    %
    %             app.FigureWithImage = hfig1;
    %             app.OtherFigure = hfig2;
    %
    %             hpanel = uipanel(...
    %                 'Parent', app.FigureWithImage,...
    %                 'Units','pixels',...
    %                 'Position', app.FigureWithImage.Position,...
    %                 'BorderType', 'none',...
    %                 'AutoResizeChildren','off');
    %
    %             app.Image = images.internal.app.utilities.Image(hpanel);
    %
    %             wireUpScrollListeners(app);
    %
    %             set(hfig1,...
    %                 'AutoResizeChildren','off',...
    %                 'Units','pixels',...
    %                 'SizeChangedFcn',@(src,evt) resizeFigure(app,evt,hpanel));
    %
    %             app.Image.Visible = true;
    %             app.Image.Enabled = true;
    %
    %         end
    %
    %         function displayImage(app,I)
    %
    %             draw(app.Image,I,[],[],[]);
    %             drawnow;
    %
    %         end
    %
    %         function resizeFigure(app,evt,hpanel)
    %
    %             set(hpanel,'Position',[1,1,evt.Source.Position(3:4)]);
    %             resize(app.Image);
    %
    %         end
    %
    %         function wireUpScrollListeners(app)
    %
    %             addlistener(app.FigureWithImage,'WindowScrollWheel',@(src,evt) scrollCallback(app,evt));
    %             addlistener(app.OtherFigure,'WindowScrollWheel',@(src,evt) scrollCallback(app,evt));
    %             addlistener(app.FigureWithImage,'WindowMouseMotion',@(src,evt) motionCallback(app,src,evt));
    %             addlistener(app.OtherFigure,'WindowMouseMotion',@(src,evt) motionCallback(app,src,evt));
    %
    %         end
    %
    %         function scrollCallback(app,evt)
    %             % Image() DOES NOT manage the scroll behavior. To manage the
    %             % scroll behavior, you should wire up listeners to all figures
    %             % in your app/ui, and determine where the mouse is located. If
    %             % the mouse is hovering over the figure with this image, then
    %             % call the scroll method. Like so:
    %             if evt.Source == app.FigureWithImage
    %                 scroll(app.Image,evt.VerticalScrollCount);
    %             end
    %
    %         end
    %
    %         function motionCallback(app,src,evt)
    %
    %             app.HitObject = ancestor(evt.HitObject,'figure');
    %
    %             if app.HitObject == app.FigureWithImage
    %                 if wasClickOnAxesToolbar(app,evt)
    %                     images.roi.setBackgroundPointer(src,'arrow');
    %                 elseif isa(evt.HitObject,'matlab.graphics.primitive.Image')
    %                     if isprop(evt.HitObject,'InteractionMode')
    %                         switch evt.HitObject.InteractionMode
    %                             case ''
    %                                 images.roi.setBackgroundPointer(src,'arrow');
    %                             case 'pan'
    %                                 images.roi.setBackgroundPointer(src,'custom',matlab.graphics.interaction.internal.getPointerCData('pan_both'),[16,16]);
    %                             case 'zoomin'
    %                                 images.roi.setBackgroundPointer(src,'custom',matlab.graphics.interaction.internal.getPointerCData('zoomin_unconstrained'),[16,16]);
    %                             case 'zoomout'
    %                                 images.roi.setBackgroundPointer(src,'custom',matlab.graphics.interaction.internal.getPointerCData('zoomout_both'),[16,16]);
    %                         end
    %                     else
    %                         images.roi.setBackgroundPointer(src,'arrow');
    %                     end
    %                 else
    %                     images.roi.setBackgroundPointer(src,'arrow');
    %                 end
    %             else
    %                 images.roi.setBackgroundPointer(src,'arrow');
    %             end
    %
    %         end
    %
    %         function TF = wasClickOnAxesToolbar(~,evt)
    %             TF = ~isempty(ancestor(evt.HitObject,'matlab.graphics.controls.AxesToolbar'));
    %         end
    %
    %     end
    %
    % end
    
        
    % Copyright 2020-2023 The MathWorks, Inc.
    
    events
        
        % Image Clicked - Event fires when the image is clicked. Container
        % classes may want to listen to this to begin drawing ROIs on the
        % image.
        ImageClicked
        
        % Image Rotated - Event fires when the image is rotated through the
        % rotate method.
        ImageRotated
        
        % View Reset - Event fires when the image view is changed, either
        % by zoom, pan, or by displaying a new image of different size.
        % Container classes may want to listen to this event to update the
        % positioning of other related ui components.
        ViewChanged
        
        % Image Requested - Event fires when the display object wants the
        % app to resend the image data. This is done only when
        % DownsamplingMode is set to 'auto'. When the image is large and
        % the viewport is small, this object may downsample to improve
        % performance without sacrificing perceptable image quality. When
        % the user zooms in on the downsampled image, the object will
        % broadcast an event to indicate the app should resend the image so
        % the degree of downsampling can be reduced.
        ImageRequested
        
        % Interaction Mode Changed - Event fires when the axes toolbar mode
        % is changed.
        InteractionModeChanged

        % Axes Toolbar Zoom Action - Event fires when a zoom action is
        % performed using the Axes Toolbar buttons
        AxesToolbarZoomAction
        
    end
    
    
    properties
        
        % Enabled - Allows clicks to be captured on the image. Set this to
        % false when you want to disable clicks.
        Enabled             (1,1) logical = false;
        
        % Visible - Allows zoom/pan on the image. When image data is
        % available, set this to true.
        Visible             (1,1) logical = false;
        
        % Alpha - Transparency of labels blended with the image. This
        % should range from [0 1].
        Alpha               (1,1) single = 0.5;
        
        % XBorder - Border around the image to the left and right,
        % respectively when the image is fully zoomed out.
        XBorder             (1,2) double = [5 5];
        
        % YBorder - Border around the image to the bottom and top,
        % respectively when the image is fully zoomed out. The 20 pixel
        % border at the top of the image provides room for the axes toolbar
        % to sit just outside the image.
        YBorder             (1,2) double = [5 21];
        
        % Background Color - Color of the axes background. This also
        % controls the background color of the axes toolbar when it is
        % located on the image.
        BackgroundColor     (1,3) double = [0.94 0.94 0.94];
        
        % Box Color - Color of the image border.
        BoxColor            (1,3) double = [0 0 0];
        
        % Superpixels Visible - Show superpixel boundaries on image
        SuperpixelsVisible  (1,1) logical = false;
        
        % Superpixel Color - Color of superpixel boundaries
        SuperpixelColor     (1,3) single = [0.5 0.5 0.5];

        % Specify the resize behaviour
        % FitToWindow - When the figure containing the image is resized,
        % any zoom applied is reset. This is the default behaviour
        % PreserveZoom - The ZoomPercent property is preserved upon resize.
        % More of the image content is displayed as the window size changes
        ResizeBehaviour     (1, 1) string ...
                            { mustBeMember( ResizeBehaviour, ...
                                [ "PreserveZoom", "FitToWindow" ] ) } ...
                                            = "FitToWindow";
    end
    
    
    properties (Dependent)
        
        % Downsample Mode - Determine if the image object should downsample
        % automatically based on the image size, screen resolution, and
        % viewport size.
        %
        % 'auto'   - Downsampling will be performed dynamically.
        % 'manual' - Downsampling will be performed based on the
        %            DownsampleLevel value.
        DownsampleMode
        
        % Downsample Level - Determine if the image object should downsample the
        % image and send less data across the binary channel to be
        % rendered.
        DownsampleLevel
        
        % Superpixels - Superpixels used to display superpixel boundaries
        Superpixels
        
        % Message Text - Text message displayed over the top of the image
        MessageText
        
        % Message Visible - Visibility of the message prompt
        MessageVisible

        % PixelSize - Size of the pixel in X and Y direction
        PixelSize

        ZoomPercent         (1,1) double {mustBePositive}

        % MinZoomFitToWindow - Flag that restricts the minimum zoom value
        % to be that which results in the displayed image being fitted to
        % either the height of width of the parent panel. The default value
        % is TRUE.
        MinZoomFitToWindow  (1,1) logical;

        % Interpolation - Specify the interpolation mode
        Interpolation (1, 1) string { mustBeMember( Interpolation, ...
                                    ["nearest", "bilinear"] ) }
        
    end
    
    
    properties (GetAccess = {?images.uitest.factory.Tester,...
            ?uitest.factory.Tester,...
            ?images.internal.app.segmenter.volume.display.Slice},...
            SetAccess = private, Transient)
        
        Panel               matlab.ui.container.Panel
        Rotate              images.internal.app.utilities.Rotate
        
        Pan                 matlab.ui.controls.ToolbarStateButton
        ZoomIn              matlab.ui.controls.ToolbarStateButton
        ZoomOut             matlab.ui.controls.ToolbarStateButton
        
        Rectangle           images.roi.Rectangle
        
        Message             matlab.ui.control.Label
        CloseMessage        matlab.ui.control.Image
    end
    
    
    properties (Dependent, Hidden)
        
        RotationState
        
    end
    
    
    properties (GetAccess = public, SetAccess = private, Transient)
        
        ImageHandle         matlab.graphics.primitive.Image
        
        AxesHandle
        
        XLim                (1,2) double
        
        YLim                (1,2) double
    end
    
    
    properties (Dependent, GetAccess = {?images.uitest.factory.Tester,...
            ?uitest.factory.Tester}, SetAccess = private)
        
        ImageHandleTester
        
        AxesHandleTester
        
    end
    
    
    properties (Access = private, Transient)
        
        % ZoomLevel = 1 => Image is displayed at "Fit To Window"
        ZoomLevel               (1,1) double = 1;
        ZoomCenter              (1,2) double = [0 0];
        PanCenter               (1,2) double = [0 0];
        CanScroll               (1,1) logical = false;
        ScrollFactor            (1,1) double = 5;
        
        PanButtonUpListener     event.listener
        PanMotionListener       event.listener
        
        DownsampleModeInternal  (1,1) logical = false;
        DownsampleLevelInternal (1,1) double = 1;

        PointerCache
        
        SuperpixelsInternal     (:,:) double = [];

        PixelSizeInternal       (1,2) double = [1 1];
        ZoomPercentInternal     (1,1) double = 0;

        % Implementation for MinZoomFitToWindow
        MinZoomFitToWindowInternal  (1,1) logical = true;

        % Track the position of the figure in which the Image is contained.
        % This is needed to implement a zoom preserving resize.
        PrevFigPosition (1, 4) double = zeros(1, 4);
        
        InterpInternal (1, 1) string { mustBeMember( InterpInternal, ...
                                    ["nearest", "bilinear"] ) } = "nearest"
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Image
        %------------------------------------------------------------------
        function self = Image(hpanel)
            create(self,hpanel);
        end
        
        %------------------------------------------------------------------
        % Draw
        %------------------------------------------------------------------
        function draw(self,img,label,cmap,contrastLimits,varargin)
            %DRAW update image CData.
            %
            %   DRAW(OBJ,IM,LABEL,CMAP,CLIM) updates the image CData for
            %   display object OBJ by blending image IM with label matrix
            %   LABEL and label colormap CMAP.
            %
            %   DRAW(OBJ,IM,LABEL,CMAP,CLIM,LABELVISIBLE) updates the image CData for
            %   display object OBJ by blending image IM with label matrix
            %   LABEL and label colormap CMAP. LABELVISIBLE specifies if
            %   the numeric label vales is visible or not, when not
            %   specified all labels except the 0 label are visible.
            %
            %   Adjust the contrast for the image by specifying a
            %   one-by-two vector CLIM in the range of [0 1]. If no
            %   contrast is desired, set CLIM to be []. CLIM is only used
            %   when the image is a grayscale image.
            %
            %   If no labels are available, set LABEL and CMAP to be [].
            %   For example, simple usage of this method without label
            %   blending or contrast adjustment:
            %
            %   draw(obj,im,[],[],[]);
            %
            %   This method does very little input validation to improve
            %   performance as much as possible. LABEL must be a 2-D valid
            %   label matrix that matches the first two dimensions of IM.
            %   CMAP must be a 256-by-3 colormap of type single.
            
            if ~isempty(self.ImageHandle)
                
                [img,label] = downsampleImage(self,img,label);
                
                img = blendImage(self,img,label,cmap,contrastLimits,varargin{:});
                
                isResetRequired = ~isequal(size(self.ImageHandle.CData,1,2),size(img,1,2));
                
                self.ImageHandle.CData = img;
                
                if isResetRequired
                    resetView(self);
                    
                    if strcmp(self.AxesHandle.Box,'off')
                        set(self.AxesHandle,'Box','on');
                        set(self.AxesHandle.XAxis,'Color',self.BoxColor);
                        set(self.AxesHandle.YAxis,'Color',self.BoxColor);
                    end
                    
                end

                self.ImageHandle.CData = img;
                
            end
            
        end
        
        %------------------------------------------------------------------
        % Resize
        %------------------------------------------------------------------
        function resize(self)
            %RESIZE React to resizing of the image object's parent panel.
            %
            %   RESIZE(OBJ) updates the positioning and zoom state of the
            %   image. Call this method when the parent uipanel or figure
            %   is being resized.
            
            if self.MessageVisible
                updateMessagePosition(self);
            end

            hfig = ancestor(self.Panel, "figure", "toplevel");
            figPos = hfig.Position;

            switch(self.ResizeBehaviour)
                case "FitToWindow"
                    self.ZoomLevel = 1;
                    setAxesPosition(self,[]);

                case "PreserveZoom"
                    % The Axes is positioned relative to the uipanel. So
                    % when the figure is resized by dragging to the left or
                    % bottom, then starting X and Y positions of the panel
                    % in the figure does not change. Hence, the axes
                    % position with respect to the panel does not change.
                    % This does not result in more image data being brought
                    % into the view along the left or bottom. Hence, the
                    % axes now has to be repositioned
                    setAxesPositionOnZPResize(self, figPos);
                    recenterImage(self);
                
                otherwise
                    assert(false, "Unsupported Zoom Behaviour");
            end

            broadcastViewChangedEvent(self);
            
            self.PrevFigPosition = figPos;
        end
        
        %------------------------------------------------------------------
        % Clear
        %------------------------------------------------------------------
        function clear(self)
            %CLEAR Clear the contents of the display object.
            %
            %   CLEAR(OBJ) clears the contents of the display object. Use
            %   this method when the current app session is cleared.
            
            self.ImageHandle.CData = [];
            self.ZoomPercentInternal = 0;
            resetView(self);
            self.Visible = false;
            self.Enabled = false;
            clear(self.Rotate);
            
        end
        
        %------------------------------------------------------------------
        % Zoom In
        %------------------------------------------------------------------
        function zoomIn(self)
            %ZOOMIN Zoom in to the center of the current viewport.
            %
            %   ZOOMIN(OBJ) zooms in to the center of the current viewport.
            %   Use this method when a keyboard shortcut is used to zoom
            %   in.
            
            if ~self.Visible || ~canImageZoomIn(self)
                return;
            end
            
            self.ZoomLevel = self.ZoomLevel + 0.5;
            setAxesPosition(self,getCenterOfWindow(self));
            broadcastViewChangedEvent(self);
            
        end
        
        %------------------------------------------------------------------
        % Zoom Out
        %------------------------------------------------------------------
        function zoomOut(self)
            %ZOOMOUT Zoom out from the center of the current viewport.
            %
            %   ZOOMOUT(OBJ) zooms out from the center of the current
            %   viewport. Use this method when a keyboard shortcut is used
            %   to zoom out.
            
            if ~self.Visible || ~canImageZoomOut(self)
                return;
            end
            
            newZoomLevel = self.ZoomLevel - 0.5;

            if self.MinZoomFitToWindowInternal
                self.ZoomLevel = max(newZoomLevel, 1);
            else
                self.ZoomLevel = newZoomLevel;
            end

            setAxesPosition(self,getCenterOfWindow(self));
            broadcastViewChangedEvent(self);
        end
        
        %------------------------------------------------------------------
        % Scroll
        %------------------------------------------------------------------
        function scroll(self,scrollCount)
            %SCROLL scrolls in and out from the current mouse location.
            %
            %   SCROLL(OBJ,COUNT) scrolls in or out from the current mouse
            %   location according to the value COUNT. When COUNT is
            %   negative, the image is zoomed in. When COUNT is positive,
            %   the image is zoomed out unless it is already fully zoomed
            %   out.
            %
            %   Listen to the WindowScrollWheel event on the figure, and
            %   then pass in the VerticalScrollCount property from the
            %   event data directly into this method:
            %
            %   scroll(obj,evt.VerticalScrollCount);
            
            if ~self.Visible || ~self.CanScroll
                return;
            end
            

            if scrollCount < 0
                % Zoom In
                if ~canImageZoomIn(self)
                    return;
                end
                self.ZoomLevel = self.ZoomLevel - (scrollCount/self.ScrollFactor);
                setAxesPosition(self, []);
                broadcastViewChangedEvent(self);
            else
                % Zoom out
                if ~canImageZoomOut(self)
                    return;
                end

                origZoomLevel = self.ZoomLevel;
                self.ZoomLevel = self.ZoomLevel - (scrollCount/self.ScrollFactor);

                if self.MinZoomFitToWindowInternal
                    self.ZoomLevel = max(self.ZoomLevel, 1);
                end

                if ~self.MinZoomFitToWindow || origZoomLevel > 1
                    setAxesPosition(self, []);
                    broadcastViewChangedEvent(self);
                end
            end
        end
        
        %------------------------------------------------------------------
        % Pan
        %------------------------------------------------------------------
        function pan(self,str)
            %PAN Pan the image.
            %
            %   PAN(OBJ,STR) pans the image in the direction specified by
            %   STR as either 'up', 'down', 'left', or 'right'. If the
            %   image is already at the edge, then pan will have no impact.
            %
            %   Listen to key presses and wire up a keyboard shortcut to
            %   call pan.
            
            switch str
                case 'up'
                    delta = [0 -1];
                case 'down'
                    delta = [0 1];
                case 'left'
                    delta = [1 0];
                case 'right'
                    delta = [-1 0];
                otherwise
                    return;
            end
            
            panKey(self,delta);
            
        end
        
        %------------------------------------------------------------------
        % Deselect Axes Interaction
        %------------------------------------------------------------------
        function deselectAxesInteraction(self)
            %DESELECTAXESINTERACTION - Programmatically remove the display
            %object from and interaction mode.
            %
            %   DESELECTAXESINTERATION(OBJ) turns off any interaction mode,
            %   like zoom or pan, in the display object. Use this method
            %   when you want a user gesture in the app to force the app
            %   out of zoom and pan and into a different mode. A use case
            %   for this would be when the user requests to begin drawing
            %   an ROI on the image.
            
            priorMode = self.ImageHandle.InteractionMode;
            
            self.ImageHandle.InteractionMode = '';
            updateToolbarState(self);
            
            if ~isempty(priorMode)
                notify(self,'InteractionModeChanged',...
                    images.internal.app.utilities.events.ModeChangedEventData(...
                    self.ImageHandle.InteractionMode,priorMode));
            end
            
        end
        
        %------------------------------------------------------------------
        % Rotate
        %------------------------------------------------------------------
        function rotate(self,val)
            %ROTATE Rotate the image.
            %
            %   ROTATE(OBJ,VAL) applies the rotation to the rotation state
            %   according to the following values for VAL:
            %
            %   'ud'    - Flip the image vertically
            %   'lr'    - Flip the image horizontally
            %   'ccw'   - Flip the image 90 degrees counter clockwise
            %   'cw'    - Flip the image 90 degrees clockwise
            %   'reset' - Reset the rotation state
            %
            %   Use this method to allow users to rotate their display
            %   without requiring you to modify their image data. This
            %   method does not update the image display directly. This
            %   method does trigger the ImageRotated event. You may want
            %   to listen to this event and then call the draw method to
            %   update the display.
            %
            %   Rotation will have an impact on the positioning of ROIs.
            
            rotate(self.Rotate,val);
            
        end
        
        %------------------------------------------------------------------
        % Blend Image
        %------------------------------------------------------------------
        function img = blendImage(self,img,label,cmap,contrastLimits,varargin)
            %BLENDIMAGE blends the image and label matrix.
            %
            %   B = BLENDIMAGE(OBJ,A,LABEL,CMAP,CLIM) blends the image A
            %   with label data LABEL and label colormap CMAP. If contrast
            %   adjustment is specified, the contrast will be adjusted by
            %   CLIM. Optional argument LABELVISIBLE can be passed in to
            %   specify if the numeric label value is visible or not, when
            %   not specified all labels except the 0 label are visible.
            %
            %   This method is the numeric computation engine of the DRAW
            %   method. Use this method when you want to blend and adjust
            %   the image but you do not want to apply it to the image
            %   CData for display. A use case for this method would be if
            %   you want to create an image that exactly matches this
            %   object's alpha, rotation, contrast, etc. but you want to
            %   use it somewhere else.

            if ~isempty(varargin)
               labelVisible = single(varargin{1});
            else
                labelVisible = [0; ones([255, 1],'single')];
            end
            
            img = im2single(img);
            
            if ismatrix(img)
                try %#ok<TRYNC>
                    % If bad inputs are passed in to imadjust, don't error,
                    % just display the image without contrast adjustment.
                    img = imadjust(img,contrastLimits);
                end
                img = repmat(img,[1,1,3]);
            end
            
            if ~isempty(self.SuperpixelsInternal) && self.SuperpixelsVisible && ...
                    self.DownsampleLevelInternal == 1 && ...
                    isequal(size(self.SuperpixelsInternal,1,2),size(img,1,2))
                % Blend superpixel boundaries into the image. Allow
                % blending only when there is no downsampling
                alpha = [0; ones([255, 1],'single')]*self.Alpha;
                img = im2single(images.internal.builtins.labeloverlay(img,self.SuperpixelsInternal,repmat(self.SuperpixelColor,[256,1]),alpha));
                
            end
            
            if ~isempty(label) && max(label(:)) > 0
                
                alpha = labelVisible*self.Alpha;
                img = images.internal.builtins.labeloverlay(img,double(label),single(cmap),alpha);
                
            end
            
            img = applyForward(self.Rotate,img);
            
        end
                
        %------------------------------------------------------------------
        % Reset View
        %------------------------------------------------------------------
        function resetView(self)
            
            self.ZoomLevel = 1;
            
            self.ZoomCenter = getCenterOfWindow(self);
            
            if ~isempty(self.ImageHandle.CData)
                xLim = get(self.ImageHandle,'XData') + [-0.5 0.5];
                yLim = get(self.ImageHandle,'YData') + [-0.5 0.5];
                set(self.AxesHandle,'XLim',xLim,'YLim',yLim);
            end
            
            % Using the default resize behaviour when resetting the view to
            % preserve backward compatibility for clients. This method is
            % called when a new image is drawn and so not really sure what
            % a Zoom preserving resize operation would look like.
            currBehave = self.ResizeBehaviour;
            self.ResizeBehaviour = "FitToWindow";

            % Resize broadcasts a view change
            resize(self);
            self.ResizeBehaviour = currBehave;
        end
		
        %------------------------------------------------------------------
        % Update View
        %------------------------------------------------------------------
        function setView(self,viewRect)
            arguments
                self (1,1) images.internal.app.utilities.Image
                viewRect (1,4) double {mustBeNonnegative,mustBeFinite}
            end

            if isempty(self.ImageHandle.CData)
                return;
            end

            self.ZoomLevel = findZoomMagnitude(self,viewRect);
            setAxesPosition(self,viewRect);
            [xLim,yLim] = computeDataspaceViewLimits(self);
            self.XLim = xLim; self.YLim = yLim;
        end
    end
    
    
    methods (Hidden)
        
        %--Pan By Dataspace Coordinates------------------------------------
        function panByDataSpaceCoordinates(self,delta)
            
            delta = delta*(self.AxesHandle.Position(3)/self.ImageHandle.XData(2));
            
            applyDelta(self,delta);
            
            broadcastViewChangedEvent(self);
            
        end
        
    end
    
    
    methods (Access = private)
        
        %--Downsample Image------------------------------------------------
        function [img,label] = downsampleImage(self,img,label)
            
            % Update XData and YData before downsampling. We must account
            % for any rotation first, but the final rotation will be
            % applied to the final blended image. This is inefficient as it
            % requires rotation twice if rotation is applied; however the
            % rotation functions are 90 degrees increments and should be
            % fast compared to downsampling, blending, or rendering.
            sz = applyImageSizeForward(self.Rotate,size(img));
            set(self.ImageHandle,'YData',[1,sz(1)],'XData',[1,sz(2)]);
            
            if self.DownsampleModeInternal
                setDownsampleLevel(self);
            end
            
            if self.DownsampleLevelInternal > 1
                
                % Downsample based on scale factor in DownsampleLevel
                img = imresize(img,1/self.DownsampleLevelInternal,'bilinear');
                
                if ~isempty(label)
                    label = imresize(label,1/self.DownsampleLevelInternal,'nearest');
                end
                
            end
            
        end
        
        %--Set Downsample Level--------------------------------------------
        function setDownsampleLevel(self)
            
            pos = self.Panel.Position;
            
            availableWidth = pos(3) - self.XBorder(1) - self.XBorder(2);
            availableHeight = pos(4) - self.YBorder(1) - self.YBorder(2);
            
            if self.ZoomLevel == 1
                
                scaleFactor = floor(min([self.ImageHandle.XData(2)/availableWidth, self.ImageHandle.YData(2)/availableHeight]));
                if scaleFactor > 1
                    self.DownsampleLevelInternal = scaleFactor;
                else
                    self.DownsampleLevelInternal = 1;
                end
                
            else
                
                scaleFactor = floor(min([self.ImageHandle.XData(2)/(exp(self.ZoomLevel-1)*availableWidth), self.ImageHandle.YData(2)/(exp(self.ZoomLevel-1)*availableHeight)]));
                if scaleFactor > 1
                    self.DownsampleLevelInternal = scaleFactor;
                else
                    self.DownsampleLevelInternal = 1;
                end
                
            end
            
        end
        
        %--Click Callback--------------------------------------------------
        function clickCallback(self,evt)
            
            if ~self.Enabled || evt.Button ~= 1
                return;
            end
            
            switch self.ImageHandle.InteractionMode
                
                case ''
                    
                    notify(self,'ImageClicked',images.internal.app.utilities.events.HitEventData(...
                        evt.IntersectionPoint));
                    
                case 'pan'
                    startPan(self);
                    
                case 'zoomin'
                    
                    clickType = images.roi.internal.getClickType(ancestor(evt.Source,'figure'));
                    
                    notify( self, "AxesToolbarZoomAction", ...
                            images.internal.app.utilities.events.AxesToolbarZoomActionEventData("zoomin") );
                    switch clickType
                        case 'left'
                            drawZoomRectangle(self);
                        case 'double'
                            resetView(self);
                        otherwise
                            % No-op?
                    end
                    
                case 'zoomout'
                    
                    clickType = images.roi.internal.getClickType(ancestor(evt.Source,'figure'));
                    notify( self, "AxesToolbarZoomAction", ...
                            images.internal.app.utilities.events.AxesToolbarZoomActionEventData("zoomout") );
                    
                    switch clickType
                        case 'left'
                            scroll(self,2.5);
                            broadcastViewChangedEvent(self);
                        case 'double'
                            resetView(self);
                        otherwise
                            % No-op?
                    end
                    
            end
            
        end
        
        %--Draw Zoom Rectangle---------------------------------------------
        function drawZoomRectangle(self)
            
            hFig = ancestor(self.Panel,'figure');
            
            self.PointerCache = getptr(hFig);
            
            set(self.Rectangle,'Parent',self.AxesHandle)
            beginDrawingFromPoint(self.Rectangle,self.AxesHandle.CurrentPoint(1,1:2));
            
        end

        %--Finish Zoom Interaction-----------------------------------------
        function finishZoomInteraction(self)

            hFig = ancestor(self.Panel,'figure');

            isAxesXDirReverse = strcmp(self.Rectangle.Parent.XDir, 'reverse');

            pos = self.Rectangle.Position;

            set(self.Rectangle,'Parent',[]);

            set(hFig,self.PointerCache{:});

            if isempty(pos)
                return;
            end            

            if isAxesXDirReverse
                % Flip the Rectangle Y location as setAxesPosition is
                % agnostic to the Axes Direction
                pos(1) = self.AxesHandle.XLim(1) + (self.AxesHandle.XLim(2) - pos(1) - pos(3));
            end

            if pos(3) > 10 || pos(4) > 10

                if ~self.Visible || ~canImageZoomIn(self)
                    return;
                end

                val = findZoomMagnitude(self,pos);

                % Rectangle zoom cannot result in a zoom out operation.
                % Check that the new zoom level is higher than the previous
                % zoom level
                self.ZoomLevel = max([val,self.ZoomLevel]);

                setAxesPosition(self,pos);

            else
                scroll(self,-2.5);
            end

            broadcastViewChangedEvent(self);

        end
        
        %--Start Pan-------------------------------------------------------
        function startPan(self)
            
            hFig = ancestor(self.Panel,'figure');
            
            if isempty(hFig.WindowButtonMotionFcn)
                hFig.WindowButtonMotionFcn = @(~,~) deal();
            end
            
            self.PanCenter = get(hFig,'CurrentPoint');
            self.PanButtonUpListener.Enabled = true;
            self.PanMotionListener.Enabled = true;
            
        end
        
        %--Do Pan----------------------------------------------------------
        function doPan(self,currentPoint)
            
            if self.ZoomLevel == 1
                return;
            end
            
            delta = currentPoint - self.PanCenter;
            
            applyDelta(self,delta);
            
            self.PanCenter = currentPoint;
            
            broadcastViewChangedEvent(self);
            
        end
        
        %--Pan Key---------------------------------------------------------
        function panKey(self,delta)
            
            if self.ZoomLevel == 1
                return;
            end
            
            % This is a somewhat arbitrary choice. Try to shift the image
            % 1/8 of the viewport size in the given dimension.
            pos = self.Panel.Position;
            delta = (pos(3:4)/8).*delta;
            
            applyDelta(self,delta);
            
            broadcastViewChangedEvent(self);
            
        end
        
        %--Apply Delta-----------------------------------------------------
        function applyDelta(self,delta)
        
            pos = self.AxesHandle.Position;
            panelPos = self.Panel.Position;
            
            if delta(1) > 0
                if pos(1) < 1
                    pos(1) = min(pos(1) + delta(1),1);
                end
            else
                if pos(1) + pos(3) > panelPos(3)
                    newPos = pos(1) + delta(1);
                    if newPos + pos(3) < panelPos(3)
                        pos(1) = panelPos(3) - pos(3);
                    else
                        pos(1) = newPos;
                    end
                end
            end
            
            if delta(2) > 0
                if pos(2) < 1
                    pos(2) = min(pos(2) + delta(2),1);
                end
            else
                if pos(2) + pos(4) > panelPos(4)
                    newPos = pos(2) + delta(2);
                    if newPos + pos(4) < panelPos(4)
                        pos(2) = panelPos(4) - pos(4);
                    else
                        pos(2) = newPos;
                    end
                end
            end
            
            set(self.AxesHandle,'Position',pos);
            
        end
            
        %--Stop Pan--------------------------------------------------------
        function stopPan(self,evt)
            
            self.PanButtonUpListener.Enabled = false;
            self.PanMotionListener.Enabled = false;
            
            doPan(self,evt.Source.CurrentPoint);
            
        end
        
        %--Find Zoom Magnitude---------------------------------------------
        function val = findZoomMagnitude(self,rectanglePosition)

            pos = self.Panel.Position;
            
            viewportAspectRatio = pos(4)/pos(3);
            imageAspectRatio = self.ImageHandle.YData(2)/self.ImageHandle.XData(2);
            
            % Compare the aspect ratio of the image with the viewport. A
            % tall image in a wide viewport (and vice versa) can be zoomed 
            % in further if necessary to better fit the rectangle 
            if imageAspectRatio/viewportAspectRatio > 1
                ARScaleFactorInX = imageAspectRatio/viewportAspectRatio;
                ARScaleFactorInY = 1;
            else
                ARScaleFactorInX = 1;
                ARScaleFactorInY = viewportAspectRatio/imageAspectRatio;
            end

            zoomLevelInX = log(ARScaleFactorInX*(self.ImageHandle.XData(2)/rectanglePosition(3))) + 1;
            zoomLevelInY = log(ARScaleFactorInY*(self.ImageHandle.YData(2)/rectanglePosition(4))) + 1;
            
            if zoomLevelInX < zoomLevelInY
                val = zoomLevelInX;
            else
                val = zoomLevelInY;
            end                     
        end
        
        %--Set Zoom Center-------------------------------------------------
        function setZoomCenter(self,intersectionPoint,pos)
            
            if any(isnan(intersectionPoint))
                self.CanScroll = false;
                return;
            end
            
            self.CanScroll = true;
            self.ZoomCenter = pos(1:2);
            
        end        
        
        %--Set Axes Position-----------------------------------------------
        function setAxesPosition(self,zoomCenter)
            pixelSize = self.PixelSize;
            xPixelSize = pixelSize(1);
            yPixelSize = pixelSize(2);
            
            if isempty(self.ImageHandle.CData)
                return;
            end
            
            panelPos = self.Panel.Position;

            if self.ZoomLevel == 1
                
                % This is how big our axes could possibly be
                availableWidth = panelPos(3) - self.XBorder(1) - self.XBorder(2);
                availableHeight = panelPos(4) - self.YBorder(1) - self.YBorder(2);
                
                % Now, let's find the required screen pixel resolution in each
                % dimension
                screenPixelsPerImagePixelX = availableWidth/(self.ImageHandle.XData(2)*xPixelSize);
                screenPixelsPerImagePixelY = availableHeight/(self.ImageHandle.YData(2)*yPixelSize);
                
                if screenPixelsPerImagePixelX < screenPixelsPerImagePixelY
                    % Case where we will use up all screen pixels in X
                    % direction
                    zoomFactor = screenPixelsPerImagePixelX;
                else
                    % Case where we will use up all screen pixels in Y
                    % direction
                    zoomFactor = screenPixelsPerImagePixelY;
                end

                self.ZoomPercentInternal = zoomFactor;

                w = round(zoomFactor*self.ImageHandle.XData(2)*xPixelSize);
                h = round(zoomFactor*self.ImageHandle.YData(2)*yPixelSize);
                x = floor((availableWidth - w)/2) + 1;
                y = floor((availableHeight - h)/2) + 1;
                
                computedPos = [x + self.XBorder(1),y + self.YBorder(1),w,h];
                
            elseif self.ZoomLevel < 1
                availableWidth = panelPos(3);
                availableHeight = panelPos(4);

                % Now, let's find the required screen pixel resolution in each
                % dimension
                screenPixelsPerImagePixelX = availableWidth/(self.ImageHandle.XData(2)*xPixelSize);
                screenPixelsPerImagePixelY = availableHeight/(self.ImageHandle.YData(2)*yPixelSize);
                
                if screenPixelsPerImagePixelX < screenPixelsPerImagePixelY
                    % Case where we will use up all screen pixels in X
                    % direction
                    zoomFactor = (exp(self.ZoomLevel-1))*screenPixelsPerImagePixelX;
                else
                    % Case where we will use up all screen pixels in Y
                    % direction
                    zoomFactor = (exp(self.ZoomLevel-1))*screenPixelsPerImagePixelY;
                end

                self.ZoomPercentInternal = zoomFactor;

                w = round(zoomFactor*self.ImageHandle.XData(2)*xPixelSize);
                h = round(zoomFactor*self.ImageHandle.YData(2)*yPixelSize);
                x = floor((availableWidth - w)/2) + 1;
                y = floor((availableHeight - h)/2) + 1;

                computedPos = [x + self.XBorder(1),y + self.YBorder(1),w,h];
            else
                if isempty(zoomCenter)
                    
                    % The zoom center is store in the global coordinate
                    % system (figure pixels), we need to put the location
                    % into the parent panel's coordinates.
                    zoomCenter = get(ancestor(self.Panel,'figure'),'CurrentPoint');
                    parentObj = self.Panel.Parent;
                    
                    % Recursively loop through parents until you reach the
                    % figure. Add the position offset to the zoom center
                    while ~isa(parentObj,'matlab.ui.Figure')
                        parentObj = parentObj.Parent;
                        if isa(parentObj,'matlab.ui.container.GridLayout') || isa(parentObj,'matlab.ui.Figure')
                            continue
                        end
                        zoomCenter = zoomCenter - parentObj.Position(1:2);                        
                    end
                    
                end
                
                availableWidth = panelPos(3);
                availableHeight = panelPos(4);
                
                % Now, let's find the required screen pixel resolution in each
                % dimension
                screenPixelsPerImagePixelX = availableWidth/(self.ImageHandle.XData(2)*xPixelSize);
                screenPixelsPerImagePixelY = availableHeight/(self.ImageHandle.YData(2)*yPixelSize);
                
                if screenPixelsPerImagePixelX < screenPixelsPerImagePixelY
                    % Case where we will use up all screen pixels in X
                    % direction
                    zoomFactor = (exp(self.ZoomLevel-1))*screenPixelsPerImagePixelX;
                else
                    % Case where we will use up all screen pixels in Y
                    % direction
                    zoomFactor = (exp(self.ZoomLevel-1))*screenPixelsPerImagePixelY;
                end

                self.ZoomPercentInternal = zoomFactor;
                
                w = round(zoomFactor*self.ImageHandle.XData(2)*xPixelSize);
                h = round(zoomFactor*self.ImageHandle.YData(2)*yPixelSize);
                
                % Try to place the axes in a spot as close to the zoom
                % center as possible, without allowing any unnecessary dead
                % space between the axes and the panel edge
                currentPosition = get(self.AxesHandle,'Position');
                
                if numel(zoomCenter) == 4
                    % Rectangle coordinates passed in. This represents the
                    % region of the image that must be visible in the
                    % viewport
                    fractionToCenterX = (zoomCenter(1) - 0.5 + zoomCenter(3)/2)/self.ImageHandle.XData(2);
                    fractionToCenterY = (zoomCenter(2) - 0.5 + zoomCenter(4)/2)/self.ImageHandle.YData(2);
                    
                    x = floor((availableWidth/2) - w*fractionToCenterX) + 1;
                    y = floor((availableHeight/2) - h*(1-fractionToCenterY)) + 1;
                    
                    % If the rectangle zoom leaves dead space in the
                    % viewport, try to adjust the image to fill it.
                    if x > 1 && w > availableWidth
                        x = 2;
                    elseif x + w < availableWidth && x < 1
                        x = availableWidth - w - 1;
                    end
                    
                    if y > 1 && h > availableHeight
                        y = 2;
                    elseif y + h < availableHeight && y < 1
                        y = availableHeight - h - 1;
                    end
                    
                else
                    % Center coordinate passed in as screen pixels
                    fractionToCenterX = (zoomCenter(1) - currentPosition(1) - panelPos(1))/currentPosition(3);
                    fractionToCenterY = (zoomCenter(2) - currentPosition(2) - panelPos(2))/currentPosition(4);
                    
                    x = floor(zoomCenter(1) - (w*fractionToCenterX) - panelPos(1)) + 1;
                    y = floor(zoomCenter(2) - (h*fractionToCenterY) - panelPos(2)) + 1;
                
                end
                
                computedPos = [x,y,w,h];
                
            end
            
            % When Zoom values lower than "FitToWindow" is permitted, it is
            % possible that user specified zoom value can be small enough
            % that the computed position has height and/or width = 0. The
            % axes position must still be updated in this case. Hence,
            % updating the axes position updation criteria.
            if (~self.MinZoomFitToWindow && all(computedPos(3:4)>=0)) || all(computedPos(3:4)>0)
                % Only update position is its valid. (If resize requests
                % are smaller than whats possible with the existing border
                % sizes, this component ignores those resize requests)
                set(self.AxesHandle,'Units','pixels','Position',computedPos);
            end
            
            if self.DownsampleModeInternal
                previousLevel = self.DownsampleLevelInternal;
                
                setDownsampleLevel(self);
                
                if previousLevel < self.DownsampleLevelInternal
                    notify(self,'ImageRequested');
                end
            end
            
            updateToolbarState(self);
            
        end
        
        %--Set Axes Position during a Zoom Preserving Resize --------------
        function setAxesPositionOnZPResize(self, figPos)
            % Helper function that repositions the AxesHandle when a zoom
            % preserving resize is requested

            prevFigPos = self.PrevFigPosition;

            if self.ZoomLevel > 1 && ...
                    ( ( figPos(1) ~= prevFigPos(1) ) || ...
                      ( figPos(2) ~= prevFigPos(2) ) )
                delX = prevFigPos(1) - figPos(1);
                delY = prevFigPos(2) - figPos(2);
                axesPos = self.AxesHandle.Position;
                axesPos(1) = axesPos(1) + delX;
                axesPos(2) = axesPos(2) + delY;
                self.AxesHandle.Position = axesPos;
            end
        end
        
        %--Recenter Image-----------------------------------------------
        function recenterImage(self)
            % Helper function that recenters a zoomed in image to avoid as
            % much white space around the image as possible

            % Obtain the current dimensions of the panel containing the
            % image
            panelPos = self.Panel.Position;
            availableWidth = panelPos(3);
            availableHeight = panelPos(4);

            % Obtain the current axes position
            axesPos = self.AxesHandle.Position;
            newAxesPos = axesPos;

            windowCenter = getCenterOfWindow(self);

            % If the image is zoomed out, then simply recenter the image
            % as white space is unavoidable as the image aspect ratio has
            % to be preserved 
            if self.ZoomLevel <= 1
                newAxesPos(1) = windowCenter(1) - round(newAxesPos(3)/2);
                newAxesPos(2) = windowCenter(2) - round(newAxesPos(4)/2);
            else
                % If number of Xdim pixels required to display image on
                % screen is larger than the number of pixels in the panel
                % (indicates zoom in)
                if newAxesPos(3) > availableWidth
                    % Ensure the starting X position is atmost at the
                    % left-edge of the panel.
                    newAxesPos(1) = min(1, newAxesPos(1));
    
                    % Compute the distance between the ending X position
                    % and the end X position of the panel. A non-zero value
                    % indicates there is a white space.
                    offset = max( 0, (availableWidth-panelPos(1)+1) - ...
                                     (newAxesPos(1)+newAxesPos(3)) );
    
                    % Update the axes position eliminate the white space at
                    % the right edge of the panel
                    newAxesPos(1) = newAxesPos(1) + offset;
                else
                    % Image is still zoomed in along the Y-direction but
                    % the image still fits within the window along the
                    % X-direction. Simply center the image along the window
                    % center
                    newAxesPos(1) = windowCenter(1) - round(newAxesPos(3)/2);
                end
    
                % The computations below are for the Y-direction. The same
                % comments for the X-direction are applicable below.
                if newAxesPos(4) > availableHeight
                    newAxesPos(2) = min(1, newAxesPos(2));
    
                    offset = max( 0, (availableHeight-panelPos(2)+1) - ...
                                     (newAxesPos(2)+newAxesPos(4)) );
                    newAxesPos(2) = newAxesPos(2) + offset;
                else
                    newAxesPos(2) = windowCenter(2) - round(newAxesPos(4)/2);
                end
            end

            if ~isequal(axesPos, newAxesPos)
                self.AxesHandle.Position = newAxesPos;
            end
        end
        
        %--Update Message Position-----------------------------------------
        function updateMessagePosition(self)
            pos = self.Panel.Position;
            set(self.Message,'Position',[1,pos(4)-20,pos(3),20]);
            set(self.CloseMessage,'Position',[pos(3) - 16,pos(4) - 16,12,12]);
        end
        
        %--Compute Dataspace View Limits-----------------------------------
        function [xLim,yLim] = computeDataspaceViewLimits(self)
            
            xLim = self.AxesHandle.XLim;
            yLim = self.AxesHandle.YLim;
            
            if self.ZoomLevel > 1

                panelPos = self.Panel.Position;
                axesPos = self.AxesHandle.Position;
                xLength = self.ImageHandle.XData(2);
                yLength = self.ImageHandle.YData(2);
                
                % XLim and YLim begin at 0.5. We need to account for this offset 
                
                if axesPos(1) < 1
                    frac = abs(axesPos(1))/axesPos(3);
                    xLim(1) = frac*xLength + 0.5;
                end
               
                if axesPos(2) < 1
                    frac = 1 - (abs(axesPos(2))/axesPos(4));
                    yLim(2) = frac*yLength + 0.5;
                end
               
                if axesPos(1) + axesPos(3) > panelPos(3)
                    frac = 1 - (((axesPos(1) + axesPos(3))-panelPos(3))/axesPos(3));
                    xLim(2) = frac*xLength + 0.5;
                end
               
                if axesPos(2) + axesPos(4) > panelPos(4)
                    frac = ((axesPos(2) + axesPos(4))-panelPos(4))/axesPos(4);
                    yLim(1) = frac*yLength + 0.5;
                end
            
            end
        end
        
        %--Broadcast View Changed Event------------------------------------
        function broadcastViewChangedEvent(self)
            [xLim,yLim] = computeDataspaceViewLimits(self);
            self.XLim = xLim; self.YLim = yLim;
            notify(self,'ViewChanged',images.internal.app.utilities.events.ViewChangedEventData(xLim,yLim));
        end
        
        %--Get Center Of Window--------------------------------------------
        function pos = getCenterOfWindow(self)
            
            % Get the center of the parent panel in the parent panel's
            % coordinate system
            panelPos = self.Panel.Position;
            pos = [panelPos(1) + (panelPos(3)/2), panelPos(2) + (panelPos(4)/2)];
            
        end
        
        %--Can Image Zoom In-----------------------------------------------
        function TF = canImageZoomIn(self)
            
            pos = self.Panel.Position;
            
            availablePanelWidth = pos(3);
            availablePanelHeight = pos(4);
            
            pos = self.AxesHandle.Position;
            
            usedWidth = pos(3);
            usedHeight = pos(4);
            
            if (usedWidth/availablePanelWidth > self.ImageHandle.XData(2)) || ...
                    (usedHeight/availablePanelHeight > self.ImageHandle.YData(2))
                TF = false;
            else
                TF = true;
            end
            
        end

        %--Can Image Zoom Out----------------------------------------------
        function TF = canImageZoomOut(self)

            axesPos = self.AxesHandle.Position;

            % Restrict the Axes Size to be minimum of 20 pixels
            TF = all(axesPos(3:4) > 20);
        end

        
        %--Update Toolbar State--------------------------------------------
        function updateToolbarState(self)
            
            switch self.ImageHandle.InteractionMode
                case ''
                    self.Pan.Value = 'off';
                    self.ZoomIn.Value = 'off';
                    self.ZoomOut.Value = 'off';
                case 'pan'
                    self.Pan.Value = 'on';
                    self.ZoomIn.Value = 'off';
                    self.ZoomOut.Value = 'off';
                case 'zoomin'
                    self.Pan.Value = 'off';
                    self.ZoomIn.Value = 'on';
                    self.ZoomOut.Value = 'off';
                case 'zoomout'
                    self.Pan.Value = 'off';
                    self.ZoomIn.Value = 'off';
                    self.ZoomOut.Value = 'on';
            end
            
        end
        
        %--Enter Pan Mode--------------------------------------------------
        function enterPanMode(self,evt)
            
            priorMode = self.ImageHandle.InteractionMode;
            
            if evt.Value
                self.ZoomIn.Value = 'off';
                self.ZoomOut.Value = 'off';
                self.ImageHandle.InteractionMode = 'pan';
            else
                self.ImageHandle.InteractionMode = '';
            end
            
            notify(self,'InteractionModeChanged',...
                images.internal.app.utilities.events.ModeChangedEventData(...
                self.ImageHandle.InteractionMode,priorMode));
            
        end
        
        %--Enter Zoom In Mode----------------------------------------------
        function enterZoomInMode(self,evt)
            
            priorMode = self.ImageHandle.InteractionMode;
            
            if evt.Value
                self.Pan.Value = 'off';
                self.ZoomOut.Value = 'off';
                self.ImageHandle.InteractionMode = 'zoomin';
            else
                self.ImageHandle.InteractionMode = '';
            end
            
            notify(self,'InteractionModeChanged',...
                images.internal.app.utilities.events.ModeChangedEventData(...
                self.ImageHandle.InteractionMode,priorMode));
            
        end
        
        %--Enter Zoom Out Mode---------------------------------------------
        function enterZoomOutMode(self,evt)
            
            priorMode = self.ImageHandle.InteractionMode;
            
            if evt.Value
                self.ZoomIn.Value = 'off';
                self.Pan.Value = 'off';
                self.ImageHandle.InteractionMode = 'zoomout';
            else
                self.ImageHandle.InteractionMode = '';
            end
            
            notify(self,'InteractionModeChanged',...
                images.internal.app.utilities.events.ModeChangedEventData(...
                self.ImageHandle.InteractionMode,priorMode));
            
        end
        
        %--Create----------------------------------------------------------
        function create(self,hpanel)
            
            validatestring(hpanel.Units,{'pixels'},'Image','uipanel Units');
            
            self.Panel = hpanel;
            self.Panel.BorderType = 'none';

            hfig = ancestor(self.Panel, "figure", "toplevel");
            self.PrevFigPosition = hfig.Position;
            
            % Manage the plot box aspect ratio, position, and extent
            % ourselves to get around the graphics bug that restricts the
            % image to the original size when zoomed in
            self.AxesHandle = axes(self.Panel,'Position',[0 0 1 1],...
                'Tag', 'ImageAxes',...
                'PlotBoxAspectRatioMode','manual');
            
            self.ImageHandle = image([],...
                'Tag','ImageHandle',...
                'Parent',self.AxesHandle,'Interpolation',self.Interpolation);

            if ~matlab.internal.capability.Capability.isSupported(...
                    matlab.internal.capability.Capability.LocalClient)
                % For MATLAB Online, restrict the max resolution size to be
                % 512. Larger images require a significantly higher
                % bandwidth than we have, so the time to transfer the data
                % to the client in ML Online is very poor. This choice
                % degrades rendering quality for online users, but it keeps
                % performance to a more acceptable level. Desktop users
                % will not be impacted.
                self.ImageHandle.MaxRenderedResolution = 512;
            end
            
            % Add a property to the image to manage the interaction mode
            addprop(self.ImageHandle,'InteractionMode');
            self.ImageHandle.InteractionMode = '';
            
            addlistener(self.ImageHandle,'Hit', @(src,evt) clickCallback(self,evt));
            addlistener(self.AxesHandle,'Hit', @(src,evt) clickCallback(self,evt));
            addlistener(ancestor(self.Panel,'figure'),'WindowMouseMotion',@(src,evt) setZoomCenter(self,evt.IntersectionPoint,evt.Source.CurrentPoint));
            
            set(self.AxesHandle,'Box','off','XTick',[],'YTick',[],'Color',self.Panel.BackgroundColor,'Visible','off');
            set(self.AxesHandle.XAxis,'Color','none');
            set(self.AxesHandle.YAxis,'Color','none');
            set(self.AxesHandle.ZAxis,'Color','none');
            
            disableDefaultInteractivity(self.AxesHandle);
            
            axtoolbar(self.AxesHandle,{'restoreview'});
            
            restoreButton = findobj(self.AxesHandle.Toolbar.Children,'Tag','restoreview');
            restoreButton.ButtonPushedFcn = @(~,~) resetView(self);
            
            self.ZoomOut = axtoolbarbtn(self.AxesHandle.Toolbar,'state',...
                'Tag','CustomZoomOut',...
                'Icon','zoomout',...
                'Tooltip',getString(message('images:commonUIString:zoomOutTooltip')),...
                'ValueChangedFcn',@(src,evt) enterZoomOutMode(self,evt));
            
            self.ZoomIn = axtoolbarbtn(self.AxesHandle.Toolbar,'state',...
                'Tag','CustomZoomIn',...
                'Icon','zoomin',...
                'Tooltip',getString(message('images:commonUIString:zoomInTooltip')),...
                'ValueChangedFcn',@(src,evt) enterZoomInMode(self,evt));
            
            self.Pan = axtoolbarbtn(self.AxesHandle.Toolbar,'state',...
                'Tag','CustomPan',...
                'Icon','pan',...
                'Tooltip',getString(message('images:commonUIString:pan')),...
                'ValueChangedFcn',@(src,evt) enterPanMode(self,evt));
            
            setAxesPosition(self,getCenterOfWindow(self));
            
            self.PanButtonUpListener = event.listener(ancestor(self.AxesHandle,'figure'),'WindowMouseRelease',@(src,evt) stopPan(self,evt));
            self.PanButtonUpListener.Enabled = false;
            
            self.PanMotionListener = event.listener(ancestor(self.AxesHandle,'figure'),'WindowMouseMotion',@(src,evt) doPan(self,evt.Source.CurrentPoint));
            self.PanMotionListener.Enabled = false;
            
            set(self.AxesHandle.Toolbar,'Visible','off');
            set(self.AxesHandle,'PickableParts','none','HitTest','off');
            set(self.ImageHandle,'PickableParts','none','HitTest','off');
            
            self.Rotate = images.internal.app.utilities.Rotate();
            addlistener(self.Rotate,'ImageRotated',@(~,~) notify(self,'ImageRotated'));
            
            self.Rectangle = images.roi.Rectangle('FaceAlpha',0,...
                'Color',[0.5 0.5 0.5],'InteractionsAllowed','none',...
                'FaceSelectable',false,'LineWidth',1,'DrawingArea','auto');

            % Prevent the zoom rectangle from using uiwait and uiresume
            % during interaction.
            self.Rectangle.WaitWhileDrawing = false;
            addlistener(self.Rectangle, 'DrawingFinished', @(src,evt) finishZoomInteraction(self));
            
            if isa(getCanvas(self.Panel),'matlab.graphics.primitive.canvas.HTMLCanvas')
                self.Message = uilabel(self.Panel,'Text','','Visible','off',...
                    'Tag','MessagePane','BackgroundColor',[1 1 0.88],...
                    'HorizontalAlignment','left','VerticalAlignment','center',...
                    'FontSize',12,'FontWeight','normal','FontColor',[0 0 0],...
                    'FontAngle','normal');
                
                self.CloseMessage = uiimage(self.Panel,'Visible','off','Tag','CloseMessagePane',...
                    'ImageSource',fullfile(toolboxdir('images'),'icons','Close_12.png'),...
                    'ImageClickedFcn',@(~,~) set(self,'MessageVisible',false));
            end

            self.PointerCache = getptr(ancestor(self.Panel,'figure'));
            
        end
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Visible
        %------------------------------------------------------------------
        function set.Visible(self,TF)
            
            self.Visible = TF;
            
            deselectAxesInteraction(self);
            
            if self.Visible
                set(self.AxesHandle,'Visible','on'); %#ok<MCSUP>
                set(self.AxesHandle.Toolbar,'Visible','on'); %#ok<MCSUP>
                set(self.AxesHandle,'PickableParts','visible','HitTest','on'); %#ok<MCSUP>
                set(self.ImageHandle,'PickableParts','visible','HitTest','on'); %#ok<MCSUP>
                resetView(self);
            else
                set(self.AxesHandle,'Visible','off'); %#ok<MCSUP>
                set(self.AxesHandle.Toolbar,'Visible','off'); %#ok<MCSUP>
                set(self.AxesHandle,'PickableParts','none','HitTest','off'); %#ok<MCSUP>
                set(self.ImageHandle,'PickableParts','none','HitTest','off'); %#ok<MCSUP>
            end
                        
        end
        
        %------------------------------------------------------------------
        % Background Color
        %------------------------------------------------------------------
        function set.BackgroundColor(self,val)
            
            self.BackgroundColor = val;
            set(self.AxesHandle,'Color',self.BackgroundColor); %#ok<MCSUP>
            
        end
        
        %------------------------------------------------------------------
        % Background Color
        %------------------------------------------------------------------
        function set.BoxColor(self,val)
            
            self.BoxColor = val;
            set(self.AxesHandle.XAxis,'Color',self.BoxColor); %#ok<MCSUP>
            set(self.AxesHandle.YAxis,'Color',self.BoxColor); %#ok<MCSUP>
            
        end
        
        %------------------------------------------------------------------
        % Rotation State
        %------------------------------------------------------------------
        function set.RotationState(self,val)
            
            % The rotation state is an internal index maintained to map
            % orientations after an arbitrary number of image
            % rotations/permutations. This index has no practical
            % application outside of the Rotation class and this method is
            % only provided to copy and set a new Rotation class with a
            % matching rotation state.
            self.Rotate.Current = val;
            
        end
        
        function val = get.RotationState(self)
            
            val = self.Rotate.Current;
            
        end
        
        %------------------------------------------------------------------
        % Downsample Mode
        %------------------------------------------------------------------
        function set.DownsampleMode(self,str)
            
            str = validatestring(str,{'auto','manual'});
            
            if strcmp(str,'auto')
                self.DownsampleModeInternal = true;
            else
                self.DownsampleModeInternal = false;
            end
            
            if self.DownsampleModeInternal && ~isempty(self.ImageHandle.CData)
                previousLevel = self.DownsampleLevelInternal;
                
                setDownsampleLevel(self);
                
                if previousLevel ~= self.DownsampleLevelInternal
                    notify(self,'ImageRequested');
                end
            end
            
        end
        
        function str = get.DownsampleMode(self)
            
            if self.DownsampleModeInternal
                str = 'auto';
            else
                str = 'manual';
            end
            
        end
        
        %------------------------------------------------------------------
        % Downsample Level
        %------------------------------------------------------------------
        function set.DownsampleLevel(self,val)
            
            validateattributes(val,{'numeric'},...
                {'positive','integer','real','nonempty','scalar','nonsparse'});
            
            previousLevel = self.DownsampleLevelInternal;
            
            self.DownsampleLevelInternal = val;
            self.DownsampleModeInternal = false;
            
            if previousLevel ~= self.DownsampleLevelInternal && ~isempty(self.ImageHandle.CData)
                notify(self,'ImageRequested');
            end
            
        end
        
        function val = get.DownsampleLevel(self)
            
            val = self.DownsampleLevelInternal;
            
        end
        
        %------------------------------------------------------------------
        % Superpixels
        %------------------------------------------------------------------
        function set.Superpixels(self,L)
            if isempty(L)
                self.SuperpixelsInternal = [];
                self.SuperpixelsVisible = false;
            else
                self.SuperpixelsInternal = boundarymask(L);
                self.SuperpixelsVisible = true;
            end
        end
        
        function L = get.Superpixels(self)
            L = self.SuperpixelsInternal;
        end
        
        %------------------------------------------------------------------
        % Message Text
        %------------------------------------------------------------------
        function set.MessageText(self,str)
            if ~isempty(self.Message)
                self.Message.Text = [' ' char(str)];
            end
        end
        
        function str = get.MessageText(self)
            if ~isempty(self.Message)
                str = self.Message.Text;
            else
                str = '';
            end
        end
        
        %------------------------------------------------------------------
        % Message Visible
        %------------------------------------------------------------------
        function set.MessageVisible(self,TF)
            
            if isempty(self.Message)
                return;
            end
            
            if TF
                updateMessagePosition(self);
                self.Message.Visible = 'on';
                self.CloseMessage.Visible = 'on';
            else
                self.Message.Visible = 'off';
                self.CloseMessage.Visible = 'off';
            end
        end
        
        function TF = get.MessageVisible(self)
            if ~isempty(self.Message)
                TF = strcmp(self.Message.Visible,'on');
            else
                TF = false;
            end
        end

        %------------------------------------------------------------------
        % PixelSize
        %------------------------------------------------------------------
        function set.PixelSize(self,pixelSize)
            
            self.PixelSizeInternal = pixelSize;
            self.AxesHandle.DataAspectRatio = [1/pixelSize(1) 1/pixelSize(2) 1];
            self.resetView();

        end
        
        function pixelSize = get.PixelSize(self)
            pixelSize = self.PixelSizeInternal;
        end

        %------------------------------------------------------------------
        % Zoom Percent
        %------------------------------------------------------------------
        function set.ZoomPercent(self,pct)
            self.ZoomPercentInternal = pct / 100;

            if isempty(self.ImageHandle.CData)
                return;
            end

            pixelSize = self.PixelSize;
            xPixelSize = pixelSize(1);
            yPixelSize = pixelSize(2);
            
            pos = self.Panel.Position;
            availableWidth = pos(3);
            availableHeight = pos(4);
                
            % Now, let's find the required screen pixel resolution i.e.
            % number of screen pixels required to display one image pixel,
            % in each dimension
            screenPixelsPerImagePixelX = availableWidth/(self.ImageHandle.XData(2)*xPixelSize);
            screenPixelsPerImagePixelY = availableHeight/(self.ImageHandle.YData(2)*yPixelSize);
            
            if screenPixelsPerImagePixelX < screenPixelsPerImagePixelY
                % Case where we will use up all screen pixels in X
                % direction
                self.ZoomLevel = log(self.ZoomPercentInternal / screenPixelsPerImagePixelX) + 1;
            else
                % Case where we will use up all screen pixels in Y
                % direction
                self.ZoomLevel = log(self.ZoomPercentInternal / screenPixelsPerImagePixelY) + 1;
            end

            % Clamp the minimum zoom level if requested
            if self.MinZoomFitToWindowInternal && (self.ZoomLevel < 1)
                self.ZoomLevel = 1;
            end

            setAxesPosition(self, getCenterOfWindow(self));

            % It is possible sometimes for the image to be positioned in
            % such a way there is a lot of white space in the figure
            % containing the image. This can happen when an image is zoomed
            % into interactively (centered around the mouse location) near
            % the edges and then the ZoomPercent property is manually set.
            % Check for this and reposition the image to avoid this.
            if self.ZoomLevel ~= 1
                recenterImage(self);
            end

            broadcastViewChangedEvent(self);
        end
        
        function pct = get.ZoomPercent(self)
            pct = self.ZoomPercentInternal * 100;
        end

        %------------------------------------------------------------------
        % MinZoomFiToToWindow
        %------------------------------------------------------------------
        function set.MinZoomFitToWindow(self,tf)

            % If the minimum zoom is to be restricted, reset the ZoomLevel
            % to "Fit To Window" and update the Axes Position
            if tf && self.ZoomLevel < 1
                resetView(self);
            end

            self.MinZoomFitToWindowInternal = tf;
        end

        function tf = get.MinZoomFitToWindow(self)
            tf = self.MinZoomFitToWindowInternal;
        end

        %------------------------------------------------------------------
        % Interpolation
        %------------------------------------------------------------------
        function set.Interpolation(self,interpMode)
            self.InterpInternal = interpMode;
            self.ImageHandle.Interpolation = interpMode;
        end

        function interpMode = get.Interpolation(self)
            interpMode = self.InterpInternal;
        end
        
        % Methods to explicitly provide GetAccess to UITester
        function h = get.ImageHandleTester(self)
            h = self.ImageHandle;
        end
        
        function h = get.AxesHandleTester(self)
            h = self.AxesHandle;
        end
        
    end
    
    
end