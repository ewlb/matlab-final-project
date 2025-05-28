classdef View < handle
    %
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    events
        
        % Display Refreshed - Event fires when the View is requesting a
        % complete data refresh for every entry in the current display
        % range. No file IO should occur in the callback to this event.
        DisplayRefreshed
        
        % Entry Refreshed - Event fires when the View is requesting a data
        % refresh for a single entry in the display range. This is done in
        % a breakable for loop to allow to file IO to occur if needed for a
        % given entry.
        EntryRefreshed
        
        % File IO Requsted - Event fires when the View is asking if any
        % file IO would be required for the entries in the current display
        % range. If true, the listener to this event should call
        % updateIndividialEntries(self) on the View to begin the process of
        % file IO in a for loop.
        FileIORequested
        
        % Selection Changed - Event fires when user interactively clicks on
        % any entry to signal that the selection needs to be updated.
        SelectionChanged
        
        % Entry Read Started - Event fires when the View begins the process
        % of file IO in a loop. If no file IO is required, this event will
        % not fire. If file IO is required for multiple entries, this event
        % will fire only once. Use this event to disable other components
        % or display a wait bar when you know the file IO may take a long
        % time.
        EntryReadStarted
        
        % Entry Read Finished - Event fires when the View completes the
        % file IO loop or the file IO loop is interactively broken by user
        % interaction. Use this event to clean up any actions or state
        % change from callbacks to EntryReadStarted.
        EntryReadFinished
        
    end
    
    
    properties (Dependent)
        
        % Layout - "auto" | "row" | "column"
        Layout
        
        % Enabled - true | false
        Enabled
        
        % Selected Color - [0.349 0.667 0.847] | RGB triplet
        SelectedColor

        % Hot Selected Color - [0.592 0.792 0.906] | RGB triplet
        HotSelectedColor
        
        % Background Color - [0.94 0.94 0.94] | RGB triplet
        BackgroundColor
        
        % Entry Size - [100 100] | 1-by-2 positive integer
        EntrySize
        
        % Context Menu - uicontextmenu object
        ContextMenu
        
        % Label Visible - false | true
        LabelVisible
        
        % Label Location - "bottom" | "right" | "overlay"
        LabelLocation

        % Label Text Color - [0 0 0] | RGB Triplet
        LabelTextColor

        % Badge Location - "southwest" | "northeast" | "northwest" | "southeast"
        BadgeLocation

        % Highlight On Hover - true | false
        HighlightOnHover

        % Thumbnail Color Style - "uniform" | "individual"
        ThumbnailColorStyle
        
    end
    
    
    properties (Dependent, SetAccess = private)
        
        % NumColumns - Number of columns visible in viewport.
        NumColumns
        
        % NumVisibleRows - Number of rows visible in viewport.
        NumVisibleRows
        
    end
    
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private, Transient)
        
        % Entries - Array of entries that contain HG display objects. These
        % entries will be shuffled and reused for display as the user
        % interacts with the View
        Entries
        
        % Panel - Parent panel for the View. The axes will be placed inside
        % this panel.
        Panel matlab.ui.container.Panel
        
        % Axes - axes that contains all HG objects from the Entries.
        Axes
        
        % Scroll Bar - Scrollbar object to control vertical scrolling for
        % "auto" and "column" layouts
        ScrollBar
        
        % Slider - Slider object to control horizontal scrolling for "row"
        % layout
        Slider
        
        CharacterScaleFactor (1,1) double = 7.7;
        
    end
    
    
    properties (Access = private)
        
        % Timer to control scroll coalescing
        ScrollTimer images.internal.app.utilities.eventCoalescer.Periodic
        
        % Timer to control resize coalescing
        ResizeTimer images.internal.app.utilities.eventCoalescer.Delayed
        
        % Timer to control when the view has settled after scrolling to
        % begin file IO is necessary
        DelayTimer images.internal.app.utilities.eventCoalescer.Delayed
        
        % Properties to store coalesced data
        CachedPosition (1,4) double
        ScrollCount (1,1) double = 0;
        
        % Internal properties controlling Entry view properties
        SelectedColorInternal (1,3) double = [0.349 0.667 0.847];
        HotSelectedColorInternal (1,3) double = [0.592 0.792 0.906];
        EdgeColorInternal (1,3) double = [0, 0.251, 0.451];
        EnabledInternal (1,1) logical = true;
        LayoutInternal (1,1) string {mustBeMember(LayoutInternal,["auto","row","column"])} = "auto";
        LabelLocationInternal (1,1) string {mustBeMember(LabelLocationInternal,["bottom","right","overlay"])} = "bottom";
        LabelTextColorInternal (1,3) double = [0 0 0];
        LabelTextColorMode matlab.internal.datatype.matlab.graphics.datatype.AutoManual = "auto";
        BadgeLocationInternal (1,1) string {mustBeMember(BadgeLocationInternal, ["northwest", "northeast", "southwest", "southeast"])} = "southwest";
        EntrySizeInternal (1,2) double {mustBePositive} = [100 100];
        ThumbnailColorStyleInternal (1,1) string = "uniform";
        
        % Total number of entries loading into object. Not all entries may
        % be displayed at all times
        TotalNumEntries (1,1) double = 0;
        
        % Display range of the current viewport. The min value is 1 and the
        % max number if equal to TotalNumEntries
        DisplayRange (1,2) double = [0 0];
        
        % Cosntants to control slider/scrollbar placement
        ScrollBarWidth (1,1) double {mustBePositive} = 10;
        SliderHeight (1,1) double {mustBePositive} = 20;
        
        % Cached location during click/drag
        PreviousMouseLocation double = [];
        
        % Default context menu objects
        ContextMenuInternal (1,1) matlab.ui.container.ContextMenu
        
        % Properties to control if corresponding context menu item is
        % visible
        RemovableInternal (1,1) logical = true;
        RotatableInternal (1,1) logical = false;
        ExportableInternal (1,1) logical = false;
        
        % Property to control if the text laber is visible
        LabelVisibleInternal (1,1) logical = false;
        
        % Event listener for hover highlight
        HighlightOnHoverInternal (1,1) logical = true;
        HoverListener event.listener
        LastHitObject
        
        % Property to control when the user is interactively
        % scrolling/dragging. When true, we abandon any attempt at file IO
        IsScrollingOrResizing (1,1) logical = false;
        
        HotSelection
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % View
        %------------------------------------------------------------------
        function self = View(hparent,pos)
            % VIEW(HPARENT,POS) constructs the View object inside the
            % uipanel or figure HPARENT positioned inside the parent
            % container based on the position value in POS.
            assert(isa(hparent,'matlab.ui.Figure') || isa(hparent,'matlab.ui.container.Panel'),'Parent container must be a figure or uipanel.')
            
            if isa(getCanvas(hparent),'matlab.graphics.primitive.canvas.HTMLCanvas')
                assert(~hparent.Scrollable,'Parent container must have Scrollable turned off.');
                assert(~hparent.AutoResizeChildren,'Parent container must have AutoResizeChildren turned off.');
            end
            
            assert(strcmp(hparent.Units,'pixels'),'Parent container must be in pixel units.');
            
            % Construct HG objects
            createPanel(self,hparent,pos);
            createScrollBar(self,hparent,pos);
            self.ContextMenuInternal = uicontextmenu('Parent',ancestor(hparent,'figure'));
            
            % Wire up listeners for coalescing scroll and resize events
            self.ScrollTimer = images.internal.app.utilities.eventCoalescer.Periodic();
            self.ScrollTimer.ExecutionMode = 'fixedSpacing';
            self.ScrollTimer.Period = 0.1;
            self.ResizeTimer = images.internal.app.utilities.eventCoalescer.Delayed();
            self.ResizeTimer.Delay = 0.5;
            addlistener(self.ResizeTimer, 'DelayedEventTriggered', @(~,~) resizeOnDelay(self));
            addlistener(self.ScrollTimer, 'PeriodicEventTriggered', @(~,~) scrollOnDelay(self));
            
            % Wire up listener to wait until the view has settled before
            % attempting any file IO for unread entries
            self.DelayTimer = images.internal.app.utilities.eventCoalescer.Delayed();
            self.DelayTimer.Delay = 0.4;
            addlistener(self.DelayTimer, 'DelayedEventTriggered', @(~,~) notify(self,'FileIORequested',images.internal.app.browser.events.DisplayRefreshedEventData(self.DisplayRange)));
            
            % Wire up listener for interactive highlighting on hover
            self.HoverListener = event.listener(ancestor(hparent,'figure'),'WindowMouseMotion',@(src,evt) hoverOverEntry(self,evt));
            
        end
        
        %------------------------------------------------------------------
        % Update
        %------------------------------------------------------------------
        function update(self,entries,TF,hotSelection)
            % UPDATE(OBJ,ENTRIES,TF) updates the View entry objects with the
            % Label, Image, and Badge properties in the corresponding
            % ENTRIES. This is intended to be a rapid update of every
            % entry within view.
            
            for idx = 1:numel(entries)
                if self.ThumbnailColorStyle == "individual"
                    set(self.Entries(idx),'SelectedColor',get(entries(idx),'Color'),'HotSelectedColor',get(entries(idx),'Color'));
                end
                set(self.Entries(idx),'Label',get(entries(idx),'Label'),'Image',get(entries(idx),'Image'),'Badge',get(entries(idx),'Badge'));
                self.Entries(idx).Selected = TF(idx);
            end
            
            % Turn on the hot selection for the entry that corresponds to
            % the hotSelection, but only if it is within the display range.
            % If the entry would fall outside the display range, we don't
            % need to do anything.
            if ~isempty(hotSelection) && hotSelection >= self.DisplayRange(1) && hotSelection <= self.DisplayRange(2)
                self.Entries(hotSelection - self.DisplayRange(1) + 1).HotSelected = true;
            end

            % Make sure entries are visible
            set(self.Entries(1:numel(entries)),'Visible',true);
            
            n = getMaxNumEntriesInViewport(self);
            
            % If not all entries are used, turn off visibility in any
            % unused entry
            if numel(entries) < n
                set(self.Entries(numel(entries) + 1:n),'Visible',false);
            end
            
        end
        
        %------------------------------------------------------------------
        % Scroll
        %------------------------------------------------------------------
        function scroll(self,scrollCount)
            % SCROLL(OBJ,scrollCount) scrolls up or down based on the value
            % of scrollCount. To wire this up, use this method as a
            % callback to the WindowScrollWheel event and pass
            % evt.VerticalScrollCount as the input argument.
            
            if ~isvalid(self) || ~isvalid(self.Panel) || ~self.EnabledInternal
                return;
            end
            
            % Scrolling can be called from click/drag on scrollbar or with
            % scroll wheel events. We need to explicitly set this property
            % here to interrupt the file IO loop in updateIndividualEntries
            % if applicable.
            self.IsScrollingOrResizing = true;
            
            % Cache the scroll count. If the scroll count is Inf, adding
            % -Inf could result in a NaN. To guard against this if the
            % scroll count is infinite, use that value as the cached scroll
            % count.
            if isinf(scrollCount)
                self.ScrollCount = scrollCount;
            else
                self.ScrollCount = self.ScrollCount + scrollCount;
            end
            
            % Trigger the timer to fire periodically to reduce the number
            % of times we reposition the entries during scroll
            trigger(self.ScrollTimer);
        end
        
        %------------------------------------------------------------------
        % Up
        %------------------------------------------------------------------
        function up(self)
            % UP(OBJ) moves the view up one row. For "row" layout, this
            % moves to the left one entry.
            scroll(self,-1);
            
        end
        
        %------------------------------------------------------------------
        % Down
        %------------------------------------------------------------------
        function down(self)
            % DOWN(OBJ) moves the view down one row. For "row" layout, this
            % moves to the right one entry.
            scroll(self,1);
            
        end
        
        %------------------------------------------------------------------
        % Page Up
        %------------------------------------------------------------------
        function pageUp(self)
            % PAGEUP(OBJ) moves the view up one page, equalling the number
            % of entries that are visible in the current view.
            n = getMaxNumEntriesInViewport(self);
            col = getNumColumns(self);
            
            scroll(self,-n/col);
            
        end
        
        %------------------------------------------------------------------
        % Page Down
        %------------------------------------------------------------------
        function pageDown(self)
            % PAGEDOWN(OBJ) moves the view down one page, equalling the
            % number of entries that are visible in the current view.
            n = getMaxNumEntriesInViewport(self);
            col = getNumColumns(self);
            
            scroll(self,n/col);
            
        end
        
        %------------------------------------------------------------------
        % Bottom
        %------------------------------------------------------------------
        function bottom(self)
            % BOTTOM(OBJ) moves the view to the bottom of the entries
            scroll(self,Inf);

        end
        
        %------------------------------------------------------------------
        % Top
        %------------------------------------------------------------------
        function top(self)
            % TOP(OBJ) moves the view to the top of the entries
            scroll(self,-Inf);
            
        end
        
        %------------------------------------------------------------------
        % Resize
        %------------------------------------------------------------------
        function resize(self,pos)
            % RESIZE(OBJ,POS) resizes the View to fit in the parent
            % container according to position POS. This method should be in
            % a callback from the parent figure's SizeChangedFcn.
            
            if ~isvalid(self) || ~isvalid(self.Panel)
                return;
            end
            
            self.IsScrollingOrResizing = true;
            
            % Store the position and trigger a timer. We won't actually
            % reposition everything until 0.5 seconds has passed since this
            % timer was last triggered. This is done to speed up
            % interactive resizing behavior.
            self.CachedPosition = pos;
            trigger(self.ResizeTimer);
            
        end
        
        %------------------------------------------------------------------
        % Clear
        %------------------------------------------------------------------
        function clear(self)
            % CLEAR(OBJ) clears the display without deleting objects. Use
            % this method to clear the display before resetting with new
            % entries.
            set(self.Entries,'Visible',false);
            self.TotalNumEntries = 0;
            self.DisplayRange = [0 0];
            
            if self.LayoutInternal == "row"
                self.Slider.Visible = false;
                self.Slider.Enabled = false;
            else
                self.ScrollBar.Enabled = false;
            end
        end
        
        %------------------------------------------------------------------
        % Delete
        %------------------------------------------------------------------
        function delete(self)
            % DELETE(OBJ) cleans up timer objects
            delete(self.ScrollTimer);
            delete(self.ResizeTimer);
            delete(self.DelayTimer);
            delete(self.Panel);
            delete(self.ScrollBar);
            delete(self.Slider);
        end
        
        %------------------------------------------------------------------
        % Add Entries
        %------------------------------------------------------------------
        function addEntries(self,n)
            % ADDENTRIES(OBJ,N) updates the display to account for a new
            % total number of entries. The refresh call will request an
            % update for the entry display.
            previousNumEntries = self.TotalNumEntries;
            self.TotalNumEntries = n;
            
            % Snap to the top if no entries had been added already.
            if previousNumEntries == 0
                refresh(self,"top");
            else
                refresh(self,"bottom");
            end
            
        end
        
        %------------------------------------------------------------------
        % Remove Entries
        %------------------------------------------------------------------
        function removeEntries(self,n,removedIndices)
            % REMOVEENTRIES(OBJ,n,removedIndices) removes indices from the
            % display range and determines the best new display range to
            % request as an update.
            index = (1:self.TotalNumEntries)';
            index(removedIndices) = [];
            
            self.TotalNumEntries = n;
            
            n = getMaxNumEntriesInViewport(self);
            col = getNumColumns(self);
            
            % We need to find the new display range that makes the most
            % sense to users that just deleted entries.
            
            if self.TotalNumEntries <= n
                % Case where we have enough space to view all entries
                refresh(self,"top");
            else
                if any(removedIndices < self.DisplayRange(1))
                    if any(removedIndices > self.DisplayRange(2))
                        % Case where entries both above and below the
                        % display range are removed.
                        
                        % We can be smarter here, but for now just snap the
                        % view back to the top
                        refresh(self,"top");
                    else
                        % Case where entries above the current range are
                        % removed. Find the first index that was in view
                        % that hasn't been deleted and keep it roughly
                        % where it was. For multicolumn layouts, we need to
                        % ensure the last index in each row is a multiple
                        % of the number of columns.
                        anchorEntry = find(index >= self.DisplayRange(1),1);
                        
                        % Adjust the index to snap to the first entry in the
                        % row for multi columns.
                        remainder = mod(anchorEntry,col);
                        if remainder == 0
                            remainder = col;
                        end
                        anchorEntry = anchorEntry - (remainder - 1);
                        
                        if anchorEntry + n - 1 >= self.TotalNumEntries
                            % Case where there are not enough entries below the
                            % anchor point. We just need to snap to the bottom.
                            snapToBottom(self);
                        else
                            range(1) = anchorEntry;
                            
                            range(2) = range(1) + n - 1;
                            requestEntryRefresh(self,range(1),range(2));
                        end
                    end
                else
                    % Case where only entries below the current range are
                    % removed. Find the last index that was in view that
                    % hasn't been deleted and keep that one where it is,
                    % bringing all entries below it up.
                    anchorEntry = find(index >= self.DisplayRange(1),1);
                    if anchorEntry + n - 1 >= self.TotalNumEntries
                        % Case where there are not enough entries below the
                        % anchor point. We just need to snap to the bottom.
                        snapToBottom(self);
                    else
                        range(1) = anchorEntry;
                        
                        range(2) = range(1) + n - 1;
                        requestEntryRefresh(self,range(1),range(2));
                    end
                end
            end
            
        end
        
        %------------------------------------------------------------------
        % Refresh Selection
        %------------------------------------------------------------------
        function refreshSelection(self,displayInd,hotSelection)
            % REFRESHSELECTION(OBJ,displayInd) updates the selection of the
            % entries within view.
            
            if ~isvalid(self) || ~isvalid(self.Panel)
                return;
            end
            
            TF = false(1, self.TotalNumEntries);
            TF(displayInd) = true;
            TF = TF(self.DisplayRange(1):self.DisplayRange(2));
            for idx = 1:numel(TF)
                self.Entries(idx).Selected = TF(idx);
            end

            if ~isempty(hotSelection) && hotSelection >= self.DisplayRange(1) && hotSelection <= self.DisplayRange(2)
                self.Entries(hotSelection - self.DisplayRange(1) + 1).HotSelected = true;
            end
            
        end
        
        %------------------------------------------------------------------
        % Refresh Individual Entry
        %------------------------------------------------------------------
        function refreshIndividualEntry(self,dataEntry,idx)
            % REFRESHINDIVIDUALENTRY(OBJ,dataEntry,idx) sets the Label,
            % Image, and Badge for the entry specified by idx. This method
            % is intended to be called in a loop when the view has time to
            % allow for new file IO.
            
            % If the object is deleted or the user is currently scrolling,
            % abandon the update.
            if ~isvalid(self) || ~isvalid(self.Panel) || self.IsScrollingOrResizing
                return;
            end
            
            % Take the index and find the corresponding entry in the array
            entryIdx = idx - self.DisplayRange(1) + 1;

            if self.ThumbnailColorStyle == "individual"
                set(self.Entries(entryIdx),'SelectedColor',get(dataEntry,'Color'),'HotSelectedColor',get(dataEntry,'Color'));
            end
            
            set(self.Entries(entryIdx),'Label',get(dataEntry,'Label'),'Image',get(dataEntry,'Image'),'Badge',get(dataEntry,'Badge'));

            % Call drawnow limitrate to allow other callbacks to also
            % fire during this loop. This allows the user to stop this file
            % IO loop if they begin scrolling to a new location in the view
            drawnow('limitrate');
            
        end
        
        %------------------------------------------------------------------
        % Trigger Refresh
        %------------------------------------------------------------------
        function triggerRefresh(self)
            requestEntryRefresh(self,self.DisplayRange(1),self.DisplayRange(2));
        end
        
        %------------------------------------------------------------------
        % Snap To Entry
        %------------------------------------------------------------------
        function snapToEntry(self,idx)
            % SNAPTOENTRY(OBJ,IDX) snaps the view to contain the entry
            % specified by IDX.
            
            n = getMaxNumEntriesInViewport(self);
            col = getNumColumns(self);
            
            % Find the best display range that contains idx
            if self.TotalNumEntries < n
                if doEntriesOverhangViewport(self)
                    % Handle case where all entries are visible but there
                    % is a small overhang on the top or the bottom edge.
                    % Identify which edge and reposition if the requested
                    % index is in the top or bottom row.
                    col = getNumColumns(self);
                    remainder = mod(self.TotalNumEntries,col);
                    if idx > self.TotalNumEntries - col + remainder
                        alignEntriesWithBottomEdgeOfViewport(self,false);
                    elseif idx <= col
                        alignEntriesWithTopEdgeOfViewport(self,false);
                    end
                else
                    % Case where all entries are already completely 
                    % visible. We are done.
                    alignEntriesWithTopEdgeOfViewport(self,false);
                end
                requestEntryRefresh(self,self.DisplayRange(1),self.DisplayRange(2));
            elseif idx >= self.DisplayRange(1) && idx <= self.DisplayRange(2)
                % Requested index is inside of our current viewport. We are
                % done.
                if idx - self.DisplayRange(1) < col
                    alignEntriesWithTopEdgeOfViewport(self,false);
                elseif self.DisplayRange(2) - idx < col
                    alignEntriesWithBottomEdgeOfViewport(self,false);
                end
                requestEntryRefresh(self,self.DisplayRange(1),self.DisplayRange(2));
            else
                % Requested index is outside of our current viewport
                if col > 1
                    % Adjust the index to snap to the first entry in the
                    % row for multi columns.
                    remainder = mod(idx,col);
                    if remainder == 0
                        remainder = col;
                    end
                    idx = idx - (remainder - 1);
                end
                
                if idx < self.DisplayRange(1)
                    % Case where requested index is above our current
                    % range.
                    range(1) = idx;
                    range(2) = range(1) + n - 1;
                    alignEntriesWithTopEdgeOfViewport(self,false);
                else
                    % Case where requested index is below our current
                    % range. If we are close to the total number of
                    % entries, let bottom handle the right positioning.
                    if idx + col > self.TotalNumEntries
                        snapToBottom(self);
                        return;
                    else
                        range(2) = idx + col - 1;
                        range(1) = range(2) - n + 1;
                        alignEntriesWithBottomEdgeOfViewport(self,false);
                    end
                end
                requestEntryRefresh(self,range(1),range(2));
            end
            
        end

        %--Snap To Bottom--------------------------------------------------
        function snapToBottom(self)
            % BOTTOM(OBJ) moves the view to the bottom of the entries
            
            if ~isvalid(self) || ~isvalid(self.Panel)
                return;
            end
            
            % Cancel any pending scroll events.
            self.ScrollCount = 0;
            
            n = getMaxNumEntriesInViewport(self);
            n = min(n, self.TotalNumEntries);
            alignEntriesWithBottomEdgeOfViewport(self,false);
            
            % For multicolumn layouts, the bottom row may only be partially
            % filled. Compute the remainder of the last row and reduce the
            % requested display range by that amount. For example, a 5x5
            % view with 27 entries will have only two entries in the last
            % row and 3 unused spots. We can't request the last 25 entries,
            % we need to account for the unused spots and request 22.
            col = getNumColumns(self);
            remainder = mod(self.TotalNumEntries,col);
            
            if remainder == 0 || self.TotalNumEntries < getMaxNumEntriesInViewport(self)
                % For single column layouts and cases when the total number
                % of entries is divisible by the number of columns, no
                % adjustment is needed.
                requestEntryRefresh(self,self.TotalNumEntries - n + 1,self.TotalNumEntries);
            else
                emptySlots = col - remainder;
                requestEntryRefresh(self,self.TotalNumEntries - n + emptySlots + 1,self.TotalNumEntries)
            end
        end
        
        %--Snap To Top-----------------------------------------------------
        function snapToTop(self)
            % TOP(OBJ) moves the view to the top of the entries
            
            if ~isvalid(self) || ~isvalid(self.Panel)
                return;
            end
            
            % Cancel any pending scroll events.
            self.ScrollCount = 0;
            
            % Request the first n entries that will fit into view
            n = getMaxNumEntriesInViewport(self);
            n = min(n, self.TotalNumEntries);
            alignEntriesWithTopEdgeOfViewport(self,false);
            requestEntryRefresh(self,1,n);
            
        end
        
        %-----------------------------------------------------------------
        % Update Individual Entries
        %-----------------------------------------------------------------
        function updateIndividualEntries(self)
            % This is an expensive operation. This will loop through each
            % entry one by one and request and individual update for each
            % entry from the Model. This allows the Model to do expensive
            % things like file IO at a time when further interaction is
            % blocked.
            
            % Set IsScrollingOrResizing to false. If the user begins scrolling while
            % this callback is executing, we will check the value of
            % IsScrollingOrResizing and break this loop.
            self.IsScrollingOrResizing = false;
            
            % Broadcast event to client that file IO has begun. Clients can
            % use this to block interaction for long running IO.
            notify(self,'EntryReadStarted');

            lastUpdatedHotSelection = self.HotSelection;
            
            for idx = self.DisplayRange(1) : self.DisplayRange(2)
                
                if ~isvalid(self) || ~isvalid(self.Panel) || self.IsScrollingOrResizing
                    break;
                end
                
                % Request an update for each entry individually. If file IO
                % is required, this is when it should be done.
                notify(self,'EntryRefreshed',images.internal.app.browser.events.EntryRefreshedEventData(idx));

                if isvalid(self) && ~isequal(lastUpdatedHotSelection, self.HotSelection)
                    % Selection changed while refreshing, ensure it is updated
                    % first before proceeding.
                    notify(self,'EntryRefreshed',images.internal.app.browser.events.EntryRefreshedEventData(self.HotSelection));
                    lastUpdatedHotSelection = self.HotSelection;
                end
            end
            
            if ~isvalid(self) || ~isvalid(self.Panel)
                return;
            end

            % Broadcast event to client that file IO has finished
            notify(self,'EntryReadFinished');
            
        end
        
        %-----------------------------------------------------------------
        % Hide Highlight
        %-----------------------------------------------------------------
        function hideHighlight(self)
            % HIDEHIGHLIGHT(OBJ) turns off the current highlight on
            % whatever object is currently highlighted. Use this if your
            % mouse has moved away from the browser and you want to turn
            % off any hover highlight that still remains on the browser.
            if ~isempty(self.LastHitObject)
                if isequal(self.LastHitObject.FaceColor,self.SelectedColorInternal) || ...
                        isequal(self.LastHitObject.FaceColor,self.HotSelectedColorInternal)
                    set(self.LastHitObject,'EdgeColor',self.EdgeColorInternal);
                else
                    set(self.LastHitObject,'EdgeColor','none');
                end
            end
            self.LastHitObject = [];
        end
        
    end
    
    
    methods (Access = private)
        
        %--Refresh---------------------------------------------------------
        function refresh(self,loc)
            % REFRESH(OBJ,LOC) refreshes the layout and positioning of the
            % view. This is called when the view is fundamentally changed
            % (e.g. position resized, layout changed) and we need to
            % reposition, possibly add entries, enable/disable scroll bars
            % etc.
            %
            % LOC can be one of three options:
            %
            % "top"     - We will snap to the top. This is best for the
            %             initial set up.
            %
            % "bottom"  - We will snap to the bottom of the view. This is
            %             best for adding entries when you already has
            %             entries and you want to show what was just added.
            %
            % "inplace" - We will try to keep as much of the current view
            %             in view as possible. This is best for things like
            %             resizing or thumbnail size changes.
            
            n = getMaxNumEntriesInViewport(self);
            
            if n > numel(self.Entries)
                % If we need more objects, construct them now.
                for idx = numel(self.Entries) + 1 : n
                    obj = images.internal.app.browser.display.Entry(self.Axes);
                    set(obj,'ContextMenu',self.ContextMenuInternal,'LabelVisible',self.LabelVisibleInternal,...
                        'SelectedColor',self.SelectedColorInternal,'LabelLocation',self.LabelLocationInternal,...
                        'CharacterScaleFactor',self.CharacterScaleFactor,'EntrySize',self.EntrySizeInternal,...
                        'BadgeLocation',self.BadgeLocationInternal,'HotSelectedColor',self.HotSelectedColorInternal);
                    if self.LabelTextColorMode == "manual"
                        set(obj,'LabelTextColor',self.LabelTextColorInternal);
                    end
                    addlistener(obj,'EntryClicked',@(src,evt) imageClicked(self,src));
                    self.Entries = [self.Entries; obj];
                end
            elseif n < numel(self.Entries)
                % Hide unneeded objects
                set(self.Entries(n + 1:end),'Visible',false);
            end
            
            if self.TotalNumEntries < n
                % Case where we have more entry containers available than
                % we need. Use some and turn the visibility off for others.
                set(self.Entries(self.TotalNumEntries + 1:end),'Visible',false);
                
                % Hide scrollbar or slider
                if self.LayoutInternal == "row"
                    self.Slider.Visible = false;
                    self.Slider.Enabled = false;
                else
                    self.ScrollBar.Enabled =  self.EnabledInternal;
                end
                alignEntriesWithTopEdgeOfViewport(self,true);
                requestEntryRefresh(self,1,self.TotalNumEntries);
                
            else
                % Show scrollbar or slider
                if self.LayoutInternal == "row"
                    % Check edge case where we have *exactly* enough space
                    % (down to the pixel) to show all entries. Don't show
                    % the slider in that case
                    if self.TotalNumEntries == self.Axes.Position(3)/self.EntrySizeInternal(1)
                        self.Slider.Visible = false;
                        self.Slider.Enabled = false;
                    else
                        self.Slider.Visible = true;
                        self.Slider.Enabled = self.EnabledInternal;
                    end
                else
                    self.ScrollBar.Enabled = self.EnabledInternal;
                end
                if loc == "top"
                    % We need to snap to the top after refresh
                    alignEntriesWithTopEdgeOfViewport(self,true);
                    snapToTop(self);
                elseif loc == "bottom"
                    % We need to snap to the bottom after refresh
                    alignEntriesWithBottomEdgeOfViewport(self,true);
                    snapToBottom(self);
                else
                    % Snap entries to top edge, but keep something
                    % from the current view in view
                    oldrange = self.DisplayRange;
                    
                    if oldrange(1) == 1
                        alignEntriesWithTopEdgeOfViewport(self,true);
                        snapToTop(self);
                    elseif oldrange(2) == self.TotalNumEntries
                        alignEntriesWithBottomEdgeOfViewport(self,true);
                        snapToBottom(self);
                    else
                        
                        col = getNumColumns(self);
                        
                        if col > 1
                            % Adjust the index to snap to the first entry in the
                            % row for multi columns. This keeps the rows
                            % consistent and the number of entries divisble
                            % by the number of columns
                            range(1) = oldrange(1) - round((n - (oldrange(2) - oldrange(1) + 1))/2);
                            range(2) = range(1) + n - 1;
                            
                            remainder = mod(range(1),col);
                            if remainder == 0
                                remainder = col;
                            end
                            range = range - (remainder - 1);
                            
                            if remainder > col/2
                                range = range + col;
                            end
                            
                        else
                            range(1) = oldrange(1) - round((n - (oldrange(2) - oldrange(1) + 1))/2);
                            range(2) = range(1) + n - 1;
                        end
                        
                        if range(1) <= 1
                            alignEntriesWithTopEdgeOfViewport(self,true);
                            snapToTop(self);
                        elseif range(2) + col > self.TotalNumEntries
                            alignEntriesWithBottomEdgeOfViewport(self,true);
                            snapToBottom(self);
                        else
                            alignEntriesWithTopEdgeOfViewport(self,true);
                            requestEntryRefresh(self,range(1),range(2));
                        end
                    end
                end
                
            end
            
        end
        
        %--Request Entry Refresh-------------------------------------------
        function requestEntryRefresh(self,minEntry,maxEntry)
            % Request entry refresh for the specified display range. This
            % gets called rapidly as users programmatically or
            % interactively move the view.
            
            if self.TotalNumEntries == 0
                return;
            end
            
            % Set IsScrollingOrResizing to true to interrupt the file IO loop if
            % needed.
            self.IsScrollingOrResizing = true;
            self.DisplayRange = [minEntry maxEntry];
            
            % Request updated information for the display range
            notify(self,'DisplayRefreshed',images.internal.app.browser.events.DisplayRefreshedEventData(self.DisplayRange));
            
            if ~isobject(self.LayoutInternal)
                return;
            end

            if self.LayoutInternal == "row"
                % Update the horizontal slider
                if self.Slider.Visible
                    n = getMaxNumEntriesInViewport(self);
                    if self.TotalNumEntries == n
                        % Check if we have overhang and if the overhang is
                        % at the top. If so, we want the current index of
                        % the slider to be at the max val, not 1.
                        if doEntriesOverhangViewport(self) && doEntriesOverhangTopEdgeOfViewport(self)
                            minEntry = 2;
                        else
                            minEntry = 1;
                        end
                        % Cases when the number of entries equals the
                        % number of entries we can fit in the viewport are
                        % special cases for the slider. Set the slider to
                        % have two steps to handle overhang on either side.
                        maxVal = 2;
                    else
                        maxVal = self.TotalNumEntries - getMaxNumEntriesInViewport(self) + 1;
                    end
                    update(self.Slider,minEntry,maxVal);
                end
                
            else
                % Update the vertical scrollbar
                viewportHeight = self.Axes.Position(4);
                totalHeight = ceil(self.TotalNumEntries/getNumColumns(self))*self.EntrySizeInternal(2);
                heightAboveView = ceil((self.DisplayRange(1)-1)/getNumColumns(self))*self.EntrySizeInternal(2);
                
                % Add viewport height and account for offset if the top row
                % is hanging over the edge of viewport
                range(2) = viewportHeight + (1 - self.Entries(1).Position(2)) + heightAboveView;
                range(1) = range(2) - totalHeight + 1;
                
                update(self.ScrollBar,range);
                
            end
            % Trigger timer. After a period of time without this timer
            % being triggered, this will kick off a check if any file IO
            % should be done on the new display range.
            trigger(self.DelayTimer);
            
        end
        
        %--Resize On Delay-------------------------------------------------
        function resizeOnDelay(self)
            % Callback for timer delayed resize. When resize is called, we
            % cache the position and start a timer. When the timer fires,
            % we need to grab the position and update the display
            
            if ~isvalid(self) || ~isvalid(self.Panel)
                return;
            end
            
            pos = self.CachedPosition;
            
            % Offset positioning based on if scrollbar or slider are used.
            if self.LayoutInternal == "row"
                n = pos(3)/self.EntrySizeInternal(1);
                if self.TotalNumEntries > n
                    % Slider is needed
                    h = self.SliderHeight;
                else
                    h = 0;
                end
                pos(4) = pos(4) - h;
                pos(2) = h + 1;
            else
                pos(3) = pos(3) - self.ScrollBarWidth;
            end
            
            % Check if the new size meets the minimum allowed size. If not
            % abandon reposition.
            if ~isempty(self.Entries)
                val = minimumSizeRequired(self.Entries(1));
            else
                val = max(self.EntrySizeInternal);
            end
            
            if pos(3) <= val || pos(4) <= val
                return;
            end
            
            % Set panel and axes position
            self.Panel.Position = pos;
            self.Axes.Position = [1 1 pos(3:4)];
            set(self.Axes,'XLim',[1 pos(3)],'YLim',[1 pos(4)]);
            drawnow;

            if ~isvalid(self) || ~isvalid(self.Panel)
                % Above drawnow during close might render this invalid.
                return;
            end
            
            % Resize slider and scrollbar
            if self.LayoutInternal == "row"
                sliderPosition = [pos(1), pos(2) - h, pos(3), self.SliderHeight];
                resize(self.Slider,sliderPosition);
            else
                scrollbarPosition = [pos(3) + 1, pos(2), self.ScrollBarWidth, pos(4)];
                resize(self.ScrollBar,scrollbarPosition);
            end
            
            refresh(self,"inplace");
            
        end
        
        %--Scroll On Delay-------------------------------------------------
        function scrollOnDelay(self)
            % Scrolling coalesces events to make a smooth/somewhat
            % responsive scrolling process. If the user scrolls rapidly, we
            % don't want to waste time rendering the intermediate views.
            % This gets called by a periodic timer for as long as
            % ScrollCount is not zero.
            
            if ~isvalid(self) || ~isvalid(self.Panel)
                return;
            end
            
            scrollCount = self.ScrollCount;
            
            % Stop the timer if our scroll count is finished.
            if scrollCount == 0
                stop(self.ScrollTimer);
                return;
            end
            
            % Don't scroll for partial entries with scrolling. This can
            % happen with click/drag motion. Wait until we have enough
            % scrolling to move one row.
            if abs(scrollCount) < 1
                return;
            end
            
            % Beyond this point we have committed to scrolling. No returns
            % should follow without a call to requestEntryRefresh and a
            % drawnow limitrate. This is what kicks off the file IO loop if
            % required.
            
            % Scale scroll count by the number of columns. This will
            % convert scrolling from view row units to display range units.
            col = getNumColumns(self);
            
            if round(scrollCount) ~= scrollCount
                newScrollCount = fix(scrollCount);
                self.ScrollCount = mod(scrollCount,newScrollCount);
                scrollCount = newScrollCount;
            else
                self.ScrollCount = 0;
            end
            
            scrollCount = scrollCount*col;
            
            n = getMaxNumEntriesInViewport(self);
            
            % Positive scroll count is down (at least on my pc)
            if scrollCount > 0
                
                if self.TotalNumEntries < n
                    if doEntriesOverhangViewport(self)
                        % Handle case where we are scrolling when all
                        % entries are visible but there is overhang on
                        % either to top or the bottom row of the view. In
                        % this case, scrolling down should shift entries to
                        % be bottom aligned.
                        snapToBottom(self);
                    else
                        snapToTop(self);
                    end
                elseif self.DisplayRange(2) + abs(scrollCount) < self.TotalNumEntries
                    alignEntriesWithBottomEdgeOfViewport(self,false);
                    newRange = self.DisplayRange + abs(scrollCount);
                    requestEntryRefresh(self,newRange(1),newRange(2));
                else
                    snapToBottom(self);
                end
                
            else
                
                if self.TotalNumEntries > n && self.DisplayRange(1) - abs(scrollCount) > 1
                    alignEntriesWithTopEdgeOfViewport(self,false);
                    newRange = self.DisplayRange - abs(scrollCount);
                    newRange(2) = newRange(1) + n - 1;
                    requestEntryRefresh(self,newRange(1),newRange(2));
                else
                    snapToTop(self);
                end
                
            end
            % Trigger graphics update
            drawnow('limitrate');
        end
        
        %--Drag Slider-----------------------------------------------------
        function dragSlider(self,currentVal,previousVal)
            % Slider uses the scroll API to handle motion, event coalescing
            scrollCount = currentVal - previousVal;
            scroll(self,scrollCount)
            
        end
        
        %--Drag Scroll Bar-------------------------------------------------
        function dragScrollBar(self,currentPoint,originalPoint,scrollBarLimits,scrollBarExtents)
            
            % Scroll bar works in pixel coordinates. Convert pixel
            % coordinate motion into entry coordinate motion.
            if isempty(self.PreviousMouseLocation)
                self.PreviousMouseLocation = originalPoint;
            end
            
            delta = (currentPoint - self.PreviousMouseLocation)/(scrollBarLimits(2)-(scrollBarExtents(2) - scrollBarExtents(1)));
            
            nRows = ceil(self.TotalNumEntries/getNumColumns(self));
            
            scrollCount = -(delta*nRows);
            
            % Use the scroll API to handle movement and event coalescing.
            scroll(self,scrollCount)
            
            self.PreviousMouseLocation = currentPoint;
            
        end
        
        %--Stop Dragging--------------------------------------------------
        function stopDragging(self)
            % Clean up after motion. Setting the ScrollCount to zero is an
            % important step in turning off the scroll timer.
            self.PreviousMouseLocation = [];
            self.ScrollCount = 0;
            % Trigger delay to kick off a check for any required file IO.
            trigger(self.DelayTimer);
        end
        
        %--Get Scroll Bar Height-------------------------------------------
        function val = getScrollBarHeight(self)
            if self.LayoutInternal == "row" && (isempty(self.Slider) || self.Slider.Visible)
                val = self.SliderHeight;
            else
                val = 0;
            end
        end
        
        %--Image Clicked---------------------------------------------------
        function imageClicked(self,src)
            % Callback for EntryClicked event on Entry. We are here because
            % the user clicked on an entry. Broadcast SelectionChanged
            % event.
            hfig = ancestor(self.Axes,'figure');
            
            clickType = images.roi.internal.getClickType(hfig);
            
            idx = find(src == self.Entries);
            hotSelection = self.DisplayRange(1) + idx - 1;
            
            notify(self,'SelectionChanged',images.internal.app.browser.events.SelectionChangedEventData(...
                clickType,hotSelection,self.DisplayRange));

            % Record current selection. This is used to check if we need to
            % async udpate the selected thumbnail while lazy loading the
            % current view port.
            self.HotSelection = hotSelection;
        end
        
        %--Hover Over Entry------------------------------------------------
        function hoverOverEntry(self,evt)
            % Callback for motion listener to highlight the entry under the
            % mouse currently.
            if isa(evt.HitObject,'matlab.graphics.primitive.Rectangle') && evt.HitObject.Parent == self.Axes
                % We hit an entry, hide the highlighting of the last hit
                % entry
                if ~isempty(self.LastHitObject)
                    if isequal(self.LastHitObject.FaceColor,self.SelectedColorInternal) || isequal(self.LastHitObject.FaceColor,self.HotSelectedColorInternal)
                        set(self.LastHitObject,'EdgeColor',self.EdgeColorInternal);
                    else
                        set(self.LastHitObject,'EdgeColor','none');
                    end
                end
                % Turn on the highlighting for the currently hit object
                if isequal(evt.HitObject.FaceColor,self.SelectedColorInternal) || isequal(evt.HitObject.FaceColor,self.HotSelectedColorInternal)
                    set(evt.HitObject,'EdgeColor',[0 0 0]);
                else
                    set(evt.HitObject,'EdgeColor',self.SelectedColorInternal);
                end
                self.LastHitObject = evt.HitObject;
            else
                % Hide highlighting for list hit object
                hideHighlight(self);
            end
            
        end
        
        %--Create Panel----------------------------------------------------
        function createPanel(self,hparent,pos)
            % Create panel and axes. Turn on toolbar, default interactions.
            pos(3) = pos(3) - self.ScrollBarWidth;
            
            self.Panel = uipanel('Parent',hparent,...
                'BorderType','none',...
                'Units','pixels',...
                'HandleVisibility','off',...
                'Position',pos,...
                'Tag','ScrollablePanel',...
                'AutoResizeChildren','off');
            
            self.Axes = axes(self.Panel,...
                'Units','pixels',...
                'Tag', 'ImageAxes',...
                'Visible','off','YDir','reverse');
            
            set(self.Axes,'Position',[1 1 pos(3:4)],'XLim',[1 pos(3)],...
                'YLim',[1 pos(4)],'Toolbar',[],'PickableParts','visible',...
                'HitTest','off','Box','off','XTick',[],'YTick',[],...
                'Color',[0.94 0.94 0.94]);
            
            set(self.Axes.XAxis,'Color','none');
            set(self.Axes.YAxis,'Color','none');
            set(self.Axes.ZAxis,'Color','none');
            
            disableDefaultInteractivity(self.Axes);
            
        end
        
        %--Create Scroll Bar-----------------------------------------------
        function createScrollBar(self,hparent,pos)
            % Create scrollbar using IPT utility
            scrollbarPosition = [pos(3) - self.ScrollBarWidth + 1, pos(2), self.ScrollBarWidth, pos(4)];
            
            self.ScrollBar = images.internal.app.utilities.ScrollBar(hparent,scrollbarPosition);
            addlistener(self.ScrollBar,'ScrollBarDragging',@(src,evt) dragScrollBar(self,evt.CurrentPoint,evt.OriginalPoint,evt.ScrollBarLimits,evt.ScrollBarExtents));
            addlistener(self.ScrollBar,'ScrollBarDragged',@(src,evt) stopDragging(self));
        end
        
        %--Create Slider---------------------------------------------------
        function createSlider(self,hparent,pos)
            % Create horizontal slider
            sliderPosition = [pos(1), pos(2), pos(3), self.SliderHeight];
            
            self.Slider = images.internal.app.segmenter.volume.display.Slider(hparent,sliderPosition);
            addlistener(self.Slider,'NextPressed',@(~,~) down(self));
            addlistener(self.Slider,'PreviousPressed',@(~,~) up(self));
            addlistener(self.Slider,'SliderMoving',@(src,evt) dragSlider(self,evt.Index,evt.PreviousIndex));
            addlistener(self.Slider,'SliderMoved',@(~,~) stopDragging(self));
            self.Slider.Enabled = true;
            
        end
        
        %--Disable---------------------------------------------------------
        function disable(self)
            % Disable entries and hide the highlight if applicable
            for i = 1:numel(self.Entries)
                disable(self.Entries(i));
            end
            self.HoverListener.Enabled = false;
            hideHighlight(self);
        end
        
        %--Enable----------------------------------------------------------
        function enable(self)
            % Enable all entries
            for i = 1:numel(self.Entries)
                enable(self.Entries(i));
            end
            self.HoverListener.Enabled = self.HighlightOnHoverInternal;
        end
        
        %--Get Max Number Of Entries In Viewport---------------------------
        function n = getMaxNumEntriesInViewport(self)
            % The maximum number of entries that could possible fit into
            % the current viewport at one time. This number may or may not
            % be the number displayed, depending on if the number of
            % entries is equal to this value or not not.
            col = getNumColumns(self);
            if self.LayoutInternal == "row"
                n = ceil(self.Axes.Position(3)/self.EntrySizeInternal(1));
            else
                n = col*ceil(self.Axes.Position(4)/self.EntrySizeInternal(2));
            end
            
        end
        
        %--Get Number Of Columns-------------------------------------------
        function n = getNumColumns(self)
            % Get the number of columns. For row and column layouts, this
            % is always 1.
            if self.Layout == "auto"
                n = floor((self.Axes.Position(3))/self.EntrySizeInternal(1));
                if n == 0
                    n = 1;
                end
            else
                n = 1;
            end
            
        end
        
        %--Do Entries Overhang Viewport-----------------------------------
        function TF = doEntriesOverhangViewport(self)
            % Returns true if the entries hang off the edge of the
            % viewport, returns false if they do not.
            n = getMaxNumEntriesInViewport(self);
            
            if self.TotalNumEntries > n
                TF = true;
            else
                if self.LayoutInternal == "row"
                    TF = self.TotalNumEntries > (self.Axes.Position(3)/self.EntrySizeInternal(1));
                else
                    TF = ceil(self.TotalNumEntries/getNumColumns(self)) > (self.Axes.Position(4)/self.EntrySizeInternal(2));
                end
            end
            
        end
        
        %--Do Entries Overhang Top Edge Of Viewport-----------------------
        function TF = doEntriesOverhangTopEdgeOfViewport(self)
            
            if isempty(self.Entries)
                TF = false;
                return;
            end
            
            pos = self.Entries(1).Position;
            
            if self.LayoutInternal == "row"
                % For row layout, if it does not overhang the top edge, the
                % first entry should be positioned at x = 1.
                TF = pos(1) ~= 1;
            else
                % For column and auto layouts, if it does not overhang the
                % top edge, the first entry should be positioned at y equal
                % to the height of the entry away from the height of the
                % axes.
                TF = pos(2) ~= self.Axes.Position(4) - self.EntrySizeInternal(2);
            end
            
        end
        
        %--Do Entries Overhang Bottom Edge Of Viewport--------------------
        function TF = doEntriesOverhangBottomEdgeOfViewport(self)
            
            if isempty(self.Entries)
                TF = false;
                return;
            end
            
            n = getMaxNumEntriesInViewport(self);
            
            pos = self.Entries(n).Position;
            
            if self.LayoutInternal == "row"
                % For row layout, if it does not overhang the bottom edge, the
                % last entry should be positioned at x equal
                % to the width of the entry away from the width of the
                % axes.
                % TF = pos(1) ~= 1;
                TF = pos(1) ~= self.Axes.Position(3) - self.EntrySizeInternal(1);
            else
                % For column and auto layouts, if it does not overhang the
                % bottom edge, the last entry should be positioned at
                % y = 1.
                TF = pos(2) ~= 1;
            end
            
        end
        
        %--Align Entries With Top Edge Of Viewport-------------------------
        function alignEntriesWithTopEdgeOfViewport(self,forceReposition)
            % Snap entries to top edge. We do this because the viewport
            % likely doesn't perfectly line up with the entries, When we
            % snap to the top edge, we position the entries to line up
            % with the top edge, meaning the bottom edge of the bottom row
            % in view likely hangs off the bottom of the viewport.
            
            % Check if we have more space than entries. If forceReposition
            % is true, we will always reposition entries.
            if (doEntriesOverhangViewport(self) && doEntriesOverhangTopEdgeOfViewport(self)) || forceReposition
                n = getMaxNumEntriesInViewport(self);
                if self.LayoutInternal == "row"
                    panelPosition = self.Axes.Position;
                    pos = [1, 1, self.EntrySizeInternal(1), panelPosition(4)];
                    positionEntries(self,n,pos,1);
                else
                    col = getNumColumns(self);
                    panelPosition = self.Axes.Position;
                    pos = [1, 1, panelPosition(3)/col, self.EntrySizeInternal(2)];
                    positionEntries(self,n,pos,col);
                end
            end
            
        end
        
        %--Align Entries With Bottom Edge Of Viewport----------------------
        function alignEntriesWithBottomEdgeOfViewport(self,forceReposition)
            % Snap entries to bottom edge. We do this because the viewport
            % likely doesn't perfectly line up with the entries, When we
            % snap to the bottom edge, we position the entries to line up
            % with the bottom edge, meaning the top edge of the top row
            % in view likely hangs off the top of the viewport.
            
            % Check if we have more space than entries. If forceReposition
            % is true, we will always reposition entries.
            if (doEntriesOverhangViewport(self) && doEntriesOverhangBottomEdgeOfViewport(self)) || forceReposition
                n = getMaxNumEntriesInViewport(self);
                if self.LayoutInternal == "row"
                    panelPosition = self.Axes.Position;
                    pos = [1 - mod(self.EntrySizeInternal(1)*n,self.Axes.Position(3)), 1, self.EntrySizeInternal(1), panelPosition(4)];
                    positionEntries(self,n,pos,1);
                else
                    col = getNumColumns(self);
                    panelPosition = self.Axes.Position;
                    pos = [1, 1 - mod(self.EntrySizeInternal(2)*(n/col),self.Axes.Position(4)), panelPosition(3)/col, self.EntrySizeInternal(2)];
                    positionEntries(self,n,pos,col);
                end
            end
            
        end
        
        %--Position Entries------------------------------------------------
        function positionEntries(self,n,pos,col)
            % Position the entries by incrementing through the array and
            % adding x offset after each entry. Once we hit the end of the
            % column, reset the x offset and add a y offset.
            panelPosition = self.Axes.Position;
            idx = 1;
            if self.LayoutInternal == "row"
                % Special case row layout to just add to the x offset each
                % time
                for i = 1:n
                    set(self.Entries(i),'Position',pos);
                    pos(1) = pos(1) + self.EntrySizeInternal(1);
                end
            else
                for i = 1:n
                    set(self.Entries(i),'Position',pos);
                    idx = idx + 1;
                    pos(1) = pos(1) + (panelPosition(3)/col);
                    if idx > col
                        idx = 1;
                        pos(2) = pos(2) + self.EntrySizeInternal(2);
                        pos(1) = 1;
                    end
                end
            end
            
        end
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Layout
        %------------------------------------------------------------------
        function set.Layout(self,val)
            
            previousLayout = self.LayoutInternal;
            
            if previousLayout == val
                return;
            end
            
            self.IsScrollingOrResizing = true;
            h = getScrollBarHeight(self);
            
            if val == "row"
                % col/auto --> row: Add space back that was allocated for 
                % vertical scrollbar
                self.ScrollBar.Enabled = false;
                pos = self.Panel.Position;
                pos(3) = pos(3) + self.ScrollBarWidth;
                self.CachedPosition = pos;
                if isempty(self.Slider)
                    createSlider(self,self.Panel.Parent,pos);
                end
            elseif previousLayout == "row"
                % row --> col/auto: Add space back that was allocated for 
                % horizontal slider
                pos = self.Panel.Position;
                pos(4) = pos(4) + h;
                pos(2) = pos(2) - h;
                self.CachedPosition = pos;
                
                if ~isempty(self.Slider)
                    self.Slider.Visible = false;
                    self.Slider.Enabled = false;
                end
            else
                % col/auto <--> col/auto: Add space back that was allocated
                % for vertical scrollbar
                pos = self.Panel.Position;
                pos(3) = pos(3) + self.ScrollBarWidth;
                self.CachedPosition = pos;
            end
            
            self.LayoutInternal = val;
            
            resizeOnDelay(self);
        end
        
        function val = get.Layout(self)
            val = self.LayoutInternal;
        end
        
        %------------------------------------------------------------------
        % Enabled
        %------------------------------------------------------------------
        function set.Enabled(self,TF)
            if TF
                if self.LayoutInternal == "row"
                    self.Slider.Enabled = true;
                else
                    self.ScrollBar.Enabled = true;
                end
                enable(self);
            else
                disable(self);
                if self.LayoutInternal == "row"
                    self.Slider.Enabled = false;
                else
                    self.ScrollBar.Enabled = false;
                end
            end
            self.EnabledInternal = TF;
        end
        
        function TF = get.Enabled(self)
            TF = self.EnabledInternal;
        end
        
        %------------------------------------------------------------------
        % Entry Size
        %------------------------------------------------------------------
        function set.EntrySize(self,val)
            self.EntrySizeInternal = val;
            set(self.Entries,'EntrySize',self.EntrySizeInternal);
            refresh(self,"inplace");
        end
        
        function val = get.EntrySize(self)
            val = self.EntrySizeInternal;
        end
        
        %------------------------------------------------------------------
        % Selected Color
        %------------------------------------------------------------------
        function set.SelectedColor(self,color)
            self.SelectedColorInternal = color;
            set(self.Entries,'SelectedColor',self.SelectedColorInternal);
        end
        
        function color = get.SelectedColor(self)
            color = self.SelectedColorInternal;
        end

        %------------------------------------------------------------------
        % Hot Selected Color
        %------------------------------------------------------------------
        function set.HotSelectedColor(self,color)
            self.HotSelectedColorInternal = color;
            set(self.Entries,'HotSelectedColor',self.HotSelectedColorInternal);
        end
        
        function color = get.HotSelectedColor(self)
            color = self.HotSelectedColorInternal;
        end

        %------------------------------------------------------------------
        % Label Text Color
        %------------------------------------------------------------------
        function set.LabelTextColor(self,color)
            self.LabelTextColorInternal = color;
            self.LabelTextColorMode = "manual";
            set(self.Entries,'LabelTextColor',self.LabelTextColorInternal);
        end
        
        function color = get.LabelTextColor(self)
            if isempty(self.Entries) || self.LabelTextColorMode == "manual"
                color = self.LabelTextColorInternal;
            else
                color = self.Entries(1).LabelTextColor;
            end
        end
        
        %------------------------------------------------------------------
        % Background Color
        %------------------------------------------------------------------
        function set.BackgroundColor(self,color)
            self.Panel.BackgroundColor = color;
            if isa(self.Panel.Parent, 'matlab.ui.Figure')
                set(self.Panel.Parent,'Color',color);
            elseif isa(self.Panel.Parent, 'matlab.ui.container.Panel')
                set(self.Panel.Parent,'BackgroundColor',color);
            end
        end
        
        function color = get.BackgroundColor(self)
            color = self.Panel.BackgroundColor;
        end
        
        %------------------------------------------------------------------
        % Context Menu
        %------------------------------------------------------------------
        function set.ContextMenu(self,cmenu)
            self.ContextMenuInternal = cmenu;
            set(self.ContextMenuInternal,'Parent',ancestor(self.Panel,'figure'));
            set(self.Entries,'ContextMenu',cmenu);
        end
        
        function cmenu = get.ContextMenu(self)
            cmenu = self.ContextMenuInternal;
        end
        
        %------------------------------------------------------------------
        % Label Visible
        %------------------------------------------------------------------
        function set.LabelVisible(self,TF)
            self.LabelVisibleInternal = TF;
            set(self.Entries,'LabelVisible',TF);
            refresh(self,"inplace");
        end
        
        function TF = get.LabelVisible(self)
            TF = self.LabelVisibleInternal;
        end
        
        %------------------------------------------------------------------
        % Label Location
        %------------------------------------------------------------------
        function set.LabelLocation(self,loc)
            self.LabelLocationInternal = loc;
            set(self.Entries,'LabelLocation',loc);
            if self.LabelVisibleInternal
                refresh(self,"inplace");
            end
        end
        
        function loc = get.LabelLocation(self)
            loc = self.LabelLocationInternal;
        end

        %------------------------------------------------------------------
        % Badge Location
        %------------------------------------------------------------------
        function set.BadgeLocation(self,loc)
            self.BadgeLocationInternal = loc;
            set(self.Entries,'BadgeLocation',loc);
            refresh(self,"inplace");
        end
        
        function loc = get.BadgeLocation(self)
            loc = self.BadgeLocationInternal;
        end

        %------------------------------------------------------------------
        % Badge Location
        %------------------------------------------------------------------
        function set.HighlightOnHover(self,TF)
            self.HighlightOnHoverInternal = TF;
            if ~TF
                hideHighlight(self);
            end
            self.HoverListener.Enabled = TF;
        end
        
        function TF = get.HighlightOnHover(self)
            TF = self.HighlightOnHoverInternal;
        end

        %------------------------------------------------------------------
        % Thumbnail Color Style
        %------------------------------------------------------------------
        function set.ThumbnailColorStyle(self,style)
            self.ThumbnailColorStyleInternal = style;
            if style == "uniform"
                set(self.Entries,'SelectedColor',self.SelectedColorInternal,'HotSelectedColor',self.HotSelectedColorInternal);
            end
        end

        function style = get.ThumbnailColorStyle(self)
            style = self.ThumbnailColorStyleInternal;
        end
        
        %------------------------------------------------------------------
        % Number Of Columns
        %------------------------------------------------------------------
        function n = get.NumColumns(self)
            if self.LayoutInternal == "row"
                n = getMaxNumEntriesInViewport(self);
            else
                n = getNumColumns(self);
            end
        end
        
        %------------------------------------------------------------------
        % Number Of Visible Rows
        %------------------------------------------------------------------
        function n = get.NumVisibleRows(self)
            if self.LayoutInternal == "row"
                n = 1;
            else
                n = getMaxNumEntriesInViewport(self)/getNumColumns(self);
            end
        end
        
    end
    
end
