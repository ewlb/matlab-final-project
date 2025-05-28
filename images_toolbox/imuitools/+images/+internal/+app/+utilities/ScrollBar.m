classdef ScrollBar < handle
    %
    
    % Copyright 2020 The MathWorks, Inc.
    
    events
        
        ScrollBarDragging
        ScrollBarDragged
        
    end
    
    properties (Dependent)
        
        Enabled
        
    end
    
    
    properties (Access = private, Transient)
        
        % Enabled
        EnabledInternal     (1,1) logical = false;
        
        % Panel height
        Height              (1,1) double {mustBePositive} = 24;
        
        % Width of entire scrollbar
        Width               (1,1) double {mustBePositive} = 5;
        
        % Scrollbar height
        ScrollBarHeight     (1,1) double {mustBePositive} = 5;
        
        % Y location of scrollbar
        Y                   (1,1) double {mustBePositive} = 1;
        
        % Range of the things that are scrollable
        Range               (1,2) double = [1 2];
        
        StartPoint          (:,:) double = [];
        
        HighlightListener   event.listener
        MotionListener      event.listener
        ButtonUpListener    event.listener
        
    end
    
    
    properties (GetAccess = {?images.uitest.factory.Tester, ?uitest.factory.Tester}, ...
                SetAccess = private, Transient)
        
        % Parent panel
        Panel               matlab.ui.container.Panel
        
        % Draggable scrollbar
        Bar                 matlab.graphics.shape.Rectangle
        
    end
    
    
    properties (Access = private, Hidden, Transient)
        
        LightGray           (1,3) double = [0.75 0.75 0.75];
        MediumGray          (1,3) double = [0.65 0.65 0.65];
        DarkGray            (1,3) double = [0.4 0.4 0.4];
                
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Scroll Bar
        %------------------------------------------------------------------
        function self = ScrollBar(hParent,pos)
            
            self.Width = pos(3);
            self.Height = pos(4);
                        
            self.Panel = uipanel('Parent',hParent,...
                'BorderType','none',...
                'Units','pixels',...
                'HandleVisibility','off',...
                'Position',pos,...
                'Tag','ScrollBarPanel',...
                'AutoResizeChildren','off',...
                'Visible','off');
                        
            self.Bar = annotation(self.Panel,'rectangle',...
                'Units','pixels',...
                'LineStyle','none',...
                'Tag','ScrollBarRectangle',...
                'FaceColor',self.LightGray,...
                'Position',getBarPosition(self),...
                'Visible','off');
            
            hfig = ancestor(hParent,'figure');
            self.HighlightListener = event.listener(hfig,'WindowMouseMotion',@(src,evt) hover(self,evt));
            self.HighlightListener.Enabled = false;
            self.MotionListener = event.listener(hfig,'WindowMouseMotion',@(src,evt) drag(self,evt));
            self.MotionListener.Enabled = false;
            self.ButtonUpListener = event.listener(hfig,'WindowMouseRelease',@(src,evt) stopDrag(self,evt));
            self.ButtonUpListener.Enabled = false;
            
            setBarHeight(self);
                                    
        end
        
        %------------------------------------------------------------------
        % Update
        %------------------------------------------------------------------
        function update(self,range)
                        
            self.Range = range;
            setBarHeight(self);

        end
        
        %------------------------------------------------------------------
        % Resize
        %------------------------------------------------------------------
        function resize(self,pos)
                        
            if ~isequal(self.Panel.Position,pos)
                
                self.Panel.Position = pos;
                
                self.Width = pos(3);
                self.Height = pos(4);
                setBarHeight(self);
                
            end
            
        end
        
        %------------------------------------------------------------------
        % Clear
        %------------------------------------------------------------------
        function clear(self)
            
            self.Enabled = false;
            
        end
        
    end
    
    
    methods (Access = private)
        
        %--Get Slider Position---------------------------------------------
        function pos = getBarPosition(self)
            
            pos = [1, self.Y, self.Width, self.ScrollBarHeight];
            
        end
        
        %--Set Bar Height--------------------------------------------------
        function setBarHeight(self)
            
            if ~self.EnabledInternal
                return;
            end
            
            if self.Range(1) > 1 || self.Range(2) - self.Range(1) <= self.Height
                if strcmp(self.Bar.Visible,'on')
                    self.Bar.Visible = 'off';
                end
                return;
            end
                        
            minVal = min([self.Range(1),1]);
            totalLength = max([self.Range(2),self.Height]) - minVal;
            inViewLength = self.Height - 1;
            
            self.ScrollBarHeight = max([round(self.Height*(inViewLength/totalLength)),round(self.Height/10),1]);
            self.Y = max([(self.Height - self.ScrollBarHeight)*(1 - minVal)/(totalLength - inViewLength),1]);
            
            set(self.Bar,'Position',getBarPosition(self),'Visible','on');
            
        end
        
        %--Hover-----------------------------------------------------------
        function hover(self,evt)
            
            if evt.HitObject == self.Bar
                if ~isequal(self.Bar.FaceColor,self.MediumGray)
                    self.Bar.FaceColor = self.MediumGray;
                end
            else
                if ~isequal(self.Bar.FaceColor,self.LightGray)
                    self.Bar.FaceColor = self.LightGray;
                end
            end
            
        end
        
        %--Start Drag------------------------------------------------------
        function startDrag(self)
            self.ButtonUpListener.Enabled = true;
            self.HighlightListener.Enabled = false;
            self.Bar.FaceColor = self.DarkGray;
            
            % TODO - add click/drag support
            hfig = ancestor(self.Panel,'figure');
            self.StartPoint = hfig.CurrentPoint(2);
            self.MotionListener.Enabled = true;
        end
        
        %--Drag------------------------------------------------------------
        function drag(self,evt)
            
            notify(self,'ScrollBarDragging',images.internal.app.utilities.events.ScrollBarDraggedEventData(evt.Point(2),self.StartPoint,[1,self.Height],[self.Y,self.Y+self.ScrollBarHeight]));
            
        end
        
        %--Stop Drag-------------------------------------------------------
        function stopDrag(self,evt)
            self.MotionListener.Enabled = false;
            self.ButtonUpListener.Enabled = false;
            self.Bar.FaceColor = self.LightGray;
            self.HighlightListener.Enabled = true;
            
            notify(self,'ScrollBarDragged',images.internal.app.utilities.events.ScrollBarDraggedEventData(evt.Point(2),self.StartPoint,[1,self.Height],[self.Y,self.Y+self.ScrollBarHeight]));
            
        end
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Enabled
        %------------------------------------------------------------------
        function set.Enabled(self,TF)
            
            if self.EnabledInternal == TF
                return;
            end
            
            self.EnabledInternal = TF;
            
            if TF
                set(self.Bar,'ButtonDownFcn',@(~,~) startDrag(self));
                self.Panel.Visible = 'on';
                setBarHeight(self);
            else
                if strcmp(self.Panel.Visible,'on')
                    self.Panel.Visible = 'off';
                    self.Bar.Visible = 'off';
                    set(self.Bar,'ButtonDownFcn',[]);
                end
            end
            
            self.HighlightListener.Enabled = TF;

        end
        
        function TF = get.Enabled(self)
            TF = self.EnabledInternal;
        end
        
    end
    
end