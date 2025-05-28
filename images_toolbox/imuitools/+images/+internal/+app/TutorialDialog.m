classdef TutorialDialog < handle
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

%   Copyright 2017-2022 The MathWorks, Inc.

    properties (Access = private)
        
        ImagePaths      % Cell array of file paths to images that will be 
                        % displayed in tutorial
                        
        MessageStrings  % Cell array of char arrays for message that 
                        % corresponds to each image
                        
        Title           % Message displayed in title bar
                        
        Setting         % Optional setting from SettingsGroup to allow user
                        % to not display tutorial again
        
        UseAppContainer = false

    end
    
    properties (Dependent)
        CurrentIndex
    end
    
    properties (Access = private)
        
        CurrentIndexInternal = 1;
        NumPages
        
        % UI Components
        FigureHandle
        AxesHandle
        OKButton
        LeftButton
        RightButton
        CheckBox
        CheckBoxText
        Font
        TextHandleArray
        DotHandle
        DotAxesHandle
        Position = get(0,'DefaultFigurePosition');
        
        % Hardcoded Layout Parameters
        Offset = 10; % points
        OKButtonWidth = 40;
        OKButtonHeight = 17;
        ArrowButtonHeight = 20;
        ImageHeight = 400;
        DotHeight = 10;
        OKXOffset
        
    end
    
    methods (Access = public)
        
        function self = TutorialDialog(imagePaths,messageStrings,titleMessage,varargin)
            
            if nargin > 3
                assert(isa(varargin{1},'matlab.settings.Setting'),'The third argument must be a matlab.settings.Setting object.')
                self.Setting = varargin{1};
                
                % Check if user preference is set to not show dialog         
               if ~self.Setting.ActiveValue
                    % Don't show dialog
                    return;
                end
            end
            
            if numel(varargin)>1
                assert(isa(varargin{2},'logical'),'The fourth argument must be a logical scalar stating if the app uses appcontainer')
                self.UseAppContainer = varargin{2};
            end

            assert(isa(imagePaths,'cell'),'Image paths should be in a cell array');
            assert(isa(messageStrings,'cell'),'Message strings should be in a cell array');
            assert(isequal(size(imagePaths),size(messageStrings)),'Number of images and messages should be equal');
            
            self.ImagePaths = imagePaths;
            self.MessageStrings = messageStrings;
            self.NumPages = numel(self.ImagePaths);
            self.Title = titleMessage;
            self.TextHandleArray = cell(size(messageStrings));
            
            self.createDialog();

        end
            
        function createDialog(self)
            
            % Create font
            self.Font.FontUnits  = 'points';
            self.Font.FontSize   = get(0,'FactoryUicontrolFontSize');
            self.Font.FontName   = get(0,'FactoryUicontrolFontName');
            self.Font.FontWeight = get(0, 'DefaultTextFontWeight');
            
            self.Position = get(0,'DefaultFigurePosition');
            self.Position(3) = 200;
            self.Position(4) = self.ImageHeight + self.DotHeight + 40;
            
            % Create UI objects
            self.createFigure();
            self.createImageAxes();
            self.createDots();
            self.createOKButton();
            self.createRightButton();
            self.createLeftButton();
            self.createTextMessageArray();
            self.createCheckBox();
            
            self.setFinalPositions();
            self.updatePage();
            
            % Make figure centered, visible, and modal
            if(~isWebFigure(self))
                movegui(self.FigureHandle,'center');
                set(self.FigureHandle,'HandleVisibility','callback','Visible','on');
            else
                % Figure handle gets deleted when setting fig units and
                % final position in movegui(). So replaced movegui() with
                % custom function i.e., moveFigureToCenter().
                moveFigureToCenter(self);
                set(self.FigureHandle,'HandleVisibility','callback','Visible','on');
                % Setting self.FigureHandle.WindowStyle to modal while
                % creating figure makes figure visible even when Visible
                % property is set to 'off', so handling it after
                % figure got displayed.
                self.FigureHandle.WindowStyle = 'modal';
            end
            uiwait(self.FigureHandle);
            drawnow;
        end
        
        function createFigure(self)
            if isWebFiguresActive(self)
                if ismac && self.UseAppContainer
                    units = 'pixels';
                else
                    units = 'points';
                end
                self.FigureHandle = uifigure('Name',self.Title, ...
                    'Pointer','arrow', ...
                    'Units',units,...
                    'Visible','off', ...
                    'KeyPressFcn',@self.doKeyPress, ...
                    'Resize','off',...
                    'HandleVisibility','on', ...
                    'CloseRequestFcn', @self.closePopup, ...
                    'Tag','TutorialDialog');
            else
                self.FigureHandle = dialog('Name',self.Title, ...
                    'Pointer','arrow', ...
                    'Units','points', ...
                    'Visible','off', ...
                    'KeyPressFcn',@self.doKeyPress, ...
                    'WindowStyle','modal', ...
                    'Toolbar','none', ...
                    'HandleVisibility','on', ...
                    'CloseRequestFcn', @self.closePopup, ...
                    'Tag','TutorialDialog');
            end
        end
        
        function createImageAxes(self)
            % create an axes for the images
            imagePos = [(2*self.Offset)+self.ArrowButtonHeight, self.Position(4)-self.ImageHeight-self.Offset, self.Position(3)-(4*self.Offset)-(2*self.ArrowButtonHeight), self.ImageHeight];
            if(~isWebFigure(self))
                self.AxesHandle = axes('Parent',self.FigureHandle, ...
                    'Units','points', ...
                    'Position',imagePos, ...
                    'Tag','ImageAxes');
            else
                self.AxesHandle = axes('Parent',self.FigureHandle, ...
                    'Units','points', ...
                    'Position',imagePos, ...
                    'Interactions', [],...
                    'Tag','ImageAxes');
            end
        end
        
        function createDots(self)
            % create an axes for the dots
            dotPos = [(2*self.Offset)+self.ArrowButtonHeight, self.Position(4)-self.ImageHeight-self.DotHeight-self.Offset, self.Position(3)-(4*self.Offset)-(2*self.ArrowButtonHeight), self.DotHeight];
            self.DotAxesHandle = axes('Parent',self.FigureHandle, ...
                'Units','points', ...
                'Position',dotPos, ...
                'Tag','ImageAxes', ...
                'Visible','off', ...
                'XLimMode','manual', ...
                'YLimMode','manual');            
            yData = 0.5*ones([self.NumPages,1]);
            xSpacing = 0.025;
            xStart = 0.5 - (xSpacing*((self.NumPages - 1)/2));
            xFinish = 0.5 + (xSpacing*((self.NumPages - 1)/2));
            xData = xStart:xSpacing:xFinish;
            cData = 0.5*ones([self.NumPages,3]);
            cData(1,:) = [0 0 0];
            if(~isWebFigure(self))
                self.DotHandle = scatter(xData,yData,10,cData,...
                    'Parent',self.DotAxesHandle,...
                    'MarkerEdgeColor','none',...
                    'MarkerFaceColor','flat');
            else
                self.DotHandle = scatter(xData,yData,10,cData,...
                    'Parent',self.DotAxesHandle,...
                    'MarkerEdgeColor','none',...
                    'MarkerFaceColor','flat', ...
                    'PickableParts', 'none');
            end
            set(self.DotAxesHandle,'XLim',[0 1],'YLim',[0 1],'ZLim',[0 1],'Visible','off');
        end
        
        function createTextMessageArray(self)
            msgTxtWidth = self.Position(3) - (2*self.Offset);
            msgTxtXOffset = self.Offset;
            msgTxtYOffset = (2*self.Offset) + self.OKButtonHeight;
            msgTxtHeight = max(0,self.Position(4) - self.ImageHeight - self.DotHeight - self.Offset - msgTxtYOffset);
            msgPos = [msgTxtXOffset, msgTxtYOffset, msgTxtWidth, msgTxtHeight];
            
            msgHandle = uicontrol(self.FigureHandle,self.Font, ...
                    'Style','text', ...
                    'Units','points', ...
                    'Position', msgPos, ...
                    'String',' ', ...
                    'Tag','MessageBox', ...
                    'HorizontalAlignment','left', ...
                    'BackgroundColor',self.FigureHandle.Color, ...
                    'ForegroundColor',[0 0 0]);
                
            msgAxesHandle = axes('Parent',self.FigureHandle ,'Position',[0 0 1 1],'Visible','off');
            
            if(isWebFigure(self))
                msgAxesHandle.Toolbar.Visible = 'off';
            end
            
            for idx = 1:self.NumPages
                
                [wrapString,newMsgTxtPos] = textwrap(msgHandle,self.MessageStrings(idx),100);
                
                self.TextHandleArray{idx} = text('Parent',msgAxesHandle, ...
                    'Units','points', ...
                    'String',wrapString, ...
                    'Color',[0 0 0], ...
                    self.Font, ...
                    'HorizontalAlignment','left', ...
                    'VerticalAlignment','bottom', ...
                    'Interpreter','none', ...
                    'Tag','MessageBox',...
                    'Visible','off');

                textExtent = get(self.TextHandleArray{idx}, 'Extent');

                %textExtent and extent from uicontrol are not the same. For Windows, extent from uicontrol is larger
                %than textExtent. But on Macs, it is reverse. Pick the max value.
                msgTxtWidth = max([msgTxtWidth newMsgTxtPos(3) textExtent(3)]);
                msgTxtHeight = max([msgTxtHeight newMsgTxtPos(4) textExtent(4)]);
            end
            
            delete(msgHandle);
            
            self.Position(3) = msgTxtWidth + (2*self.Offset);
            self.Position(4) = self.OKButtonHeight + self.ImageHeight + self.DotHeight + msgTxtHeight + (4*self.Offset);
        end
        
        function createOKButton(self)
            self.OKXOffset=(self.Position(3) - self.OKButtonWidth)/2;
            if self.UseAppContainer && ismac
                okPos = [self.OKXOffset, self.Offset , self.OKButtonWidth, (self.OKButtonHeight+4)];
            else
                okPos = [self.OKXOffset, self.Offset, self.OKButtonWidth, self.OKButtonHeight];
            end
            
            self.OKButton = uicontrol(self.FigureHandle,self.Font, ...
                'Style','pushbutton', ...
                'Units','points', ...
                'FontSize',(self.Font.FontSize-2),...
                'FontName',self.Font.FontName,...
                'Position', okPos, ...
                'Callback',@self.closePopup, ...
                'KeyPressFcn',@self.doKeyPress, ...
                'String',getString(message('MATLAB:uistring:popupdialogs:OK')), ...
                'HorizontalAlignment','center', ...
                'Tag','OKButton');
        end
        
        function createRightButton(self)            
            rightPos = [self.Position(3)-self.Offset-self.ArrowButtonHeight, self.Position(4)/2, self.ArrowButtonHeight, self.ArrowButtonHeight];
            self.RightButton = uicontrol(self.FigureHandle,...
                'Style','pushbutton', ...
                'Units','points', ...
                'Position', rightPos, ...
                'Callback',@self.moveRight, ...
                'KeyPressFcn',@self.doKeyPress, ...
                'HorizontalAlignment','center', ...
                'Tag','RightButton',...
                'CData',self.getArrowIcon());
        end
        
        function createLeftButton(self)
            leftPos = [self.Offset, self.Position(4)/2, self.ArrowButtonHeight, self.ArrowButtonHeight];
            self.LeftButton = uicontrol(self.FigureHandle,...
                'Style','pushbutton', ...
                'Units','points', ...
                'Position', leftPos, ...
                'Callback',@self.moveLeft, ...
                'KeyPressFcn',@self.doKeyPress, ...
                'HorizontalAlignment','center', ...
                'Tag','LeftButton',...
                'CData',fliplr(self.getArrowIcon()));
        end
        
        function createCheckBox(self)
            
            % Only create check box if setting exists
            if isempty(self.Setting)
                return;
            end
            if self.UseAppContainer && ismac               
                checkPos = [self.Offset, self.Offset+6, 14, 16];
            else
                checkPos = [self.Offset, self.Offset, 15, 10];
            end
            self.CheckBox = uicontrol('Style','checkbox',...
                'Parent',self.FigureHandle,...
                'Units','Points',...
                'Position',checkPos,...
                'Value',0,...
                'Tag','CheckBox');
            
            chkLabelXOffset = self.Offset + 15;
            chkLabelXWidth = self.OKXOffset - chkLabelXOffset;
            yPos = self.Font.FontSize;
            if self.UseAppContainer && ismac
               chkLabelPos = [chkLabelXOffset, self.Offset, chkLabelXWidth-8, yPos+9];
            else
               chkLabelPos = [chkLabelXOffset, self.Offset, chkLabelXWidth, yPos+2];
            end
            
            self.CheckBoxText = uicontrol(self.FigureHandle,self.Font, ...
                'Style','text', ...
                'Units','points', ...
                'Position', chkLabelPos, ...
                'String',getString(message(sprintf('images:imageRegistration:dontShowAgain'))), ...
                'Tag','checkBoxLabel', ...
                'HorizontalAlignment','left', ...
                'Enable','inactive', ...
                'ButtonDownFcn', @self.checkBoxLabelCallback);

            if self.UseAppContainer && ismac
                self.CheckBoxText.FontSize = self.Font.FontSize-2;
            end

        end
        
        function setFinalPositions(self)            
            % Set final figure position
            set(self.FigureHandle,'Position',self.Position);
            
            % Set final OK button position
            self.OKXOffset = (self.Position(3) - self.OKButtonWidth)/2;
            set(self.OKButton,'Position',[self.OKXOffset self.Offset self.OKButtonWidth self.OKButtonHeight]);
            
            pos = self.CheckBoxText.Position;
            pos(3) = self.OKXOffset - (self.Offset + 15);
            set(self.CheckBoxText,'Position',pos);
            
            % Set final text position
            txtPos = [self.Offset, self.OKButtonHeight+(2*self.Offset), 0];
            cellfun(@(x) set(x,'Position',txtPos),self.TextHandleArray);
            
            % Set final image axes position
            imagePos = [(2*self.Offset)+self.ArrowButtonHeight, self.Position(4)-self.ImageHeight-self.Offset, self.Position(3)-(4*self.Offset)-(2*self.ArrowButtonHeight), self.ImageHeight];
            set(self.AxesHandle,'Position',imagePos);
            
            
            dotPos = [(2*self.Offset)+self.ArrowButtonHeight, self.Position(4)-self.ImageHeight-self.DotHeight-self.Offset, self.Position(3)-(4*self.Offset)-(2*self.ArrowButtonHeight), self.DotHeight];
            set(self.DotAxesHandle,'Position',dotPos);
            
            % Set final left and right button positions
            rightPos = [self.Position(3)-self.Offset-self.ArrowButtonHeight, self.Position(4)/2, self.ArrowButtonHeight, self.ArrowButtonHeight];
            set(self.RightButton,'Position',rightPos);
            
            leftPos = [self.Offset, self.Position(4)/2, self.ArrowButtonHeight, self.ArrowButtonHeight];
            set(self.LeftButton,'Position',leftPos);
        end
        
    end
    
    methods (Access = private)
        % Callbacks
        function doKeyPress(self,obj,evt)
            switch(evt.Key)
                case 'right'
                    self.moveRight()
                case 'left'
                    self.moveLeft()
                case {'return','space','escape'}
                    self.closePopup(obj,evt);
            end
        end
        
        function checkBoxLabelCallback(self,varargin)
            if ~isempty(self.CheckBox)
                self.CheckBox.Value = ~self.CheckBox.Value;
            end
        end
        
        function moveRight(self,varargin)
            if self.CurrentIndex < self.NumPages
                set(self.TextHandleArray{self.CurrentIndex},'Visible','off');
                self.CurrentIndex = self.CurrentIndex + 1;
                self.updatePage();
            end
        end
        
        function moveLeft(self,varargin)
            if self.CurrentIndex > 1
                set(self.TextHandleArray{self.CurrentIndex},'Visible','off');
                self.CurrentIndex = self.CurrentIndex - 1;
                self.updatePage();
            end
        end
        
        function closePopup(self,varargin)
            if ~isempty(self.CheckBox) && self.CheckBox.Value
                self.Setting.PersonalValue = false;
            end            
            delete(gcf);
        end
        
        function updatePage(self)
            
            cData = 0.5*ones([self.NumPages,3]);
            cData(self.CurrentIndex,:) = [0 0 0];
            self.DotHandle.CData = cData;
            set(self.TextHandleArray{self.CurrentIndex},'Visible','on');
            I = imread(self.ImagePaths{self.CurrentIndex});
            
            imshow(I,'Parent',self.AxesHandle);
            if(isWebFigure(self))
                self.AxesHandle.Toolbar.Visible = 'off';
                self.DotAxesHandle.Toolbar.Visible = 'off';
            end
            if self.CurrentIndex == 1
                set(self.LeftButton,'Visible','off');
            else
                set(self.LeftButton,'Visible','on');
            end
            
            if self.CurrentIndex == self.NumPages
                set(self.RightButton,'Visible','off');
            else
                set(self.RightButton,'Visible','on');
            end
            
        end
        
        function moveFigureToCenter(self)
            fig = self.FigureHandle;
            oldfunits = get(fig, 'Units');
            set(fig, 'Units', 'pixels');
            % save figure position before making adjustments
            oldpos = get(fig, 'Position');
            
            % Initialize width and height adjustments
            widthAdjustment = 0;
            heightAdjustment = 0;
            
            if isunix
                % reasonable defaults to calculate outer position in unix
                % border estimate for figure window
                borderEstimate = 0;
                % padding value to account backward compatibility
                paddingEstimate = 6;
                % width adjustment is border value plus padding value of window
                widthAdjustment = borderEstimate + paddingEstimate;
                % estimated value of titlebar
                titleBarEstimate = 24;
            else
                % reasonable defaults to calculate outer position in windows
                % border estimate for figure window
                borderEstimate = 8;
                % border value of both left and right side of window
                widthAdjustment = borderEstimate * 2;
                % estimated value of titlebar
                titleBarEstimate = 31;
            end
            
            % estimate the outer position
            heightAdjustment = titleBarEstimate + borderEstimate;
            oldpos(3) = oldpos(3) + widthAdjustment;
            oldpos(4) = oldpos(4) + heightAdjustment;
            
            fleft   = oldpos(1);
            fbottom = oldpos(2);
            fwidth  = oldpos(3);
            fheight = oldpos(4);
            
            old0units = get(0, 'Units');
            set(0, 'Units', 'pixels');
            screensize = get(0, 'ScreenSize');
            monitors = get(0,'MonitorPositions');
            set(0, 'Units', old0units);
            
            % Determine which monitor contains atleast one of the corners
            % of the figure window We cycle through each monitor and check
            % the four corners of the figure. Starting with bottom left,
            % moving clockwise. If any one of the corners is found to be
            % within a particular monitor we break the search and that
            % monitor is used as the reference screen size for further
            % calculations.
            for k = 1:size(monitors,1)
                monitorPos = monitors(k,:);
                if (((fleft > monitorPos(1)) && (fleft < monitorPos(1) + monitorPos(3)) && (fbottom > monitorPos(2)) && (fbottom < monitorPos(2) + monitorPos(4))) || ... % bottom left
                        ((fleft > monitorPos(1)) && (fleft < monitorPos(1) + monitorPos(3)) && (fbottom + fheight > monitorPos(2)) && (fbottom + fheight < monitorPos(2) + monitorPos(4))) || ... % left top
                        ((fleft + fwidth > monitorPos(1)) && (fleft + fwidth < monitorPos(1) + monitorPos(3)) && (fbottom + fheight > monitorPos(2)) && (fbottom + fheight < monitorPos(2) + monitorPos(4))) || ... % top right
                        ((fleft + fwidth > monitorPos(1)) && (fleft + fwidth < monitorPos(1) + monitorPos(3)) && (fbottom > monitorPos(2)) && (fbottom < monitorPos(2) + monitorPos(4)))) % bottom right
                    screensize = monitorPos;
                    break;
                end
            end
            
            sx = screensize(1);
            sy = screensize(2);
            swidth = screensize(3);
            sheight = screensize(4);
            % make sure the figure is not bigger than the screen size
            fwidth = min(fwidth, swidth);
            fheight = min(fheight, sheight);
            
            % Remaining width
            rwidth  = swidth-fwidth;
            
            % Remaining height
            rheight = sheight-fheight;
            
            % Calculate new psoition
            newpos = [rwidth/2, rheight/2];
            % adjustment needed for window border
            newpos = newpos + [sx + borderEstimate, sy + borderEstimate];
            newpos(3:4) = [fwidth, fheight];
            
            % remove width and height adjustments added above
            newpos(3) = newpos(3) - widthAdjustment;
            newpos(4) = newpos(4) - heightAdjustment;
            fig.Position = newpos;
            fig.Units = oldfunits;
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
        
    end
    
    methods (Static)
        
        function icon = getArrowIcon()
            arrowIcon = load(fullfile(toolboxdir('images'),'icons','binary_arrow_icon.mat'));
            icon = double(repmat(arrowIcon.arrow,[1 1 3]));
            icon(icon == 1) = NaN;
        end
                
    end
    
end

%--------------------------------------------------------------------------
% Helper functions
%--------------------------------------------------------------------------
function TF = isWebFigure(self)
% This function returns true if figHandle support webfigures
hFig = self.FigureHandle;
TF = isa(getCanvas(hFig),'matlab.graphics.primitive.canvas.HTMLCanvas') || self.UseAppContainer;
end

function TF = isWebFiguresActive(self)
% This function returns true if matlab invoked with webfigures flag
s = settings;
try
    TF = s.matlab.ui.internal.figuretype.webfigures.ActiveValue || self.UseAppContainer;
catch
    TF = false;
end
end