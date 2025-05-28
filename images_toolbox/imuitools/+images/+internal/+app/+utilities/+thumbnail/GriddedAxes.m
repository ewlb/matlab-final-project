%

% Copyright 2016-2020 The MathWorks, Inc.

classdef GriddedAxes < handle
    
    properties
        % BlockSize - Axis is filled with discrete blocks of this size.
        %             Note order: [BlockSizeY, BlockSizeX]
        BlockSize = [100 100];
        
        % Layout - Layout of the grid, one of "Row", "Col", or "Auto"
        %
        Layout = "Auto";
        
        % NumBlocks - Total number of blocks needed
        NumBlocks = 0;
        
        hAxes;
        
        % CoalescePeriod - time (in seconds) to wait before after the view
        % port has settled before attempting to replace placeholder
        % thumbnails with real thumbnails.
        CoalescePeriod = 1; % second
        
        % LeftMargin - margin on the left side of the axis (px)
        LeftMargin = 0;
        
        % Viewport X-Y Limits - Visible axes X-Y limits on parent panel
        ViewportXLim
        ViewportYLim
    end
    
    properties (SetAccess = private, GetAccess = protected)
        hParent;
        hParentSize;
        
        % GridSize
        GridSize;
        
        CoalesceTimer = [];
        
        % State - (of place holders being placed)
        PlacingHolders = false;
    end
    
    events
        PlacingThumbnailsStarted
        PlacingThumbnailsFinished
    end
    
    methods
        function gax = GriddedAxes(hParent)
            assert(isa(hParent,'matlab.ui.Figure') ...
                || isa(hParent,'matlab.ui.container.Panel'));
            gax.hParent = hParent;
            
            % Note SizeChangedFcn is clobbered
            % Client should call 'init' after setting required properties.
            
        end
        
        function delete(gax)
            try
                if ~isempty(gax.CoalesceTimer) && isvalid(gax.CoalesceTimer)
                    stop(gax.CoalesceTimer)
                    delete(gax.CoalesceTimer)
                end
            catch ALL %#ok<NASGU>
                % test timing causes stop to be called while timer is being
                % deleted.
            end
        end
        
        % Create UI elements, should only be called once
        function init(gax)
            gax.hAxes = uiaxes(...
                'Units','pixels',...
                'Position', [0,0,1,1],...
                'Ydir', 'reverse',...        % Place origin on top left
                'XLimMode','manual',...
                'YLimMode','manual',...
                'Tag', 'griddedAxes',...
                'XTick', [],...
                'YTick', [],...
                'XColor', 'none',...
                'YColor', 'none',...
                'NextPlot','add',...
                'Parent',gax.hParent,...
                'LooseInset',[0,0,0,0]);
            % Turn visibility off for toolbar
            gax.hAxes.Toolbar.Visible = 'off';
            
            % Ensure grayscale images show up as such
            colormap(gax.hAxes,gray);
            
            gax.hParent.AutoResizeChildren = 'off';
            gax.hParent.SizeChangedFcn = @gax.parentSizeChanged;
            
            % Fit to the initial size of parent
            gax.parentSizeChanged();
        end
        
        % Recompute axis limits, in-view blocks, issue callbacks for view
        % change. Called on parent size change or block size change.
        function updateGridLayout(gax)
            
            % Find number of blocks that will fit in current view port
            oldUnits = gax.hParent.Units;
            gax.hParent.Units = 'pixels';
            gax.hParentSize = gax.hParent.InnerPosition;
            gax.hParent.Units = oldUnits;
            
            % Reset viewport Xlim and Ylim. When blocksize changes, ensure
            % we start with a clean limit
            gax.ViewportXLim = [0, gax.hParentSize(3)];
            gax.ViewportYLim = [0, gax.hParentSize(4)];
            
            viewPortLimits = gax.hParentSize(3:4);
            % Move to Y - X order (height - width order)
            viewPortLimits = fliplr(viewPortLimits);
            
            numVisibleBlocksyx = viewPortLimits./gax.BlockSize;
            
            % GridSize
            if strcmpi(gax.Layout, "Row")
                gax.GridSize(1) = 1;
                gax.GridSize(2) = gax.NumBlocks;
            elseif strcmpi(gax.Layout, "Col")
                gax.GridSize(1) = gax.NumBlocks;
                gax.GridSize(2) = 1;
            elseif strcmpi(gax.Layout, "Auto")
                numFullVisibleBlocksyx = floor(numVisibleBlocksyx);
                % Show at least one.
                numFullVisibleBlocksyx = max(1, numFullVisibleBlocksyx);
                if numFullVisibleBlocksyx(1)==1
                    % Switch to 'Row'
                    gax.GridSize(1) = 1;
                    gax.GridSize(2) = gax.NumBlocks;
                else
                    % Vertical scroll, fill width
                    gax.GridSize(2) = numFullVisibleBlocksyx(2);
                    gax.GridSize(1) = ceil(gax.NumBlocks/numFullVisibleBlocksyx(2));
                    % Show at least one.
                    gax.GridSize = max(1, gax.GridSize);
                end
            elseif isnumeric(gax.Layout)
                if isnan(gax.Layout(1))
                    gax.GridSize(1) = ceil(gax.NumBlocks/gax.Layout(2));
                    gax.GridSize(2) = gax.Layout(2);
                    
                elseif isnan(gax.Layout(2))
                    gax.GridSize(1) = gax.Layout(1);
                    gax.GridSize(2) = ceil(gax.NumBlocks/gax.Layout(1));
                    
                else
                    assert(false,'At least one element of Layout must be nan');
                end
            else
                assert(false, 'Unsupported layout');
            end
            
            totalXLim = max(gax.GridSize(2)*gax.BlockSize(2), gax.hParentSize(3));
            totalYLim = max(gax.GridSize(1)*gax.BlockSize(1), gax.hParentSize(4));
            
            % Required left padding
            if numVisibleBlocksyx(2)>1 && gax.GridSize(1)~=1
                gax.LeftMargin = gax.hParentSize(3) - floor(numVisibleBlocksyx(2))*gax.BlockSize(2);
                % Distributed on left and right
                gax.LeftMargin = gax.LeftMargin/2;
            else
                gax.LeftMargin = 1;
            end
            % Update axes position
            gax.hAxes.XLim = [0, totalXLim];
            gax.hAxes.YLim = [0, totalYLim];
            gax.hAxes.Position = [0,0,totalXLim,totalYLim];
            
            % If the parent size is changed by dragging, scrollbar location
            % will not change. This issue is reported in geck g2366062. As
            % of now, to get correct scrollbar location, slider is dragged
            % to bottom and agin to top using scroll function.
            scroll(gax.hParent, 'bottom');
            images.internal.app.imageBrowser.drawnowWrapper();
            scroll(gax.hParent, 'top');
            images.internal.app.imageBrowser.drawnowWrapper();
            
            % Position of all previously visible/created blocks will no
            % longer be valid
            gax.positionsInvalidated();
            
            % Drawnow is required for use in app container (Image Labeler),
            % otherwise successive calls to positionsInvalidated cause a
            % hang.
            images.internal.app.imageBrowser.drawnowWrapper();
            
            gax.updateViewPortWithPlaceHolders()
            
            % One more drawnow after update resolves thumbnail rendering
            % issue.
            images.internal.app.imageBrowser.drawnowWrapper();
        end
        
        % Mouse wheel scroll
        function mouseWheelFcn(gax, ~, hEvent)
            scrollBarLoc = gax.hParent.ScrollableViewportLocation;
            % Default slider width occupied on parent component
            sliderWidth = 17;
            if (gax.hAxes.InnerPosition(3) > gax.hParentSize(3)) && (gax.GridSize(1) == 1)
                % Horizontal slider is visible
                
                % Minimum and maximum values for horizontal slider
                minValue = 1;
                maxValue = gax.hAxes.InnerPosition(3)-gax.hParentSize(3)+sliderWidth;
                
                oneBlockScrollAmount = gax.BlockSize(2);
                newValue = scrollBarLoc(1) ...
                    + (hEvent.VerticalScrollCount * oneBlockScrollAmount);
                
                newValue = min(maxValue, newValue);
                newValue = max(minValue, newValue);
                
                % Update viewport XLim
                gax.ViewportXLim = [newValue-1, gax.hParentSize(3)+newValue-1];
                scroll(gax.hParent, newValue, scrollBarLoc(2));
                gax.updateViewPortWithPlaceHolders();
            elseif gax.hAxes.InnerPosition(4) > gax.hParentSize(4)
                % Vertical scroll is visible
                
                % Minimum and maximum values for horizontal slider
                minValue = 1;
                maxValue = gax.hAxes.InnerPosition(4)-gax.hParentSize(4)+sliderWidth;
                
                oneBlockScrollAmount = gax.BlockSize(1);
                newValue = scrollBarLoc(2) ...
                    - (hEvent.VerticalScrollCount * oneBlockScrollAmount);
                
                newValue = min(maxValue, newValue);
                newValue = max(minValue, newValue);
                
                % Update viewport YLim
                gax.ViewportYLim = [maxValue-newValue+1, gax.hParentSize(4)+maxValue-newValue+1];
                scroll(gax.hParent,scrollBarLoc(1),newValue);
                gax.updateViewPortWithPlaceHolders();
            end
        end
        
        % Scroll to ensure blockNum is in visible view port
        function scrollToBlockNum(gax, blockNum)
            if isempty(blockNum)
                return;
            end
            topLeftYXs = getTopLeftYX(gax, blockNum);
            scrollbarLoc = gax.hParent.ScrollableViewportLocation;
            curXLim = gax.ViewportXLim;
            curYLim = gax.ViewportYLim;
            
            % Drag scrollbar to either left or right if block is not in
            % visible XLim
            if (topLeftYXs(2)-gax.LeftMargin) < curXLim(1)
                % Drag left if the top left corner of blockNum is not
                % in current XLim range.
                drag = topLeftYXs(2)-gax.LeftMargin-curXLim(1);
                % Scroll left
                scroll(gax.hParent,scrollbarLoc(1)+drag, scrollbarLoc(2));
                % and update viewport XLim
                gax.ViewportXLim = curXLim+drag;
            elseif (topLeftYXs(2)+gax.LeftMargin+gax.BlockSize(2))>curXLim(2)
                % Drag right if the top right corner of blockNum is not
                % in current XLim range.
                drag = topLeftYXs(2)+gax.LeftMargin+gax.BlockSize(2)-curXLim(2);
                % Scroll right
                scroll(gax.hParent,scrollbarLoc(1)+drag, scrollbarLoc(2));
                % and update viewport XLim
                gax.ViewportXLim = curXLim+drag;
            end
            
            % Take current scrollbar location
            scrollbarLoc = gax.hParent.ScrollableViewportLocation;
            % Scroll up or down if block is not in visible YLim
            if topLeftYXs(1)<curYLim(1)
                % Scroll up
                drag = curYLim(1)-topLeftYXs(1);
                scroll(gax.hParent,scrollbarLoc(1),scrollbarLoc(2)+drag);
                % and update viewport YLim
                gax.ViewportYLim = curYLim - drag;
            elseif (topLeftYXs(1)+gax.BlockSize(1))>curYLim(2)
                % Scroll down
                drag = curYLim(2)-topLeftYXs(1)-gax.BlockSize(1);
                scroll(gax.hParent,scrollbarLoc(1),scrollbarLoc(2)+drag);
                % and update viewport YLim
                gax.ViewportYLim = curYLim - drag;
            end
            
            if any(gax.ViewportXLim ~= curXLim) || any(gax.ViewportYLim ~= curYLim)
                % Viewport limits changed, update place holders
                gax.updateViewPortWithPlaceHolders();
            end
        end
    end
    
    methods % helpers
        function [by, bx] = blockNum2yx(gax, blockNum)
            by = ceil(blockNum/gax.GridSize(2));
            bx = blockNum-(by-1)*gax.GridSize(2);
        end
        
        function blockNum = getCurrentClickBlock(gax)
            axesPointYX    = gax.hAxes.CurrentPoint(1,2:-1:1);
            axesPointYX(2) = axesPointYX(2)-gax.LeftMargin;
            thumnailExtent = gax.GridSize.*gax.BlockSize;
            blockNum = Inf;
            if all(axesPointYX<thumnailExtent) && all(axesPointYX>0)
                blockYX = ceil(axesPointYX./gax.BlockSize);
                blockNum = (blockYX(1)-1)*gax.GridSize(2)+blockYX(2);
            end
        end
        
        function topLeftYXs = getTopLeftYX(gax, blockNums)
            topLeftYXs = zeros(numel(blockNums),2);
            for ind = 1:numel(blockNums)
                blockNum = blockNums(ind);
                [by, bx] = gax.blockNum2yx(blockNum);
                px = (bx-1)*gax.BlockSize(2)+gax.LeftMargin;
                py = (by-1)*gax.BlockSize(1);
                topLeftYXs(ind,1) = py;
                topLeftYXs(ind,2) = px;
            end
        end
    end
    
    
    methods (Abstract)
        % Called on each block that's visible in a changed viewport
        putPlaceHolders(gax, topLeftYX, blockNum);
        putActual(gax, topLeftYX, blockNum);
        % Grid layout has changed, all positions of existing blocks are
        % invalid
        positionsInvalidated(gax);
    end
    
    methods (Access = private)
        function parentSizeChanged(gax,~,~)
            newSize = gax.hParent.InnerPosition;
            if(isequal(gax.hParentSize, newSize))
                % Already handled
                return;
            end
            gax.hParentSize = newSize;
            % Whenever the parent size changes, the axes limits and
            % position will vary. To stop invoking the callback when the
            % axes position varied, remove the callback handle. (This will
            % prevent updating viewport with placeholders multiple times)
            gax.hParent.ScrollableViewportLocationChangedFcn = '';
            gax.updateGridLayout();
            % Reassign callback handle once the grid layout and axes are
            % updated.
            gax.hParent.ScrollableViewportLocationChangedFcn = @gax.onScrollableViewportLocationChanged;
        end
        
        function onScrollableViewportLocationChanged(gax,~, evt)
            if evt.ScrollableViewportLocation(1) ~= evt.PreviousScrollableViewportLocation(1)
                % Horizontal scroll
                gax.ViewportXLim = (evt.ScrollableViewportLocation(1)-1)+[0, gax.hParentSize(3)];
                gax.updateViewPortWithPlaceHolders();
            elseif evt.ScrollableViewportLocation(2) ~= evt.PreviousScrollableViewportLocation(2)
                % Vertical scroll
                drag = evt.PreviousScrollableViewportLocation(2) - evt.ScrollableViewportLocation(2);
                % Ensure location change is valid
                if ((gax.ViewportYLim(1)+drag) > 0) && ((gax.ViewportYLim(2)+drag) > 0)
                    gax.ViewportYLim = gax.ViewportYLim+drag;
                    gax.updateViewPortWithPlaceHolders();
                end
            end
        end
        
        function [topLeftYXs, oneBasedBlockNums] = inViewBlockDetails(gax)
            % Zero based subscripts
            xSubLims = [floor(gax.ViewportXLim(1)/gax.BlockSize(2)), ...
                floor(gax.ViewportXLim(2)/gax.BlockSize(2))];
            ySubLims = [floor(gax.ViewportYLim(1)/gax.BlockSize(1)), ...
                floor(gax.ViewportYLim(2)/gax.BlockSize(1))];
            
            % Limit subs to GridSize
            ySubLims(2) = min(gax.GridSize(1)-1, ySubLims(2));
            xSubLims(2) = min(gax.GridSize(2)-1, xSubLims(2));
            
            xSubs = xSubLims(1):xSubLims(2);
            ySubs = (ySubLims(1):ySubLims(2))';
            oneBasedBlockNums = xSubs + ySubs.*gax.GridSize(2)+ 1;
            % Trim
            oneBasedBlockNums = oneBasedBlockNums(oneBasedBlockNums>0 & oneBasedBlockNums<=gax.NumberOfThumbnails);
            topLeftYXs = getTopLeftYX(gax, oneBasedBlockNums);
        end
        
        function updateViewPortWithPlaceHolders(gax)
            gax.PlacingHolders = true;
            
            [topLeftYXs, oneBasedBlockNums] = gax.inViewBlockDetails();
            
            % Call update on each block to place the placeholder
            for ind =1:numel(oneBasedBlockNums)
                placeSelectionPatch(gax,oneBasedBlockNums(ind),topLeftYXs(ind,:));
                gax.putPlaceHolders(topLeftYXs(ind,:),...
                    oneBasedBlockNums(ind));
            end
            
            % Start/reset timer to put in actual block content after a delay
            if ~isempty(gax.CoalesceTimer) && isvalid(gax.CoalesceTimer)
                stop(gax.CoalesceTimer)
                delete(gax.CoalesceTimer)
            end
            
            cb = @(varargin)gax.updateViewPortWithActuals();
            cbhandler = @(e,d) matlab.graphics.internal.drawnow.callback(cb);
            
            gax.CoalesceTimer = timer(...
                'ExecutionMode','singleShot',...
                'StartDelay',gax.CoalescePeriod,...
                'TimerFcn',cbhandler);
            start(gax.CoalesceTimer);
        end
        
        function updateViewPortWithActuals(gax)
            
            try
                % Reset placing holder status
                gax.PlacingHolders = false;
                
                [topLeftYXs, oneBasedBlockNums] = gax.inViewBlockDetails();
                
                imageNums = gax.ImageNumToDataInd(oneBasedBlockNums);
                if isvalid(gax) && ~isempty(find(imageNums,1))
                    evtData = images.internal.app.utilities.thumbnail.GeneratingThumbnailsEventData(imageNums);
                    gax.notify('PlacingThumbnailsStarted',evtData);
                end
                
                % Call update on each block to place real content
                for ind =1:numel(oneBasedBlockNums)
                    % Allow other callbacks (scrolling etc), if view port
                    % changes, PlacingHolders will get set
                    images.internal.app.imageBrowser.drawnowWrapper();
                    
                    if gax.PlacingHolders
                        % More changes happening, place real content in
                        % blocks after they settle
                        break;
                    end
                    
                    gax.putActual(topLeftYXs(ind,:),...
                        oneBasedBlockNums(ind));
                end
                
                if isvalid(gax) && ~isempty(find(imageNums,1))
                    gax.notify('PlacingThumbnailsFinished');
                end
                
            catch ALL %#ok<NASGU>
                %delete doesn't get called, hence timers are not
                %deleted and this method fails (when tool has already
                %closed)
            end
        end
    end
    
end
