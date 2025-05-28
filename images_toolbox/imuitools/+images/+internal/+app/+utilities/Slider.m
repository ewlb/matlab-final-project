classdef Slider < handle
    % For internal use only
    %
    % Slider(HPARENT,POS) Creates places a slider on the figure or uipanel
    % HPARENT with the position defined by POS in units of pixels
    
    % Copyright 2019 The MathWorks, Inc.
    
    properties (Access = public)
        Value = 0.5;
        Visible = true;
        Position
        Enabled = true;
        Tag = '';
    end
    
    properties (Access = private)
        Panel
        SliderPointer
        SliderLine
        LineListener
        PointerListener
        MotionListener
        ButtonUpListener
    end
    
    events
        SliderChanging
        SliderChanged
    end
    
    methods
        
        function self = Slider(hParent,pos)
            buildSlider(self,hParent,pos);
            self.Position = pos;
        end

    end
    
    methods
        % Set/get methods
        function set.Value(self,val)
            
            if ~isscalar(val)
                return;
            end
            
            if isnan(val)
                if self.Value < 0.1
                    val = 0;
                elseif self.Value > 0.9
                    val = 1;
                else
                    return;
                end
            end
            
            if val < 0
                val = 0;
            elseif val > 1
                val = 1;
            end

            self.Value = val;
            set(self.SliderPointer,'XData',val) %#ok<MCSUP>
            
        end
        
        function set.Visible(self,TF)
            if TF
                set(self.Panel,'Visible','on'); %#ok<MCSUP>
            else
                set(self.Panel,'Visible','off'); %#ok<MCSUP>
            end
            self.Visible = TF;
        end
        
        function set.Position(self,inputVal)
            self.Position = inputVal;
            set(self.Panel,'Position',inputVal); %#ok<MCSUP>
        end
        
        function set.Enabled(self,TF)
            if TF
                self.PointerListener.Enabled = true; %#ok<MCSUP>
                self.LineListener.Enabled = true; %#ok<MCSUP>
                set(self.SliderLine,'Color',[0 0 0]); %#ok<MCSUP>
                set(self.SliderPointer,'MarkerEdgeColor',[0 0 0],...
                    'MarkerFaceColor',[1 1 1]); %#ok<MCSUP>
            else
                self.PointerListener.Enabled = false; %#ok<MCSUP>
                self.LineListener.Enabled = false; %#ok<MCSUP>
                set(self.SliderLine,'Color',[0.5 0.5 0.5]); %#ok<MCSUP>
                set(self.SliderPointer,'MarkerEdgeColor',[0.5 0.5 0.5],...
                    'MarkerFaceColor',[0.94 0.94 0.94]); %#ok<MCSUP>
            end
        end
        
        function set.Tag(self,inputVal)
            if ischar(inputVal)
                self.Tag = inputVal;
            end
        end
        
    end
    
    methods (Access = private)
    
        function sliderCallback(self)
            
            set(self.SliderPointer,'PickableParts','none');
            set(self.SliderLine,'PickableParts','none');
            self.MotionListener.Enabled = true;
            self.ButtonUpListener.Enabled = true;

        end
        
        function sliderDrag(self,evt)
            
            self.Value = evt.IntersectionPoint(1);
            notify(self,'SliderChanging')
            
        end
        
        function sliderUp(self,evt)
            
            set(self.SliderPointer,'PickableParts','all');
            set(self.SliderLine,'PickableParts','all');
            self.MotionListener.Enabled = false;
            self.ButtonUpListener.Enabled = false;
            
            sliderDrag(self,evt);
            notify(self,'SliderChanged')
            
        end
        
        function buildSlider(self,hParent,pos)
            
            hFig = ancestor(hParent,'figure');
            
            self.Panel = uipanel('Parent',hParent,...
                'Units','pixels',...
                'Position',pos,...
                'Visible','on',...
                'HitTest','off',...
                'BorderType','none',...
                'HandleVisibility','off');
            
            hAx = axes('Parent',self.Panel,...
                'Visible','off',...
                'HitTest','on',...
                'PickableParts','all',...
                'Units','normalized',...
                'Position',[0.05 0 0.9 1],...
                'HandleVisibility','off',...
                'Toolbar',[]);
            
            self.SliderLine = line('Parent',hAx,...
                'XData',[0 1],...
                'YData',[0.5 0.5],...
                'Color',[0 0 0],...
                'HandleVisibility','off');
            
            self.LineListener = event.listener(self.SliderLine,'Hit',@(~,~) sliderCallback(self));
            
            self.SliderPointer = line('Parent',hAx,...
                'XData',0.5,...
                'YData',0.5,...
                'Marker','o',...
                'MarkerFaceColor',[1 1 1],...
                'MarkerEdgeColor',[0 0 0],...
                'Linestyle','none',...
                'HandleVisibility','off');
            
            self.PointerListener = event.listener(self.SliderPointer,'Hit',@(~,~) sliderCallback(self));
            
            self.MotionListener = event.listener(hFig,'WindowMouseMotion',@(src,evt) sliderDrag(self,evt));
            self.MotionListener.Enabled = false;
            
            self.ButtonUpListener = event.listener(hFig,'WindowMouseRelease',@(src,evt) sliderUp(self,evt));
            self.ButtonUpListener.Enabled = false;
            
        end
        
    end
    
end