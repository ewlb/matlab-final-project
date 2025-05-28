classdef HistoryBrowser < handle
    %

    %     Copyright 2015-2019 The MathWorks, Inc.
    
    properties (Hidden = true)
        hParent
        hApp
    end
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)    
        ImageStrip
    end
    
    methods
        function self = HistoryBrowser(parentHandle, hApp)
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
        end
        
        function selection = getSelection(self)
            selection = self.ImageStrip.Current;
        end
        
        function scroll(self,scrollCount)
            scroll(self.ImageStrip,scrollCount);
        end
        
        function scrollToEnd(~)
            % No-op
        end
        
        function stepBackward(self)
            up(self.ImageStrip);
            self.updateAppFromSelection()
            self.hApp.updateUndoRedoButtons()
        end
        
        function stepForward(self)
            down(self.ImageStrip);
            self.updateAppFromSelection()
            self.hApp.updateUndoRedoButtons()
        end
        
        function disable(self)
            disable(self.ImageStrip);
        end
        
        function enable(self)
            enable(self.ImageStrip);
        end
        
    end
    
    % Callbacks
    methods (Access = private)
        
        function leftClickCallback(self,evt)
            cancelled = self.respondToNewSelection(evt.CurrentSelection);
            if (cancelled)
                self.setSelection(evt.PreviousSelection);
            end
        end
        
        function cancelled = respondToNewSelection(self, currentSelection)
            if (isempty(currentSelection))
                cancelled = false;
                return
            end
            
            if self.hApp.DrawingROI
                cancelled = true;
                return;
            end
            
            if (self.hApp.ActiveContoursIsRunning)
                self.hApp.stopActiveContours()
                wasRunningAC = true;
            else
                wasRunningAC = false;
            end
            
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
                        self.hApp.applyCurrentTabSettings()
                        self.hApp.returnToSegmentTab()
                    case nobtn
                        self.hApp.clearTemporaryHistory()
                        self.hApp.returnToSegmentTab()
                    case cancelbtn
                        cancelled = true;
                        return
                end
            end

            cancelled = false;
            
            % Committing temporary state above might have moved the
            % selection. Be sure it matches what was clicked.
            if (~isequal(self.ImageStrip.Current, currentSelection))
                self.setSelection(currentSelection);
            end
            
            self.updateAppFromSelection()
            self.hApp.updateUndoRedoButtons()
        end
        
        function updateAppFromSelection(self)
            self.hApp.setCurrentHistoryItem(self.ImageStrip.Current);
        end
    end
end
