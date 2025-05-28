classdef Entry < handle & matlab.mixin.SetGet
    %

    % Copyright 2020-2021 The MathWorks, Inc.

    events

        % Entry Clicked - Event fires when the entry is interactively
        % clicked.
        EntryClicked

    end


    properties (Dependent)

        % Selected - Controls if the entry should be highlighted.
        Selected

        % Image - Image displayed in entry. If empty is passed in, a
        % placeholder icon is used.
        Image

        % Position - Location of the entry. This represents the entire area
        % alloted to all UI components in the entry.
        Position

        % Visible - Controls whether or not the entry and its UI components
        % are visible.
        Visible

        % Context Menu - Menu object dispalyed during right clicks.
        ContextMenu

        % Selected Color - Color used for highlight when Selected is true.
        SelectedColor

        % Badge - Badge enum used to display supported badge icons at the
        % lower left corner of the image.
        Badge

        % Label - Text label displayed in the entry.
        Label

        % Label Visible - Controls whether or not the label is visible. If
        % not, the entry is positioned to occupy the space that would be
        % alloted to the label.
        LabelVisible

        % Label Location - Controls where the label is placed, either
        % "bottom", "right", or "overlay".
        LabelLocation

        % Label Text Color - Color used for the text of the label
        LabelTextColor
        
        % Entry Size - Requested size of the entry
        EntrySize

        % Badge Location - Controls the location of the badge icon
        BadgeLocation

        % Hot Selected - Indicates whether this entry is hot selected. Only
        % one entry in the browser can be hot selected at a time.
        HotSelected

        % Hot Selected Color - Color used to indicate the hot selection
        HotSelectedColor

    end
    
    
    properties
        
        CharacterScaleFactor (1,1) double = 7.7;
        
    end


    properties (GetAccess = ?uitest.factory.Tester, SetAccess = protected, Transient)

        % UI components that need tester access
        ImageUI
        SelectionUI
        BadgeUI
        LabelUI

    end


    properties (Access = private, Hidden, Transient)

        HitListener event.listener

        SelectedInternal (1,1) logical = false;

        HotSelectedInternal (1,1) logical = false;

        PositionInternal (1,4) double

        BadgeInternal (1,1) images.internal.app.browser.data.Badge = images.internal.app.browser.data.Badge.Empty;

        LabelInternal (:,1) string

        LabelLocationInternal (1,1) string {mustBeMember(LabelLocationInternal,["bottom","right","overlay"])} = "bottom";

        BadgeLocationInternal (1,1) string {mustBeMember(BadgeLocationInternal,["northwest", "northeast", "southwest", "southeast"])} = "southwest";

        LabelVisibleInternal (1,1) logical = false;

        SelectedColorInternal (1,3) = [0.349 0.667 0.847];

        HotSelectedColorInternal (1,3) = [0.592 0.792 0.906];

        EdgeColorInternal (1,3) = [0, 0.251, 0.451];

        LabelTextColorInternal (1,3) = [0, 0, 0];

        LabelTextColorMode matlab.internal.datatype.matlab.graphics.datatype.AutoManual = "auto";
        
        EntrySizeInternal (1,2) double {mustBePositive} = [100 100];

    end


    properties (Constant, Access = private)

        % Static property containing all badge icons and placeholder
        Icons = images.internal.app.browser.display.Icons;

    end


    properties (Constant, Access = private, Hidden)

        % Border between entry elements in pixels
        Border = 4;

        % Minimum space between the selection rectangle and the image
        SelectionWidth = 4;

        % Label height when LabelLocation is "bottom"
        LabelHeight = 12;

    end


    methods

        %------------------------------------------------------------------
        % Entry
        %------------------------------------------------------------------
        function self = Entry(haxes)
            createUI(self,haxes);
        end

        %------------------------------------------------------------------
        % Enable
        %------------------------------------------------------------------
        function enable(self)
            self.HitListener.Enabled = true;
        end

        %------------------------------------------------------------------
        % Disable
        %------------------------------------------------------------------
        function disable(self)
            self.HitListener.Enabled = false;
        end

        %------------------------------------------------------------------
        % Delete
        %------------------------------------------------------------------
        function delete(self)
            delete(self.ImageUI);
            delete(self.SelectionUI);
            delete(self.BadgeUI);
            delete(self.LabelUI);
        end

        %------------------------------------------------------------------
        % Minimum Size Required
        %------------------------------------------------------------------
        function val = minimumSizeRequired(self)
            % Compute how small the width/height can be. The View should
            % abandon any attempts to resize that will force the entry to
            % be smaller than this size
            if self.LabelVisibleInternal && self.LabelLocationInternal ~= "overlay"
                if self.LabelLocationInternal == "bottom"
                    % Label visible and located at bottom
                    val = (2*self.Border) + (2*self.SelectionWidth) + getLabelHeight(self) + 1;
                else
                    % Label visible and located on right
                    val = (3*self.Border) + (2*self.SelectionWidth) + 2;
                end
            else
                % Overlay or invisible label
                val = (2*self.Border) + (2*self.SelectionWidth) + 1;
            end
        end

    end


    methods (Access = private)

        %--Create UI-------------------------------------------------------
        function createUI(self,haxes)

            self.SelectionUI = rectangle('Parent',haxes,'Visible','on',...
                'HitTest','off','PickableParts','none',...
                'FaceColor','none','EdgeColor','none');

            self.ImageUI = image('Parent',haxes,...
                'Visible','off','HitTest','off','PickableParts','none','Interpolation','bilinear');

            self.HitListener = event.listener(self.SelectionUI,'Hit',@(~,~) notify(self,'EntryClicked'));

        end

        %--Create File Name UI---------------------------------------------
        function createFileNameUI(self,haxes)
            % Defer constructing this object until we know it is needed.
            self.LabelUI = text('Parent',haxes,'Visible','on',...
                'HitTest','off','PickableParts','none','FontUnits','pixels','FontSize',12,...
                'VerticalAlignment','cap','HorizontalAlignment','center',...
                'FontName','FixedWidth','Interpreter','none','Margin',0.25);

        end

        %--Create Badge UI------------------------------------------------
        function createBadgeUI(self,haxes)
            % Defer constructing this object until we know it is needed.
            self.BadgeUI = image('Parent',haxes,...
                'Visible','off','HitTest','off','PickableParts','none');
            updatePosition(self);

        end

        %--Get Image Position----------------------------------------------
        function [xData,yData] = getImagePosition(self)
            % Compute image position. Convert the position coordinates from
            % pixels into axes dataspace coordinates for the image object
            % XData and YData. This will both place the image in the
            % correct spot and stretch the image to maintain aspect ratio.

            pos = self.PositionInternal;
            xData(1) = pos(1) + self.Border + self.SelectionWidth + 0.5;
            yData(1) = pos(2) + self.Border + self.SelectionWidth + 0.5;
            xData(2) = pos(1) + pos(3) - self.Border - getLabelWidth(self) - self.SelectionWidth - 0.5;
            yData(2) = pos(2) + pos(4) - self.Border - getLabelHeight(self) - self.SelectionWidth - 0.5;

            if yData(2) < yData(1)
                yData(2) = yData(1) + 1;
            end

            sz = size(self.ImageUI.CData);

            % Determine aspect ratio
            AR = sz(1)/sz(2);

            % Stretch the image in the appropriate dimension to occupy as
            % much of the alloted space as possible while still maintaining
            % aspect ratio.
            if AR > 1
                if (yData(2) - yData(1)) / (xData(2) - xData(1)) > AR
                    % Span full width
                    height = (xData(2) - xData(1) + 1)*AR;
                    center = ((yData(2) - yData(1))/2) + yData(1);
                    yData = [center - (height/2), center + (height/2)];
                else
                    % Span full height
                    width = (yData(2) - yData(1) + 1)/AR;
                    center = ((xData(2) - xData(1))/2) + xData(1);
                    xData = [center - (width/2), center + (width/2)];
                end
            else
                if (yData(2) - yData(1)) / (xData(2) - xData(1)) < AR
                    % Span full height
                    width = (yData(2) - yData(1) + 1)/AR;
                    center = ((xData(2) - xData(1))/2) + xData(1);
                    xData = [center - (width/2), center + (width/2)];
                else
                    % Span full width
                    height = (xData(2) - xData(1) + 1)*AR;
                    center = ((yData(2) - yData(1))/2) + yData(1);
                    yData = [center - (height/2), center + (height/2)];
                end
            end

        end

        %--Get Selection Position------------------------------------------
        function pos = getSelectionPosition(self)

            pos = self.PositionInternal;
            pos(1) = pos(1) + self.Border;
            pos(2) = pos(2) + self.Border;
            pos(3) = pos(3) - (2*self.Border);
            pos(4) = pos(4) - (2*self.Border);

        end

        %--Update Position-------------------------------------------------
        function updatePosition(self)
            % Reposition all objects in the entry based on the values held
            % in the Position property.
            if ~isempty(self.ImageUI)
                [xData,yData] = getImagePosition(self);
                set(self.ImageUI,'XData',xData,'YData',yData);
                set(self.SelectionUI,'Position',getSelectionPosition(self));
                if ~isempty(self.BadgeUI)
                    switch self.BadgeLocationInternal
                        case "southwest"
                            set(self.BadgeUI,'XData',[xData(1) - self.Border, xData(1) - self.Border + 15],'YData',[yData(2) + self.Border - 15, yData(2) + self.Border]);
                        case "northeast"
                            set(self.BadgeUI,'XData',[xData(2) + self.Border - 15, xData(2) + self.Border],'YData',[yData(1) - self.Border, yData(1) - self.Border + 15]);
                        case "northwest"
                            set(self.BadgeUI,'XData',[xData(1) - self.Border, xData(1) - self.Border + 15],'YData',[yData(1) - self.Border, yData(1) - self.Border + 15]);
                        case "southeast"
                            set(self.BadgeUI,'XData',[xData(2) + self.Border - 15, xData(2) + self.Border],'YData',[yData(2) + self.Border - 15, yData(2) + self.Border]);
                    end
                end
                if self.LabelVisibleInternal
                    if self.LabelLocationInternal == "bottom"
                        set(self.LabelUI,'Position',[self.PositionInternal(1) + (self.PositionInternal(3)/2),yData(2)]);
                    elseif self.LabelLocationInternal == "right"
                        set(self.LabelUI,'Position',[self.PositionInternal(1) + (self.PositionInternal(3) - getLabelWidth(self)) - self.Border,self.PositionInternal(2) + (self.PositionInternal(4)/2)]);
                    else
                        set(self.LabelUI,'Position',[xData(1),yData(2)]);
                    end
                end
            end
        end

        %--Update Label Properties-----------------------------------------
        function updateLabelProperties(self)

            if self.LabelVisibleInternal
                switch self.LabelLocationInternal
                    case "bottom"
                        set(self.LabelUI,'VerticalAlignment','cap','HorizontalAlignment','center','BackgroundColor','none');
                    case "right"
                        set(self.LabelUI,'VerticalAlignment','middle','HorizontalAlignment','left','BackgroundColor','none');
                    case "overlay"
                        set(self.LabelUI,'VerticalAlignment','bottom','HorizontalAlignment','left','BackgroundColor',self.SelectedColorInternal);
                end
                if self.LabelTextColorMode == "manual"
                    set(self.LabelUI,'Color',self.LabelTextColorInternal);
                end
            end

        end

        %--Get Label Height------------------------------------------------
        function val = getLabelHeight(self)
            % Compute height needed for the label, if any.
            if self.LabelVisibleInternal && self.LabelLocationInternal == "bottom"
                val = self.LabelHeight;
            else
                val = 0;
            end
        end

        %--Get Label Width-------------------------------------------------
        function val = getLabelWidth(self)
            % Compute width needed for label, if any.
            if self.LabelVisibleInternal && self.LabelLocationInternal == "right"
                % Right label location assigns a square region to the image
                % and any remaining region to the label.
                val = (self.PositionInternal(3) - self.EntrySizeInternal(2) - (2*self.SelectionWidth) - self.Border);
                if val < 1
                    val = 1;
                end
                val = val + self.Border;
            else
                val = 0;
            end
        end

        %--Maximum Allowable Number Of Characters--------------------------
        function val = maximumAllowableNumCharacters(self)
            % Maximum number of characters allowed based on the space we
            % have available.
            if self.LabelLocationInternal == "bottom"
                val = floor((self.PositionInternal(3) - (2*self.SelectionWidth) - self.Border)/self.CharacterScaleFactor);
                if val < 0
                    val = 0;
                end
            elseif self.LabelLocationInternal == "right"
                val = floor(((self.PositionInternal(3) - self.EntrySizeInternal(2) - (2*self.SelectionWidth) - self.Border))/self.CharacterScaleFactor);
                if val < 0
                    val = 0;
                end
            else
                [xData,~] = getImagePosition(self);
                val = floor((xData(2) - xData(1))/self.CharacterScaleFactor);
                if val < 0
                    val = 0;
                end
            end

        end

    end


    methods

        %------------------------------------------------------------------
        % Image
        %------------------------------------------------------------------
        function set.Image(self,img)

            if isempty(img)
                repositionImage = ~isequal(size(self.ImageUI.CData,1,2),size(self.Icons.Placeholder,1,2));
                self.ImageUI.CData = self.Icons.Placeholder;
            else
                repositionImage = ~isequal(size(self.ImageUI.CData,1,2),size(img,1,2));
                self.ImageUI.CData = img;
            end

            if repositionImage
                updatePosition(self);
            end

        end

        %------------------------------------------------------------------
        % Selected
        %------------------------------------------------------------------
        function set.Selected(self,TF)

            if self.SelectedInternal == TF && ~self.HotSelectedInternal
                return;
            end

            self.SelectedInternal = TF;
            self.HotSelectedInternal = false;

            if TF
                set(self.SelectionUI,'FaceColor',self.SelectedColorInternal,'EdgeColor',self.EdgeColorInternal);
            else
                set(self.SelectionUI,'FaceColor','none','EdgeColor','none');
            end

        end

        function TF = get.Selected(self)
            TF = self.SelectedInternal;
        end

        %------------------------------------------------------------------
        % Hot Selected
        %------------------------------------------------------------------
        function set.HotSelected(self,TF)

            self.HotSelectedInternal = TF;

            if TF 
                if self.SelectedInternal
                    set(self.SelectionUI,'FaceColor',self.HotSelectedColorInternal);
                else
                    set(self.SelectionUI,'FaceColor','none','EdgeColor','none');
                end
            else
                if self.SelectedInternal
                    set(self.SelectionUI,'FaceColor',self.SelectedColorInternal,'EdgeColor',self.EdgeColorInternal);
                else
                    set(self.SelectionUI,'FaceColor','none','EdgeColor','none');
                end
            end

        end

        function TF = get.HotSelected(self)
            TF = self.HotSelectedInternal;
        end

        %------------------------------------------------------------------
        % Visible
        %------------------------------------------------------------------
        function set.Visible(self,TF)

            if TF
                if strcmp(self.ImageUI.Visible,'on')
                    return;
                end

                set(self.ImageUI,'Visible','on');
                if self.SelectedInternal
                    set(self.SelectionUI,'FaceColor',self.SelectedColorInternal,'EdgeColor',self.EdgeColorInternal,'HitTest','on','PickableParts','all');
                else
                    set(self.SelectionUI,'FaceColor','none','EdgeColor','none','HitTest','on','PickableParts','all');
                end
                if self.LabelVisibleInternal
                    set(self.LabelUI,'Visible','on');
                end
                if ~isempty(self.BadgeUI)
                    if self.BadgeInternal ~= images.internal.app.browser.data.Badge.Empty
                        set(self.BadgeUI,'Visible','on');
                    else
                        set(self.BadgeUI,'Visible','off');
                    end
                end
            else
                if strcmp(self.ImageUI.Visible,'off')
                    return;
                end

                set(self.ImageUI,'Visible','off');
                set(self.SelectionUI,'FaceColor','none','EdgeColor','none','HitTest','off','PickableParts','none');
                if ~isempty(self.LabelUI)
                    set(self.LabelUI,'Visible','off');
                end
                if ~isempty(self.BadgeUI)
                    set(self.BadgeUI,'Visible','off');
                end
            end

        end

        function TF = get.Visible(self)
            TF = isvalid(self.ImageUI) && strcmp(self.ImageUI.Visible,'on');
        end

        %------------------------------------------------------------------
        % Position
        %------------------------------------------------------------------
        function set.Position(self,pos)
            self.PositionInternal = pos;
            updatePosition(self);
        end

        function pos = get.Position(self)
            pos = self.PositionInternal;
        end

        %------------------------------------------------------------------
        % Context Menu
        %------------------------------------------------------------------
        function set.ContextMenu(self,menu)
            self.SelectionUI.ContextMenu = menu;
        end

        function menu = get.ContextMenu(self)
            menu = self.SelectionUI.ContextMenu;
        end
        
        %------------------------------------------------------------------
        % Entry Size
        %------------------------------------------------------------------
        function set.EntrySize(self,val)
            self.EntrySizeInternal = val;
        end

        function val = get.EntrySize(self)
            val = self.EntrySizeInternal;
        end

        %------------------------------------------------------------------
        % Selected Color
        %------------------------------------------------------------------
        function set.SelectedColor(self,color)
            self.SelectedColorInternal = color;
            if self.SelectedInternal
                set(self.SelectionUI,'FaceColor',self.SelectedColorInternal,'EdgeColor',self.EdgeColorInternal);
            end
            updateLabelProperties(self);
        end

        function color = get.SelectedColor(self)
            color = self.SelectedColorInternal;
        end

        %------------------------------------------------------------------
        % Hot Selected Color
        %------------------------------------------------------------------
        function set.HotSelectedColor(self,color)
            self.HotSelectedColorInternal = color;
            if self.HotSelectedInternal
                set(self.SelectionUI,'FaceColor',self.HotSelectedColorInternal,'EdgeColor',self.EdgeColorInternal);
            end
            updateLabelProperties(self);
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
            updateLabelProperties(self);
        end

        function color = get.LabelTextColor(self)
            color = self.LabelUI.Color;
        end

        %------------------------------------------------------------------
        % Badge
        %------------------------------------------------------------------
        function set.Badge(self,val)

            if self.BadgeInternal == val
                return;
            end

            self.BadgeInternal = val;

            % Defer constructing the badge UI object until we know we need
            % it.
            switch val
                case images.internal.app.browser.data.Badge.Empty
                    if ~isempty(self.BadgeUI)
                        set(self.BadgeUI,'Visible','off');
                    end
                case images.internal.app.browser.data.Badge.Done
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.DoneIcon,'AlphaData',self.Icons.DoneIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.Error
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.ErrorIcon,'AlphaData',self.Icons.ErrorIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.Stale
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.StaleIcon,'AlphaData',self.Icons.StaleIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.Waiting
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.WaitingIcon,'AlphaData',self.Icons.WaitingIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.FullCheckerboard
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.FullCheckerboardIcon,'AlphaData',self.Icons.FullCheckerboardIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.PartialCheckerboard
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.PartialCheckerboardIcon,'AlphaData',self.Icons.PartialCheckerboardIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.Selected
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.SelectedIcon,'AlphaData',self.Icons.SelectedIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.Warning
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.WarningIcon,'AlphaData',self.Icons.WarningIconAlpha,'Visible',self.ImageUI.Visible);

               case images.internal.app.browser.data.Badge.LabelingRequired
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.LabelingRequiredIcon,'AlphaData',self.Icons.LabelingRequiredIconAlpha,'Visible',self.ImageUI.Visible);
        
               case images.internal.app.browser.data.Badge.LabelingInProgress
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.LabelingInProgressIcon,'AlphaData',self.Icons.LabelingInProgressIconAlpha,'Visible',self.ImageUI.Visible);

                case images.internal.app.browser.data.Badge.ReviewRequiredUnsent
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.ReviewRequiredUnsentIcon,'AlphaData',self.Icons.ReviewRequiredUnsentIconAlpha,'Visible',self.ImageUI.Visible);
    
                case images.internal.app.browser.data.Badge.ReviewRequired
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.ReviewRequiredIcon,'AlphaData',self.Icons.ReviewRequiredIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.ReviewInProgress
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.ReviewInProgressIcon,'AlphaData',self.Icons.ReviewInProgressIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.ReadyForExportUnsent
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.ReadyForExportUnsentIcon,'AlphaData',self.Icons.ReadyForExportUnsentIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.ReadyToExport
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.ReadyToExportIcon,'AlphaData',self.Icons.ReadyToExportIconAlpha,'Visible',self.ImageUI.Visible);
               case images.internal.app.browser.data.Badge.InUnpublishedLT
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.InUnpublishedLTIcon,'AlphaData',self.Icons.InUnpublishedLTIconAlpha,'Visible',self.ImageUI.Visible);
        
               case images.internal.app.browser.data.Badge.LockedByLabeler
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.LockedByLabelerIcon,'AlphaData',self.Icons.LockedByLabelerIconAlpha,'Visible',self.ImageUI.Visible);

                case images.internal.app.browser.data.Badge.LabelDoneNeedRT
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.LabelDoneNeedRTIcon,'AlphaData',self.Icons.LabelDoneNeedRTIconAlpha,'Visible',self.ImageUI.Visible);
    
                case images.internal.app.browser.data.Badge.InUnpublishedRT
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.InUnpublishedRTIcon,'AlphaData',self.Icons.InUnpublishedRTIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.LockedByReviewer
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.LockedByReviewerIcon,'AlphaData',self.Icons.LockedByReviewerIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.LabelReviewDone
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.LabelReviewDoneIcon,'AlphaData',self.Icons.LabelReviewDoneIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.DoneUnsent
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.DoneUnsentIcon,'AlphaData',self.Icons.DoneUnsentIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.DoneSent
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.DoneSentIcon,'AlphaData',self.Icons.DoneSentIconAlpha,'Visible',self.ImageUI.Visible);
                case images.internal.app.browser.data.Badge.RejectedUnsent
                    if isempty(self.BadgeUI)
                        createBadgeUI(self,self.ImageUI.Parent);
                    end
                    set(self.BadgeUI,'CData',self.Icons.RejectedUnsentIcon,'AlphaData',self.Icons.RejectedUnsentIconAlpha,'Visible',self.ImageUI.Visible);
                    
            end

        end

        function val = get.Badge(self)
            val = self.BadgeInternal;
        end

        %------------------------------------------------------------------
        % Label
        %------------------------------------------------------------------
        function set.Label(self,val)

            if isempty(val)
                self.LabelInternal = "";
            else
                self.LabelInternal = val;
            end

            n = maximumAllowableNumCharacters(self);
            % If the label is too long, trim it down to the maximum
            % allowable length, then trim off the first three characters
            % and replace with '...'. For edge cases where we don't even
            % have enough space for '...', just place an empty string.
            if max(strlength(self.LabelInternal)) > n
                for idx = 1:numel(self.LabelInternal)
                    if strlength(self.LabelInternal(idx)) > n
                        if n > 4
                            str = char(self.LabelInternal(idx));
                            if self.LabelLocationInternal == "bottom"
                                self.LabelInternal(idx) = strcat("...",str(end-(n-4):end));
                            else
                                self.LabelInternal(idx) = strcat(str(1:n-3),"...");
                            end
                        else
                            self.LabelInternal(idx) = "";
                        end
                    end
                end
            end
            if ~isempty(self.LabelUI)
                if self.LabelLocationInternal == "right"
                    set(self.LabelUI,'String',self.LabelInternal);
                else
                    % bottom and overlay locations only support one line
                    % labels
                    set(self.LabelUI,'String',self.LabelInternal(1));
                end
            end
        end

        function val = get.Label(self)
            val = self.LabelInternal;
        end

        %------------------------------------------------------------------
        % Label Visible
        %------------------------------------------------------------------
        function set.LabelVisible(self,TF)

            if self.LabelVisibleInternal == TF
                return;
            end

            self.LabelVisibleInternal = TF;
            if TF && isempty(self.LabelUI)
                createFileNameUI(self,self.ImageUI.Parent);
            elseif ~isempty(self.LabelUI)
                if TF
                    set(self.LabelUI,'Visible','on');
                else
                    set(self.LabelUI,'Visible','off');
                end
            end

        end

        function TF = get.LabelVisible(self)
            TF = self.LabelVisibleInternal;
        end

        %------------------------------------------------------------------
        % Label Location
        %------------------------------------------------------------------
        function set.LabelLocation(self,loc)
            self.LabelLocationInternal = loc;
            updateLabelProperties(self);
        end

        function loc = get.LabelLocation(self)
            loc = self.LabelLocationInternal;
        end

        %------------------------------------------------------------------
        % Badge Location
        %------------------------------------------------------------------
        function set.BadgeLocation(self,loc)
            self.BadgeLocationInternal = loc;
        end
        
        function loc = get.BadgeLocation(self)
            loc = self.View.BadgeLocation;
        end
    end

end
