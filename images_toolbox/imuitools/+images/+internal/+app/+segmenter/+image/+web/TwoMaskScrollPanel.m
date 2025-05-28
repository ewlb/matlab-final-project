classdef TwoMaskScrollPanel < handle
    %

    % Copyright 2015-2019 The MathWorks, Inc.
    
    properties (Access = public)
        Visible
        AlphaMaskOpacity
    end
    
    properties (SetAccess=private,GetAccess=public)
        hFig
        hPanel
        Image
        hDocument
        
        PreviewMask
        CommittedMask
    end
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        ImageTester
    end
    
    properties (Access=private)
        CachedOpacity
        CachedColormap
        CachedImage
        CachedImageForBinary
        
        IncludeList = [1 2];
        ColormapInternal = single([0 0 0; 1 1 0; 0 1 1]);
        
        hLegend
        
        isShowBinary
        isLegendVisible
        
    end
    
    methods
        % Constructor
        function self = TwoMaskScrollPanel(hApp)
            
            % Add a figure-based document
            figOptions.Title = getString(message('images:imageSegmenter:imageTitle'));
            figOptions.DocumentGroupTag = "SegmenterFigure";
            
            self.hDocument = matlab.ui.internal.FigureDocument(figOptions);
            self.hDocument.Closable = false;
            hApp.add(self.hDocument);
            self.hFig = self.hDocument.Figure;
                        
            set(self.hFig,'NumberTitle', 'off',...
                'Units','pixels',...
                'IntegerHandle','off',...
                'HandleVisibility','off',...
                'AutoResizeChildren','off'); 
                        
            % Set the WindowKeyPressFcn to a non-empty function. This is
            % effectively a no-op that executes every time a key is pressed
            % when the App is in focus. This is done to prevent focus from
            % shifting to the MATLAB command window when a key is typed.
            self.hFig.WindowKeyPressFcn = @(~,~)[];
            
            iptPointerManager(self.hFig);
            
            self.hPanel = uipanel(...
                'Parent', self.hFig,...
                'Units','pixels',...
                'Position', [1 1 self.hFig.Position(3:4)],...
                'BorderType','none',...
                'tag', 'ImagePanel',...
                'AutoResizeChildren','off');
            
            layoutScrollpanel(self, self.hPanel);
            self.AlphaMaskOpacity = 1;
            
            % Prevent MATLAB graphics from being drawn in figures docked
            % within App.
            set(self.hFig, 'HandleVisibility', 'callback');
            
        end
        
        function resize(self)
            reactToAppResize(self);
        end
        
        function updateScrollPanel(self,im)
            
            sz = size(im);
            self.PreviewMask = zeros(sz(1:2));
            self.CommittedMask = zeros(sz(1:2));
            im = im2single(im);
            self.CachedImage = im;
            
            self.Image.Visible = true;
            self.Image.Enabled = true;
            self.isLegendVisible = false;
            
            reactToAppResize(self);
            
            redraw(self);
            
        end
        
        % Mask control
        function updatePreviewMask(self,previewMask)
            
            assert(isequal(size(previewMask),size(self.PreviewMask)),'Size mismatch when updating scrollpanel preview mask.')
            
            self.PreviewMask = previewMask;
            
            self.redraw();
                        
        end
        
        function updateCommittedMask(self,committedMask)
            
            assert(isequal(size(committedMask),size(self.CommittedMask)),'Size mismatch when updating scrollpanel committed mask.')
            
            self.CommittedMask = committedMask;
            
            self.redraw();
                        
        end
        
        function resetPreviewMask(self)
            self.PreviewMask = zeros(size(self.PreviewMask)); 
        end
        
        function resetCommittedMask(self)
            self.CommittedMask = zeros(size(self.PreviewMask)); 
        end
        
        function redraw(self)
            
            L = double(self.CommittedMask);
            L(self.PreviewMask == 1) = 2;
            draw(self.Image,self.CachedImage,L,self.ColormapInternal,[]);
            
        end
        
        % Show binary
        function showBinary(self)
            
            % Do not fire view changes if we are already in show binary 
            % mode.
            if self.isShowBinary
                return;
            end
            
            self.isShowBinary = true;
            
            self.CachedOpacity = self.AlphaMaskOpacity;
            self.AlphaMaskOpacity = 1;
            
            self.CachedImageForBinary = self.CachedImage;
            self.CachedImage = zeros(size(self.CachedImage),'like',self.CachedImage);
            self.CachedColormap = self.ColormapInternal;
            self.ColormapInternal = ones([3,3],'single');
            
            self.hLegend.Visible = 'off';
            
            self.redraw();
            
        end
        
        function unshowBinary(self)
            
            % Do not fire view changes if we are already in grayscale mode.
            if ~self.isShowBinary
                return;
            end
            
            self.isShowBinary = false;
            
            self.AlphaMaskOpacity = self.CachedOpacity;
            
            if ~isempty(self.CachedImageForBinary)
                self.CachedImage = self.CachedImageForBinary;
                self.CachedImageForBinary = [];

                self.ColormapInternal = self.CachedColormap;
            end
            
            if self.isLegendVisible && ~isempty(self.hLegend)
                self.hLegend.Visible = 'on';
            end
            
            self.redraw();
            
        end
        
        % Legend
        function addLegend(self)
            
            if isempty(self.hLegend)
                self.createLegend();
            else
                if self.isShowBinary
                    self.isLegendVisible = true;
                    return;
                end
                self.hLegend.Visible = 'on';
            end
            
            self.isLegendVisible = true;
        end
        
        function removeLegend(self)
            
            if ~isempty(self.hLegend)
                self.hLegend.Visible = 'off';
            end
            
            self.isLegendVisible = false;
        end
        
        function setMessagePaneText(self,str)
            self.Image.MessageText = str;
        end
        
        function showMessagePane(self,TF)
            self.Image.MessageVisible = TF;
        end
        
        function setFigureName(self,name)
            self.hDocument.Title = name;
        end
        
        % Destructor
        function delete(self)
            if isvalid(self.hFig)                
                delete(self.hFig)
            end
        end
    end
    
    % Set/Get accessor methods
    methods
        function set.Visible(self,newValue)
            
            switch (lower(newValue))
                case 'off'
                    self.Visible = 'off';
                case 'on'
                    self.Visible = 'on';
                otherwise
                    assert(false, 'Acceptable values for Visible property are ''On'' and ''Off''.')
            end
            
            self.setVisibility(self.Visible);
            
        end
        
        function set.AlphaMaskOpacity(self,newValue)
            
            if ~isempty(newValue) && newValue>=0 && newValue<=1
                self.AlphaMaskOpacity = newValue;
                self.Image.Alpha = newValue; %#ok<MCSUP>
            end
            self.redraw()
        end
                
    end
    
    methods (Access = private)
        function layoutScrollpanel(self, imPanel)
            
            self.Image = images.internal.app.utilities.Image(imPanel);
            addlistener(self.hFig,'WindowScrollWheel',@(src,evt) scroll(self.Image,evt.VerticalScrollCount));

        end
        
        function createLegend(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            previewColor = self.ColormapInternal(3,:);
            committedColor = self.ColormapInternal(2,:);
            
            % Create invisible patch objects of preview and committed color
            hPreviewPatch   = patch(1,1,previewColor,'Parent',self.Image.AxesHandle,'Visible','off');
            hCommittedPatch = patch(1,1,committedColor,'Parent',self.Image.AxesHandle,'Visible','off');
            
            self.hLegend = legend([hPreviewPatch,hCommittedPatch],{getMessageString('preview'),getMessageString('applied')},...
                'HandleVisibility','off','PickableParts','none','HitTest','off');
            self.hLegend.Location = 'northwest';
            
            % Remove the context menu
            self.hLegend.UIContextMenu.delete();
        end
        
        function setVisibility(self, visibility)
            set(self.hFig, 'Visible', visibility)
        end
        
        function reactToAppResize(self)
            
            if ~isempty(self.hPanel) && isvalid(self.hPanel)
                self.hPanel.Position = [1 1 self.hFig.Position(3:4)];
                resize(self.Image);
            end
        end
        
    end
    
    methods
        
        function obj = get.ImageTester(self)
            obj = self.Image;
        end
        
    end
    
end
