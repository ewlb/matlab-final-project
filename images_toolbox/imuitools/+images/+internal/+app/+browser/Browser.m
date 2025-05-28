classdef (Sealed) Browser < handle & matlab.mixin.SetGet
    
    %
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    events
        
        % SelectionChanged Event to notify when selection has changed.
        SelectionChanged
        
        % OpenSelection Event to notify a double-click open operation
        OpenSelection
        
        % ThumbnailReadStarted Event that fires when the Browser ReadFcn is
        % called. For a series of thumbnails that require file IO, this
        % event should only fire once.
        ThumbnailReadStarted
        
        % ThumbnailReadFinshed Event that fires when the Browser ReadFcn
        % has finished executing. For a series of thumbnails that require
        % file IO, this event should only fire once after all thumbnails
        % are read or when the browser is interrupted.
        ThumbnailReadFinished

        % DisplayIndexChanged Event to notify an updated browser data
        % information when browser slider position has changed.
        DisplayIndexChanged
        
    end
    
    
    properties (Dependent)
        
        % Layout - "auto" | "row" | "column"
        Layout (1,1) string {mustBeMember(Layout, ["auto", "row", "column"])}
        
        % Enabled - true | false
        Enabled (1,1) logical

        % Selection Type - "multi" | "single" | "none"
        SelectionType

        % Selection Required - false | true
        % Determines if at least one thumbnail should be selected at all
        % times. When SelectionType is "none", this property has no effect.
        SelectionRequired
        
        % Selected Color - [0.349 0.667 0.847] | RGB triplet
        SelectedColor

        % Hot Selected Color - [0.592 0.792 0.906] | RGB triplet
        LastSelectedColor
        
        % Background Color - [0.94 0.94 0.94] | RGB triplet
        BackgroundColor
        
        % Entry Size - [100 100] | 1-by-2 positive integer
        ThumbnailSize (1,2) double {mustBePositive, mustBeInteger}
        
        % Context Menu - uicontextmenu object displayed during right clicks
        % on the thumbnails when interactivity is enabled.
        ContextMenu
        
        % Label Visible - false | true
        LabelVisible (1,1) logical
        
        % Label Location - "bottom" | "right" | "overlay"
        LabelLocation (1,1) string {mustBeMember(LabelLocation, ["bottom", "right", "overlay"])}

        % Label Text Color - [0 0 0] | RGB triplet
        LabelTextColor

        % Badge Location - "southwest" | "northeast" | "northwest" | "southeast"
        BadgeLocation (1,1) string {mustBeMember(BadgeLocation, ["northwest", "northeast", "southwest", "southeast"])}
        
        % ReadFcn - A function handle which takes in a single source and
        % returns its corresponding full image.
        %  [im, label, badge, userData] = ReadFcn(Sources(ind)) should
        %  return image data (MxNx3 uint8) for ind'th source. Label data as
        %  a scalar string and userData as a scalar struct - both of these
        %  can be empty. The badge must be an enumeration from
        %  images.internal.app.browser.data.Badge.
        ReadFcn (1,1) function_handle
        
        % ThumbnailVisible - A 1-by-NumImages array of logicals indicating if
        % the corresponding thumbnail's visible status.
        ThumbnailVisible (1,:) logical

        % ThumbnailColorStyle
        % Color style of the thumbnail browser. When specified as
        % "uniform", the browser will color each thumbnail by the value
        % specified in SelectedColor and LastSelectedColor. When specified
        % as "individual", the browser will color the thumbnail by the
        % color set with the setColor method for the corresponding
        % thumbnail index. When set to "individual", the SelectedColor and
        % LastSelectedColor properties will have no effect.
        ThumbnailColorStyle (1,1) string {mustBeMember(ThumbnailColorStyle, ["uniform", "individual"])}

    end
    
    
    properties (Dependent, SetAccess = private)
        
        % Sources - A 1-byNumImages cell array containing the original
        % sources.
        Sources (:,1) cell
        
        % NumImages - A scalar indicating the total number of images
        % currently in the browser.
        % Note - The total number of currently _visible_ thumbnails is
        % controlled by ThumbnailVisible property.
        NumImages (1,1) double
        
        % NumVisibleColumns - The number of thumbnail images that can fit
        % in a single row in the current view port.
        NumVisibleColumns (1,1) double
        
        % NumVisibleRows - The number of thumbnail images that can fit in a
        % single column in the current view port.
        NumVisibleRows (1,1) double

        % Selected - A 1-by-NumImages array of indices into Sources for the
        % currently selected thumbnails.
        Selected (:,1) double
        
        % LastSelected - A scalar index into Sources indicating the last
        % entry that was added to the Selected list.
        LastSelected (1,1) double
        
    end
    
    
    properties (Access = private, Hidden, Transient)
        
        Model      images.internal.app.browser.Model
        Controller images.internal.app.browser.Controller
        
    end
    
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private, Transient)
        
        View       images.internal.app.browser.View
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Browser
        %------------------------------------------------------------------
        function self = Browser(hparent,pos,varargin)
            
            self.Model      = images.internal.app.browser.Model();
            self.View       = images.internal.app.browser.View(hparent,pos);
            
            if ~isvalid(self.View)
                return;
            end
            
            self.Controller = images.internal.app.browser.Controller(self.Model,self.View);
            
            addlistener(self.Model,'SelectionChanged',@(src,evt) notify(self,'SelectionChanged',evt));
            % Notify clients that Model removed some entries
            addlistener(self.Model,'OpenSelection', @(src, evt) notify(self,'OpenSelection',evt));
            addlistener(self.View,'EntryReadStarted', @(~, ~) notify(self,'ThumbnailReadStarted'));
            addlistener(self.View,'EntryReadFinished', @(~, ~) notify(self,'ThumbnailReadFinished'));

            addlistener(self.Model,'DisplayUpdated', @(src, evt) notify(self,'DisplayIndexChanged', evt));
            
            parseInputs(self,varargin{:});
            
        end
        
        %------------------------------------------------------------------
        % Scroll
        %------------------------------------------------------------------
        function scroll(self,scrollCount)
            scroll(self.View,scrollCount);
        end
        
        %------------------------------------------------------------------
        % Up
        %------------------------------------------------------------------
        function up(self)
            up(self.View);
        end
        
        %------------------------------------------------------------------
        % Down
        %------------------------------------------------------------------
        function down(self)
            down(self.View);
        end
        
        %------------------------------------------------------------------
        % Page Up
        %------------------------------------------------------------------
        function pageUp(self)
            pageUp(self.View);
        end
        
        %------------------------------------------------------------------
        % Page Down
        %------------------------------------------------------------------
        function pageDown(self)
            pageDown(self.View);
        end
        
        %------------------------------------------------------------------
        % Bottom
        %------------------------------------------------------------------
        function bottom(self)
            bottom(self.View);
        end
        
        %------------------------------------------------------------------
        % Top
        %------------------------------------------------------------------
        function top(self)
            top(self.View);
        end
        
        %------------------------------------------------------------------
        % Resize
        %------------------------------------------------------------------
        function resize(self,pos)
            resize(self.View,pos);
        end
        
        %------------------------------------------------------------------
        % Clear - clear all content. Component is ready for new sources
        % via add() after this call.
        %------------------------------------------------------------------
        function clear(self)
            clear(self.View);
            clear(self.Model);
        end
        
        %------------------------------------------------------------------
        % Add
        %------------------------------------------------------------------
        function add(self,sources, insertBefore)
            arguments
                self
                sources (:,1) cell
                insertBefore = [] % Default adds to the end
            end
            add(self.Model,sources, insertBefore);
            
            if ~isempty(insertBefore)
                % Ensure newly added entries are visible
                snapToEntry(self.View, insertBefore);
            end
        end
        
        %------------------------------------------------------------------
        % Select
        %------------------------------------------------------------------
        function select(self, selectionInds)
            if self.Enabled
                self.Model.select(selectionInds)
            end
        end
        
        %------------------------------------------------------------------
        % Remove
        %------------------------------------------------------------------
        function remove(self, removeInds)
            if self.Enabled
                self.Model.remove(removeInds);
            end
        end
        
        %------------------------------------------------------------------
        % Remove Selected
        %------------------------------------------------------------------
        function removeSelected(self)
            if self.Enabled
                self.Model.removeSelected();
            end
        end
        
        %------------------------------------------------------------------
        % Rotate
        %------------------------------------------------------------------
        function rotate(self, rotateInds, theta)
            if self.Enabled
                self.Model.rotate(rotateInds,theta);
                triggerRefresh(self.View);
            end
        end
        
        %------------------------------------------------------------------
        % Remove Selected
        %------------------------------------------------------------------
        function rotateSelected(self, theta)
            if self.Enabled
                self.Model.rotateSelected(theta);
                triggerRefresh(self.View);
            end
        end
        
        %------------------------------------------------------------------
        % Set a badge
        %------------------------------------------------------------------
        function setBadge(self, badgeInds, badge)
            arguments
                self
                badgeInds (:,1) double
                badge (1,1) {mustBeA(badge, 'images.internal.app.browser.data.Badge')}
            end
            self.Model.badge(badgeInds, badge);
            triggerRefresh(self.View);
        end
        
        %------------------------------------------------------------------
        % Set label explicitly
        %------------------------------------------------------------------
        function setLabel(self, imageInd, label)
            arguments
                self
                imageInd (:,1) double
                label (:,1) string 
            end
            self.Model.setLabel(imageInd, label);
            triggerRefresh(self.View);
        end

        %------------------------------------------------------------------
        % Set Color
        %------------------------------------------------------------------
        function setColor(self, imageInd, color)
            % This color has no impact on the browser unless
            % ThumbnailColorStyle is set to "individual"
            arguments
                self
                imageInd (:,1) double
                color (1,3) double {mustBeInRange(color,0,1)}
            end
            self.Model.setColor(imageInd, color);
            triggerRefresh(self.View);
        end

        %------------------------------------------------------------------
        % Refresh (clear out existing thumbnails, and recreate them from
        % scratch
        %------------------------------------------------------------------
        function refresh(self, imageInds)
            arguments
                self
                imageInds (:,1) double = []
            end           
            if isempty(imageInds)
                % Refresh all
                imageInds = 1:self.NumImages;
            end
            refresh(self.Model, imageInds)
            triggerRefresh(self.View)
        end
        
        %------------------------------------------------------------------
        % getuserData
        %------------------------------------------------------------------
        function userData = getUserData(self, index)
            arguments
                self
                index (1,1) double {mustBePositive}
            end
            userData = self.Model.getUserData(index);
        end
        
        %------------------------------------------------------------------
        % Delete
        %------------------------------------------------------------------
        function delete(self)
            delete(self.Controller);
            delete(self.View);
            delete(self.Model);
        end
        
    end


    methods (Hidden)
        %------------------------------------------------------------------
        % Set Multiline label explicitly 
        %------------------------------------------------------------------
        function setMultilineLabel(self, imageInd, label)
            % The method has an implicit assumption that the number of
            % lines per label must be the same between all entries being
            % set.

            arguments
                self
                imageInd (:,1) double
                label (:,1) string
            end
            self.Model.setMultilineLabel(imageInd, label);
            triggerRefresh(self.View);
        end

        %------------------------------------------------------------------
        % Set badges for image indices
        %------------------------------------------------------------------
        function setMultipleBadges(self, badgeInds, badges)
            arguments
                self
                badgeInds (:,1) double
                badges (:,1) {mustBeA(badges, 'images.internal.app.browser.data.Badge')}
            end
            numBadges = numel(badges);
            numInds = numel(badgeInds);
            assert(numBadges == numInds);
            for n = 1:numBadges
                self.Model.badge(badgeInds(n), badges(n));
            end
            triggerRefresh(self.View);
        end
    end
    
    
    methods (Access = private)
        
        %--Parse Inputs----------------------------------------------------
        function parseInputs(self,varargin)
            
            % Convert strings to char for input validation
            varargin = matlab.images.internal.stringToChar(varargin);
            
            if ~isempty(varargin)
                set(self, varargin{:});
            end
            
        end
        
    end
    
    % Get/Set methods
    methods
        
        %------------------------------------------------------------------
        % Layout
        %------------------------------------------------------------------
        function set.Layout(self,val)
            self.View.Layout = val;
        end
        
        function val = get.Layout(self)
            val = self.View.Layout;
        end
        
        %------------------------------------------------------------------
        % Enabled
        %------------------------------------------------------------------
        function set.Enabled(self,TF)
            self.View.Enabled = TF;
        end
        
        function TF = get.Enabled(self)
            TF = self.View.Enabled;
        end
        
        %------------------------------------------------------------------
        % Entry Size
        %------------------------------------------------------------------
        function set.ThumbnailSize(self,val)
            self.View.EntrySize = val;
            self.Model.ThumbnailSize = val;
        end
        
        function val = get.ThumbnailSize(self)
            val = self.View.EntrySize;
        end
        
        %------------------------------------------------------------------
        % Selected Color
        %------------------------------------------------------------------
        function set.SelectedColor(self,color)
            self.View.SelectedColor = color;
        end
        
        function color = get.SelectedColor(self)
            color = self.View.SelectedColor;
        end

        %------------------------------------------------------------------
        % Hot Selected Color
        %------------------------------------------------------------------
        function set.LastSelectedColor(self,color)
            self.View.HotSelectedColor = color;
        end
        
        function color = get.LastSelectedColor(self)
            color = self.View.HotSelectedColor;
        end
        
        %------------------------------------------------------------------
        % Background Color
        %------------------------------------------------------------------
        function set.BackgroundColor(self,color)
            self.View.BackgroundColor = color;
        end
        
        function color = get.BackgroundColor(self)
            color = self.View.BackgroundColor;
        end

        %------------------------------------------------------------------
        % Label Text Color
        %------------------------------------------------------------------
        function set.LabelTextColor(self,color)
            self.View.LabelTextColor = color;
        end
        
        function color = get.LabelTextColor(self)
            color = self.View.LabelTextColor;
        end
        
        %------------------------------------------------------------------
        % Context Menu
        %------------------------------------------------------------------
        function set.ContextMenu(self,TF)
            self.View.ContextMenu = TF;
        end
        
        function TF = get.ContextMenu(self)
            TF = self.View.ContextMenu;
        end
        
        %------------------------------------------------------------------
        % Label Visible
        %------------------------------------------------------------------
        function set.LabelVisible(self,TF)
            self.View.LabelVisible = TF;
        end
        
        function TF = get.LabelVisible(self)
            TF = self.View.LabelVisible;
        end
        
        %------------------------------------------------------------------
        % Label Location
        %------------------------------------------------------------------
        function set.LabelLocation(self,loc)
            self.View.LabelLocation = loc;
        end
        
        function loc = get.LabelLocation(self)
            loc = self.View.LabelLocation;
        end

        %------------------------------------------------------------------
        % Badge Location
        %------------------------------------------------------------------
        function set.BadgeLocation(self,loc)
            self.View.BadgeLocation = loc;
        end
        
        function loc = get.BadgeLocation(self)
            loc = self.View.BadgeLocation;
        end

        %------------------------------------------------------------------
        % Selection Type
        %------------------------------------------------------------------
        function set.SelectionType(self,type)
            self.Model.SelectionType = type;
            self.View.HighlightOnHover = self.Model.SelectionType ~= "none";
        end
        
        function type = get.SelectionType(self)
            type = self.Model.SelectionType;
        end

        %------------------------------------------------------------------
        % Selection Type
        %------------------------------------------------------------------
        function set.SelectionRequired(self,TF)
            self.Model.SelectionRequired = TF;
        end
        
        function TF = get.SelectionRequired(self)
            TF = self.Model.SelectionRequired;
        end
        
        %------------------------------------------------------------------
        % NumImages
        %------------------------------------------------------------------
        function n = get.NumImages(self)
            n = self.Model.NumImages;
        end
        
        %------------------------------------------------------------------
        % Number Of Columns
        %------------------------------------------------------------------
        function n = get.NumVisibleColumns(self)
            n = self.View.NumColumns;
        end
        
        %------------------------------------------------------------------
        % Number Of Visible Rows
        %------------------------------------------------------------------
        function n = get.NumVisibleRows(self)
            n = self.View.NumVisibleRows;
        end
        
        %------------------------------------------------------------------
        % Selected
        %------------------------------------------------------------------
        function selectedInds = get.Selected(self)
            selectedInds = self.Model.Selected;
        end
        
        %------------------------------------------------------------------
        % LastSelected
        %------------------------------------------------------------------
        function lastSelectedIndex = get.LastSelected(self)
            lastSelectedIndex = self.Model.LastSelected;
        end
        
        %------------------------------------------------------------------
        % ReadFcn
        %------------------------------------------------------------------
        function set.ReadFcn(self, readFcn)
            arguments
                self
                readFcn(1,1) function_handle
            end
            self.Model.ReadFcn = readFcn;
            % Clear out all existing thumbnails, and refresh.
            refresh(self);
        end
        
        function readFcn = get.ReadFcn(self)
            readFcn = self.Model.ReadFcn;
        end
        
        %------------------------------------------------------------------
        % Sources
        %------------------------------------------------------------------
        function sources = get.Sources(self)
            sources = self.Model.Sources;
        end
        
        %------------------------------------------------------------------
        % ThumbnailVisible
        %------------------------------------------------------------------
        function set.ThumbnailVisible(self, tf)
            self.Model.FilteredIn = tf;
            clear(self.View);
            addEntries(self.View, sum(tf));
        end
        
        function tf = get.ThumbnailVisible(self)
            tf = self.Model.FilteredIn;
        end

        %------------------------------------------------------------------
        % Thumbnail Color Style
        %------------------------------------------------------------------
        function set.ThumbnailColorStyle(self, style)
            self.View.ThumbnailColorStyle = style;
            triggerRefresh(self.View);
        end
        
        function style = get.ThumbnailColorStyle(self)
            style = self.View.ThumbnailColorStyle;
        end
        
    end
    
    
end
