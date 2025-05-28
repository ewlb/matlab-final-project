classdef SegmentationBrowser < handle
    %

    % Copyright 2015-2020 The MathWorks, Inc.
    
    properties (Hidden = true)
        hParent
        hApp
    end
       
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        ImageStrip
    end
    
    methods
        function self = SegmentationBrowser(parentHandle, hApp)
            self.hParent = parentHandle;
            self.hApp = hApp;

            self.ImageStrip = images.internal.app.segmenter.image.web.ThumbnailList(self.hParent,[1 1 self.hParent.Position(3:4)]);
            addlistener(self.ImageStrip,'EntryInteractivelyClicked',@(src,evt) leftClickCallback(self,evt));
            
            % TODO - Undo/redo handling

        end
        
        function resize(self)
            resize(self.ImageStrip,[1,1,self.hParent.Position(3:4)]);
        end
        
        function setContent(self, segmentationDetailsCell, selectedRow)
            if ~isvalid(self.hApp)
                return;
            end
            if isempty(selectedRow)
                clear(self.ImageStrip);
            else
                update(self.ImageStrip,selectedRow,segmentationDetailsCell(:,1),segmentationDetailsCell(:,2));
            end
        end
        
        function setSelection(self, idx)
            if ~isvalid(self.hApp)
                return;
            end
            if isempty(idx)
                clear(self.ImageStrip);
            else
                setSelection(self.ImageStrip,idx);
            end
            self.hApp.refreshHistoryBrowser()
        end
        
        function selection = getSelection(self)
            selection = self.ImageStrip.Current;
        end
        
        function updateActiveThumbnail(self, newThumbnail)
            updateCurrentImage(self.ImageStrip,newThumbnail);
        end
        
        function scroll(self,scrollCount)
            scroll(self.ImageStrip,scrollCount);
        end
        
        function disable(self)
            disable(self.ImageStrip);
        end
        
        function enable(self)
            enable(self.ImageStrip);
        end
        
        function scrollToEnd(~)
            % No-op
        end
    end
    
    % Callbacks
    methods (Access = private)
        function leftClickCallback(self,evt)
            
            if (self.hApp.ActiveContoursIsRunning)
                self.hApp.stopActiveContours()
                wasRunningAC = true;
            else
                wasRunningAC = false;
            end
            
            % If there is uncommitted history, ask the user if they want to
            % apply changes before returning to the main tab.
            if ((~isempty(self.hApp.CurrentSegmentation) && self.hApp.CurrentSegmentation.HasUncommittedState) || wasRunningAC)
                
                warnstring = getString(message('images:imageSegmenter:uncommitedStateQuestion'));
                dlgname    = getString(message('images:imageSegmenter:uncommitedStateTitle'));
                yesbtn     = getString(message('images:commonUIString:yes'));
                nobtn      = getString(message('images:commonUIString:no'));
                cancelbtn  = getString(message('images:commonUIString:cancel'));
                self.hApp.CanClose = false;
                dlg = uiconfirm(self.hParent,warnstring,dlgname,...
                    'Options',{yesbtn,nobtn,cancelbtn},...
                    'DefaultOption',3,'CancelOption',3);
                self.hApp.CanClose = true;
                switch dlg
                    case yesbtn
                        self.setSelection(evt.PreviousSelection)
                        self.hApp.applyCurrentTabSettings()
                        self.hApp.returnToSegmentTab()
                    case nobtn
                        self.hApp.clearTemporaryHistory()
                        self.hApp.returnToSegmentTab()
                    case cancelbtn
                        self.setSelection(evt.PreviousSelection)
                        return
                end

            end
            
            % If a different segmentation has been selected, update the
            % history view and mask view.
            self.hApp.Session.ActiveSegmentationIndex = evt.CurrentSelection;
            self.hApp.refreshHistoryBrowser()
            
            theSegmentation = self.hApp.Session.CurrentSegmentation();
            self.hApp.updateScrollPanelCommitted(theSegmentation.getMask())
            self.hApp.updateModeOnSegmentationChange()
            
            self.hApp.scrollHistoryBrowserToEnd()
            
            % Committing temporary state above might have moved the
            % selection. Be sure it matches what was clicked.
            if (~isequal(self.ImageStrip.Current, evt.CurrentSelection))
                self.setSelection(evt.CurrentSelection);
            end
            
            self.hApp.updateUndoRedoButtons()
        end

    end
end
