classdef (Abstract) OkCancelDialog < images.internal.app.utilities.Dialog
    %
    
    % Copyright 2019 The MathWorks, Inc.
    
    properties (GetAccess = public, SetAccess = protected)
        
        Ok
        Cancel
        
        Canceled (1,1) logical = true;
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Ok Dialog
        %------------------------------------------------------------------
        function self = OkCancelDialog(loc, dlgTitle)
            
            self = self@images.internal.app.utilities.Dialog(loc, dlgTitle);
            
        end
        
        %------------------------------------------------------------------
        % Create
        %------------------------------------------------------------------
        function create(self)
            
            create@images.internal.app.utilities.Dialog(self);
            
            addOK(self);
            addCancel(self);
            
        end
        
    end
    
    methods (Access = protected)
        
        %--Ok Clicked------------------------------------------------------
        function okClicked(self)
            
            if strcmp(get(self.Ok, 'Enable'),'on')
                self.Canceled = false;
                close(self);
            end
            
        end
        
        %--Cancel Clicked--------------------------------------------------
        function cancelClicked(self)
            
            close(self);
            
        end
        
        %--Add Ok----------------------------------------------------------
        function addOK(self)
            
            self.Ok = uibutton('Parent',self.FigureHandle, ...
                'ButtonPushedFcn', @(~,~) okClicked(self),...
                'FontSize', 12, ...
                'Position',[self.Size(1) - (2*self.ButtonSpace) - (2*self.ButtonSize(1)), self.ButtonSpace, self.ButtonSize],...
                'Text',getString(message('MATLAB:uistring:popupdialogs:OK')),...
                'Tag', 'OK');
            
        end
        
        %--Add Cancel------------------------------------------------------
        function addCancel(self)
            
            self.Cancel = uibutton('Parent', self.FigureHandle, ...
                'ButtonPushedFcn', @(~,~) cancelClicked(self),...
                'Position',[self.Size(1) - self.ButtonSpace - self.ButtonSize(1), self.ButtonSpace, self.ButtonSize], ...
                'FontSize', 12,...
                'Text',getString(message('MATLAB:uistring:popupdialogs:Cancel')),...
                'Tag', 'Cancel');
            
        end
        
        %--Key Press-------------------------------------------------------
        function keyPress(self, evt)
            
            if ~validateKeyPressSupport(self,evt)
                return;
            end
            
            switch(evt.Key)
                case {'return','space'}
                    okClicked(self);
                case 'escape'
                    cancelClicked(self);
            end
            
        end
        
    end
    
end
