classdef Model < handle & matlab.mixin.SetGet
    %
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    events
        
        EntriesAdded
        
        % For view to react
        DataEntriesRemoved
        % For browser to notify client
        Removed
        
        EntriesUpdated
        
        DataEntryUpdated
        
        UpdateViewSelection
                
        SelectionChanged
        
        OpenSelection
        
        SnapTo
        
        FileIORequired
        
        DisplayUpdated
    end
    
    
    properties (Access = private, Transient)
        % Data entries, contains the actual thumbnail image in memory.
        Entries
    end

    properties (Dependent)
        % Selection Type - "multi" | "single" | "none"
        SelectionType

        % Selection Required - false | true
        SelectionRequired
    end
    
    properties (Dependent, SetAccess = private)
        % Total number of images
        NumImages
        % Total number of images currently filtered-in for display
        NumDisplayedImages
        
        % Data Index of currently selected entries
        Selected
    end
    
    properties (SetAccess = private)
        % Cell array. ReadFcn should be able to interpret each element of
        % this cell array.
        Sources (:,1) cell = {}
        
        % Index of the last data entry to be selected. (Needed as an anchor
        % point for actions like shit+arrow key multi selection)
        LastSelected
    end
    
    properties (Access = private)
        % Logical arrays with length == number of images.
        % A true value indicates that the corresponding image is selected
        IsSelected (:,1) logical

        SelectionTypeInternal (1,1) string {mustBeMember(SelectionTypeInternal, ["multi", "single", "none"])} = "multi";
        SelectionRequiredInternal (1,1) logical = false;
    end
    
    properties
        % Function handle.
        %  [im, label, badge, userData] = ReadFcn(Sources(ind)) should
        %  return image data (MxNx3 uint8) for ind'th source. Label data as
        %  a scalar string and userData as a scalar struct - both of these
        %  can be empty. The badge must be an enumeration from
        %  images.internal.app.browser.data.Badge.
        ReadFcn (1,1) function_handle = @images.internal.app.browser.data.defaultReadFcn
        
        ThumbnailSize = [100 100]
        
        % Logical array, if true, corresponding thumbnail is shown. If
        % false, its filtered out (hidden).
        FilteredIn (:,1) logical
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Model
        %------------------------------------------------------------------
        function self = Model()
            
        end
        
        %------------------------------------------------------------------
        % Add
        %------------------------------------------------------------------
        function add(self,imageList, insertBeforeInd)
            % Initialize flags:
            n = numel(imageList);
            self.IsSelected = insert(self.IsSelected, false([n,1]), insertBeforeInd);
            self.FilteredIn = insert(self.FilteredIn, true([n,1]), insertBeforeInd);
            
            self.Sources = insert(self.Sources, imageList, insertBeforeInd);
            
            % Use temporary array to create new entries before appending to
            % the existing list for performance:
            h(1:n) = images.internal.app.browser.data.Entry(string.empty);
            for idx = 1:n
                h(idx) = images.internal.app.browser.data.Entry(imageList{idx});
            end
            
            self.Entries = insert(self.Entries, h', insertBeforeInd);
            
            % Notify the view
            notify(self,'EntriesAdded',...
                images.internal.app.browser.events.EntriesAddedEventData(numel(self.Entries)));
        end
        
        %------------------------------------------------------------------
        % Remove
        %------------------------------------------------------------------
        function remove(self,dataIndices)
            if isempty(dataIndices)
                return
            end
            % Compute display indices _before_ removing
            displayIndices = self.data2displayIndices(dataIndices);
            
            % Remove it
            self.Entries(dataIndices) = [];
            self.IsSelected(dataIndices) = [];
            self.FilteredIn(dataIndices) = [];
            % Hold on to the removed sources list
            removedSources = self.Sources(dataIndices);
            self.Sources(dataIndices) = [];

            if isempty(self.LastSelected) || any(dataIndices == self.LastSelected)
                % Case when nothing is LastSelected. Or the LastSelected
                % itself was removed. In this case, we need to make sure we
                % clear our LastSelected.
                self.LastSelected = [];
            else
                % LastSelected was not removed, but others were. This means
                % the idices of all entries will shift. LastSelected needs
                % to also shift to remain in sync with the entry that
                % corresponded to LastSelected prior to removal.
                self.LastSelected = self.LastSelected - sum(dataIndices < self.LastSelected);
            end

            checkForRequiredSelection(self,[]);
            
            % For View
            newNumVisibleEntries = sum(self.FilteredIn);
            notify(self,'DataEntriesRemoved',...
                images.internal.app.browser.events.DataEntriesRemovedEventData(newNumVisibleEntries, displayIndices));
            
            % For Brower.
            % Note: This means clients get this event before the view has
            % had a chance to refresh.
            notify(self,'Removed',...
                images.internal.app.browser.events.RemovedEventData(dataIndices, removedSources, newNumVisibleEntries));
        end
        
        %------------------------------------------------------------------
        % Refresh
        %------------------------------------------------------------------
        function refresh(self, dataInds)
            % Clear any already created thumbnails. (They'll get recreated
            % when the View indicates so).
            if ~isempty(self.Entries)
                for entry = self.Entries(dataInds)'
                    clear(entry);
                end
            end
        end
        
        %------------------------------------------------------------------
        % Gather Entries - this gets called when scrolling/resize, it has
        % to be quick and NOT perform file IO (returns thumbnails if they
        % were already read)
        %------------------------------------------------------------------
        function gatherEntries(self,displayRange)

            dataInds = self.display2dataIndices(displayRange(1):displayRange(2));
            if isempty(dataInds)
                return
            end
            dataEntries = self.Entries(dataInds);
            notify(self,'EntriesUpdated',...
                images.internal.app.browser.events.EntriesUpdatedEventData...
                (dataEntries,self.IsSelected(dataInds),self.data2displayIndices(self.LastSelected)));

            % Request updated information for the display range
            notify(self,'DisplayUpdated',...
                images.internal.app.browser.events.DisplayedIndexEventData(dataInds));

        end
        
        %------------------------------------------------------------------
        % Gather Entry - this gets called when the View has settled. IO
        % happens here (if needed).
        %------------------------------------------------------------------
        function gatherEntry(self, displayIndex)

            dataIndex = self.display2dataIndices(displayIndex);
            if isempty(dataIndex)
                return
            end
            dataEntry = self.Entries(dataIndex);
            
            if readRequired(dataEntry,self.ThumbnailSize)
                readImage(dataEntry, self.ReadFcn, self.ThumbnailSize);
                notify(self, 'DataEntryUpdated',...
                    images.internal.app.browser.events.DataEntryUpdatedEventData(dataEntry, displayIndex));
            end
            
        end
        
        %------------------------------------------------------------------
        % Check For Unread Entries - Let View know if there is any IO
        % required for the current display range.
        %------------------------------------------------------------------
        function checkForUnreadEntries(self,displayRange)
            
            if isempty(self.Entries) || ~all(displayRange > 0)
                % No Entries in Model, so no file IO required. It may be
                % possible for timer-based delayed events to ask for file
                % IO after the Model has been cleared. If we have no data,
                % we should not begin to inspect what we do not have. Guard
                % against any invalid inputs that may break Model indexing.
                return;
            end
            
            dataInds = self.display2dataIndices(displayRange(1):displayRange(2));
            if isempty(dataInds)
                return
            end
            
            dataEntries = self.Entries(dataInds);
            
            for idx = 1:numel(dataEntries)
                if readRequired(dataEntries(idx),self.ThumbnailSize)
                    % Notify View that at least one entry in the current
                    % display range needs file IO
                    notify(self,'FileIORequired');
                    break;
                end
            end
            
        end
        
        %------------------------------------------------------------------
        % Clear
        %------------------------------------------------------------------
        function clear(self)
            self.IsSelected = logical.empty;
            self.FilteredIn = logical.empty;
            self.Sources = {};
            self.Entries = [];
            self.LastSelected = [];
        end
        
        %------------------------------------------------------------------
        % Update Selection - response to selection change from view
        %------------------------------------------------------------------
        function updateSelection(self,selectionType,currentHotDisplayLocation)

            % Convert to data indices. Update LastSelected but keep the
            % previous state cached.
            currentSelectedDataIndex = self.display2dataIndices(currentHotDisplayLocation);
            if isempty(currentSelectedDataIndex)
                return
            end
            lastSelectedDataIndex = self.LastSelected;
            self.LastSelected = currentSelectedDataIndex;

            % Handle 'none' selection type
            if self.SelectionTypeInternal == "none"
                selectionType = 'none';
            end

            switch selectionType
                
                case {'left', 'double'}
                    % Select just one entry.
                    resetSelectionWithOneEntry(self,currentSelectedDataIndex);
                    
                case 'shift' % + click event, multi-select.
                    if self.SelectionTypeInternal == "single"
                        % When single selection is required, shift should
                        % multiselect. The behavior here should match a
                        % left or double click
                        resetSelectionWithOneEntry(self,currentSelectedDataIndex);
                    else
                        % For multiselect, shift click will select
                        % everything from the current LastSelected to the
                        % previous LastSelected.
                        if lastSelectedDataIndex > currentSelectedDataIndex
                            self.IsSelected(currentSelectedDataIndex:lastSelectedDataIndex) = true;
                        else
                            self.IsSelected(lastSelectedDataIndex:currentSelectedDataIndex) = true;
                        end
                    end
                    
                case 'ctrl' % + click event, add/remove to/from current selection.
                    if self.SelectionTypeInternal == "single"
                        if self.IsSelected(currentSelectedDataIndex)
                            self.IsSelected = false(size(self.IsSelected));
                        else
                            resetSelectionWithOneEntry(self,currentSelectedDataIndex);
                        end
                    else
                        self.IsSelected(currentSelectedDataIndex) = ~self.IsSelected(currentSelectedDataIndex);
                    end
                    
                case 'right'
                    if self.IsSelected(currentSelectedDataIndex)
                        % Right click on something thats already selected.
                        % NOP. (View will open context menu)
                        return
                    else
                        % Right click on an image that is NOT in current
                        % selection, discard old selection and move
                        resetSelectionWithOneEntry(self,currentSelectedDataIndex);
                    end

                case 'none'
                    % No selection supported. Enforce that all are
                    % deselected.
                    self.IsSelected = false(size(self.IsSelected));
                    
                otherwise
                    % Not handled
                    return;
            end
            
            % Validate the required selection, if necessary
            checkForRequiredSelection(self,lastSelectedDataIndex);

            selectedDataInds = find(self.IsSelected);
            selectedDisplayInds = self.data2displayIndices(selectedDataInds);
            
            % Notify the view (with display indices)
            notify(self,'UpdateViewSelection',...
                images.internal.app.browser.events.UpdateViewSelectionEventData(...
                selectedDisplayInds,self.data2displayIndices(self.LastSelected)));
            
            % Notify Browser (with data indices)
            notify(self,'SelectionChanged',...
                images.internal.app.browser.events.SelectionUpdatedEventData(...
                selectedDataInds));
            
            % Also notify Browser of double click if needed
            if strcmp(selectionType, 'double')
                notify(self, 'OpenSelection',...
                    images.internal.app.browser.events.OpenSelectionEventData(...
                    selectedDataInds));
            end
        end
        
        %------------------------------------------------------------------
        % Select - response to selection change request from Browser
        %------------------------------------------------------------------
        function select(self, dataInds)
            
            lastHotSelection = self.LastSelected;

            if ~isempty(dataInds)
                % Empty is a valid input to signify that not entry should
                % be selected. If nonempty, then the input argument must be
                % positive and less than the max number of entries.
                mustBePositive(dataInds)
                mustBeLessThanOrEqual(dataInds, self.NumImages)
            
                self.IsSelected = false(size(self.IsSelected));
                if self.SelectionTypeInternal == "multi"
                    self.IsSelected(dataInds) = true;
                elseif self.SelectionTypeInternal == "single"
                    % Don't error for programmatic selection that is
                    % invalid for single selection, just use the last
                    % requested selected entry.
                    self.IsSelected(dataInds(end)) = true;
                end

                % For programmatic selection, we don't have a good guess as
                % to what the best LastSelected entry should be, just use
                % the last one.
                self.LastSelected = dataInds(end);
            else
                self.IsSelected = false(size(self.IsSelected));
                self.LastSelected = [];
            end

            % Validate the required selection, if necessary
            checkForRequiredSelection(self,lastHotSelection);
            dataInds = find(self.IsSelected);
            
            % Notify the view (with display indices) to ensure selection is
            % displayed in current display range.
            displayInds = self.data2displayIndices(dataInds);
            if ~isempty(displayInds)
                % Only if any of the selected ones are 'filtered in'
                notify(self,'SnapTo',images.internal.app.browser.events.SnapToEventData(...
                    displayInds(end)));
            else
                notify(self,'UpdateViewSelection',...
                    images.internal.app.browser.events.UpdateViewSelectionEventData(...
                    displayInds,self.data2displayIndices(self.LastSelected)));
            end

            % Notify Browser after the View has reacted to this change
            notify(self,'SelectionChanged',images.internal.app.browser.events.SelectionUpdatedEventData(...
                dataInds));            
        end
        
        %------------------------------------------------------------------
        % Remove Selected
        %------------------------------------------------------------------
        function removeSelected(self)
            removeDataIndices = find(self.IsSelected);
            self.remove(removeDataIndices);
        end
        
        
        %------------------------------------------------------------------
        % getuserData - Browser exposes this as an API
        %------------------------------------------------------------------
        function userData = getUserData(self, index)
            dataEntry = self.Entries(index);
            userData = readImageUserData(dataEntry, self.ReadFcn);            
        end
        
        
        %------------------------------------------------------------------
        % Rotate Selected
        %------------------------------------------------------------------
        function rotateSelected(self,theta)
            rotateDataIndices = find(self.IsSelected);
            self.rotate(rotateDataIndices,theta);
        end
        
        %------------------------------------------------------------------
        % Rotate
        %------------------------------------------------------------------
        function rotate(self,dataIndices,theta)
            if isempty(dataIndices)
                return
            end
            rotatedDataEntries = self.Entries(dataIndices);
            for ind = 1:numel(rotatedDataEntries)
                if ~readRequired(rotatedDataEntries(ind),self.ThumbnailSize)
                    % Only rotate thumbnails we already have. KEY
                    % ASSUMPTION: Client will rotate the source. So for the
                    % rest, we'll get rotated data when we open the file to
                    % create the thumbnail.
                    rotatedDataEntries(ind).rotate(theta);
                end
            end
        end
        
        %------------------------------------------------------------------
        % Add a badge
        %------------------------------------------------------------------
        function badge(self, badgeInds, badge)
            for ind = 1:numel(badgeInds)
                self.Entries(badgeInds(ind)).Badge = badge;
            end
        end

        %------------------------------------------------------------------
        % Add a color
        %------------------------------------------------------------------
        function setColor(self, dataInd, color)
            for ind = 1:numel(dataInd)
                self.Entries(dataInd(ind)).Color = color;
            end
        end
        
        %------------------------------------------------------------------
        % Add a label explicitly
        %------------------------------------------------------------------
        function setLabel(self, dataInd, label)

            n = numel(dataInd);

            switch numel(label)
                case 0
                    % Empty string. Clear out label in all corresponding
                    % indices
                    for ind = 1:numel(dataInd)
                        self.Entries(dataInd(ind)).Label = string.empty;
                    end
                case 1
                    % Scalar label. Apply label to all corresponding
                    % indices
                    for ind = 1:numel(dataInd)
                        self.Entries(dataInd(ind)).Label = label;
                    end
                case n
                    % One label for each index. Apply all accordingly.
                    for ind = 1:numel(dataInd)
                        self.Entries(dataInd(ind)).Label = label(ind);
                    end
                otherwise
                    assert(false,'Dimensions of the label string array must match the index array.')
            end

        end  

        %------------------------------------------------------------------
        % Add a multiline label explicitly
        %------------------------------------------------------------------
        function setMultilineLabel(self, dataInd, label)
            
            m = numel(label)/numel(dataInd);
            assert(mod(m, 1) == 0, 'The label string must be equal or multiple of the index array.');

            % Multiline label for each index. Apply all accordingly.
            for ind = 1:numel(dataInd)
                self.Entries(dataInd(ind)).Label = label((ind-1)*m+1:ind*m);
            end
            
        end

    end
    
    % Property set/get methods
    methods

        %------------------------------------------------------------------
        % Selection Type
        %------------------------------------------------------------------
        function set.SelectionType(self,type)
            self.SelectionTypeInternal = type;
            if self.SelectionTypeInternal == "none"
                select(self,[]);
            elseif self.SelectionTypeInternal == "single"
                select(self,self.LastSelected);
            else
                select(self,self.Selected);
            end
        end
        
        function type = get.SelectionType(self)
            type = self.SelectionTypeInternal;
        end

        %------------------------------------------------------------------
        % Selection Required
        %------------------------------------------------------------------
        function set.SelectionRequired(self,TF)
            self.SelectionRequiredInternal = TF;
            checkForRequiredSelection(self,[]);

            selectedDataInds = find(self.IsSelected);
            selectedDisplayInds = self.data2displayIndices(selectedDataInds);
            
            % Notify the view (with display indices)
            notify(self,'UpdateViewSelection',...
                images.internal.app.browser.events.UpdateViewSelectionEventData(...
                selectedDisplayInds,self.data2displayIndices(self.LastSelected)));
            
            % Notify Browser (with data indices)
            notify(self,'SelectionChanged',...
                images.internal.app.browser.events.SelectionUpdatedEventData(...
                selectedDataInds));

        end
        
        function TF = get.SelectionRequired(self)
            TF = self.SelectionRequiredInternal;
        end

        function n = get.NumImages(self)
            n = numel(self.Entries);
        end

        function n = get.NumDisplayedImages(self)
            n = sum(self.FilteredIn);
        end

        function selectedInds = get.Selected(self)
            selectedInds = find(self.IsSelected);
        end

    end

    methods (Access = private)

        %--Reset Selection With One Entry----------------------------------
        function resetSelectionWithOneEntry(self,idx)
            self.IsSelected = false(size(self.IsSelected));
            self.IsSelected(idx) = true;
        end
        
        %--Check For Required Selection------------------------------------
        function checkForRequiredSelection(self,previousHotSelection)

            if ~self.SelectionRequiredInternal || self.SelectionTypeInternal == "none" || numel(self.IsSelected) == 0
                % No selection validation required
                return;
            end

            % How many entries are currently selected. Depending on the
            % selection type, this number may be invalid and we need to
            % update selection.
            numSelected = sum(self.IsSelected);

            switch numSelected
                case 0
                    % Nothing is selected, but selection is required. We 
                    % must add a selection.
                    if isempty(self.LastSelected)
                        % We already validated above that the number of
                        % entries is greater than zero. We have something
                        % in the browser that can be selected.
                        self.IsSelected(1) = true;
                        self.LastSelected = 1;
                    else
                        % This can be hit if a user attempts to ctrl click
                        % a single selected entry while selection is
                        % enforced to be single. We must keep the previous
                        % selected entry selected.
                        resetSelectionWithOneEntry(self,self.LastSelected);
                    end
                case 1
                    % Valid state for both single and multi selection. We
                    % just need to update LastSelected to be in sync.
                    self.LastSelected = self.Selected;
                otherwise
                    % More than one entry. This isn't valid for single
                    % selection, but it is for multi selection.
                    selectedIndices = self.Selected;

                    if self.SelectionTypeInternal == "single"
                        % More than one is selected. We must choose only
                        % one to be selected.
                        if isempty(self.LastSelected)
                            % We don't have a last selection. Default to
                            % the first selected thumbnail
                            resetSelectionWithOneEntry(self,selectedIndices(1));
                            self.LastSelected = selectedIndices(1);
                        else
                            if any(selectedIndices == self.LastSelected)
                                % One of the selected thumbnails is also
                                % the last selected. Use that one.
                                idx = find(selectedIndices == self.LastSelected,1);
                                resetSelectionWithOneEntry(self,selectedIndices(idx));
                                self.LastSelected = selectedIndices(idx);
                            else
                                % Find the nearest selected thumbnail to
                                % the last selected
                                distanceIdx = abs(selectedIndices - self.LastSelected);
                                [~,idx] = min(distanceIdx);
                                resetSelectionWithOneEntry(self,selectedIndices(idx(1)));
                                self.LastSelected = selectedIndices(idx(1));
                            end
                        end
                    else
                        % More than one is selected. For "multi"
                        % SelectionType this is valid. Let's ensure that
                        % LastSelection is also a selected thumbnail.
                        if isempty(self.LastSelected)
                            % We don't have a last selection. Default to
                            % the first selected thumbnail
                            self.LastSelected = selectedIndices(1);
                        else
                            if ~any(selectedIndices == self.LastSelected)
                                if ~isempty(previousHotSelection) && any(selectedIndices == previousHotSelection)
                                    % Use the prior state of LastSelected.
                                    % This will help ctrl deselect look
                                    % more natural
                                    self.LastSelected = previousHotSelection;
                                else
                                    % Find the nearest selected thumbnail to
                                    % the last selected
                                    distanceIdx = abs(selectedIndices - self.LastSelected);
                                    [~,idx] = min(distanceIdx);
                                    self.LastSelected = selectedIndices(idx(1));
                                end
                            end
                        end
                    end
            end

        end

    end
    
    methods (Access = private)
        
        % Display index - A linear index into the display Entries. This is
        % limited to the number of 'filtered in' thumbnails
        %
        % Data index - A linear index into the browsers Sources property.
        %
        % e.g
        %   If there are 5 images, data index goes from 1:5 always.
        %   If self.FilteredIn is = [ 1 0 0 0 1];
        %   Then, display indices range from[1 2] and maps to data indices [1 5]
        
        function dataInds = display2dataIndices(self, displayInds)

            dataInds = zeros(size(displayInds));
            try
                
                displayedDataInds = cumsum(self.FilteredIn);
                for ind = 1:numel(displayInds)
                    displayInd = displayInds(ind);
                    dataInds(ind) = find(displayedDataInds==displayInd,1,'first');
                end

                if any(dataInds == 0)
                    dataInds = [];
                end
                
            catch
                dataInds = [];
                % Swallow errors. This can happen in the following scenario:
                % - Model is updated (removed entries)
                % - Model notified view
                % - View requested a new update before the model
                %   notification reached view
                % In the above case, Model and View are out of  sync, so
                % just silently swallow this.
            end

        end
        
        function displayInds = data2displayIndices(self, dataInds)
            displayedDataInds = cumsum(self.FilteredIn);
            % Check if the datainds are filtered out
            isFilteredOut = ~self.FilteredIn(dataInds);
            dataInds(isFilteredOut) = [];
            % Note - this can now be empty!
            displayInds = displayedDataInds(dataInds);
        end
    end
    
end


%% Helpers
function out = insert(in, part, insertBeforeInd)
if isempty(insertBeforeInd) || insertBeforeInd>numel(in)
    % Append
    out = [in; part];
elseif insertBeforeInd==1
    % Prepend
    out = [part; in];
else
    % Insert
    out = [in(1:insertBeforeInd-1);
           part;
           in(insertBeforeInd:end)];
end
end