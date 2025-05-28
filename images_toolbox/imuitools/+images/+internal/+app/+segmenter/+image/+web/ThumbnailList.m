classdef ThumbnailList < images.internal.app.utilities.EntryPanel
    %
    
    % Copyright 2020 The MathWorks, Inc.
    
    events
        
        EntryInteractivelyClicked
        
    end
    
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private, Transient)
                        
        NameListener event.listener
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Thumbnail Browser
        %------------------------------------------------------------------
        function self = ThumbnailList(hfig,pos)
            
            self@images.internal.app.utilities.EntryPanel(hfig,pos,'UseHeader',false);
            
            self.EntryHeight = images.internal.app.segmenter.image.web.getThumbnailSize();
            self.ScrollBarWidth = 8;
            
            createPanel(self,hfig,pos);
            createScrollBar(self,hfig,pos); 
            
            self.NameListener = event.listener(hfig,'WindowMousePress',@(src,evt) nameClicked(self,evt));
            set(self.Panel,'AutoResizeChildren','off');
            
        end
        
        %------------------------------------------------------------------
        % Set Selection
        %------------------------------------------------------------------
        function setSelection(self,idx)
            updateCurrentSelection(self,idx);
        end
        
        %------------------------------------------------------------------
        % Update Current Image
        %------------------------------------------------------------------
        function updateCurrentImage(self,im)
            self.Entries(self.Current).Image = im;
        end
        
    end
    
    
    methods (Access = protected)
        
        %--Name Clicked----------------------------------------------------
        function nameClicked(self,evt)
            % Workaround with web figures for the fact that uieditfield 
            % does not support ButtonDown events. 
            if isa(evt.HitObject,'matlab.ui.control.Label')
                if numel(self.Entries) > 1
                    idx = find(cellfun(@(x) eq(evt.HitObject,x),get(self.Entries,'NameUI')));
                    nameClicked(self.Entries(idx),evt.HitObject);
                elseif numel(self.Entries) == 1
                    nameClicked(self.Entries(1),evt.HitObject);
                end               
            end
            
        end
        
        %--Update Entry Data-----------------------------------------------
        function reorderRequired = updateEntryData(self,im,names)
            
            reorderRequired = false;
            
            for idx = 1:numel(names)
                
                % Don't forget the offset to account for the background
                % label
                if idx > numel(self.Entries)
                    addToEntryList(self,names{idx},im{idx});
                    reorderRequired = true;
                else
                    self.Entries(idx).Name = names{idx};
                    self.Entries(idx).Image = im{idx};
                end
                
            end
            
            if idx < numel(self.Entries)
                
                delete(self.Entries(idx+1:end));
                self.Entries(idx+1:end) = [];
                reorderRequired = true;
                
            end
        
        end
        
        %--Entry Interactively Clicked-------------------------------------
        function entryInteractivelyClicked(self,src)
            entryClicked(self,src);
            notify(self,'EntryInteractivelyClicked',packageEntrySelectedEventData(self));
        end
            
        %--Package Entry Selected Event Data-------------------------------
        function evt = packageEntrySelectedEventData(self)
            evt = images.internal.app.segmenter.image.web.events.EntrySelectedEventData(self.Current,self.PreviousSelection);
        end
        
        %--Create Entry----------------------------------------------------
        function newEntry = createEntry(self,varargin)
            
            newEntry = images.internal.app.segmenter.image.web.Entry(self.Panel,getNextLocation(self),varargin{1},varargin{2});

            addlistener(newEntry,'EntryClicked',@(src,evt) entryInteractivelyClicked(self,src));
            addlistener(newEntry,'EntryRemoved',@(src,evt) entryRemoved(self,evt));
            
        end
        
    end
    
    
end