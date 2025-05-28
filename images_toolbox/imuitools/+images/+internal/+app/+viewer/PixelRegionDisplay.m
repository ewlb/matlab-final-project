classdef PixelRegionDisplay < matlab.mixin.SetGet
% Helper class that overlays the Pixel Values on the Main Image

%   Copyright 2023, The MathWorks, Inc.

    properties(Access=public, Dependent)
        IsEnabled
    end

    properties(GetAccess=public, SetAccess=private)
        ImageAxes

        % Original image data as read from the source
        OrigImage (:, :, :) = zeros(0, 0, 0);
    end

    properties(Access=public)
        % Image modified from the original source by applying basic IPT
        % operations
        ProcessedImage (:, :, :);
    end

    % Data members used to actively update the pixel values
    properties(Access=private)
        CachedViewLimits (2, 2) double

        % A pool of textboxes which will be re-used to display the pixel
        % values. A pool with an initial estimate of values will be
        % constructed. More items will be added to the pool if needed.
        TextBoxPool = [];
        
        % The TextBoxPool is searched sequentially to determine an unused
        % textbox. This tracks the location in the pool to start searching
        % from.
        PoolStartLoc (1, 1) double = 1;

        % Dictionary that stores the pixel locations that are currently in
        % view. The dictionary has the format:
        % {(x, y)} -> IDX, where
        % {(x, y)} is the pixel location of the image
        % IDX is the index in the TextBoxPool indicating which textbox from
        % the pool is being used to display the pixel values.
        PixCoordsInView = dictionary();

        CDataListener
    end

    % Grid Lines UI
    properties(Access=private)
        HorizGridLines = [];
        VertGridLines = [];
    end

    % Status Flags
    properties(Access=private)
        IsGridLinesDisplayed (1, 1) logical = false;
        IsPixValsDisplayed (1, 1) logical = false;
        IsEnabledInternal (1, 1) logical = false;
    end

    properties(Access=private, Constant)
        % Minimum number of textboxes that are created during app creation.
        % This number is chosen based on number of textboxes that are
        % displayed on a 1080p monitor when app is at fullscreen.
        MinNumTextBoxesInPool = 600;

        % If additional textboxes are needed, create them in increments
        TextBoxPoolIncr = 25;
    end

    properties(Access=public, Constant)
        % Minimum screen pixel size at which the grid is displayed
        MinGridDispSize = 25;
    end

    % Construction
    methods
        function obj = PixelRegionDisplay(him, srcImage, modImage)
            obj.ImageAxes = him.AxesHandle;
            obj.CDataListener = addlistener( him.ImageHandle, "CData", ...
                        "PostSet", @(~, ~) reactToCDataChange(obj) );

            obj.OrigImage = srcImage;

            if isempty(modImage)
                obj.ProcessedImage = zeros(0, 0, 0);
            else
                obj.ProcessedImage = modImage;
            end

            viewLimits = [ him.XLim; him.YLim ];

            % Cache the currently displayed view limits. This is needed to
            % compute the difff in the view upon pan/zoom to identify only
            % those locations that have to be updated
            obj.CachedViewLimits = viewLimits;
        end

        function delete(obj)
            % Delete all graphics elements that are drawn on the image
            if ~isempty(obj.HorizGridLines)
                delete(obj.HorizGridLines);
            end

            if ~isempty(obj.VertGridLines)
                delete(obj.VertGridLines);
            end

            if ~isempty(obj.TextBoxPool)
                delete(obj.TextBoxPool);
            end

            delete(obj.CDataListener);
        end
    end

    % Operations
    methods(Access=public)
        function updateRegion(obj, newLimits)
            % Update the labels reacting to the new view limits

            % If the Pixel Region Display is not enabled, no change needs
            % to be made. Store the new limits for future use.
            if ~obj.IsEnabled
                obj.CachedViewLimits = newLimits;
                return;
            end

            % Compute the size (in pixels) on the screen that will be used
            % to display each image value.
            windowSize = obj.ImageAxes.Parent.Position(3:4);
            pixDispSize = computePixelDispSize(newLimits, windowSize);
            
            % The Grid lines will be shown only if the image has been
            % zoomed to a level that grid lines are reasonably spaced
            % apart. 
            if any(pixDispSize < obj.MinGridDispSize)
                if obj.IsGridLinesDisplayed
                    toggleGridLines(obj, "off");
                end
            else
                if ~obj.IsGridLinesDisplayed
                    toggleGridLines(obj, "on");
                end
            end

            % The pixel values will be shown only if there is space
            % available to display the text.
            minScreenPixSize = ...
                images.internal.app.viewer.computeMinPixSizeForPixelRegion(obj.OrigImage);
            if any(pixDispSize < minScreenPixSize)
                % Indicates the image is not zoomed in sufficiently enough
                % and so pixel values will not be displayed

                % If the pixel values are currently not being displayed,
                % then no changes need to be made to the UI. The new view
                % limits are stored for future use.
                if ~obj.IsPixValsDisplayed
                    obj.CachedViewLimits = newLimits;
                else
                    % Mark that pixel values are not being displayed
                    obj.IsPixValsDisplayed = false;

                    % Hide all the coodinates in the current view
                    hideValues(obj);
                end
            else

                % Code reaching here indicates pixel value display is
                % enabled AND the image is zoomed in sufficiently.
                obj.IsPixValsDisplayed = true;
    
                % Compute the image coords in the current and updated views
                coordsInOldView = computeCoordsInView(obj.CachedViewLimits);
                coordsInNewView = computeCoordsInView(newLimits);
    
                obj.CachedViewLimits = newLimits;
    
                % The coordinates that overlap in the old and new view need
                % not be updated.
    
                % Determine coords for whom the pixel values have to be
                % hidden
                coordsToHide = setdiff( coordsInOldView, ...
                                        coordsInNewView, "rows" );
    
                if ~isempty(coordsToHide)
                    hideValues(obj, coordsToHide);
                end
    
                % Determine coords for whom the pixel values have to be
                % shown
                coordsToShow = setdiff( coordsInNewView, ...
                                        coordsInOldView, "rows" );
    
                if isempty(coordsToShow)
                    % Indicates the new view is completely enclosed in the
                    % old view (image zoomed in/button toggled without view
                    % change). Hence, it is sufficient to show the
                    % coordinates in the new view.
                    showValues(obj, coordsInNewView);
                else
                    showValues(obj, coordsToShow);
                end
            end
        end

    end

    % Setters/Getters
    methods
        function set.IsEnabled(obj, tf)
            if obj.IsEnabledInternal == tf
                return;
            end
            
            obj.IsEnabledInternal = tf;

            if obj.IsEnabledInternal
                % If a pool of textboxes does not exist, it indicates the
                % first time pixel region is being enabled. Construct the
                % pool of textboxes.
                if isempty(obj.TextBoxPool)
                    create(obj);
                end
                updateRegion(obj, obj.CachedViewLimits);
            else
                coordsToHide = computeCoordsInView(obj.CachedViewLimits);
                toggleGridLines(obj, "off");
                hideValues(obj, coordsToHide);
            end
        end

        function tf = get.IsEnabled(obj)
            tf = obj.IsEnabledInternal;
        end
    end

    % Private Callbacks
    methods(Access=private)
        function reactToCDataChange(obj)
            % Refresh the Pixel region values. This is done most likely due
            % to a change in the displayed image

            if ~obj.IsEnabled || numEntries(obj.PixCoordsInView) == 0
                return;
            end

            % Update the text in the visible textboxes
            coordKeys = cell2mat(keys(obj.PixCoordsInView));
            tbidx = values(obj.PixCoordsInView);
 
            coordsTextColor = computeTextColor(obj, coordKeys);
            for cnt = 1:numel(tbidx)
                obj.TextBoxPool(tbidx(cnt)).String = ...
                            createPixValText( obj, coordKeys(cnt, 2), ...
                                                    coordKeys(cnt, 1) );
                obj.TextBoxPool(tbidx(cnt)).Color = coordsTextColor(cnt);
            end
        end
    end

    % Private Helpers
    methods(Access=private)
        function showValues(obj, coords)
            if numEntries(obj.PixCoordsInView) == 0
                newCoords = coords;
            else
                % These coordKeys represent the coordinates for which
                % textboxes are currently being displayed.
                coordKeys = cell2mat(keys(obj.PixCoordsInView));

                newCoords = setdiff(coords, coordKeys, "row");
            end

            numNewCoordsToAdd = size(newCoords, 1);
            if numNewCoordsToAdd == 0
                return;
            end

            newCoordsTextColor = computeTextColor(obj, newCoords);

            % Cyclically traverse through the pool of textboxes identifying
            % currently unused text boxes and use them.
            
            % Location to start the search
            currLoc = obj.PoolStartLoc;

            % Location to stop the search. If the start location is the
            % first element, then the stop location is the last element of
            % the array.
            stopLoc = currLoc - 1;
            if stopLoc == 0
                stopLoc = size(obj.TextBoxPool, 1);
            end

            coordsAddedCnt = 1;
            while coordsAddedCnt <= numNewCoordsToAdd
                % Obtain the current text box
                tb = obj.TextBoxPool(currLoc);

                currLoc = currLoc + 1;
                if currLoc > size(obj.TextBoxPool, 1)
                    currLoc = 1;
                end

                % If this textbox ends up being the last textbox needed,
                % then update the new start location for the next time.
                obj.PoolStartLoc = currLoc;

                if tb.Visible == "off"
                    % Textboxes that are not visible are available for use.
                    % Update the position and pixel value string
                    c = newCoords(coordsAddedCnt, :);

                    tb.String = createPixValText(obj, c(2), c(1));
                    tb.Position = c;
                    tb.Visible = "on";
                    tb.Color = newCoordsTextColor(coordsAddedCnt);

                    % The current location was updated above. Decrement it
                    % to get the index of the actual textbox that is to be
                    % stored.
                    currLocToStore = currLoc-1;
                    if currLocToStore == 0
                        currLocToStore = size(obj.TextBoxPool, 1);
                    end
                    obj.PixCoordsInView({c}) = currLocToStore;
                    coordsAddedCnt = coordsAddedCnt + 1;
                end

                if (currLoc == stopLoc) && ...
                                    (coordsAddedCnt < numNewCoordsToAdd)
                    % Indicates that all currently created textboxes have
                    % been searched but there are still coordinates for
                    % which information has to be displayed. This means new
                    % textboxes have to be created.
                    numCoordsToCreate = numNewCoordsToAdd - coordsAddedCnt;
                    numTBsToCreate = obj.TextBoxPoolIncr*...
                                ceil(numCoordsToCreate/obj.TextBoxPoolIncr);

                    % Create new textboxes
                    tblist = createTextBoxes(obj.ImageAxes, numTBsToCreate);

                    % Only search in the newly added textboxes
                    currLoc = size(obj.TextBoxPool, 1) + 1;
                    obj.TextBoxPool(end+1:end+size(tblist, 1)) = tblist;
                    stopLoc = size(obj.TextBoxPool, 1);
                end
            end
        end

        function hideValues(obj, coords)
            arguments
                obj (1, 1) images.internal.app.viewer.PixelRegionDisplay
                coords = []
            end

            if numEntries(obj.PixCoordsInView) == 0
                return;
            end

            if isempty(coords)
                % Hide all the coordinates in the view
                coordsToHide = keys(obj.PixCoordsInView);
                tbidx = values(obj.PixCoordsInView);
                for cnt = 1:numel(tbidx)
                    obj.TextBoxPool(tbidx(cnt)).Visible = "off";
                end
            else
                % Track the coordinates that need to be hidden. This is
                % used to remove the hidden coords from the dictionary.
                coordsToHide = repmat({[]}, [size(coords, 1) 1]);
                coordsIdx = 1;
    
                % Turn OFF each text box that has to be hidden.
                for cnt = 1:size(coords, 1)
                    c = coords(cnt, :);
                    if isKey(obj.PixCoordsInView, {c})
                        tbidx = obj.PixCoordsInView({c});
                        obj.TextBoxPool(tbidx).Visible = "off";
                        coordsToHide{coordsIdx} = c;
                        coordsIdx = coordsIdx + 1;
                    end
                end
    
                coordsToHide(cellfun( @(x) isempty(x), coordsToHide)) = [];
            end

            % Remove the entries for the hidden textboxes. This allows the
            % text objects to be reused.
            obj.PixCoordsInView(coordsToHide) = [];
        end

        function toggleGridLines(obj, status)
            hold(obj.ImageAxes, status);
            
            if ~isempty(obj.HorizGridLines)
                obj.HorizGridLines.Visible = status;
            end

            if ~isempty(obj.VertGridLines)
                obj.VertGridLines.Visible = status;
            end

            obj.IsGridLinesDisplayed = status == "on";
        end

        function create(obj)
            % Create the grid lines and the pool of textboxes that will be
            % used to perform the pixel region display

            [hGridCoords, vGridCoords] = computeGridCoords(obj.ImageAxes);

            obj.HorizGridLines = line( obj.ImageAxes, ...
                                       hGridCoords(:, 1), ...
                                       hGridCoords(:, 2), ...
                                       Color=[0 0.4470 0.7410], ...
                                       LineStyle="--", ...
                                       LineWidth=0.25, ...
                                       Visible="off" );

            obj.VertGridLines = line( obj.ImageAxes, ...
                                      vGridCoords(:, 1), ...
                                      vGridCoords(:, 2), ...
                                      Color=[0 0.4470 0.7410], ...
                                      LineStyle="--", ...
                                      LineWidth=0.25, ...
                                      Visible="off" );

            if isempty(obj.TextBoxPool)
                obj.TextBoxPool = createTextBoxes( obj.ImageAxes, ...
                                                 obj.MinNumTextBoxesInPool );
            end
        end

        function pixTxt = createPixValText(obj, r, c)
            % Create the string that displays the pixel values

            origPix = squeeze( obj.OrigImage(r, c, :) );

            if ~isempty(obj.ProcessedImage)
                modPix = squeeze( obj.ProcessedImage(r, c, :) );

                assert( (numel(origPix) == 1) && (numel(modPix) == 1), ...
                        "Original and Modified Images support only 1 channel" );

                pixTxt = "Adj: " + modPix;

                pixTxt = pixTxt + newline() + newline() + ...
                            createPixValTxtImpl(origPix);
            else
                pixTxt = createPixValTxtImpl(origPix);
            end

            function txt = createPixValTxtImpl(pixVal)
                switch(numel(pixVal))
                    case 1
                        if isfloat(pixVal)
                            txt = "I: " + sprintf("%1.3f", pixVal);
                        else
                            txt = "I: " + pixVal;
                        end
    
                    case 3
                        if isfloat(pixVal)
                            txt = [ "R: " + sprintf("%1.3f", pixVal(1));
                                    "G: " + sprintf("%1.3f", pixVal(2));
                                    "B: " + sprintf("%1.3f", pixVal(3)) ];
                        else
                            txt = [ "R: " + pixVal(1);
                                    "G: " + pixVal(2);
                                    "B: " + pixVal(3) ];
                        end
                    otherwise
                        assert(false, "Incorrect number of channels")
                end
            end
        end

        function textColorToUse = computeTextColor(obj, coords)
            % Compute the text colour to use to display the pixel values
            
            imageToUse = obj.CDataListener.Object{1}.CData;
            
            imageDims = size(imageToUse, [1 2]);

            % coords represent (x, y) coords. Image array indexing is
            % (y, x).
            coordsIdx = sub2ind(imageDims, coords(:, 2), coords(:, 1));
            coordsIdx = [ coordsIdx; coordsIdx + prod(imageDims); ...
                                coordsIdx + 2*prod(imageDims) ];

            % Linear index to grab all the pixel values of interest
            pixVals = imageToUse(coordsIdx);

            % Reshape the pixels as Nx3 as the CData is always RGB
            pixVals = reshape(pixVals, size(coords, 1), []);

            % The logic used below matches the "truecolor" logic used in
            % imagemodel/getScreenPixelRGBValue and impixelregionpanel.
            % Since CData in the image utility is always single precision
            % RGB, the true color code path is sufficient to borrow.
            range = getrangefromclass(imageToUse);
            
            screenPixColor = (pixVals - range(1)) ./ diff(range);
            screenPixColor = min(1, max(0, screenPixColor));

            % Convert them into grayscale
            screenPixColor = screenPixColor * [0.2989 0.5870 0.1140]';

            % Threshold the image. Use black color text for brighter image
            % regions and vice-versa
            idx = screenPixColor > 0.5;
            
            textColorToUse = strings(numel(screenPixColor), 1);
            textColorToUse(idx) = "k";
            textColorToUse(~idx) = "w";
        end
    end
end

function [hc, vc] = computeGridCoords(ax)
    % Compute Coords for Horizontal Grid Lines
    xc = [ax.XLim NaN];
    yc = ax.YLim(1):1:ax.YLim(2);

    [xc, yc] = ndgrid(xc, yc);
    yc(3, :) = NaN;
    hc = [xc(:) yc(:)];

    % Compute Coords for Vertical Grid Lines
    xc = ax.XLim(1):1:ax.XLim(2);
    yc = [ax.YLim, NaN];

    [xc, yc] = ndgrid(xc, yc);
    xc(:, 3) = NaN;
    xc = xc'; yc = yc';

    vc = [xc(:) yc(:)];
end

function tb = createTextBoxes(ax, N)
    % Helper function that creates a pool of textboxes which are used to
    % display the pixel values.

    tb = repmat(matlab.graphics.primitive.Text, [N 1]);
    for cnt = 1:N
        tb(cnt) = text( ax, FontName="FixedWidth", ...
                        HorizontalAlignment="center", ...
                        VerticalAlignment="middle", ...
                        Units="data", ...
                        Visible="off" );
    end

end

function coords = computeCoordsInView(viewLimits)
    
    imageCoordLimits = zeros(2, 2);

    imageCoordLimits(:, 1) = max(ceil(viewLimits(:, 1)-0.5), 1);
    imageCoordLimits(1, 2) = ceil(viewLimits(1, 2)-0.5);
    imageCoordLimits(2, 2) = ceil(viewLimits(2, 2)-0.5);

    [xc, yc] = ndgrid( imageCoordLimits(1, 1):imageCoordLimits(1, 2), ...
                       imageCoordLimits(2, 1):imageCoordLimits(2, 2) );
    coords = [xc(:) yc(:)];
end

function pixDispSize = computePixelDispSize(viewLimits, windowSize)
    % Compute the size (in pixels) that each image pixel will be
    % displayed at on the screen

    pixelLimits = [ ceil(viewLimits(:, 1)) floor(viewLimits(:, 2)) ];
    numFullPixels = diff(pixelLimits, [], 2)';

    pixDispSize = floor(windowSize ./ numFullPixels);
end