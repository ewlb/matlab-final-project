classdef ThumbnailBrowser < handle
%   Class that manages the thumbnails of the imported images. This wraps
%   the thumbnail Browser class that primarily does the management of the
%   thumbnails.
%   The layout of the thumbnail browser is as below:
%   Drop Down -> Select whether all or only errored images are to be
%                displayed
%   Thumbnails -> Display thumbnails based on Drop Down Selection

%   Copyright 2021-2022, The Mathworks Inc.

    properties(SetAccess=private, GetAccess=?uitest.factory.Tester)
        % Handle to the Drop Down Menu that controls the selection of the
        % files to be displayed
        FilesToShowDropDown
        
        % Thumbnail Browser
        Browser
        
        % Tag that is required for testing
        Tag = 'ThumbnailBrowserTag';
    end
    
    events
        % Event generated when an image(s) are selected
        ImageSelected
    end
    
    properties(Access=private)
        ParentFigHandle
        
        FilesDropDownUIPanel
        
        BrowserUIPanel
        
        % Listeners required for keyboard and mouse interactions.
        BrowserSelectionEvtListener;
        
        ScrollWheelListener;
        
        KeyPressListener;
        
        % List of files that errored when executing the batch function
        ErroredFilesList;

        % The Datastore that manages the thumbnails being loaded
        ThumbnailIMDS
    end
    
    properties(Access=private, Constant)
        % Constants used for laying out the thumbnail browser
        % All dimensions in pixels
        HorizMargin = 5;
        VertMargin = 5;
        DropDownHeight = 30;
        InterPanelSpacing = 5;
        DropDownAndBrowserPadding = 1;
        
        % Minimum Figure Size to perform resizing operations
        MinFigSizeForResize = 50;
    end
    
    methods
        function obj = ThumbnailBrowser(hParent, inputIMDS)
            obj.ParentFigHandle = hParent;
            obj.ParentFigHandle.AutoResizeChildren = 'off';

            % The IMDS passed in is used by the IBP UI to show preview
            % images. The thumbnail viewer will be reading images in a
            % different cadence than the preview, make a deep copy of this
            % IMDS.
            obj.ThumbnailIMDS = copy(inputIMDS);
            reset(obj.ThumbnailIMDS);
            
            % Compute the positions for the UIPanel that stores the
            % Drop-Down nd the Browser
            [dduipanelPos, tbuipanelPos] = obj.computePanelPositions();
            
            obj.FilesDropDownUIPanel = uipanel( hParent, ...
                                    'Position', dduipanelPos, ...
                                    'Tag', 'TBFilesDropDownUIPanel', ...
                                    'FontName', 'Helvetica', ...
                                    'FontSize', 12, ...
                                    'BorderType', 'none', ...
                                    'Visible', 'on' );
                                
            % Create the drop down UI
            ddList = { getString(message('images:imageList:showAll')), ...
                       getString(message('images:imageList:showErrored')) };
            
            % Make the drop-down fit within the panel with a slight padding
            ddPos = dduipanelPos;
            ddPos(1:2) = obj.DropDownAndBrowserPadding;
            ddPos(3:4) = ddPos(3:4) - 2*obj.DropDownAndBrowserPadding;
            obj.FilesToShowDropDown = uidropdown( obj.FilesDropDownUIPanel, ...
                                    'Position', ddPos, ...
                                    'Items', ddList, ...
                                    'ItemsData', [1 2], ...
                                    'Value', 1, ...
                                    'Editable', 'off', ...
                                    'ValueChangedFcn', @obj.filesToShowChanged );
                                
            % Create the UI elements corresponding to the thumbnail browser
            
            % Create the uipanel that will hold the thumbnail browser
            obj.BrowserUIPanel = uipanel( hParent, ...
                                    'Position', tbuipanelPos, ...
                                    'Tag', 'TBBrowserUIPanel', ...
                                    'FontName', 'Helvetica', ...
                                    'FontSize', 12, ...
                                    'BorderType', 'none', ...
                                    'Visible', 'on' );
            obj.BrowserUIPanel.AutoResizeChildren = 'off';
            
            % Create the Browser UI
            % Make the image browser fit the panel completely
            tbPos = tbuipanelPos;
            tbPos(1:2) = obj.DropDownAndBrowserPadding;
            tbPos(3:4) = tbPos(3:4) - 2*obj.DropDownAndBrowserPadding;
            obj.Browser = images.internal.app.browser.Browser( obj.BrowserUIPanel, ...
                                                               tbPos );
            % Use a custom read function to ensure thumbnail browser has
            % consistent behaviour with the app preview generator.
            obj.Browser.ReadFcn = @obj.thumbnailReadFcn;
            obj.Browser.LabelVisible = true;
            obj.Browser.LabelLocation = "bottom";
            
            obj.ScrollWheelListener = ...
                addlistener( obj.ParentFigHandle, ...
                             'WindowScrollWheel', ...
                             @(src,evt) scroll( obj.Browser, ...
                                           evt.VerticalScrollCount ) );
                                        
            obj.KeyPressListener = ...
                addlistener( obj.ParentFigHandle, ...
                             'KeyPress', ...
                             @(src,evt) images.internal.app.browser.helper.keyPressCallback(obj.Browser, evt) );
                         
            obj.BrowserSelectionEvtListener = addlistener( obj.Browser, ...
                                'SelectionChanged', ...
                                @obj.selectionChangedFcn );
            
            obj.updateFileList(obj.ThumbnailIMDS.Files);
            
            obj.ParentFigHandle.SizeChangedFcn = @obj.sizeChangedFcn;
            
            % When the ThumbnailBrowser is first created, the size of the
            % parent figure is reported incorrectly most times. So manually
            % triggering the resize again.
            obj.sizeChangedFcn();
        end
        
        function selectFirstImage(obj)
            % Select the first image
            obj.Browser.select(1);
        end
        
        function updateIMDS(obj, imds)
            % Update the datastore that manages the images

            obj.ThumbnailIMDS = copy(imds);
            reset(obj.ThumbnailIMDS);
            obj.updateFileList(imds.Files);
        end
        
        function updateBadge(obj, imageIndx, badgeStatus)
            % Update the badge for the specified image indices to the value
            % specified. The badgeStatus is a scalar. This is sufficient
            % for our use case.
            
            isError = badgeStatus == "error";
            obj.ErroredFilesList(imageIndx) = isError;
            
            switch(badgeStatus)
                case "none"
                    imageBadge = images.internal.app.browser.data.Badge.Empty;
                case "error"
                    imageBadge = images.internal.app.browser.data.Badge.Error;
                case "done"
                    imageBadge = images.internal.app.browser.data.Badge.Done;
                case "waiting"
                    imageBadge = images.internal.app.browser.data.Badge.Waiting;
                otherwise
                    assert(false, "Invalid Badge Status");
            end
                
            obj.Browser.setBadge(imageIndx, imageBadge);
            
            % obj.updateDisplay();
        end
        
        function delete(obj)
            delete(obj.Browser);
        end
    end
    
    % Callbacks
    methods(Access=private)
        function sizeChangedFcn(obj, varargin)
            % If the panel/document size is really small, do not perform a
            % repositioning operation as the computed positions can result
            % in garbage values.
            if any(obj.ParentFigHandle.Position(3:4) < obj.MinFigSizeForResize)
                return;
            end
            
            [dduipanelPos, tbuipanelPos] = obj.computePanelPositions();
            obj.FilesDropDownUIPanel.Position = dduipanelPos;
            
            ddPos = dduipanelPos;
            ddPos(1:2) = obj.DropDownAndBrowserPadding;
            ddPos(3:4) = ddPos(3:4) - 2*obj.DropDownAndBrowserPadding;
            obj.FilesToShowDropDown.Position = ddPos;
            
            tbPos = tbuipanelPos;
            tbPos(1:2) = obj.DropDownAndBrowserPadding;
            tbPos(3:4) = tbPos(3:4) - 2*obj.DropDownAndBrowserPadding;
            obj.BrowserUIPanel.Position = tbPos;
            resize(obj.Browser, tbPos);
        end
        
        function updateFileList(obj, fileList)
            % Update the list of files that are to be viewed in the
            % browser. This is a hard reset i.e. the existing files list is
            % cleared and a new file list is populated.
            
            obj.Browser.clear();
            
            obj.Browser.add(fileList);
            
            % Initally, there are no errored files as no processing has
            % been performed.
            obj.ErroredFilesList = false(numel(fileList), 1);
        end
        
        function filesToShowChanged(obj, ~, eventData)
            % Callback that handles the drop down change
            if strcmpi(eventData.Value, eventData.PreviousValue)
                return;
            end
            
            obj.updateDisplay();
        end
        
        function selectionChangedFcn(obj, ~, eventData)
            % Callback that is fired when an image is selected.
            evtData = ...
                images.internal.app.batchProcessor.ImageSelectionEventData( ...
                                eventData.Selected, ...
                                obj.Browser.Sources(eventData.Selected) );
            
            % Fire our custom event that contains only the information
            % relevant for this App.
            notify(obj, 'ImageSelected', evtData);
        end
    end

    methods(Access=private)
        function [dduipanelPos, tbuipanelPos] = computePanelPositions(obj)
            
            % Grabbing this position at the start of the function because
            % many times the value reported can change as the app is
            % "settling". This ensures that position of both elements is
            % computed with the same parent dimensions.
            parentWidth = obj.ParentFigHandle.Position(3);
            parentHeight = obj.ParentFigHandle.Position(4);
            
            % Determine the position of the drop down and thumbnail browser
            % panels
            dduipanelPos = [ obj.HorizMargin, ...
                             parentHeight - obj.VertMargin - ...
                                obj.DropDownHeight, ...
                             parentWidth - 2*obj.HorizMargin, ...
                             obj.DropDownHeight ];
                         
            tbuipanelPos = [ obj.HorizMargin, ...
                             obj.VertMargin, ...
                             parentWidth - 2*obj.HorizMargin, ...
                             parentHeight - 2*obj.VertMargin ...
                                - obj.InterPanelSpacing ...
                                - obj.DropDownHeight ];
        end
        
        function updateDisplay(obj)
            switch(obj.FilesToShowDropDown.Value)
                case 1 % Show All
                    obj.Browser.ThumbnailVisible = true(obj.Browser.NumImages, 1);
                
                case 2 % Show Errored
                    % Using FILTER to show only the files that have errored
                    % out.

                    obj.Browser.ThumbnailVisible = obj.ErroredFilesList;

                    indxOfErroredImages = find(obj.ErroredFilesList);

                    % Select the first errored image if
                    % 1. There are images that have errored during
                    % processing AND
                    % 2. Currently selected image when displaying all
                    % images is not an errored image.
                    if ~isempty(indxOfErroredImages) && ...
                            ~any(indxOfErroredImages == obj.Browser.Selected)
                        obj.Browser.select(indxOfErroredImages(1));
                    end
                
                otherwise
                    assert(false, 'Invalid option');
            end
        end

        function [im, label, badge, userData] = thumbnailReadFcn(obj, fileName)
        % Helper function that serves as the ReadFcn for the
        % ThumbnailBrowser class.
        % This is required to unify the reading behaviour of the preview
        % and the thumbnails to ensure consistent display.
        % Also this is required to support reading thumbnails from a user
        % supplied IMDS whose ReadFcn does non-standard image reading
        
            [~, label] = fileparts(fileName);
            label = string(label);
            
            % No badge by default
            badge = images.internal.app.browser.data.Badge.Empty;
        
            % Use the preview image reading utility
            % Using the ReadFcn directly because this callback is passed in
            % the file name to read.
            try
                im = obj.ThumbnailIMDS.ReadFcn(fileName);

                userData.ClassUnderlying = string(class(im));
                userData.OriginalSize = size(im);

                % The image read in does not need to be post-processed here
                % to generate a valid thumbnail. This is done by the
                % Thumbnail Browser component.
            catch 
                % Indicate there was an error in reading. 
                % Show the broken thumbnail image.
                im = imread(fullfile(matlabroot,'toolbox','images','imuitools',...
                    '+images','+internal','+app','+browser','+icons',...
                    'BrokenPlaceholder_100.png'));
                userData.ClassUnderlying = "";
                userData.OriginalSize = [];
            end
        end

    end
end