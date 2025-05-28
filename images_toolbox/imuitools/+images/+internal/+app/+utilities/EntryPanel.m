classdef EntryPanel < handle
    %
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    events
        
        % EntryRemoved
        EntryRemoved
        
        % EntrySelected
        EntrySelected
        
    end

    properties
        % EntrySelected - Client should call resize after setting
        % HeaderHeight
        HeaderHeight (1,1) double {mustBePositive} = 34;
    end
    
    
    properties (SetAccess = private, Hidden, Transient)
        
        Current (1,1) double = 0;
        
    end
    
    
    properties (SetAccess = private, GetAccess = protected, Hidden, Transient)
        
        PreviousSelection (1,1) double = 0;
        
    end
    
    
    properties (SetAccess = protected, Hidden)
        
        Border = 2;
        
        EntryHeight = 24;
        
        ScrollBarWidth = 5;
        
    end
    
    
    properties (Access = protected)
        
        UseHeader (1,1) logical
        
    end
    
    
    properties (GetAccess = {?images.uitest.factory.Tester,...
            ?uitest.factory.Tester,...
            ?images.internal.app.segmenter.volume.display.Labels,...
            ?images.internal.app.segmenter.image.ThumbnailList,...
            ?images.internal.app.segmenter.image.web.ThumbnailList,...
            ?images.internal.app.volview.LabelsBrowserWeb,...
            ?medical.internal.app.labeler.view.labelBrowser.LabelBrowser,...
            ?medical.internal.app.labeler.display.LabelBrowser,...
            ?medical.internal.app.home.labeler.display.LabelBrowser}, SetAccess = protected, Transient)
        
        Header matlab.ui.container.Panel
        Panel matlab.ui.container.Panel
        
        ScrollBar images.internal.app.utilities.ScrollBar
                
        Entries
                
    end
    
    
    methods (Abstract, Access = protected)
        
        evt = packageEntrySelectedEventData(self);
        entry = createEntry(self,varargin);
        reorderRequired = updateEntryData(self,varargin);
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Entry Panel
        %------------------------------------------------------------------
        function self = EntryPanel(hparent,pos, options)

            arguments
                hparent
                pos (1,4) double

                options.UseHeader (1,1) logical = false;
            end

            self.UseHeader = options.UseHeader;
            
            createPanel(self,hparent,pos);
            createScrollBar(self,hparent,pos);            
            
        end
        
        %------------------------------------------------------------------
        % Add
        %------------------------------------------------------------------
        function add(self,varargin)
            
            addToEntryList(self,varargin{:});
            
            pos = self.Panel.Position;
            update(self.ScrollBar,[pos(2),pos(2) + pos(4)]);
            
            updateCurrentSelection(self,numel(self.Entries));
            
            self.ScrollBar.Enabled = true;
            
        end

        %------------------------------------------------------------------
        % Add
        %------------------------------------------------------------------
        function remove(self, idx)

            if idx < numel(self.Entries)
                delete(self.Entries(idx));
                self.Entries(idx) = [];
            end

            if idx > numel(self.Entries)
                updateCurrentSelection(self,numel(self.Entries));
            end
            
            pos = self.Panel.Position;
            pixelsUsed = self.EntryHeight*numel(self.Entries);
            parentPosition = self.Panel.Parent.InnerPosition;
            pixelsAllowed = getPixelsAllowed(self,parentPosition);

            if pixelsAllowed > pixelsUsed
                % We currently have enough room in our panel without
                % needing to add scrolling
                pos(2) = pixelsAllowed - pixelsUsed + 1;
            else
                % We don't have enough room to show all the entries
                pos(2) = 1;
            end

            pos(4) = self.EntryHeight*(numel(self.Entries) + 1);
            
            if pos(3) < 1
                pos(3) = 1;
            end
            
            if pos(4) < 1
                pos(4) = 1;
            end

            reorderEntries(self,1);
            
            self.Panel.Position = pos;

        end
        
        %------------------------------------------------------------------
        % Update
        %------------------------------------------------------------------
        function update(self,selectedIndex,varargin)
            
            if isempty(varargin{1})
                clear(self);
                return;
            end
                                    
            reorderRequired = updateEntryData(self,varargin{:});
            
            if reorderRequired
                
                pixelsUsed = self.EntryHeight*numel(self.Entries);
                parentPosition = self.Panel.Parent.InnerPosition;
                pixelsAllowed = getPixelsAllowed(self,parentPosition);
                
                pos = self.Panel.Position;
                
                if pixelsAllowed > pixelsUsed
                    % We currently have enough room in our panel without
                    % needing to add scrolling
                    pos(2) = pixelsAllowed - pixelsUsed + 1;
                else
                    % We don't have enough room to show all the entries
                    pos(2) = 1;
                end
                
                reorderEntries(self,1);
                
                pos(4) = self.EntryHeight*(numel(self.Entries));
                
                if pos(3) < 1
                    pos(3) = 1;
                end
                
                if pos(4) < 1
                    pos(4) = 1;
                end
                
                self.Panel.Position = pos;
                
            end
            
            if selectedIndex > 0
                updateCurrentSelection(self,selectedIndex);
            end
            
            entryClicked(self,self.Entries(self.Current));
            
            if ~isempty(self.Entries)
                self.ScrollBar.Enabled = true;
                pos = self.Panel.Position;
                update(self.ScrollBar,[pos(2),pos(2) + pos(4)]);
            end
            
        end
        
        %------------------------------------------------------------------
        % Scroll
        %------------------------------------------------------------------
        function scroll(self,scrollCount)
            
            % Positive scroll count is down (at least on my pc, not sure
            % about mac)
            
            pixelsUsed = self.EntryHeight*numel(self.Entries);
            parentPosition = self.Panel.Parent.InnerPosition;
            pixelsAllowed = getPixelsAllowed(self,parentPosition);
            pos = self.Panel.Position;
            
            if pixelsAllowed > pixelsUsed + 1
                % We currently have enough room in our panel without
                % needing to add scrolling
                return;
            end
            
            if scrollCount > 0
                val = moveDown(self,abs(scrollCount));
            else
                val = moveUp(self,abs(scrollCount),pixelsAllowed);
            end
            
            if val == 0
                return;
            end
            
            pos(2) = pos(2) + val;
            self.Panel.Position = pos;
            
            if ~isempty(self.Entries)
                update(self.ScrollBar,[pos(2),pos(2) + pos(4)]);
            end
            
        end
        
        %------------------------------------------------------------------
        % Up
        %------------------------------------------------------------------
        function up(self)
            
            if self.Current > 1
                
                updateCurrentSelection(self,self.Current - 1);
                snapCurrentSelectionIntoView(self);
                
            end
            
        end
        
        %------------------------------------------------------------------
        % Down
        %------------------------------------------------------------------
        function down(self)
            
            if self.Current < numel(self.Entries)
                
                updateCurrentSelection(self,self.Current + 1);
                snapCurrentSelectionIntoView(self);
                
            end
            
        end
        
        %------------------------------------------------------------------
        % Bottom
        %------------------------------------------------------------------
        function bottom(self)
            
            if numel(self.Entries) > 0
                
                updateCurrentSelection(self,numel(self.Entries));
                snapCurrentSelectionIntoView(self);
                
            end
            
        end
        
        %------------------------------------------------------------------
        % Top
        %------------------------------------------------------------------
        function top(self)
            
            if numel(self.Entries) > 0
                
                updateCurrentSelection(self,1);
                snapCurrentSelectionIntoView(self);
                
            end
            
        end
        
        %------------------------------------------------------------------
        % Resize
        %------------------------------------------------------------------
        function resize(self,pos)
            
            headerpos = pos;
            
            pos(4) = getPixelsAllowed(self,pos);
            pos(3) = pos(3) - self.ScrollBarWidth;
            
            if any(pos < 1)
                return;
            end
            
            if self.UseHeader
                resizeHeader(self,headerpos);
            end
            
            scrollbarPosition = [pos(3) + 1, pos(2), self.ScrollBarWidth, pos(4)];
            resize(self.ScrollBar,scrollbarPosition);
            
            positionEntries(self,pos);
            
        end
        
        %------------------------------------------------------------------
        % Clear
        %------------------------------------------------------------------
        function clear(self)
            
            self.Current = 0;
            delete(self.Entries);
            self.Entries = [];
            clear(self.ScrollBar);
            
        end
        
        %------------------------------------------------------------------
        % Disable
        %------------------------------------------------------------------
        function disable(self)
            
            for idx = 1:numel(self.Entries)
                disable(self.Entries(idx));
            end
            
        end
        
        %------------------------------------------------------------------
        % Enable
        %------------------------------------------------------------------
        function enable(self)
                        
            for idx = 1:numel(self.Entries)
                enable(self.Entries(idx));
            end
            
        end
        
    end
    
    
    methods (Access = protected)
        
        %--Resize Header---------------------------------------------------
        function resizeHeader(self,pos)
            pos(2) = pos(4) - self.HeaderHeight + 1;
            pos(4) = self.HeaderHeight;
            
            self.Header.Position = pos;
        end
        
        %--Get Pixels Allowed----------------------------------------------
        function pixelsAllowed = getPixelsAllowed(self,pos)
            if self.UseHeader
                pixelsAllowed = pos(4) - self.HeaderHeight;
            else
                pixelsAllowed = pos(4);
            end
        end
        
        %--Entry Clicked---------------------------------------------------
        function entryClicked(self,src)
            
            idx = find(self.Entries == src);
            
            if ~isempty(idx)
                updateCurrentSelection(self,idx);
            end
            
        end
        
        %--Entry Removed---------------------------------------------------
        function entryRemoved(self,evt)
            
            notify(self,'EntryRemoved',evt);
            
        end
        
        %--Add To Entry List-----------------------------------------------
        function addToEntryList(self,varargin)
            
            newEntry = createEntry(self,varargin{:});
            self.Entries = [self.Entries; newEntry];
            
        end
        
        %--Get Next Location-----------------------------------------------
        function y = getNextLocation(self)
            
            pixelsUsed = self.EntryHeight*numel(self.Entries);
            parentPosition = self.Panel.Parent.InnerPosition;
            pixelsAllowed = getPixelsAllowed(self,parentPosition);
            
            pos = self.Panel.Position;
            
            if pixelsAllowed > pixelsUsed + self.EntryHeight
                % We currently have enough room in our panel without
                % needing to add scrolling
                pos(2) = pixelsAllowed - pixelsUsed - self.EntryHeight + 1;
            else
                % We don't have enough room to show all the entries
                pos(2) = 1;
            end
            
            reorderEntries(self,self.EntryHeight + 1);
            
            pos(4) = self.EntryHeight*(numel(self.Entries) + 1);
            y = 1;
            
            if pos(3) < 1
                pos(3) = 1;
            end
            
            if pos(4) < 1
                pos(4) = 1;
            end
            
            self.Panel.Position = pos;
            
        end
        
        %--Reorder Entries-------------------------------------------------
        function reorderEntries(self,y)
            
            for idx = numel(self.Entries) : -1 : 1
                self.Entries(idx).Y = y;
                y = y + self.EntryHeight;
            end
            
            if ~isempty(self.Entries)
                pos = self.Panel.Position;
                update(self.ScrollBar,[pos(2),pos(2) + pos(4)]);
            end
            
        end
        
        %--Position Entries------------------------------------------------
        function positionEntries(self,pos)
            
            pixelsUsed = self.EntryHeight*numel(self.Entries);
            pixelsAllowed = pos(4);
            
            pos(2) = pixelsAllowed - pixelsUsed + 1;
            pos(4) = self.EntryHeight*numel(self.Entries);
            
            if pos(3) < 1
                pos(3) = 1;
            end
            
            if pos(4) < 1
                pos(4) = 1;
            end
            
            self.Panel.Position = pos;
            
            % Is a call to reorder entries required here?
            
            set(self.Entries,'Width',pos(3));
            
            if ~isempty(self.Entries)
                update(self.ScrollBar,[pos(2),pos(2) + pos(4)]);
            end
            
        end
        
        %--Move Up---------------------------------------------------------
        function val = moveUp(self,mag,pixelsAllowed)
            
            pos = self.Panel.Position;
            
            y = pos(2) + pos(4);
            
            if y < pixelsAllowed + 1
                % This shouldn't happen where the height of the first
                % is below the first entry location
                %positionEntries(self,self.Panel.Position);
                val = 0;
                
            elseif y == pixelsAllowed + 1
                val = 0;
                
            elseif y <= pixelsAllowed + (mag*self.EntryHeight) + 1
                val = pixelsAllowed + 1 - y;
                
            else
                val = -(mag*self.EntryHeight);
                
            end
            
        end
        
        %--Move Down-------------------------------------------------------
        function val = moveDown(self,mag)
            
            y = self.Panel.Position(2);
            
            if y > 1
                % This shouldn't happen where the height of the last
                % is above the bottom of the panel
                %positionEntries(self,self.Panel.Position);
                val = 0;
                
            elseif y == 1
                val = 0;
                
            elseif y >= 1 - (mag*self.EntryHeight)
                val = 1 - y;
            else
                val = (mag*self.EntryHeight);
            end
            
        end
        
        %--Snap Current Selection Into View--------------------------------
        function snapCurrentSelectionIntoView(self)
            
            pixelsUsed = self.EntryHeight*numel(self.Entries);
            parentPosition = self.Panel.Parent.InnerPosition;
            pixelsAllowed = getPixelsAllowed(self,parentPosition);
            pos = self.Panel.Position;
            
            if pixelsAllowed > pixelsUsed + 1
                % We currently have enough room in our panel. Nothing more
                % needs to be done
                return;
            end
            
            entry = self.Entries(self.Current);
            
            y = entry.Y + pos(2);
            
            if y >= 1 && y <= pixelsAllowed - self.EntryHeight + 1
                % The selected entry is already in the field of view,
                % even if other entries are not
                return;
            end
            
            % Handle error conditions where the top or bottom entry is
            % already at the edge. We shouldn't hit these but let's check
            % just to be safe.
            if self.Current == 1 && y < pixelsAllowed - self.EntryHeight + 1
                return;
            end
            
            if self.Current == numel(self.Entries) && y > 1
                return;
            end
            
            if y < 1
                % We need to shift everything up to make the selected entry
                % visible
                val = 1 - y;
            else
                % We need to shift everything down to make the selected
                % entry visible
                val = (pixelsAllowed - self.EntryHeight + 1) - y;
            end
            
            if val == 0
                return;
            end
            
            pos(2) = pos(2) + val;
            self.Panel.Position = pos;
            
            if ~isempty(self.Entries)
                update(self.ScrollBar,[pos(2),pos(2) + pos(4)]);
            end
            
        end
        
        %--Update Current Selection----------------------------------------
        function updateCurrentSelection(self,idx)
            
            if self.Current ~= idx
                
                if self.Current > 0 && self.Current ~= idx && self.Current <= numel(self.Entries)
                    self.Entries(self.Current).Selected = false;
                end
                
                if self.Current > 0 && self.Current ~= idx && self.Current <= numel(self.Entries)
                    deactivate(self.Entries(self.Current));
                end
                
                self.PreviousSelection = self.Current;
                self.Current = idx;
                
                self.Entries(self.Current).Selected = true;
                
                % TODO - it is not necessary to broadcast this event when a
                % new label is added. Maybe refactor to save an extra
                % traversal through the controller
                self.notify('EntrySelected',packageEntrySelectedEventData(self));
                
            end
            
        end
        
        function dragScrollBar(self,currentPoint,originalPoint,scrollBarLimits,scrollBarExtents)
            
            % TODO - We need to wait for g2364438 to be fixed before we can
            % wire this up.
            
        end
        
        %--Create Panel----------------------------------------------------
        function createPanel(self,hparent,pos)
            
            pos(4) = getPixelsAllowed(self,pos);
            pos(3) = pos(3) - self.ScrollBarWidth;
            
            self.Panel = uipanel('Parent',hparent,...
                'BorderType','none',...
                'Units','pixels',...
                'HandleVisibility','off',...
                'Position',pos,...
                'Tag','EntryPanel',...
                'AutoResizeChildren','off');
                        
        end
        
        %--Create Scroll Bar-----------------------------------------------
        function createScrollBar(self,hparent,pos)
            
            scrollbarPosition = [pos(3) + 1, pos(2), self.ScrollBarWidth, pos(4)];
            
            self.ScrollBar = images.internal.app.utilities.ScrollBar(hparent,scrollbarPosition);
            addlistener(self.ScrollBar,'ScrollBarDragged',@(src,evt) dragScrollBar(self,evt.CurrentPoint,evt.OriginalPoint,evt.ScrollBarLimits,evt.ScrollBarExtents));
            
        end
        
    end
    
    % Set/Get
    methods

        function set.HeaderHeight(self, height)
            self.HeaderHeight = height;
        end

    end
    
end
