classdef GaussianFilterSettings < images.automation.volume.settings.Settings
    %
    
    % Copyright 2020 The MathWorks, Inc.
    properties
        
        FilterLabel
        XLabel
        YLabel
        ZLabel
        X
        Y
        Z
        
        ThresholdLabel
        Threshold
        
        SigmaLabel
        Sigma
        
        ApplyFilter
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Initialize
        %------------------------------------------------------------------
        function initialize(self)
            
            self.Parameters = struct('ApplyFilter',true,'Sigma',0.5,'FilterSize',[3,3,3],'Threshold',1);
            self.Size = [300, 260];
            
        end
        
        
        %------------------------------------------------------------------
        % Create UI
        %------------------------------------------------------------------
        function createUI(self,hPanel)
            
            addApply(self,hPanel);
            addSigma(self,hPanel);
            addFilterSizeLabels(self,hPanel);
            addSpinners(self,hPanel);
            addThreshold(self,hPanel);
            
            % Ensure that the controls are correctly enabled or didsabled
            % based on the state of ApplyFilter
            applyFilterChanged(self,self.Parameters.ApplyFilter);
            
        end
        
    end
    
    
    methods (Access = protected)
        
        function addApply(self,hPanel)
            
            self.ApplyFilter = uicheckbox(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1 + (6*self.ButtonSize(2)) + (6*self.ButtonSpace),self.Size(1) - (2*self.ButtonSpace),self.ButtonSize(2)],...
                'FontSize', 12,...
                'Value',self.Parameters.ApplyFilter,...
                'Text',getString(message('images:segmenter:applyFilter')),...
                'Tooltip',getString(message('images:segmenter:applyFilterTooltip')),...
                'Tag', 'ApplyFilter', ...
                'ValueChangedFcn',@(src,evt) applyFilterChanged(self,evt.Value));
            
        end
        
        %--Add Filter Size Labels------------------------------------------
        function addFilterSizeLabels(self,hPanel)
            
            self.FilterLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1 + (5*self.ButtonSize(2)) + (5*self.ButtonSpace),round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:filterSize')));
            
            self.XLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1 + (4*self.ButtonSize(2)) + (4*self.ButtonSpace),round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:filterSizeX')));
            
            self.YLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1 + (3*self.ButtonSize(2)) + (3*self.ButtonSpace),round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:filterSizeY')));
            
            self.ZLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1 + (2*self.ButtonSize(2)) + (2*self.ButtonSpace),round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:filterSizeZ')));
            
        end
        
        %--Add Spinners----------------------------------------------------
        function addSpinners(self,hPanel)
            
            sz = self.Parameters.FilterSize;
            
            self.X = uispinner(hPanel,...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1 + (4*self.ButtonSize(2)) + (4*self.ButtonSpace),round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',sz(2),'Limits',[1 25],...
                'RoundFractionalValues','on',...
                'Step',2,...
                'Tag', 'X', ...
                'ValueChangedFcn',@(~,evt) xValueChanged(self,evt));
            
            self.Y = uispinner(hPanel,...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1 + (3*self.ButtonSize(2)) + (3*self.ButtonSpace),round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',sz(1),'Limits',[1 25],...
                'RoundFractionalValues','on',...
                'Step',2,...
                'Tag', 'Y', ...
                'ValueChangedFcn',@(~,evt) yValueChanged(self,evt));
            
            self.Z = uispinner(hPanel,...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1 + (2*self.ButtonSize(2)) + (2*self.ButtonSpace),round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',sz(3),'Limits',[1 25],...
                'RoundFractionalValues','on',...
                'Step',2,...
                'Tag', 'Z', ...
                'ValueChangedFcn',@(~,evt) zValueChanged(self,evt));
            
        end
        
        %--Add Threshold---------------------------------------------------
        function addThreshold(self,hPanel)
            
            self.ThresholdLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:threshold')));
            
            self.Threshold = uieditfield(hPanel,'numeric',...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',self.Parameters.Threshold,'Limits',[-Inf Inf],...
                'RoundFractionalValues','off',...
                'Tag', 'Threshold', ...
                'ValueChangedFcn',@(~,evt) thresholdChanged(self,evt));
            
        end
        
        %--Add Sigma-------------------------------------------------------
        function addSigma(self,hPanel)
            
            self.SigmaLabel = uilabel(...
                'Parent', hPanel,...
                'Position', [self.ButtonSpace,1 + self.ButtonSize(2) + self.ButtonSpace,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',getString(message('images:segmenter:sigma')));
            
            self.Sigma = uieditfield(hPanel,'numeric',...
                'Position', [round((self.Size(1) - (3*self.ButtonSpace))/2) + (2*self.ButtonSpace),1 + self.ButtonSize(2) + self.ButtonSpace,round((self.Size(1) - (3*self.ButtonSpace))/2),self.ButtonSize(2)],...
                'Value',self.Parameters.Sigma,'Limits',[eps 100],...
                'RoundFractionalValues','off',...
                'Tag', 'Sigma', ...
                'ValueChangedFcn',@(~,evt) sigmaChanged(self,evt));
            
        end
        
        function applyFilterChanged(self,val)
            
            self.Parameters.ApplyFilter = logical(val);
            
            if val
                self.X.Enable = 'on';
                self.Y.Enable = 'on';
                self.Z.Enable = 'on';
                self.Sigma.Enable = 'on';
            else
                self.X.Enable = 'off';
                self.Y.Enable = 'off';
                self.Z.Enable = 'off';
                self.Sigma.Enable = 'off';
            end
            
        end
        
        %--Threshold Changed-----------------------------------------------
        function thresholdChanged(self,evt)
            
            self.Parameters.Threshold = evt.Value;
            
        end
        
        %--Sigma Changed---------------------------------------------------
        function sigmaChanged(self,evt)
            
            self.Parameters.Sigma = evt.Value;
            
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