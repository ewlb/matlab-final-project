classdef (Abstract) CloseDialog < images.internal.app.utilities.Dialog
    %
    
    % Copyright 2019 The MathWorks, Inc.
    
    properties (Hidden, GetAccess = public, SetAccess = protected)
        
        Close
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Ok Dialog
        %------------------------------------------------------------------
        function self = CloseDialog(loc, dlgTitle)
            
            self = self@images.internal.app.utilities.Dialog(loc, dlgTitle);
            
        end
        
        %------------------------------------------------------------------
        % Create
        %------------------------------------------------------------------
        function create(self)
            
            create@images.internal.app.utilities.Dialog(self);
            
            addClose(self);
            
        end
        
    end
    
    methods (Access = protected)
        
        %--Close Clicked---------------------------------------------------
        function closeClicked(self)
            
            close(self);
            
        end
        
        %--Add Close----------------------------------------------------------
        function addClose(self)
            
            self.Close = uibutton('Parent',self.FigureHandle, ...
                'ButtonPushedFcn', @(~,~) closeClicked(self),...
                'FontSize', 12, ...
                'Position',[self.Size(1) - self.ButtonSpace - self.ButtonSize(1), self.ButtonSpace, self.ButtonSize],...
                'Text',getString(message('images:segmenter:close')),...
                'Tag', 'Close');
            
        end
        
        %--Key Press-------------------------------------------------------
        function keyPress(self, evt)
            
            if ~validateKeyPressSupport(self,evt)
                return;
            end
            
            switch(evt.Key)
                case {'return','space','escape'}
                    closeClicked(self);
            end
            
        end
        
    end
    
end
