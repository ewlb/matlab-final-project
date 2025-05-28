classdef TextureManager < handle
%

%   Copyright 2016-2019 The MathWorks, Inc.
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        TextureButton
    end
    
    properties
        Section
    end
    
    properties (Dependent)
        Enabled
        Selected
    end
    
    properties (Access = private)
        hApp
        hToolstrip
    end
    
    events
        TextureButtonClicked
    end
    
    methods
        
        function self = TextureManager(hTab,hApp,hToolstrip)
            self.hApp = hApp;
            self.hToolstrip = hToolstrip;
            self.layoutTextureSection(hTab);
        end
        
        function updateTextureState(self,TF)
            self.Selected = TF;
        end
        
    end
    
    methods
    % set/get methods
    function set.Enabled(self,TF)
        self.TextureButton.Enabled = TF;
    end
    
    function TF = get.Enabled(self)
        TF = self.TextureButton.Enabled;
    end
    
    function set.Selected(self,TF)
        self.TextureButton.Value = TF;
    end
    
    function TF = get.Selected(self)
        TF = self.TextureButton.Value;
    end
    
    end
    
    methods (Access = private)
        
        function textureCallback(self)
            self.toggleTexture();
        end
        
        function toggleTexture(self)
            
            import images.internal.app.segmenter.image.web.AppMode;

            if self.Selected
                self.hApp.App.Busy = true;
                TF = self.hApp.Session.createTextureFeatures();
                self.hApp.App.Busy = false;
                self.hApp.Session.UseTexture = TF;
                self.Selected = TF;
            end
            
            self.hApp.Session.UseTexture = self.Selected;
            notify(self,'TextureButtonClicked');
            self.hToolstrip.setMode(AppMode.ToggleTexture);
            
        end
        
        function layoutTextureSection(self,hTab)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            section = hTab.addSection(getMessageString('texture'));
            section.Tag = 'texture';

            %Texture Button
            self.TextureButton = matlab.ui.internal.toolstrip.ToggleButton(getMessageString('textureTitle'), matlab.ui.internal.toolstrip.Icon('imageTexture'));
            self.TextureButton.Tag = 'btnTexture';
            self.TextureButton.Description = getMessageString('textureTooltip');            
            addlistener(self.TextureButton, 'ValueChanged', @(~,~) self.textureCallback());
            
            %Layout
            c = section.addColumn();
            c.add(self.TextureButton);
            self.Section = section;
            
        end
        
    end
    
end

