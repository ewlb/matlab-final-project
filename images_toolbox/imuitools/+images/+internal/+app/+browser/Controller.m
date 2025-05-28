classdef Controller < handle
    %

    % Copyright 2020-2021 The MathWorks, Inc.

    properties (Access = private, Hidden, Transient)

        Model
        View

    end


    properties (Access = private, Hidden, Transient)

        Listeners event.listener

    end


    methods

        %------------------------------------------------------------------
        % Controller
        %------------------------------------------------------------------
        function self = Controller(modelObject,viewObject)

            self.Model = modelObject;
            self.View = viewObject;

            wireUpListeners(self);

        end

        %------------------------------------------------------------------
        % Delete
        %------------------------------------------------------------------
        function delete(self)
            delete(self.Listeners)
        end

    end


    methods (Access = private)

        %--Wire Up Listeners-----------------------------------------------
        function wireUpListeners(self)

            % Notify View that Model added entries via add()
            ea = event.listener(self.Model,'EntriesAdded',...
                @(src,evt) addEntries(self.View,evt.NumEntries));
            
            % Notify View that Model has updated entries with existing data
            % (i.e quick update for scrolling)
            eu = event.listener(self.Model,'EntriesUpdated',...
                @(src,evt) update(self.View,evt.Entries,evt.Selected,evt.CurrentHotLocation));
            
            % Notify View that Model has created a thumbnail for this entry
            eupd = event.listener(self.Model, 'DataEntryUpdated',...
                @(src, evt) refreshIndividualEntry(self.View, evt.DataEntry, evt.DisplayIndex));
            
            % Notify View that selection has changed in the Model
            su = event.listener(self.Model,'UpdateViewSelection',...
                @(src,evt) refreshSelection(self.View,evt.Selected,evt.CurrentHotLocation));
            
            sc = event.listener(self.View,'SelectionChanged',...
                @(src,evt) updateSelection(self.Model,evt.ClickType,evt.CurrentHotLocation));
            
            % Notify View that slection has changed via an API call from
            % the Browser, ensure selection is in view.
            st = event.listener(self.Model,'SnapTo',...
                @(src, evt) snapToEntry(self.View, evt.DisplayIndex));

            dr = event.listener(self.View,'DisplayRefreshed',...
                @(src,evt) gatherEntries(self.Model,evt.DisplayRange));
            
            % Notify View that Model removed some entries
            er = event.listener(self.Model,'DataEntriesRemoved',...
                @(src,evt) removeEntries(self.View,evt.NewNumEntries,evt.RemovedDisplayIndices));

            eref = event.listener(self.View,'EntryRefreshed',...
                @(src, evt) gatherEntry(self.Model, evt.Index));
            % Notify Model that View wants to know if current display range
            % would need a file IO operation to create thumbnails
            vio = event.listener(self.View,'FileIORequested',...
                @(src, evt) checkForUnreadEntries(self.Model,evt.DisplayRange));
            mio = event.listener(self.Model,'FileIORequired',...
                @(~,~) updateIndividualEntries(self.View));

            self.Listeners = [ea eu su dr sc st er eref eupd vio mio];

        end

    end

end
