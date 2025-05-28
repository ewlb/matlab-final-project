classdef MorphologySettings < images.automation.volume.settings.Settings
    %
    
    % Copyright 2020 The MathWorks, Inc.
    properties
        
        RadiusLabel
        NLabel
        
        Radius
        N
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Initialize
        %------------------------------------------------------------------
        function initialize(self)
            
            self.Parameters = struct('Radius',3,'N',4);
            self.Size = [300, 110];
            
        end
        
        
        %------------------------------------------------------------------
        % Create UI
        %------------------------------------------------------------------
        function createUI(self,hPanel)
            
            addLabels(self,hPanel);
            addRadius(self,hPanel);
            addN(self,hPanel);
            
        end
        
    end
    
    
    methods (Access = protected)
        
        %--Add Labels------------------------------------------------------
        function addLabels(self,hPanel)
            
            self.RadiusLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1 + self.ButtonSize(2) + self.ButtonSpace,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:radius')),...
                'Tooltip',getString(message('images:segmenter:radiusTooltip')));
            
            self.NLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:nElements')),...
                'Tooltip',getString(message('images:segmenter:nElementsTooltip')));
            
        end
        
        %--Add Radius------------------------------------------------------
        function addRadius(self,hPanel)
            
            self.Radius = uispinner(hPanel,...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1 + self.ButtonSize(2) + self.ButtonSpace,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',self.Parameters.Radius,'Limits',[1 100],...
                'RoundFractionalValues','on',...
                'Step',1,...
                'Tag','Radius', ...
                'ValueChangedFcn',@(~,evt) radiusValueChanged(self,evt));
            
        end
        
        %--Add N-----------------------------------------------------------
        function addN(self,hPanel)
            
            n = self.Parameters.N;
            
            switch n
                case 0
                    val = '0';
                case 4
                    val = '4';
                case 6
                    val = '6';
                case 8
                    val = '8';
            end
            
            self.N = uidropdown(hPanel,...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',val,'Items',{'0' '4' '6' '8'},...
                'Tag','N', ...
                'ValueChangedFcn',@(~,evt) nValueChanged(self,evt));
            
        end
        
        %--Radius Value Changed---------------------------------------------
        function radiusValueChanged(self,evt)
            
            self.Parameters.Radius = evt.Value;
            
        end
        
        %--N Value Changed-------------------------------------------------
        function nValueChanged(self,evt)
            
            switch evt.Value
                case '0'
                    self.Parameters.N = 0;
                case '4'
                    self.Parameters.N = 4;
                case '6'
                    self.Parameters.N = 6;
                case '8'
                    self.Parameters.N = 8;
            end
            
        end
        
    end
    
    
end