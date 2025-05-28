classdef ImagePreviewPanel < handle & matlab.mixin.SetGet
    % Show images.internal.app.utilities.Image with a label on top and
    % bottom. 
    % Also has capability to show Left and Right nav buttons at the bottom
    % to allow scrolling through multiple selections in the imageBrowser.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    events
        NavigateLR
    end
    
    properties (Dependent)
        LRButtonsEnabled (1,1) logical
    end
    properties (Access = private)
        LRButtonsEnabled_ (1,1) logical = false;
        ImageHeight (1,1) double = 10;
    end
    
    
    properties (Constant = true)
        % Left and right arrow icons for the preview (when multiple
        % thumbnails are selected)
        LIconImage = ...
            imread(fullfile(matlabroot,'toolbox','images','icons','leftArrow.png'));
        RIconImage = ...
            imread(fullfile(matlabroot,'toolbox','images','icons','rightArrow.png'));
    end
    
    properties (GetAccess = {?uitest.factory.Tester},...
            SetAccess = private, Transient)
        ParentFigure
        ImagePanel matlab.ui.container.Panel
        Image images.internal.app.utilities.Image
        TopLabel
        BottomLabel
        LeftButton
        RightButton        
    end
    
    methods
        
        %------------------------------------------------------------------
        % ProfileImagePanel
        %------------------------------------------------------------------
        function self = ImagePreviewPanel(hfig)
            self.ParentFigure = hfig;
            
            self.TopLabel = uilabel('Parent',self.ParentFigure,...
                'Text','',...
                'Visible','off',...
                'Interpreter', 'none',...
                'VerticalAlignment','top',...
                'HorizontalAlignment', 'center',...
                'FontSize',18);
            self.ImagePanel = uipanel('Parent',self.ParentFigure,...
                'BorderType','none',...
                'Units','pixels',...
                'HandleVisibility','off',...
                'Visible', 'on',...
                'Tag','ProfileImagePanel',...
                'AutoResizeChildren','off');
            
            self.Image = images.internal.app.utilities.Image(self.ImagePanel);
            self.Image.Enabled = true;
            self.Image.Visible = true;
            
            self.BottomLabel = uilabel('Parent',self.ParentFigure,...
                'Text','',...
                'Interpreter', 'none',...
                'Visible','off',...
                'VerticalAlignment','top',...
                'HorizontalAlignment', 'center',...
                'FontSize',18);
            
            self.LeftButton = uibutton('Parent', self.ParentFigure,...
                'Visible', 'off',...
                'Tag', 'Left', ...
                'Text','',...
                'Icon', self.LIconImage, ...
                'Tooltip', getString(message('images:imageBrowser:lrButtonToolTips')),...
                'ButtonPushedFcn', @(~,~) notify(self, 'NavigateLR', images.internal.app.imageBrowser.web.NavigateLREventData('l')));
            self.RightButton = uibutton('Parent', self.ParentFigure,...
                'Visible', 'off',...
                'Tag', 'Right', ...
                'Text','',...
                'Icon', self.RIconImage,...
                'Tooltip', getString(message('images:imageBrowser:lrButtonToolTips')),...
                'ButtonPushedFcn', @(~,~) notify(self, 'NavigateLR', images.internal.app.imageBrowser.web.NavigateLREventData('r')));
            
            hfig.SizeChangedFcn = @(~,~)self.resize;
            hfig.KeyPressFcn = @self.keyPress;
            
            self.resize();
        end
        
        function draw(self, img, topLineText, bottomLineText)
            self.ImageHeight = size(img,1);
            
            if isempty(img)
                clear(self.Image);
            else   
                oldImageSize = size(self.Image.ImageHandle.CData);
                draw(self.Image,img,[],[],[]);
                if ~isequal(oldImageSize, size(img))
                    % Re-layout the panel.
                    self.resize();
                end
            end
            
            self.TopLabel.Text = topLineText;
            self.BottomLabel.Text = bottomLineText;
            
            drawnow limitrate
        end
        
        function scroll(self, evt)
            scroll(self.Image,evt.VerticalScrollCount);
        end

        function motionCallback(self,src,evt)
            hitObject = ancestor(evt.HitObject,'figure');

            if hitObject == self.ParentFigure
                if ~isempty(ancestor(evt.HitObject,'matlab.graphics.controls.AxesToolbar'))
                    images.roi.setBackgroundPointer(src,'arrow');
                elseif isa(evt.HitObject,'matlab.graphics.primitive.Image')
                    if isprop(evt.HitObject,'InteractionMode')
                        switch evt.HitObject.InteractionMode
                            case ''
                                images.roi.setBackgroundPointer(src,'arrow');
                            case 'pan'
                                images.roi.setBackgroundPointer(src,'custom',matlab.graphics.interaction.internal.getPointerCData('pan_both'),[16,16]);
                            case 'zoomin'
                                images.roi.setBackgroundPointer(src,'custom',matlab.graphics.interaction.internal.getPointerCData('zoomin_unconstrained'),[16,16]);
                            case 'zoomout'
                                images.roi.setBackgroundPointer(src,'custom',matlab.graphics.interaction.internal.getPointerCData('zoomout_both'),[16,16]);
                        end
                    else
                        images.roi.setBackgroundPointer(src,'arrow');
                    end
                else
                    images.roi.setBackgroundPointer(src,'arrow');
                end
            else
                images.roi.setBackgroundPointer(src,'arrow');
            end

        end    
    end
    
    methods
        function set.LRButtonsEnabled(self, TF)
            if self.LRButtonsEnabled_ ~= TF
                self.LRButtonsEnabled_ = TF;
                self.resize();
                self.LeftButton.Visible = TF;
                self.RightButton.Visible = TF;
            end
        end
        function TF = get.LRButtonsEnabled(self)
            TF = self.LRButtonsEnabled_;
        end
    end
    
    methods (Access = private)
        function keyPress(self, ~, evt)
            switch(evt.Key)
                case {'leftarrow', 'uparrow'}
                    notify(self, 'NavigateLR', ...
                        images.internal.app.imageBrowser.web.NavigateLREventData('l'));
                case {'rightarrow', 'downarrow'}
                    notify(self, 'NavigateLR',...
                        images.internal.app.imageBrowser.web.NavigateLREventData('r'));
            end
        end
        
        function resize(self)
            w = self.ParentFigure.Position(3);
            h = self.ParentFigure.Position(4);
            
            labelHeight = 22;
            buttonHeight = 30;
            buttonWidth = 30;
            gutter = 10;
                        
            spaceForLabelsAndButtons = gutter+labelHeight+gutter+gutter+labelHeight;
            if self.LRButtonsEnabled
                spaceForLabelsAndButtons = spaceForLabelsAndButtons + gutter+buttonHeight+gutter;
            end
            maxImageHeightPossible = h - spaceForLabelsAndButtons;
            
            if maxImageHeightPossible<50
                % Show only image
                self.TopLabel.Visible = false;
                self.BottomLabel.Visible = false;
                self.LeftButton.Visible = false;
                self.RightButton.Visible = false;
                self.BottomLabel.Visible = false;
                self.ImagePanel.Position = [ 1, 1, ...
                    self.ParentFigure.Position(3:4)];
                
            else
                % Enough space to show labels and buttons
                self.TopLabel.Visible = true;
                self.BottomLabel.Visible = true;
                if self.LRButtonsEnabled
                    self.LeftButton.Visible = true;
                    self.RightButton.Visible = true;
                end
                self.BottomLabel.Visible = true;
                
                actImageHeight = self.ImageHeight;
                imagePanelHeight = min(maxImageHeightPossible, actImageHeight);
                
                curTop = max(gutter,h-spaceForLabelsAndButtons-imagePanelHeight);
                
                % Build from bottom up
                if self.LRButtonsEnabled
                    self.LeftButton.Position = [gutter curTop buttonWidth buttonHeight];
                    self.RightButton.Position = [w-buttonWidth-gutter curTop buttonWidth buttonHeight];
                    curTop = curTop + buttonHeight + gutter;
                end
                
                self.BottomLabel.Position = [1 curTop w labelHeight];
                curTop = curTop + labelHeight + gutter;
                
                self.ImagePanel.Position = [1 curTop w imagePanelHeight];
                curTop = curTop + imagePanelHeight;
                
                self.TopLabel.Position = [1 curTop w labelHeight];
            end
            
            self.Image.resize();
        end
    end
end