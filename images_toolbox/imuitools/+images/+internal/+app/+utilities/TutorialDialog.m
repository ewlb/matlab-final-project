classdef TutorialDialog < images.internal.app.utilities.CloseDialog
    % TutorialDialog Display tutorial dialog with images and messages in an app
    % context
    %
    %   FOR INTERNAL USE ONLY
    %
    %   images.internal.app.TutorialDialog(IMAGES,MESSAGES,TITLE) displays a
    %   tutorial dialog that allows user to click through images with
    %   corresponding text. IMAGES is a 1xN or Nx1 cell array of paths to the
    %   images to be displayed in the tutorial, MESSAGES is a cell array of the
    %   same size as IMAGES that contains the strings or char arrays for each
    %   corresponding image. The number of images and messages must be the
    %   same. TITLE is a string or char array of the message to be displayed in
    %   the title bar.
    %
    %   images.internal.app.TutorialDialog(IMAGES,MESSAGES,TITLE,S) displays a
    %   tutorial dialog with a checkbox that the user can select to not show
    %   the dialog again. S must be the SettingsGroup setting of class
    %   matlab.settings.Setting that the tutorial dialog checks before opening
    %   and modifies when the checkbox is selected.
    %
    %   If the "Don't show me again" checkbox is selected when the user closes
    %   the tutorial, the setting (S.PersonalValue) will be set to false.
    %   Before opening the dialog, the setting will be queried and the dialog
    %   will only be opened if the setting is true.

    %   Copyright 2017-2024 The MathWorks, Inc.

    properties (Access = private)

        ImagePaths      % Cell array of file paths to images that will be
        % displayed in tutorial

        MessageStrings  % Cell array of char arrays for message that
        % corresponds to each image

        Setting         % Optional setting from SettingsGroup to allow user
        % to not display tutorial again

    end
    
    properties
        
        % IsAborted - Logical flag to indicate if the dialog should be
        % shown according to the setting
        IsAborted (1,1) logical = false;
        
    end

    properties (Dependent)
        CurrentIndex
        IsDoNotShowCheckBoxVisible
    end

    properties (GetAccess = ?uitest.factory.Tester)

        CurrentIndexInternal = 1;
        NumPages
        Tag = 'TutorialDialog';

        % UI Components
        Layout
        MiddleLayout
        AxesHandle
        ImageHandle
        LeftButton
        RightButton
        CheckBox
        DotHandle
        DotAxesHandle
        Text

    end

    methods (Access = public)

        function self = TutorialDialog(loc,imagePaths,messageStrings,titleMessage,varargin)

            self = self@images.internal.app.utilities.CloseDialog(loc, titleMessage);
            
            self.Size = [500, 500];
                        
            if nargin > 4
                assert(isa(varargin{1},'matlab.settings.Setting'),'The third argument must be a matlab.settings.Setting object.')
                self.Setting = varargin{1};

                % Check if user preference is set to not show dialog
                if ~self.Setting.ActiveValue
                    % Don't show dialog
                    self.IsAborted = true;
                    return;
                end
            end

            assert(isa(imagePaths,'cell'),'Image paths should be in a cell array');
            assert(isa(messageStrings,'cell'),'Message strings should be in a cell array');
            assert(isequal(size(imagePaths),size(messageStrings)),'Number of images and messages should be equal');

            self.ImagePaths = imagePaths;
            self.MessageStrings = messageStrings;
            self.NumPages = numel(self.ImagePaths);

            self.create();

        end

        function create(self)

            create@images.internal.app.utilities.CloseDialog(self);

            % Create UI objects
            self.createLayout();
            self.createImageAxes();
            self.createDots();
            self.createRightButton();
            self.createLeftButton();
            self.createTextMessageArray();
            self.createCheckBox();

            self.updatePage();

        end

        function createLayout(self)

            panel = uipanel('Parent',self.FigureHandle',...
                'Units','pixels','Position',[1,self.ButtonSize(2) + self.ButtonSpace,self.Size(1),self.Size(2) - self.ButtonSize(2) - self.ButtonSpace],...
                'BorderType','none');
            
            self.Layout = uigridlayout(panel);
            self.Layout.RowHeight = {'fit',20,'fit'};
            self.Layout.ColumnWidth = {'1x'};
            
            self.MiddleLayout = uigridlayout(self.Layout,'Padding',[0 0 0 0],'ColumnSpacing',0,'RowSpacing',0);
            self.MiddleLayout.RowHeight = {20};
            self.MiddleLayout.ColumnWidth = {20,'1x',20};
            
            self.MiddleLayout.Layout.Row = 2;
            self.MiddleLayout.Layout.Column = 1;
            
        end

        function createImageAxes(self)      
                                
            self.AxesHandle = axes(self.Layout,...
                'Tag','ImageAxes','Units','pixels');
            
            set(self.AxesHandle,'Units','normalized');
            set(self.AxesHandle,'Position',[0 0 1 1]);
            set(self.AxesHandle,'Units','pixels');
            
            I = imread(self.ImagePaths{self.CurrentIndex});
            
            self.ImageHandle = image(I,...
                'Tag','ImageHandle',...
                'Parent',self.AxesHandle,'Interpolation','bilinear');
            
            set(self.AxesHandle,'Box','off','XTick',[],'YTick',[])
            
            self.AxesHandle.Layout.Row = 1;
            self.AxesHandle.Layout.Column = 1;
            
            disableDefaultInteractivity(self.AxesHandle);
            
            set(self.AxesHandle.Toolbar,'Visible','off');
            set(self.AxesHandle,'PickableParts','none','HitTest','off');

            set(self.AxesHandle.XAxis,'Color','none');
            set(self.AxesHandle.YAxis,'Color','none');
            set(self.AxesHandle.ZAxis,'Color','none');
            
            set(self.ImageHandle,'PickableParts','none','HitTest','off');


        end

        function createDots(self)
            % create an axes for the dots
            self.DotAxesHandle = axes('Parent',self.MiddleLayout, ...
                'Tag','ImageAxes', ...
                'Visible','off', ...
                'XLimMode','manual', ...
                'YLimMode','manual');
            
            self.DotAxesHandle.Layout.Row = 1;
            self.DotAxesHandle.Layout.Column = 2;
            
            yData = 0.5*ones([self.NumPages,1]);
            xSpacing = 0.025;
            xStart = 0.5 - (xSpacing*((self.NumPages - 1)/2));
            xFinish = 0.5 + (xSpacing*((self.NumPages - 1)/2));
            xData = xStart:xSpacing:xFinish;
            cData = 0.5*ones([self.NumPages,3]);
            cData(1,:) = [0 0 0];
            self.DotHandle = scatter(xData,yData,10,cData,...
                'Parent',self.DotAxesHandle,...
                'MarkerEdgeColor','none',...
                'MarkerFaceColor','flat', ...
                'PickableParts', 'none');
            set(self.DotAxesHandle,'XLim',[0 1],'YLim',[0 1],'ZLim',[0 1],'Visible','off');
            self.DotAxesHandle.Toolbar.Visible = 'off';
        end

        function createTextMessageArray(self)

            self.Text = uilabel(self.Layout, ...
                'FontSize',12,...
                'WordWrap','on',...
                'Text',' ', ...
                'Tag','MessageBox', ...
                'HorizontalAlignment','left', ...
                'VerticalAlignment','top');
            
            self.Text.Layout.Row = 3;
            self.Text.Layout.Column = 1;

        end

        function createRightButton(self)
            self.RightButton = uibutton(self.MiddleLayout,...
                'Text','', ...
                'ButtonPushedFcn', @self.moveRight, ...
                'HorizontalAlignment', 'left', ...
                'IconAlignment','center', ...
                'Tag', 'RightButton');
            matlab.ui.control.internal.specifyIconID(self.RightButton, 'navigationArrowEastUI', 16);
            self.RightButton.Layout.Row = 1;
            self.RightButton.Layout.Column = 3;
        end

        function createLeftButton(self)
            self.LeftButton = uibutton(self.MiddleLayout,...
                'Text','', ...
                'ButtonPushedFcn',@self.moveLeft, ...
                'HorizontalAlignment', 'right', ...
                'IconAlignment', 'center', ...
                'Tag', 'LeftButton');
            matlab.ui.control.internal.specifyIconID(self.LeftButton, 'navigationArrowWestUI', 16);
            self.LeftButton.Layout.Row = 1;
            self.LeftButton.Layout.Column = 1;
        end

        function createCheckBox(self)

            % Only create check box if setting exists
            if isempty(self.Setting)
                return;
            end

            self.CheckBox = uicheckbox('Parent',self.FigureHandle,...
                'Position',[self.ButtonSpace,self.ButtonSpace,self.Size(1) - self.ButtonSize(1) - (2*self.ButtonSpace),self.ButtonSize(2)],...
                'Value',0,...
                'Tag','CheckBox',...
                'Text',getString(message('images:imageRegistration:dontShowAgain')),...
                'ValueChangedFcn',@(src,evt) updateCheckBoxState(self,evt));

        end
    end

    methods (Access = protected)
        % Callbacks
        function keyPress(self,evt)
            switch(evt.Key)
                case 'rightarrow'
                    self.moveRight()
                case 'leftarrow'
                    self.moveLeft()
                case {'return','space','escape'}
                    closeClicked(self);
            end
        end

        function moveRight(self,varargin)
            if self.CurrentIndex < self.NumPages
                self.CurrentIndex = self.CurrentIndex + 1;
                self.updatePage();
            end
        end

        function moveLeft(self,varargin)
            if self.CurrentIndex > 1
                self.CurrentIndex = self.CurrentIndex - 1;
                self.updatePage();
            end
        end

        function updateCheckBoxState(self,evt)
            self.Setting.PersonalValue = ~evt.Value;
        end

        function updatePage(self)

            cData = 0.5*ones([self.NumPages,3]);
            cData(self.CurrentIndex,:) = [0 0 0];
            self.DotHandle.CData = cData;
            set(self.Text,'Text',self.MessageStrings{self.CurrentIndex});
            I = imread(self.ImagePaths{self.CurrentIndex});
            set(self.ImageHandle,'CData',I);
            
            if self.CurrentIndex == 1
                set(self.LeftButton,'Enable','off');
            else
                set(self.LeftButton,'Enable','on');
            end

            if self.CurrentIndex == self.NumPages
                set(self.RightButton,'Enable','off');
            else
                set(self.RightButton,'Enable','on');
            end

        end

    end

    methods
        % Set/Get methods
        function set.CurrentIndex(self,idx)
            idx = round(idx);
            assert(idx >= 1 && idx <= self.NumPages,'Invalid index requested.');
            self.CurrentIndexInternal = idx;
            self.updatePage();
        end

        function idx = get.CurrentIndex(self)
            idx = self.CurrentIndexInternal;
        end

        function set.IsDoNotShowCheckBoxVisible(self, TF)
            set(self.CheckBox,'Visible',TF);
        end

        function TF = get.IsDoNotShowCheckBoxVisible(self)
            TF = self.CheckBox.Visible;
        end

    end

end
