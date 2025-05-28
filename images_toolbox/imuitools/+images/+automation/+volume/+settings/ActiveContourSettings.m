classdef ActiveContourSettings < images.automation.volume.settings.Settings
    %
    
    % Copyright 2020 The MathWorks, Inc.
    properties
        
        Label
        EditField
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Initialize
        %------------------------------------------------------------------
        function initialize(self)
                        
            self.Parameters = struct('Iterations',50);
            self.Size = [300, 80];
            
        end
        
        %------------------------------------------------------------------
        % Create UI
        %------------------------------------------------------------------
        function createUI(self,hPanel)
            
            addLabel(self,hPanel);
            addEditField(self,hPanel);
            
        end
        
    end
    
    
    methods (Access = protected)
        
        %--Add Label-------------------------------------------------------
        function addLabel(self,hPanel)
            
            self.Label = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:iterations')));
            
        end
        
        %--Add Edit Field--------------------------------------------------
        function addEditField(self,hPanel)
            
            self.EditField = uieditfield(hPanel,'numeric',...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',self.Parameters.Iterations,'Limits',[1 Inf],...
                'RoundFractionalValues','on',...
                'Tag', 'Iterations', ...
                'ValueChangedFcn',@(~,evt) valueChanged(self,evt));
            
        end
        
        %--Value Changed---------------------------------------------------
        function valueChanged(self,evt)
            
            self.Parameters.Iterations = evt.Value;
            
        end
        
    end
    
    
end