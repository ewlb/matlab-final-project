classdef ModeFilterSettings < images.automation.volume.settings.Settings
    %
    
    % Copyright 2020 The MathWorks, Inc.
    properties
        
        Label
        XLabel
        YLabel
        ZLabel
        X
        Y
        Z
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Initialize
        %------------------------------------------------------------------
        function initialize(self)
            
            self.Parameters = struct('FilterSize',[3 3 3]);
            self.Size = [300, 160];
            
        end
        
        %------------------------------------------------------------------
        % Create UI
        %------------------------------------------------------------------
        function createUI(self,hPanel)
            
            addLabels(self,hPanel);
            addSpinners(self,hPanel);
            
        end
        
    end
    
    
    methods (Access = protected)
        
        %--Add Labels------------------------------------------------------
        function addLabels(self,hPanel)
            
            self.Label = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1 + (3*self.ButtonSize(2)) + (3*self.ButtonSpace),round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:filterSize')));
            
            self.XLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1 + (2*self.ButtonSize(2)) + (2*self.ButtonSpace),round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:filterSizeX')));
            
            self.YLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1 + self.ButtonSize(2) + self.ButtonSpace,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:filterSizeY')));
            
            self.ZLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:filterSizeZ')));
            
        end
        
        %--Add Spinners----------------------------------------------------
        function addSpinners(self,hPanel)
            
            sz = self.Parameters.FilterSize;
            
            self.X = uispinner(hPanel,...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1 + (2*self.ButtonSize(2)) + (2*self.ButtonSpace),round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',sz(2),'Limits',[1 25],...
                'RoundFractionalValues','on',...
                'Step',2,...
                'Tag','X', ...
                'ValueChangedFcn',@(~,evt) xValueChanged(self,evt));
            
            self.Y = uispinner(hPanel,...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1 + self.ButtonSize(2) + self.ButtonSpace,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',sz(1),'Limits',[1 25],...
                'RoundFractionalValues','on',...
                'Step',2,...
                'Tag','Y', ...
                'ValueChangedFcn',@(~,evt) yValueChanged(self,evt));
            
            self.Z = uispinner(hPanel,...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',sz(3),'Limits',[1 25],...
                'RoundFractionalValues','on',...
                'Step',2,...
                'Tag','Z', ...
                'ValueChangedFcn',@(~,evt) zValueChanged(self,evt));
            
        end
        
        %--X Value Changed-------------------------------------------------
        function xValueChanged(self,evt)
            
            sz = self.Parameters.FilterSize;
            
            sz(2) = validateOddInteger(self,evt.Value);
            self.X.Value = sz(2);
            
            self.Parameters.FilterSize = sz;
            
        end
        
        %--Y Value Changed-------------------------------------------------
        function yValueChanged(self,evt)
            
            sz = self.Parameters.FilterSize;
            
            sz(1) = validateOddInteger(self,evt.Value);
            self.Y.Value = sz(1);
            
            self.Parameters.FilterSize = sz;
            
        end
        
        %--Z Value Changed-------------------------------------------------
        function zValueChanged(self,evt)
            
            sz = self.Parameters.FilterSize;
            
            sz(3) = validateOddInteger(self,evt.Value);
            self.Z.Value = sz(3);
            
            self.Parameters.FilterSize = sz;
            
        end
        
        %--Validate Odd Integer--------------------------------------------
        function val = validateOddInteger(~,val)
            
            if mod(val,2) == 0
                val = max(val - 1,1);
            end
            
        end
        
    end
    
    
end