classdef Entry < handle & matlab.mixin.SetGet
    %
    
    % Copyright 2020 The MathWorks, Inc.
    
    events
        
        % EntryRemoved
        EntryRemoved
        
        % EntryClicked
        EntryClicked
        
    end
    
    
    properties (Dependent)
        
        Selected
        
    end
    
    
    properties
        
        % Entry name
        Name                    char = '';
        
        % Entry thumbnail
        Image                   (:,:) logical
        
        % Entry width
        Width                   (1,1) double {mustBePositive} = 1;
        
        % Y position in parent panel
        Y                       (1,1) double = 1;
    end
    
    
    properties (GetAccess = {?images.uitest.factory.Tester,...
            ?images.internal.app.segmenter.volume.display.Labels,...
            ?images.internal.app.segmenter.image.web.ThumbnailList}, SetAccess = private, Transient)
        
        NameUI                  matlab.ui.control.Label
        Panel                   matlab.ui.container.Panel
        ThumbnailUI             matlab.ui.control.Image
        
    end
    
    
    properties (Access = private, Hidden, Transient)
        
        ThumbnailListener       event.listener
        NameListener            event.listener
        
        Dirty                   (1,1) logical = false;
        
        SelectedInternal        (1,1) logical = false;

    end
    
    
    properties (Constant, Hidden)
        
        % X location in parent panel in pixel units
        X = 1;
        
        % Height of entry in pixel units
        Height = images.internal.app.segmenter.image.web.getThumbnailSize();
        
        % Border between entry elements in pixels
        Border = 2;
        
        SelectedColor = "--mw-backgroundColor-selectedFocus";
        UnselectedColor = "--mw-backgroundColor-primary";
        FontColor = "--mw-color-primary";
    end
    
    methods
        
        %------------------------------------------------------------------
        % Entry
        %------------------------------------------------------------------
        function self = Entry(hpanel,yloc,name,BW)

            self.Width = hpanel.Position(3);
            self.Y = yloc;
            
            createUI(self,hpanel,BW);
            
            self.Name = name;
            self.Image = BW;
            
        end
        
        %------------------------------------------------------------------
        % Enable
        %------------------------------------------------------------------
        function enable(self)
            
            self.NameListener.Enabled = true;
            self.ThumbnailListener.Enabled = true;
            
        end
        
        %------------------------------------------------------------------
        % Disable
        %------------------------------------------------------------------
        function disable(self)
            
            self.NameListener.Enabled = false;
            self.ThumbnailListener.Enabled = false;
            
        end
        
        %------------------------------------------------------------------
        % Delete
        %------------------------------------------------------------------
        function delete(self)
            
            delete(self.Panel)
            delete(self.NameUI)
            delete(self.ThumbnailUI)
            
        end
        
        %------------------------------------------------------------------
        % Update Thumbnail
        %------------------------------------------------------------------
        function updateThumbnail(self,BW)
            set(self.ThumbnailUI,'ImageSource',BW);
        end
        
        %------------------------------------------------------------------
        % Deactivate
        %------------------------------------------------------------------
        function deactivate(~)
            
            % No-op
            
        end
        
    end
    
    
    methods (Hidden)
        
        %------------------------------------------------------------------
        % Name Clicked
        %------------------------------------------------------------------
        function nameClicked(self,~)
            
            notify(self,'EntryClicked');
            
        end
        
    end
    
    
    methods (Access = private)
        
        %--Name Changed----------------------------------------------------
        function nameChanged(self)
            
            % TODO - Edit fields are really annoying to use. There is more
            % work to be done here to make this UI passable
            if ~isa(self.NameUI,'matlab.ui.control.EditField')
                set(self.NameUI,'Enable','inactive');
                val = self.NameUI.String;
            else
                set(self.NameUI,'Editable','off');
                val = self.NameUI.Value;
            end
            
            self.Selected = true;
            
            notify(self,'NameChanged',images.internal.app.segmenter.volume.events.NameChangedEventData(...
                    self.Name,val));
            
        end
        
        %--Remove Entry----------------------------------------------------
        function removeEntry(self)
            notify(self,'EntryRemoved',images.internal.app.segmenter.volume.events.LabelEventData(...
                    self.Name));
        end
        
        %--Create UI-------------------------------------------------------
        function createUI(self,hpanel,BW)
            import matlab.graphics.internal.themes.specifyThemePropertyMappings;
            self.Panel = uipanel('Parent',hpanel,...
                'BorderType','none',...
                'Units','pixels',...
                'HandleVisibility','off',...
                'BorderType','none',...
                'Tag', 'MainEntryPanel', ...
                'Position',getPanelPosition(self));
            specifyThemePropertyMappings( self.Panel, 'BackgroundColor', ...
                                                    self.SelectedColor );

            set(self.Panel,'ButtonDownFcn',@(src,evt) nameClicked(self,src));
            
            self.NameUI = uilabel(...
                'Parent',self.Panel,...
                'Position',getNamePosition(self),...
                'Text',self.Name,...
                'HorizontalAlignment','left');
            specifyThemePropertyMappings( self.NameUI, 'FontColor', ...
                                                        self.FontColor );
            
            
            BW = repmat(im2uint8(BW),[1 1 3]);
            
            self.ThumbnailUI = uiimage('Parent',self.Panel,...
                'ScaleMethod','fit',...
                'ImageSource',BW,...
                'Position',getImagePosition(self));
            
            self.ThumbnailListener = event.listener(self.ThumbnailUI,'ImageClicked',@(src,evt) nameClicked(self,src));
            self.NameListener = event.listener(self.NameUI,'ButtonDown',@(src,evt) nameClicked(self,src));
            
        end
        
        %--Get Name Position-----------------------------------------------
        function pos = getNamePosition(self)
            pos = [1 + self.Height + (3*self.Border), 1 + self.Border, self.Width - self.Height - (4*self.Border), self.Height];
            pos(pos < 1) = 1;
        end
        
        %--Get Panel Position----------------------------------------------
        function pos = getPanelPosition(self)
            pos = [self.X, self.Y, self.Width, self.Height + (2*self.Border)];
        end
        
        %--Get Image Position-----------------------------------------------
        function pos = getImagePosition(self)
            pos = [1 + self.Border,...
                1 + self.Border,...
                self.Height,...
                self.Height];
        end
        
        %--Update Position-------------------------------------------------
        function updatePosition(self)
            if ~isempty(self.NameUI)
                set(self.Panel,'Position',getPanelPosition(self));
                set(self.NameUI,'Position',getNamePosition(self));
                set(self.ThumbnailUI,'Position',getImagePosition(self));
            end
        end
        
        %--Update Name-----------------------------------------------------
        function updateName(self)
            self.NameUI.Text = self.Name;
        end
        
        %--Update Name-----------------------------------------------------
        function updateImage(self)
            self.ThumbnailUI.ImageSource = self.Image;
        end
        
        %--Open Context Menu-----------------------------------------------
        function openContextMenu(self,src)
        
            % When we enable the entry, we turn on the NameListener. Check
            % for that to determine if the context menu should be usable
            if self.NameListener.Enabled
                set(src.Children,'Enable','on');
            else
                set(src.Children,'Enable','off');
            end
            
        end
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Name
        %------------------------------------------------------------------
        function set.Name(self,name)
            self.Name = name;
            updateName(self);
        end
        
        %------------------------------------------------------------------
        % Name
        %------------------------------------------------------------------
        function set.Image(self,BW)
            self.Image = repmat(im2uint8(BW),[1 1 3]);
            updateImage(self);
        end
        
        %------------------------------------------------------------------
        % Width
        %------------------------------------------------------------------
        function set.Width(self,val)
            self.Width = val;
            updatePosition(self);
        end
        
        %------------------------------------------------------------------
        % Y
        %------------------------------------------------------------------
        function set.Y(self,val)
            self.Y = val;
            updatePosition(self);
        end
        
        %------------------------------------------------------------------
        % Selected
        %------------------------------------------------------------------
        function set.Selected(self,TF)
            import matlab.graphics.internal.themes.specifyThemePropertyMappings;
            if TF
                specifyThemePropertyMappings( self.Panel, ...
                                'BackgroundColor', self.SelectedColor );
            else
                specifyThemePropertyMappings(self.Panel, ...
                                'BackgroundColor', self.UnselectedColor );
            end
            
            self.SelectedInternal = TF;
            
        end
        
        function TF = get.Selected(self)
            
            TF = self.SelectedInternal;
            
        end
        
    end
    
    
end