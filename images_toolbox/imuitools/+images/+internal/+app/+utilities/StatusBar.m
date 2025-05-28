classdef StatusBar < handle
    
    %

    % Copyright 2016-2020 The MathWorks, Inc.
    
    properties
        StatusText
        Bar
        Label
    end
    
    methods

        function tool = StatusBar()
            
            tool.StatusText = '';
            
            tool.Bar = matlab.ui.internal.statusbar.StatusBar();
            tool.Bar.Tag = "statusBar";
            
            tool.Label = matlab.ui.internal.statusbar.StatusLabel();
            tool.Label.Tag = "statusLabel";
            tool.Label.Text = "";
            tool.Label.Region = "right";
            tool.Bar.add(tool.Label);
            
        end
        
        function setStatus(tool,text)
            tool.StatusText = text;
            tool.Label.Text = string(text);
        end
        
    end
    
end
