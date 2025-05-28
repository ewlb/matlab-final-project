classdef ViewControlsManager < handle
    %

    % Copyright 2015-2019 The MathWorks, Inc.
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        OpacityLabelTester
        OpacitySliderTester
        ShowBinaryButtonTester
    end
    
    properties
        Section
        OpacityLabel
        OpacitySlider
        ShowBinaryButton
    end
    
    properties (Dependent)
        Enabled
        Opacity
    end
    
    methods
        
        function self = ViewControlsManager(hTab)
            
            import iptui.internal.*;
            import images.internal.app.segmenter.image.web.*;
            
            section = hTab.addSection(getMessageString('viewControls'));
            section.Tag = 'ViewControls';
            
            self.Section = section;
            
            % Opacity Label
            self.OpacityLabel = matlab.ui.internal.toolstrip.Label(getMessageString('foregroundOpacity'));
            self.OpacityLabel.Tag = 'labelOverlayOpacity';
            self.OpacityLabel.Description = getMessageString('foregroundOpacity');
            
            % Opacity Slider
            self.OpacitySlider = matlab.ui.internal.toolstrip.Slider([0,100],60);
            self.OpacitySlider.Ticks = 0;
            self.OpacitySlider.Tag = 'sliderMaskOpacity';
            self.OpacitySlider.Description = getMessageString('sliderTooltip');
            
            % Show Binary Button
            self.ShowBinaryButton = matlab.ui.internal.toolstrip.ToggleButton(...
                getMessageString('showBinary'),...
                matlab.ui.internal.toolstrip.Icon('binaryImageMask'));
            self.ShowBinaryButton.Tag = 'btnShowBinary';
            self.ShowBinaryButton.Description = getMessageString('viewBinaryTooltip');
            
            c = section.addColumn('width',100,...
                'HorizontalAlignment','center');
            c.add(self.OpacityLabel)
            c.add(self.OpacitySlider);
            
            c2 = section.addColumn();
            c2.add(self.ShowBinaryButton);
            
            self.Section = section;

        end
        
    end
    
    
    % Set/Get accessors
    methods
        
        function TF = get.Enabled(self)
            
            TF = self.OpacitySlider.Enabled;
            
        end
        
        function set.Enabled(self,TF)
            
            if TF && self.ShowBinaryButton.Value
                self.OpacityLabel.Enabled  = false;
                self.OpacitySlider.Enabled = false;
            else
                self.OpacityLabel.Enabled  = TF;
                self.OpacitySlider.Enabled = TF;
            end
            
            self.ShowBinaryButton.Enabled = TF;
            
        end
        
        function o = get.Opacity(self)
            
            o = self.OpacitySlider.Value;
            
        end
        
        function set.Opacity(self,o)
            
            self.OpacitySlider.Value = o;
            
        end
        
        function obj = get.OpacityLabelTester(self)
            obj = self.OpacityLabel;
        end
        
        function obj = get.OpacitySliderTester(self)
            obj = self.OpacitySlider;
        end
        
        function obj = get.ShowBinaryButtonTester(self)
            obj = self.ShowBinaryButton;
        end
        
    end
end