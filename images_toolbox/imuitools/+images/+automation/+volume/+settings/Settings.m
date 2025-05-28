classdef (Abstract) Settings < images.internal.app.utilities.CloseDialog
    %
    
    % Copyright 2019 The MathWorks, Inc.
    
    
    properties
        
        Parameters struct
        
    end
    
    
    properties (Access = protected)
        
        Panel matlab.ui.container.Panel
        
    end
    
    
    properties (Dependent)
       
        Visible
        
    end
    
    
    methods (Abstract)
    
        createUI(self,hPanel);
        initialize(self);
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Settings
        %------------------------------------------------------------------
        function self = Settings()
            
            self = self@images.internal.app.utilities.CloseDialog([100 100], getString(message('images:segmenter:algorithmSettingsOneLine')));
            
        end
        
        %------------------------------------------------------------------
        % Create
        %------------------------------------------------------------------
        function create(self)
             
            if isempty(self.Parameters)
                initialize(self);
            end
            
            constructPanel(self);
            
            createUI(self,self.Panel);
            
            sz = self.Panel.Position;
            
            create@images.internal.app.utilities.CloseDialog(self);
            
            self.Panel.Parent = self.FigureHandle;
            self.Panel.Position = [1, (2*self.ButtonSpace) + self.ButtonSize(2), sz(3), sz(4)];
            
            set(self.FigureHandle,'Visible','on');
            
        end
        
    end
    
    
    methods (Access = private)
        
        %--Construct Panel-------------------------------------------------
        function constructPanel(self)
            
            self.Panel = uipanel('Parent',gobjects(0),...
                'Units','pixels','Position',[1 1 self.Size],...
                'BorderType','none');
            
        end
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Visible
        %------------------------------------------------------------------
        function set.Visible(self,val)
            
            if ~isempty(self.Panel)
                hFig = ancestor(self.Panel,'figure');
                if ~isempty(hFig)
                    hFig.Visible = val;
                end
            end
            
        end
        
        function val = get.Visible(self)
            
            if ~isempty(self.Panel)
                hFig = ancestor(self.Panel,'figure');
                if ~isempty(hFig)
                    val = hFig.Visible;
                else
                    val = 'off';
                end
            else
                val = 'off';
            end
            
        end
        
    end

    
end