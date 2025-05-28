classdef (Abstract) OkDialog < images.internal.app.utilities.Dialog
    %
    
    % Copyright 2019 The MathWorks, Inc.
    
    properties (GetAccess = public, SetAccess = protected)
        
        Ok
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Ok Dialog
        %------------------------------------------------------------------
        function self = OkDialog(loc, dlgTitle)
            
            self = self@images.internal.app.utilities.Dialog(loc, dlgTitle);
            
        end
        
        %------------------------------------------------------------------
        % Create
        %------------------------------------------------------------------
        function create(self)
            
            create@images.internal.app.utilities.Dialog(self);
            
            addOK(self);
            
        end
        
    end
    
    
    methods (Access = private)
        
        %--Add Ok----------------------------------------------------------
        function addOK(self)
            
            w = round(self.ButtonSize(1) / 2);
            
            self.Ok = uibutton('Parent',self.FigureHandle, ...
                'ButtonPushedFcn', @(~,~) close(self),...
                'FontSize', 12, ...
                'Position',[round(self.Size(1)/2)-w self.ButtonSpace 2*w 2*self.ButtonSpace],...
                'Text',getString(message('MATLAB:uistring:popupdialogs:OK')),...
                'Tag', 'OK');
            
        end
        
    end
    
    methods (Access = protected)
        
        %--Key Press-------------------------------------------------------
        function keyPress(self, evt)
            
            switch(evt.Key)
                case {'return', 'space', 'escape'}
                    close(self);
            end
            
        end
        
    end
    
end
