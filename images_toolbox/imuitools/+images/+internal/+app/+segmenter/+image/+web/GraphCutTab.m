classdef GraphCutTab < images.internal.app.segmenter.image.web.GraphCutBaseTab
    %

    % Copyright 2016-2024 The MathWorks, Inc.
    
    %%Public API
    methods
        function self = GraphCutTab(toolGroup, tabGroup, theToolstrip, theApp, varargin)

            % Call base class constructor
            self@images.internal.app.segmenter.image.web.GraphCutBaseTab(toolGroup, tabGroup, theToolstrip, theApp, 'graphCutTab', varargin{:})
            
        end
        
        function setMode(self, mode)
            import images.internal.app.segmenter.image.web.AppMode;
            
            switch (mode)
            case AppMode.GraphCutOpened
                
                self.initializeGraphCut();
                if self.ShowSuperpixelButton.Value
                    self.hApp.ScrollPanel.Image.Superpixels = self.SuperpixelLabelMatrix;
                    redraw(self.hApp.ScrollPanel);
                end
                self.disableApply();
                self.hApp.hideLegend();
                self.hApp.ScrollPanel.resetCommittedMask();
                
                % Message Panes
                self.MessageStatus = true;
                self.showMessagePane();
                
                % Set tool to start marking
                self.CommonTSCtrls.ForegroundButton.Value = true;
                self.addForegroundScribble();
                self.enableAllButtons();          
                self.showSuperpixelBoundaries();
                
            case AppMode.GraphCutDone
                self.resetAppState();

            case AppMode.NoImageLoaded
                reset(self.DrawCtrls);
                    
            case AppMode.NoMasks
                %If the app enters a state with no mask, make sure we set
                %the state back to unshow binary.
                if self.ViewMgr.ShowBinaryButton.Enabled
                    self.reactToUnshowBinary();
                    % This is needed to ensure that state is settled after
                    % unshow binary.
                    drawnow;
                end
                self.ViewMgr.Enabled = false;
                
            case AppMode.MasksExist
                self.ViewMgr.Enabled = true;
                
            case AppMode.ImageLoaded
                self.updateImageProperties()

            case AppMode.OpacityChanged
                self.reactToOpacityChange()
            case AppMode.ShowBinary
                self.reactToShowBinary()
            case AppMode.UnshowBinary
                self.reactToUnshowBinary()
            case AppMode.ToggleTexture
                self.TextureMgr.updateTextureState(self.hApp.Session.UseTexture);
            otherwise
                % Many App Modes do not require any action from this tab.
            end
            
        end
        
        function applyAndClose(self)
            self.onApply();
            self.onClose();
        end
        
        function onApply(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.hApp.setCurrentMask(self.GraphCutter.Mask);
            self.ApplyCloseMgr.ApplyButton.Enabled = false;
            if self.hApp.Session.UseTexture
                self.hApp.addToHistory(self.GraphCutter.Mask,getMessageString('graphCutTextureComment'),self.getCommandsForHistory());
            else
                self.hApp.addToHistory(self.GraphCutter.Mask,getMessageString('graphCutComment'),self.getCommandsForHistory());
            end
        end
        
        function onClose(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            self.hApp.clearTemporaryHistory()
            
            % This ensures that zoom tools have settled down before the
            % marker pointer is removed.
            drawnow;
            
            self.hideMessagePane()
            reset(self.DrawCtrls);
            
            if self.hApp.ScrollPanel.Image.SuperpixelsVisible
                self.hApp.ScrollPanel.Image.Superpixels = [];
                redraw(self.hApp.ScrollPanel);
            end
            
            self.hToolstrip.showSegmentTab()
            self.hToolstrip.hideGraphCutTab()
            self.disableAllButtons();
            self.hToolstrip.setMode(AppMode.GraphCutDone);
        end
    end
    
    %%Layout
    methods (Access = protected)
        function ctrl = createCommonTSControls(~)
            ctrl = images.internal.app.utilities.semiautoseg.TSControls();
        end

        function layoutTab(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;

            self.DrawSection        = self.hTab.addSection(getMessageString('markerTools'));
            self.DrawSection.Tag    = 'Draw Tools';
            self.ClearSection       = self.hTab.addSection(getMessageString('clearTools'));
            self.ClearSection.Tag   = 'Clear Markings';
            self.SuperpixelSection  = self.hTab.addSection(getMessageString('superpixelSettings'));
            self.SuperpixelSection.Tag  = 'Superpixel Settings';
            self.TextureSection     = self.addTextureSection();
            self.ViewSection        = self.addViewSection();
            self.ApplyCloseSection  = self.addApplyCloseSection();
            
            self.layoutDrawSection();
            self.layoutClearTools(self.ClearSection);
            self.layoutSuperpixelSection();
            
        end
        
        function section = addTextureSection(self)
            self.TextureMgr = images.internal.app.segmenter.image.web.TextureManager(self.hTab,self.hApp,self.hToolstrip);
            section = self.TextureMgr.Section;
            addlistener(self.TextureMgr, 'TextureButtonClicked', @(~,~) self.textureCallback());
        end
        
        function section = addApplyCloseSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            tabName = getMessageString('graphCutTab');
            
            useApplyAndClose = true;
            
            self.ApplyCloseMgr = iptui.internal.ApplyCloseManager(self.hTab, tabName, useApplyAndClose);
            section = self.ApplyCloseMgr.Section;
            
            addlistener(self.ApplyCloseMgr.ApplyButton,'ButtonPushed',@(~,~)self.applyAndClose());
            addlistener(self.ApplyCloseMgr.CloseButton,'ButtonPushed',@(~,~)self.onClose());
        end
    end
    
    %%Algorithm
    methods (Access = protected)
        function reactToScribbleDone(self)
            self.doSegmentationAndUpdateApp();
        end

        function [mask, maskSrc] = applySegmentation(self)      
            
            import images.internal.app.segmenter.image.web.getMessageString;
                       
            % Default parameters
            conn = 8; % node connectivity
            lambda = 500; % edge weight scale factor
            
            self.hApp.updateStatusBarText(getMessageString('applyingGraphCut'));
            self.showAsBusy()
                     
            if ~self.isGraphBuilt
                if self.hApp.Session.UseTexture
                self.GraphCutter = images.graphcut.internal.lazysnapping(self.hApp.Session.getTextureFeatures(), ...
                    self.SuperpixelLabelMatrix,self.NumSuperpixels,conn,lambda);
                elseif self.hApp.wasRGB
                self.GraphCutter = images.graphcut.internal.lazysnapping(prepLab(self.hApp.getImage()), ...
                    self.SuperpixelLabelMatrix,self.NumSuperpixels,conn,lambda);
                else
                self.GraphCutter = images.graphcut.internal.lazysnapping(self.hApp.getImage(), ...
                    self.SuperpixelLabelMatrix,self.NumSuperpixels,conn,lambda);
                end
            end

            if self.NumSuperpixels > 1  
                self.GraphCutter = self.GraphCutter.addHardConstraints( ...
                                        self.DrawCtrls.ForegroundInd, ...
                                        self.DrawCtrls.BackgroundInd );
                self.GraphCutter = self.GraphCutter.segment();
            end
            
            mask = self.GraphCutter.Mask;
            maskSrc = 'Graph Cut';
            self.hApp.showLegend();
                
            self.hApp.ScrollPanel.resetCommittedMask();
            
            self.isGraphBuilt = true;
            
            self.enableApply();
            
            self.hApp.updateStatusBarText('');
            self.unshowAsBusy()
            
        end
        
        function TF = isUserDrawingValid(self)
            TF = ~isempty(self.DrawCtrls.ForegroundInd(:)) && ...
                    ~isempty(self.DrawCtrls.BackgroundInd(:));
        end
    end
    
    %%Callbacks
    methods (Access = protected)
        
        function cleanupAfterClearAll(self)
            self.cleanupAfterClear();
        end
        
        function cleanupAfterClear(self, ~)
            self.hApp.ScrollPanel.resetPreviewMask();
            self.hApp.hideLegend();
            self.disableApply();
            self.showMessagePane();
            redraw(self.hApp.ScrollPanel);
        end
        
        function textureCallback(self)
            if self.isUserDrawingValid()
                self.isGraphBuilt = false;
                [mask, maskSrc] = self.applySegmentation();
                self.setTempHistory(mask, maskSrc);
            end
        end
        
    end
    
     %%Helpers
    methods (Access = protected)
        function enableAllButtons(self)

            self.TextureMgr.Enabled                             = true;
            self.ViewMgr.Enabled                                = true;
            self.ApplyCloseMgr.CloseButton.Enabled              = true;
            self.ShowSuperpixelButton.Enabled                   = true;
            self.SuperpixelDensityButton.Enabled                = true;
            enableAllControls(self.CommonTSCtrls);
            
        end
        
        function disableAllButtons(self)

            self.TextureMgr.Enabled                             = false;
            self.ViewMgr.Enabled                                = false;
            self.ApplyCloseMgr.ApplyButton.Enabled              = false;
            self.ApplyCloseMgr.CloseButton.Enabled              = false;
            self.ShowSuperpixelButton.Enabled                   = false;
            self.SuperpixelDensityButton.Enabled                = false;
            disableAllControls(self.CommonTSCtrls);
            
        end 
        
        function commands = getCommandsForHistory(self)
        
            foreInd = self.DrawCtrls.ForegroundInd;
            backInd = self.DrawCtrls.BackgroundInd;
            fString = sprintf('%d ', foreInd);
            bString = sprintf('%d ', backInd);
            
            if isscalar(foreInd)
                commands{1} = sprintf('foregroundInd = %s;', fString);
            else
                commands{1} = sprintf('foregroundInd = [%s];', fString);
            end
            
            if isscalar(backInd)
                commands{2} = sprintf('backgroundInd = %s;', bString);
            else
                commands{2} = sprintf('backgroundInd = [%s];', bString);
            end

            if self.hApp.wasRGB
                commands{3} = sprintf('L = superpixels(X,%d,''IsInputLab'',true);',self.NumRequestedSuperpixels);
                if self.hApp.Session.UseTexture
                    commands{4} = sprintf('BW = lazysnapping(gaborX,L,foregroundInd,backgroundInd);');
                else
                    commands{4} = '';
                    commands{5} = ['% ',getString(message('images:imageSegmenter:convertLab'))];
                    commands{6} = 'scaledX = prepLab(X);';
                    commands{7} = sprintf('BW = lazysnapping(scaledX,L,foregroundInd,backgroundInd);');
                end
            else
                commands{3} = sprintf('L = superpixels(X,%d);',self.NumRequestedSuperpixels);
                if self.hApp.Session.UseTexture
                    commands{4} = sprintf('BW = lazysnapping(gaborX,L,foregroundInd,backgroundInd);');
                else
                    commands{4} = sprintf('BW = lazysnapping(X,L,foregroundInd,backgroundInd);');
                end
            end
            
        end
        
        function showMessagePane(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            if self.MessageStatus
                message = getMessageString('graphCutMessagePane1');
            else
                message = getMessageString('graphCutMessagePane2');
            end
            setMessagePaneText(self.hApp.ScrollPanel,message);
            showMessagePane(self.hApp.ScrollPanel,true);
            
        end
        
        function hideMessagePane(self)
            showMessagePane(self.hApp.ScrollPanel,false);
        end
        
    end
    
end

function out = prepLab(in)
%prepLab - Convert L*a*b* image to range [0,1]

out = in;
out(:,:,1) = in(:,:,1) / 100;  % L range is [0 100].
out(:,:,2) = (in(:,:,2) + 86.1827) / 184.4170;  % a* range is [-86.1827,98.2343].
out(:,:,3) = (in(:,:,3) + 107.8602) / 202.3382;  % b* range is [-107.8602,94.4780].

end
