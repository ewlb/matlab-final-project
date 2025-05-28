%

% Copyright 2016-2020 The MathWorks, Inc.

classdef Thumbnails < images.internal.app.utilities.thumbnail.GriddedAxes
    
    properties (Constant = true)
        SelectionColor = uint8([131, 202, 253 ]);
    end
    
    properties
        %ThumbnailSize - only used to resize placeholders and create
        %thumbnails
        ThumbnailSize;
        
        BlockNumToImageNum = []; % used for sorting/filtering
        ImageNumToDataInd  = []; % indices into hImageData
        hImageData         = []; % struct array with handles
        
        % SelectionPatchInset - negative space around the selection patch
        % relative to the block. Used to show separation between adjacent
        % blocks.
        SelectionPatchInset = 4;
    end
    
    
    properties (SetAccess=private)
        CurrentSelection = [];
        hContextMenu = [];
        % Corrupted images
        CorruptedImagePlaceHolder
        %
        PlaceHolderImage
    end
    
    properties (SetAccess = protected)
        EnableMultiSelect = true;
    end
    
    properties (Access = private)
        ShiftSelectionBlockNumAnchor = [];
        % Selection patch, initialize with empty graphics object
        hSelectionPatch  = gobjects(0);
    end
    
    properties (Abstract, SetAccess = protected)
        NumberOfThumbnails
    end
    
    events
        SelectionChange;
        OpenSelection;
        DeleteSelection;
    end
    
    methods
        function thumbs = Thumbnails(hParent, blockSize)
            thumbs@images.internal.app.utilities.thumbnail.GriddedAxes(hParent);
            thumbs.BlockSize     = blockSize;
            thumbs.ThumbnailSize = blockSize;
            thumbs.init();
            
            thumbs.hContextMenu = ...
                uicontextmenu('Parent', ancestor(thumbs.hAxes,'figure'),...
                'Callback',@thumbs.showContextMenu);
            thumbs.hAxes.UIContextMenu = thumbs.hContextMenu;
        end
        
        function showContextMenu(varargin)
            % stub
        end
        
        function exportToWorkSpace(thumbs, varargin)
            % will only be called for single selection
            im = thumbs.readFullImage(thumbs.CurrentSelection(1));
            dlg = images.internal.app.dicom.export2wsdlg([1,1],"im",string([getString(message('images:commonUIString:saveAs')) ':']),{im}); 
        end
        
        function refreshThumbnails(thumbs)
            % Clears out all thumbnails, and reloads _all_ of them from the
            % data sources (*expensive*!)
            if(~isempty(thumbs.hAxes))
                % Clear out existing thumbnails
                cla(thumbs.hAxes);
                
                thumbs.hImageData = [];
                thumbs.ImageNumToDataInd = zeros(1,thumbs.NumberOfThumbnails);
                % Default - no filter, no sorting
                thumbs.BlockNumToImageNum = 1:thumbs.NumberOfThumbnails;
                thumbs.NumBlocks = thumbs.NumberOfThumbnails;
                
                thumbs.updateGridLayout();
                if isempty(thumbs.CurrentSelection)
                    thumbs.scrollToImageNum(1);
                else
                    thumbs.scrollToImageNum(thumbs.CurrentSelection(end));
                    % Re-mark the selections
                    thumbs.markCurrentSelection();
                end
            end
        end
        
        function recreateThumbnails(thumbs, imageNums)
            % Remove images from view and cache
            hImageInds = thumbs.ImageNumToDataInd(imageNums);
            % Ignore images not created yet
            hImageInds(hImageInds==0)=[];
            
            % Remove thumbnail and associated HG elements from view
            hgObjNames = fieldnames(thumbs.hImageData);
            for hImageInd = hImageInds
                for gInd = 1:numel(hgObjNames)
                    hgObj = thumbs.hImageData(hImageInd).(hgObjNames{gInd});
                    if isvalid(hgObj)
                        delete(hgObj);
                    end
                end
            end
            thumbs.ImageNumToDataInd(imageNums) = 0;
            
            % Recreate and add the removed thumbnails
            thumbs.updateGridLayout();
        end
        
        function filter(thumbs, filterInds)
            % Values should be in the range 0 to number of images in the
            % data source. A value of 0 implies 'hide' this thumbnail.
            
            % Don't delete anything - just reposition
            thumbs.NumberOfThumbnails = nnz(filterInds);
            thumbs.NumBlocks = thumbs.NumberOfThumbnails;
            thumbs.BlockNumToImageNum = filterInds(filterInds~=0);
            
            thumbs.updateGridLayout();
            
            if numel(intersect(thumbs.CurrentSelection, filterInds))...
                    ~= numel(thumbs.CurrentSelection)
                % If any of the current selection is not visible in the
                % filtered list, reset selection
                thumbs.CurrentSelection = filterInds(1);
                thumbs.markCurrentSelection();
                thumbs.scrollToImageNum(thumbs.CurrentSelection(1));
            end
        end
        
        function set.ThumbnailSize(thumbs, newSize)
            thumbs.ThumbnailSize = newSize;
            im = ...
                imread(fullfile(matlabroot,'toolbox','images','icons','PlaceHolderImage_72.png'));
            thumbs.PlaceHolderImage = imresize(im,newSize); %#ok<MCSUP>
            im = ...
                imread(fullfile(matlabroot,'toolbox','images','icons','CorruptedImage_72.png'));
            thumbs.CorruptedImagePlaceHolder = imresize(im, newSize); %#ok<MCSUP>
        end
        
        function set.CurrentSelection(thumbs, newSelection)
            if ~thumbs.EnableMultiSelect && numel(newSelection)>1%#ok<MCSUP>
                return; % reject selection change request
            end
            
            if isequal(thumbs.CurrentSelection, newSelection)
                return;
            end
            
            thumbs.CurrentSelection = newSelection;
            notify(thumbs,'SelectionChange');
        end
        
        % Mouse
        function mouseButtonDownFcn(thumbs, ~, hEvent)
            blockNum = thumbs.getCurrentClickBlock();
            if(blockNum>thumbs.NumberOfThumbnails)
                % Outside area of thumbnails
                return;
            end
            imageNum = thumbs.BlockNumToImageNum(blockNum);
            
            switch(hEvent.Source.SelectionType)
                case 'normal'
                    if ismac
                        specialKeys = hEvent.Source.CurrentModifier;
                        if any(strcmp(specialKeys, 'command'))
                            thumbs.addRemoveFromSelection(imageNum);
                        else
                            thumbs.setSelection(imageNum);
                        end
                    else
                        thumbs.setSelection(imageNum);
                    end
                case 'open'
                    thumbs.setSelection(imageNum);
                    notify(thumbs,'OpenSelection');
                case 'alt'
                    specialKeys = hEvent.Source.CurrentModifier;
                    if any(strcmp(specialKeys, 'control'))
                        thumbs.addRemoveFromSelection(imageNum);
                    else
                        % triggered by a right click
                        if ismember(imageNum, thumbs.CurrentSelection)
                            % Do nothing, context menu will be shown by
                            % code elsewhere and it will apply to current
                            % selection.
                        else
                            % Right clicked on something that's not in
                            % current selection, move selection...
                            thumbs.setSelection(imageNum);
                        end
                    end
                case 'extend'
                    % shift+click - always adds to collection
                    blockNum = find(thumbs.BlockNumToImageNum==imageNum);
                    if thumbs.ShiftSelectionBlockNumAnchor>blockNum
                        blockNums = blockNum:thumbs.ShiftSelectionBlockNumAnchor-1;
                        imageNums = thumbs.BlockNumToImageNum(blockNums);
                        thumbs.addToSelection(imageNums);
                    else
                        blockNums = thumbs.ShiftSelectionBlockNumAnchor+1:blockNum;
                        imageNums = thumbs.BlockNumToImageNum(blockNums);
                        thumbs.addToSelection(imageNums);
                    end
            end
        end
        
        % Keyboard
        function keyPressFcn(thumbs, ~, hEvent)
            if ~isempty(hEvent.Modifier)...
                    && (any(strcmp(hEvent.Modifier,'control'))...
                    ||any(strcmp(hEvent.Modifier,'command')))
                if strcmpi(hEvent.Key,'a')
                    % Only ctrl+a is supported with CTRL modifier
                    imageNums = thumbs.BlockNumToImageNum(1:thumbs.NumberOfThumbnails);
                    thumbs.setSelection(imageNums);
                end
                return;
            end
            
            if isempty(thumbs.CurrentSelection)
                % Rest of the keyevents are only defined when there is a
                % valid selection
                return;
            end
            
            if strcmp(hEvent.Modifier,'shift')
                oldBlockNum = thumbs.ShiftSelectionBlockNumAnchor;
            else
                oldImageNum = thumbs.CurrentSelection(end);
                oldBlockNum = find(thumbs.BlockNumToImageNum==oldImageNum);
            end
            
            rowNum = ceil(oldBlockNum/thumbs.GridSize(2));
            colNum = oldBlockNum-(rowNum-1)*thumbs.GridSize(2);
            
            blockNum = [];
            switch(hEvent.Key) %TODO - use Layout
                case 'downarrow'
                    if thumbs.GridSize(1)==1
                        colNum = colNum+1;
                    else
                        rowNum = rowNum+1;
                    end
                    blockNum = (rowNum-1)*thumbs.GridSize(2)+colNum;
                    blockNum = min(blockNum,thumbs.NumberOfThumbnails);
                case 'pagedown'
                    numCols = 1;
                    if thumbs.GridSize(2)~=1
                        % i.e 'fill', find actual count
                        numCols = floor(diff(thumbs.hAxes.XLim)/thumbs.BlockSize(2));
                    end
                    numRows = 1;
                    if thumbs.GridSize(1)~=1
                        numRows = ceil(diff(thumbs.hAxes.YLim)/thumbs.BlockSize(1));
                    end
                    blockNum = oldBlockNum+numCols*numRows;
                    blockNum = min(blockNum,thumbs.NumberOfThumbnails);
                case 'uparrow'
                    if thumbs.GridSize(1)==1
                        colNum = colNum-1;
                    else
                        rowNum = rowNum-1;
                    end
                    blockNum = (rowNum-1)*thumbs.GridSize(2)+colNum;
                    blockNum = max(blockNum,1);
                case 'pageup'
                    numCols = 1;
                    if thumbs.GridSize(2)~=1
                        numCols = floor(diff(thumbs.hAxes.XLim)/thumbs.BlockSize(2));
                    end
                    numRows = 1;
                    if thumbs.GridSize(1)~=1
                        numRows = ceil(diff(thumbs.hAxes.YLim)/thumbs.BlockSize(1));
                    end
                    blockNum = oldBlockNum-numCols*numRows;
                    blockNum = max(blockNum,1);
                case 'leftarrow'
                    colNum = colNum-1;
                    blockNum = (rowNum-1)*thumbs.GridSize(2)+colNum;
                    blockNum = max(blockNum,1);
                case 'rightarrow'
                    colNum = colNum+1;
                    blockNum = (rowNum-1)*thumbs.GridSize(2)+colNum;
                    blockNum = min(blockNum,thumbs.NumberOfThumbnails);
                case 'home'
                    blockNum = 1;
                case 'end'
                    blockNum = thumbs.NumberOfThumbnails;
                case {'delete','backspace'}
                    notify(thumbs, 'DeleteSelection');
                    return;
                case 'return'
                    notify(thumbs,'OpenSelection');
            end
            
            if(blockNum)
                if strcmp(hEvent.Modifier,'shift')
                    if thumbs.ShiftSelectionBlockNumAnchor>blockNum
                        blockNums = fliplr(blockNum:thumbs.ShiftSelectionBlockNumAnchor-1);
                        imageNums = thumbs.BlockNumToImageNum(blockNums);
                        thumbs.addToSelection(imageNums);
                    else
                        blockNums = thumbs.ShiftSelectionBlockNumAnchor+1:blockNum;
                        imageNums = thumbs.BlockNumToImageNum(blockNums);
                        thumbs.addToSelection(imageNums);
                    end
                else
                    imageNum = thumbs.BlockNumToImageNum(blockNum);
                    thumbs.setSelection(imageNum);
                end
            end
        end
    end
    
    methods (Abstract)
        % Called on each block that's visible in a changed viewport
        updateBlockWithPlaceholder(gax, topLeftYX, imageNum);
        updateBlockWithActual(gax, topLeftYX, imageNum);
    end
    
    % Required implementation of Abstract base class methods
    methods
        function positionsInvalidated(thumbs)
            % Hide all re-positioned thumbnails
            positionedThumbnailInds = ...
                thumbs.ImageNumToDataInd(thumbs.ImageNumToDataInd~=0);
            if ~isempty(positionedThumbnailInds)
                % Hide all previously rendered HG objects since their
                % positions needs to be recalculated.
                hgObjNames = fieldnames(thumbs.hImageData(positionedThumbnailInds));
                for gInd = 1:numel(hgObjNames)
                    hgObjs = [thumbs.hImageData(positionedThumbnailInds).(hgObjNames{gInd})];
                    validObjs = hgObjs.isvalid;
                    set(hgObjs(validObjs),'Visible','off');
                end
            end
            % Reposition selection
            thumbs.markCurrentSelection();
            if ~isempty(thumbs.CurrentSelection)
                % and ensure its visible
                thumbs.scrollToImageNum(thumbs.CurrentSelection(1));
            end
        end
    end
    
    methods
        function putPlaceHolders(thumbs, topLeftYX, blockNum)
            imageNum = thumbs.BlockNumToImageNum(blockNum);
            thumbs.updateBlockWithPlaceholder(topLeftYX, imageNum);
        end
        
        function putActual(thumbs, topLeftYX, blockNum)
            imageNum = thumbs.BlockNumToImageNum(blockNum);
            thumbs.updateBlockWithActual(topLeftYX, imageNum);
        end
        
        function scrollToImageNum(thumbs, imageNum)
            blockNum = find(thumbs.BlockNumToImageNum==imageNum);
            thumbs.scrollToBlockNum(blockNum); %#ok<FNDSB>
        end
    end
    
    methods (Access = protected)
        % Protected access since the data layer should ensure data is in
        % sync with any addition/deletion from the view
        function removeImages(thumbs, inds)
            % Remove images from view and cache - assume its also removed
            % from data source
            hImageInds = thumbs.ImageNumToDataInd(inds);
            % Ignore images not created yet while deleting
            hImageInds(hImageInds==0)=[];
            
            % Remove thumbnail and associated HG elements from view
            hgObjNames = fieldnames(thumbs.hImageData);
            for hImageInd = hImageInds
                for gInd = 1:numel(hgObjNames)
                    hgObj = thumbs.hImageData(hImageInd).(hgObjNames{gInd});
                    if isvalid(hgObj)
                        delete(hgObj);
                    end
                end
            end
            % Also removecached thumbnail data
            thumbs.hImageData(hImageInds)  = [];
            
            % Update book - fill the holes of the deleted images by sliding
            % the next image(s) over.
            newNumToDataInd = thumbs.ImageNumToDataInd;
            for hImageInd = hImageInds
                % For every lookup index deleted, move all indices above it
                % down by one.
                newNumToDataInd(thumbs.ImageNumToDataInd>hImageInd) = ...
                    newNumToDataInd(thumbs.ImageNumToDataInd>hImageInd)-1;
            end
            % Remove indices of deleted thumbnails
            newNumToDataInd(inds) = [];
            thumbs.ImageNumToDataInd = newNumToDataInd;
            
            % Update number of blocks the gridded axes needs to account for
            thumbs.NumBlocks = thumbs.NumBlocks-numel(inds);
        end
        
        function appendSpaceForNImages(thumbs, N)
            % Add space for N more images to the thumbnail view and cache.
            % Assume that the data source has N more images.
            thumbs.ImageNumToDataInd(end+N) = 0;
            thumbs.BlockNumToImageNum = 1:thumbs.NumberOfThumbnails;
            thumbs.NumBlocks = thumbs.NumberOfThumbnails;
        end
    end
    
    methods
        function thumbnail = resizeToThumbnail(thumbs, fullImage)
            if(size(fullImage,1)>size(fullImage,2))
                thumbnail = imresize(fullImage,[thumbs.ThumbnailSize(1), NaN],'nearest');
            else
                thumbnail = imresize(fullImage,[NaN, thumbs.ThumbnailSize(2)],'nearest');
            end
            % Handle thumbNail size which are larger than thumbs.ThumbnailSize
            if size(thumbnail,1)>thumbs.ThumbnailSize(1)
                thumbnail = imresize(thumbnail,[thumbs.ThumbnailSize(1), NaN]);
            end
            if size(thumbnail,2)>thumbs.ThumbnailSize(2)
                thumbnail = imresize(thumbnail,[NaN, thumbs.ThumbnailSize(2)]);
            end
        end
        
        function setSelection(thumbs, imageNums)
            % Select
            
            % Set previous selection patch visibility to off
            toHide = setdiff(thumbs.CurrentSelection,imageNums);
            hideSelectionPatch(thumbs,toHide)
            
            thumbs.CurrentSelection = imageNums;
            thumbs.markCurrentSelection();
            thumbs.scrollToImageNum(imageNums(end));
            imageNum = imageNums(end);
            thumbs.ShiftSelectionBlockNumAnchor = find(thumbs.BlockNumToImageNum==imageNum);
        end
        
        function [patchX, patchY] = getPatchVerticesForFullBlock(thumbs, topLeftYXs)
            
            patchX = zeros(4, size(topLeftYXs,1));
            patchY = zeros(4, size(topLeftYXs,1));
            
            topLeftX = topLeftYXs(:,2)';
            patchX(1, :)  = topLeftX+thumbs.SelectionPatchInset;
            patchX(2, :)  = topLeftX+thumbs.BlockSize(2)-thumbs.SelectionPatchInset;
            patchX(3, :)  = topLeftX+thumbs.BlockSize(2)-thumbs.SelectionPatchInset;
            patchX(4, :)  = topLeftX+thumbs.SelectionPatchInset;
            
            topLeftY = topLeftYXs(:,1)';
            patchY(1, :)  = topLeftY+thumbs.SelectionPatchInset;
            patchY(2, :)  = topLeftY+thumbs.SelectionPatchInset;
            patchY(3, :)  = topLeftY+thumbs.BlockSize(1)-thumbs.SelectionPatchInset;
            patchY(4, :)  = topLeftY+thumbs.BlockSize(1)-thumbs.SelectionPatchInset;
        end
        
        function markCurrentSelection(thumbs)
            if isempty(thumbs.BlockNumToImageNum)
                thumbs.CurrentSelection = [];
                delete(thumbs.hSelectionPatch);
                return;
            end
            
            imageNums = thumbs.CurrentSelection;
            blockNums = thumbs.getBlockNumbers(imageNums);
            if isempty(blockNums)
                % Filtered out, update selection to first block.
                blockNums = 1;
                imageNum = thumbs.BlockNumToImageNum(blockNums);
                thumbs.CurrentSelection = imageNum;
            end
            
            % Mark all selected thumbnails
            for ind = 1:numel(thumbs.CurrentSelection)
                topLeftYXs = getTopLeftYX(thumbs, thumbs.CurrentSelection(ind));
                placeSelectionPatch(thumbs,thumbs.CurrentSelection(ind),topLeftYXs);
                thumbs.hSelectionPatch(thumbs.CurrentSelection(ind)).Visible = 'on';
            end
        end
        
        function blockNums = getBlockNumbers(thumbs, imageNums)
            blockNums = [];
            for ind = 1:numel(imageNums)
                blockNum = find(thumbs.BlockNumToImageNum==imageNums(ind));
                if ~isempty(blockNum)
                    blockNums(end+1) = blockNum; %#ok<AGROW>
                end
            end
        end
        
        function placeSelectionPatch(thumbs,blockNum,topLeftYXs)
            % Create patch
            [patchX, patchY] = getPatchVerticesForFullBlock(thumbs, topLeftYXs);
            if (size(thumbs.hSelectionPatch,2)< blockNum)...
                    || ((size(thumbs.hSelectionPatch,2)>= blockNum)...
                    && (~isa(thumbs.hSelectionPatch(blockNum), 'matlab.graphics.primitive.Patch')...
                    || ~isvalid(thumbs.hSelectionPatch(blockNum))))
                % Create a new selection patch
                thumbs.hSelectionPatch(blockNum) =...
                    patch(patchX, patchY, thumbs.SelectionColor,...
                    'Parent',thumbs.hAxes,...
                    'Tag','SelectionPatch',...
                    'EdgeColor','none');
                thumbs.hSelectionPatch(blockNum).Visible = 'off';
                thumbs.hSelectionPatch(blockNum).UIContextMenu = thumbs.hContextMenu;
           
            elseif isvalid(thumbs.hSelectionPatch(blockNum)) ...
                    && isa(thumbs.hSelectionPatch(blockNum), 'matlab.graphics.primitive.Patch')
                % Reposition 
                set(thumbs.hSelectionPatch(blockNum),'XData', patchX);
                set(thumbs.hSelectionPatch(blockNum),'YData', patchY); 
            end
        end
    end
    
    methods (Access = private)
        function addRemoveFromSelection(thumbs, imageNums)
            toRemove = intersect(thumbs.CurrentSelection, imageNums);
            toAdd    = setdiff(imageNums, toRemove);
            if numel(thumbs.CurrentSelection)==1 ...
                    && numel(toRemove)==1 ...
                    && isempty(toAdd)
                % Cant remove last from selection
                return;
            end
            thumbs.addToSelection(toAdd);
            thumbs.removeFromSelection(toRemove);
        end
        
        function addToSelection(thumbs, imageNums)
            if isempty(imageNums)
                return;
            end
            thumbs.CurrentSelection = unique([thumbs.CurrentSelection, imageNums],'stable');
            thumbs.markCurrentSelection();
            imageNum = imageNums(end);
            thumbs.ShiftSelectionBlockNumAnchor = find(thumbs.BlockNumToImageNum==imageNum);
            thumbs.scrollToImageNum(thumbs.CurrentSelection(end));
        end
        
        function removeFromSelection(thumbs, imageNums)
            for ind=imageNums
                toHide = thumbs.CurrentSelection(thumbs.CurrentSelection==imageNums);
                hideSelectionPatch(thumbs,toHide)
                thumbs.CurrentSelection(thumbs.CurrentSelection==ind) = [];
            end
            if isempty(thumbs.CurrentSelection)
                thumbs.ShiftSelectionBlockNumAnchor = [];
            elseif any(thumbs.BlockNumToImageNum(thumbs.ShiftSelectionBlockNumAnchor)==imageNums)
                imageNum = thumbs.CurrentSelection(end);
                thumbs.ShiftSelectionBlockNumAnchor = find(thumbs.BlockNumToImageNum==imageNum);
            end
            thumbs.markCurrentSelection();
            notify(thumbs,'SelectionChange');
        end
        
        function hideSelectionPatch(thumbs,imageNums)
            for ind = 1:numel(imageNums)
                thumbs.hSelectionPatch(imageNums(ind)).Visible = 'off';
            end
        end
    end
end
