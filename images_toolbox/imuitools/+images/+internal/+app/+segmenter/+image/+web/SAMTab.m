classdef SAMTab < images.internal.app.segmenter.image.web.GraphCutBaseTab
%   Base class for Image Segmenter Tabs that make use of SAM

    properties(Access=protected)
        % Manages the life time of the SAM object
        SAMMgrObj (1, 1) images.internal.app.segmenter.image.web.sam.SAMMgr = ...
                    images.internal.app.segmenter.image.web.sam.SAMMgr.getInstance();

        % Logits generated by the last segmentation call.
        MaskLogits (:, :) = [];

        % Generated MATLAB Code for the current segmentation session
        % This code tracks actions from Tab Launch until Apply being
        % Pressed
        CurrSessMLCode (1, 1) string = ""
    end

    properties(Access=protected)
        ROISection matlab.ui.internal.toolstrip.Section ...
                            = matlab.ui.internal.toolstrip.Section.empty()
    end

    properties(Access=private)
        % Used for display purposes. This "hides" image regions outside the
        % ROI
        ROIAlphaData (:, :) double = [];

        % The two data members below help avoid duplicate SAM
        % initialization calls in the generated MATLAB code. This can
        % happen since SAM Tab can be called multiple times. Also, SAM can
        % be already initialized in the PaintBrush Tab.

        % Listener for Keyboard Shortcuts
        KeyPressListener (:, :) event.listener = event.listener.empty()
    end

    methods(Access=protected, Abstract)
        createBox(obj);

        mask = getBinaryMask(obj);
        
        hideTab(obj);

        % Perform Add/Refine specific configuration for default tab state.
        % The default state when the tab is opened is Scribble Drawing
        % and not Auto Seg
        setupDefaultTabSegState(obj);

        % Perform Additional Cleanup specific to the SAM Mode after
        % performing segmentation
        cleanupOnSegDoneImpl(obj);
    end
    
    % Public Interface
    methods(Access=public)
        function obj = SAMTab(toolGroup, tabGroup, theToolstrip, theApp, varargin)
            % Call base class constructor
            obj@images.internal.app.segmenter.image.web.GraphCutBaseTab( ...
                        toolGroup, tabGroup, theToolstrip, ...
                        theApp, "segmentAnythingTab", varargin{:} );
            obj.DrawCtrls.DrawOnlyPoints = true;

            addlistener( obj.DrawCtrls, "ROIDrawingDone", ...
                            @(~, evt) reactToROIDrawingDone(obj, evt) );
        end
    end

    % Implementation of Abstract Methods
    methods(Access=public)
        function onApply(obj)
            import images.internal.app.segmenter.image.web.getMessageString;
            
            binaryMask = getBinaryMask(obj);

            setCurrentMask(obj.hApp, binaryMask);

            addToHistory( obj.hApp, binaryMask, ...
                          getMessageString("segmentAnythingComment"), ...
                          getCommandsForHistory(obj) );
            
            cleanupOnSegDone(obj);

            % If an ROI was drawn to generate the previously accepted mask,
            % then ensure we put the user in the ROI Drawing Mode on Accept
            if ~isempty(obj.CommonTSCtrls.ROIButton) && ...
                                        obj.CommonTSCtrls.ROIButton.Value
                obj.CommonTSCtrls.ForegroundButton.Value = false;
                obj.CommonTSCtrls.BackgroundButton.Value = false;

                createROI(obj);
                updateEditMode(obj, "ROI");
            elseif ~isempty(obj.DrawCtrls.EditMode) && ...
                                    obj.DrawCtrls.EditMode == "erase"
                % If EditMode is in erase when mask is accepted, then
                % switch mode to FG because erase mode is not valid when
                % there is no mask being drawn.
                obj.CommonTSCtrls.ForegroundButton.Value = true;
                addForegroundScribble(obj);
            end
        end

        function onClose(obj)
            import images.internal.app.segmenter.image.web.AppMode;

            cleanupOnSegDone(obj);

            clearTemporaryHistory(obj.hApp);

            disableAllButtons(obj);

            obj.hApp.ScrollPanel.Image.Superpixels = [];
            redraw(obj.hApp.ScrollPanel);

            obj.hApp.MousePointer = "arrow";
            hIm = obj.hApp.getScrollPanelImage();
            hIm.ButtonDownFcn = [];
            
            hideTab(obj);
            setMode(obj.hToolstrip, AppMode.SAMDone);

            delete(obj.KeyPressListener);
        end

        function cleanupOnSegDone(obj)
            % Clean up actions once the segmentation actions are completed
            obj.CommonTSCtrls.EraseButton.Enabled = false;
            obj.CommonTSCtrls.ClearButton.Enabled = false;

            hideLegend(obj.hApp);

            % Mask was rejected or tab being closed. The Apply Button must
            % not be enabled
            obj.ApplyCloseMgr.ApplyButton.Enabled = false;

            % If an ROI was drawn, undo the alpha data changes to the image
            % display on clean up
            if ~isempty(obj.DrawCtrls.ROI)
                updateROIDisplay(obj, false);
            end

            % Remove all user inputs
            clearAllScribbles(obj.DrawCtrls);
            clearROI(obj.DrawCtrls);

            % The current segmentation session is complete. Reset the Mask
            % Logits and the generated code.
            obj.MaskLogits = [];
            obj.CurrSessMLCode = "";

            cleanupOnSegDoneImpl(obj);
        end

        function setMode(obj, mode)
            import images.internal.app.segmenter.image.web.AppMode;
            import images.internal.app.segmenter.image.web.getMessageString;

            switch (mode)
                case {AppMode.NoImageLoaded, AppMode.ImageLoaded}
                    disableAllButtons(obj);

                    if mode == AppMode.ImageLoaded
                        updateImageProperties(obj);
                        imageSize = obj.ImageProperties.ImageSize;
                        obj.ROIAlphaData = 0.3*ones(imageSize(1), imageSize(2));
                    else
                        obj.ROIAlphaData = [];
                    end

                    clearEmbeddings(obj.SAMMgrObj);

                    % Initialize the MATLAB Code that is used for
                    % segmentation.
                    % This has to be built incrementally and hence stored
                    % as a data member.
                    obj.CurrSessMLCode = "";

                    % New image is loaded. Delete any existing Markers and
                    % ROI
                    reset(obj.DrawCtrls);

                case AppMode.SAMDone
                    reset(obj.DrawCtrls);
                    resetAppState(obj);

                otherwise
                    % Tab does not respond to a bunch of events.
            end
        end
    end
    
    % Implementation of abstract methods that are not part of the public
    % interface
    methods(Access = protected)
        function reactToScribbleDone(obj)
            switch obj.DrawCtrls.EditMode
                case {"fore", "back"}
                    % Indicates that new FG points are being drawn
                    isFg = obj.DrawCtrls.EditMode == "fore";
                    updateGenMLCodeForMarker(obj, "add", isFg);

                case "erase"
                    updateGenMLCodeForMarker(obj, "erase");

                otherwise
                    assert(false, "Invalid Mode for Updating Gen ML Code")
            end

            doSegmentationAndUpdateApp(obj);
        end

        function [mask, maskSrc] = applySegmentation(obj)
            % Re-run the segmentation after updating markers and boxes
            import images.internal.app.segmenter.image.web.getMessageString;

            % Get the FG and BG points. The internal drawing infra stores
            % erased markers as NaNs. Those are invalid.
            [fgPoints, bgPoints] = getMarkerPoints(obj, "valid");

            % Ensure only the suitable DD entries are enabled depending
            % upon the FG and BG points available
            updateEraseButtonState(obj, fgPoints, bgPoints);
            updateClearButtonState(obj, fgPoints, bgPoints);
            
            if isempty(obj.DrawCtrls.ROI)
                bbox = [];
            else
                bbox = obj.DrawCtrls.ROI.Position;
            end

            % SAM does not perform seg when only BG points are provided.
            isPerformSeg = ~( isempty(fgPoints) && isempty(bbox) );
            mask = doSegUsingPrompts(obj, fgPoints, bgPoints, bbox);

            if isPerformSeg
                showLegend(obj.hApp);
            else
                hideLegend(obj.hApp);
            end

            obj.ApplyCloseMgr.ApplyButton.Enabled = isPerformSeg;
            
            maskSrc = getMessageString("segmentAnythingComment");
        end

        function TF = isUserDrawingValid(~)
            % Marking this a TRUE always because the generated MATLAB code
            % needs to be updated even if no user drawings have been made
            TF = true;
        end

        function cleanupAfterClearAll(obj)
            % Actions to be taken after All Markers are removed

            obj.MaskLogits = [];
            if isempty(obj.DrawCtrls.ROI)
                bbox = [];
            else
                bbox = obj.DrawCtrls.ROI.Position;
            end
            obj.CurrSessMLCode = obj.createMLCodeForROI(bbox);
            [mask, maskSrc] = applySegmentation(obj);
            setTempHistory(obj, mask, maskSrc);
        end

        function cleanupAfterClear(obj, markerType)
            % Actions to be taken after Clear Foreground/Background Markers
            % are called
            arguments
                obj
                markerType (1, 1) string { mustBeMember( markerType, ...
                                                    ["fore", "back"] ) }
            end

            updateGenMLCodeForMarker(obj, "clearType", markerType == "fore");

            [mask, maskSrc] = applySegmentation(obj);
            setTempHistory(obj, mask, maskSrc);
        end


        function disableAllButtons(obj)
            disableAllControls(obj.CommonTSCtrls);

            disableAll(obj.ApplyCloseSection);
        end

        function cmd = getCommandsForHistory(obj)
            if isSAMInitInGenMLCode(obj)
                cmd = createDrawVarsInitCode() + obj.CurrSessMLCode;
            else
                useGPU = obj.CommonTSCtrls.UseGPUButton.Enabled && ...
                                    obj.CommonTSCtrls.UseGPUButton.Value;
                isRGB = numel(obj.ImageProperties.ImageSize) == 3;
                cmd = createSAMSetupCode(useGPU, isRGB) + obj.CurrSessMLCode;
            end
        end

        function showMessagePane(~)
        end

        function hideMessagePane(~)
        end
    end

    % Toolstrip Layout Helpers
    methods(Access=protected)
        function ctrl = createCommonTSControls(~)
            ctrl = images.internal.app.utilities.semiautoseg.SAMTSControls();
        end

        function layoutROISection(obj)
            import matlab.ui.internal.toolstrip.*
            import images.internal.app.segmenter.image.web.getMessageString;

            obj.ROISection = obj.hTab.addSection(getMessageString("roi"));

            obj.ROISection.Tag = "ROISectionSAM";
            
            addROIControls(obj.CommonTSCtrls, obj.ROISection, "rectangle");
            
            addlistener( obj.CommonTSCtrls, "ROIButtonPressed", ...
                            @(~, evt) obj.reactToROIButtonPressed(evt) );
        end
        
        function layoutUseGPUSection(obj)
            import matlab.ui.internal.toolstrip.*
            import images.internal.app.segmenter.image.web.getMessageString;

            useGpuSection = addSection(obj.hTab, getMessageString("gpuSection"));

            addUseGPUControls(obj.CommonTSCtrls, useGpuSection);
            addlistener( obj.CommonTSCtrls, "UseGpuButtonPressed", ...
                                @(~, evt) reactToUseGPUBtnPressed(obj, evt) );
        end

        function layoutDrawingMarkersSection(obj)
            import images.internal.app.segmenter.image.web.getMessageString;
            obj.DrawSection = obj.hTab.addSection( ...
                            getMessageString("markerTools") );
            obj.DrawSection.Tag = "DrawSectionSAM";
            layoutDrawSection(obj);
    
            % Add clear button as part of the Drawing Tools and
            % not ROI. Users can clear markings within an ROI
            layoutClearTools(obj, obj.DrawSection);
        end
    end

    % UI Controls Callbacks
    methods(Access=private)
        function reactToUseGPUBtnPressed(obj, evt)
            s = settings;
            activeVal = s.images.imagesegmentertool.SAMUseGPU.ActiveValue;
            if evt.Data
                mlCode = "if canUseGpuArray()" + newline() + ...
                         sprintf("\t") + "embeds = gpuArray(embeds);" + newline() + ...
                         "end" + newline();
                pval = "yes";
            else
                mlCode = "embeds = gather(embeds);" + newline();
                pval = "no";
            end

            % If user has requested that they be prompted on whether to use
            % GPU, then do not save the Use GPU Toggle button value. 
            if activeVal ~= "prompt"
                s.images.imagesegmentertool.SAMUseGPU.PersonalValue = pval;
            end

            obj.CurrSessMLCode = obj.CurrSessMLCode + mlCode;
        end

        function reactToROIButtonPressed(obj, evt)
            if evt.Data
                disableAll(obj.DrawSection);

                obj.hApp.MousePointer = 'roi';
                
                createROI(obj);
                updateEditMode(obj, "ROI");
            else
                obj.CommonTSCtrls.ForegroundButton.Enabled = true;
                obj.CommonTSCtrls.BackgroundButton.Enabled = true;
                updateEraseButtonState(obj);
                updateClearButtonState(obj);
                reactToDeletingROI(obj);
            end
        end

    end

    % UI Helpers
    methods(Access=private)
        function reactToMovingROI(obj)
            % Moving the ROI invalidates all markers placed by the user.
            % Delete the markers
            clearAllScribbles(obj.DrawCtrls);

            % A new ROI position is the start of a new segmentation. Hence,
            % previous Mask Logits must also not be used.S
            obj.MaskLogits = [];

            disableAll(obj.DrawSection);
            updateROIDisplay(obj, false);
        end
        
        function reactToROIMoved(obj)
            updateROIDisplay(obj, true);

            obj.CommonTSCtrls.ForegroundButton.Enabled = true;
            obj.CommonTSCtrls.BackgroundButton.Enabled = true;
            updateEraseButtonState(obj);
            updateClearButtonState(obj);

            % Static method. Hence using obj.<FUNC> syntax
            obj.CurrSessMLCode = obj.createMLCodeForROI(obj.DrawCtrls.ROI.Position);

            % Update the segmentation using the new ROI position
            [mask, maskSrc] = applySegmentation(obj);
            setTempHistory(obj, mask, maskSrc);
        end

        function reactToDeletingROI(obj)
            % Deleting the ROI invalidates all markers placed by the user.
            % Delete the markers
            obj.CommonTSCtrls.ROIButton.Value = false;
            obj.CommonTSCtrls.ForegroundButton.Value = true;
            obj.CommonTSCtrls.BackgroundButton.Value = false;

            clearAllScribbles(obj.DrawCtrls);

            % Remove the "highlighting" of the ROI
            updateROIDisplay(obj, false);

            % The ROI Position is invalidated only after this callback
            % execution completes. Hence, set the ROI to empty
            obj.DrawCtrls.ROI = images.roi.Rectangle.empty();

            % Static method. Hence using obj.<FUNC> syntax
            obj.CurrSessMLCode = obj.createMLCodeForROI([]);

            [mask, maskSrc] = applySegmentation(obj);
            setTempHistory(obj, mask, maskSrc);

            updateEditMode(obj, "fore");
        end

        function reactToROIDrawingDone(obj, evt)
            % Actions when Box ROI drawing is complete

            if evt.Data
                % Valid ROI was drawn
                enableAll(obj.DrawSection);
                obj.CommonTSCtrls.EraseButton.Enabled = false;
                obj.CommonTSCtrls.EraseButton.Value = false;
                obj.CommonTSCtrls.ClearButton.Enabled = false;
    
                updateEditMode(obj, computeEditMode(obj));
            else
                % ROI drawn is not valid

                % Delete the drawn ROI
                clearROI(obj.DrawCtrls);

                % Create a new ROI
                createROI(obj);
                updateEditMode(obj, "ROI");
            end
        end

        function updateEraseButtonState(obj, validFg, validBg)
            if nargin == 1
                [validFg, validBg] = getMarkerPoints(obj, "valid");
            end

            obj.CommonTSCtrls.EraseButton.Enabled = ~isempty(validFg) || ~isempty(validBg);
        end

        function updateClearButtonState(obj, validFg, validBg)
            if nargin == 1
                [validFg, validBg] = getMarkerPoints(obj, "valid");
            end

            obj.CommonTSCtrls.ClearButton.Enabled = ~isempty(validFg) || ~isempty(validBg);
            fgItem = getChildByTag(obj.CommonTSCtrls.ClearButton.Popup, "ClearForeground");
            fgItem.Enabled = ~isempty(validFg);

            bgItem = getChildByTag(obj.CommonTSCtrls.ClearButton.Popup, "ClearBackground");
            bgItem.Enabled = ~isempty(validBg);

            allItem = getChildByTag(obj.CommonTSCtrls.ClearButton.Popup, "ClearAll");
            allItem.Enabled = ~isempty(validFg) || ~isempty(validBg);
        end

        function reactToKeyPress(obj, evt)
            % Handle keyboard pressed event and take suitable actions

            switch(evt.Key)
                case "space"
                    if obj.ApplyCloseMgr.ApplyButton.Enabled
                        onApply(obj);
                    end
                otherwise
                    % Take no action
            end

        end
    end

    % Segmentation Related Helpers
    methods(Access=protected)
        function isSuccess = initSAM(obj)
            import images.internal.app.segmenter.image.web.getMessageString;

            % Initialize SAM (load network and compute embeddings)
            [isSuccess, useGPU, isEnabledBtn] = ...
                init( obj.SAMMgrObj, getRGBImage(obj.hApp), obj.hAppContainer );
            

            if isSuccess
                % Indicates that loading SAM and computing the embeddings
                % were successful

                obj.CommonTSCtrls.UseGPUButton.Enabled = isEnabledBtn;
                obj.CommonTSCtrls.UseGPUButton.Value = useGPU;
            end
        end

        function mask = doSegUsingPrompts(obj, fgPoints, bgPoints, bbox)
            % Perform prompt-based segmentation using SAM

            useGPU = obj.CommonTSCtrls.UseGPUButton.Enabled && ...
                                    obj.CommonTSCtrls.UseGPUButton.Value;
            [mask, obj.MaskLogits] = segmentUsingPrompts( ...
                                obj.SAMMgrObj, obj.MaskLogits, ...
                                fgPoints, bgPoints, bbox, useGPU );
        end

        function tf = isSAMInitInGenMLCode(obj)
            % SAM object initialization is done only for prompt-based
            % SAM. Check if prompt-based SAM has been previously done.
            currSeg = CurrentSegmentation(obj.hApp.Session);
            if isempty(currSeg)
               tf = false;
            else
                segHistory = export(currSeg);
                % Compare each element because it possible that some
                % entries are not cellstrs
                segHistCode = segHistory(:, 2);
                tf = false;
                for cnt = 1:numel(segHistCode)
                    if ~iscell(segHistCode(cnt))
                        % Some techniques such as Draw ROIs add code which
                        % are not cellstrs. Hence skip them
                        continue;
                    end

                    tf = any( contains( segHistCode{cnt} , ...
                            "sam = segmentAnythingModel()" ) );
                    if tf
                        % No need for further checks if entry detected
                        break;
                    end
                end
            end
        end
        
        function updateGenMLCodeForMarker(obj, action, isFg)
            % Method that generates the MATLAB code when user draws FG or
            % BG markers.
            arguments
                obj
                action (1, 1) string { mustBeMember( action, ...
                                        ["add", "erase", "clearType"] ) }
                isFg (1, 1) logical = true
            end

            if isFg
                ptsVarNameInGenCode = "fgPoints";
            else
                ptsVarNameInGenCode = "bgPoints";
            end

            fgPoints = [];

            switch action 
                case "add"
                    % Adding new points. The generated code grows the
                    % variables fgPoints/bgPoints as appropriate to
                    % accomodate the newly added points  
                    if isFg
                        pts = getMarkerPoints(obj, "all");
                        fgPoints = pts;
                    else
                        [fgPoints, pts] = getMarkerPoints(obj, "all");
                    end
    
                    startIdx = find(isnan(pts(:, 1)));
                    if isempty(startIdx)
                        startIdx = 1;
                    else
                        startIdx = startIdx(end)+1;
                    end
    
                    ptsToAdd = pts(startIdx:end, :);
                    numPts = size(ptsToAdd, 1);
                    if numPts == 1
                        arrayIndexCode = "(end+1, :)";
                    else
                        arrayIndexCode = "(end+1:end+" + numPts + ", :)";
                    end
    
                    ptsCode = obj.matrix2dToString(ptsToAdd);
                    mlCode = ptsVarNameInGenCode + arrayIndexCode + " = " + ...
                                                    ptsCode + newline();

                case "clearType"
                    % Clearing all markers of a specific type
                    % Compute available fgPoints. If not, the M-code
                    % generation path will assume there are no FG points
                    % and hence no segmentation is being performed.
                    fgPoints = getMarkerPoints(obj, "valid");
                    mlCode = ptsVarNameInGenCode + " = [];" + newline();

                case "erase"
                    % Erasing points using the eraser tool. This can result
                    % in portions of FG and BG markers being removed by the
                    % user.
                    % The generated code simply reinitializes the FG and BG
                    % variables to list the currently valid points. It can
                    % get tricky to add code to determine the erased
                    % points and update it.
                    [fgPoints, bgPoints] = getMarkerPoints(obj, "valid");
                    mlCode = "fgPoints = " + obj.matrix2dToString(fgPoints) + newline();
                    mlCode = mlCode + "bgPoints = " + obj.matrix2dToString(bgPoints) + newline();

                otherwise
                    assert(false, "Unsupported action");
            end

            % If no FG or BBOX is present, then the mask is empty as no
            % segmentation is performed
            if isempty(obj.DrawCtrls.ROI) && isempty(fgPoints)
                mlCode = mlCode + "BW = false(imsz);" + newline() + newline();
            else
                mlCode = mlCode + obj.createSAMSegmentObjectsCode() + newline();
            end

            obj.CurrSessMLCode = obj.CurrSessMLCode + mlCode;
        end

        function [fgPoints, bgPoints] = getMarkerPoints(obj, ptsType)
            % Get the FG and BG markers points that have been drawn.
            arguments
                obj
                ptsType (1, 1) string { mustBeMember( ptsType, ...
                                        ["valid", "all"] ) } = "valid"
            end

            fgPoints = obj.DrawCtrls.FGPoints;
            bgPoints = obj.DrawCtrls.BGPoints;
            if ptsType == "valid"
                if ~isempty(fgPoints)
                    fgPoints(isnan(fgPoints(:, 1)), :) = [];
                end

                if ~isempty(bgPoints)
                    bgPoints(isnan(bgPoints(:, 1)), :) = [];
                end
            end
        end
    end
    
    methods(Access=protected)
        function tf = setupTabForSegmentation(obj)
            tf = initSAM(obj);
            if ~tf
                return;
            end

            initDrawControls(obj);
            configureForScribbleDrawing(obj.CommonTSCtrls);
            updateEditMode(obj, "fore");

            hideLegend(obj.hApp);

            enableAll(obj.ApplyCloseSection);
            obj.ApplyCloseMgr.ApplyButton.Enabled = false;

            obj.KeyPressListener = addlistener( getScrollPanelFigure(obj.hApp), ...
                        "WindowKeyPress", ...
                         @(~, evt) reactToKeyPress(obj, evt) );

            setupDefaultTabSegState(obj);
        end

        function mode = computeEditMode(obj)
            if obj.CommonTSCtrls.ForegroundButton.Value == false && ...
                    obj.CommonTSCtrls.BackgroundButton.Value == false
                obj.CommonTSCtrls.ForegroundButton.Value = true;
                mode = "fore";
            elseif obj.CommonTSCtrls.ForegroundButton.Value
                mode = "fore";
            elseif obj.CommonTSCtrls.BackgroundButton.Value
                mode = "back";
            else
                mode = "";
                assert(false, "Both Marker Buttons cannot be TRUE");
            end
        end

        function createROI(obj, options)
            arguments
                obj
                options.Deletable (1, 1) logical = true
            end

            % Create an ROI
            ax = getScrollPanelAxes(obj.hApp);
            roi = images.roi.Rectangle( ax, Color="black", ...
                                        FaceSelectable=false, ...
                                        FaceAlpha=0, LineWidth=2, ...
                                        Deletable=options.Deletable );

            % Needed to clear existing Markers when the
            % drawing/translation/resizing starts
            addlistener(roi, "MovingROI", @(~, ~) reactToMovingROI(obj));

            % Needed to update the segmentation once the
            % drawing/translation/resizing is completed
            addlistener(roi, "ROIMoved", @(~, ~) reactToROIMoved(obj));

            % Needed to update the segmentation
            if options.Deletable
                addlistener( roi, "DeletingROI", ...
                            @(~, ~) reactToDeletingROI(obj) );
            end
            obj.DrawCtrls.ROI = roi;
        end

        function updateROIDisplay(obj, highlightROI)
            % Highlight/Hide the ROI drawn on the image
            arguments
                obj
                highlightROI (1, 1) logical
            end

            him = getScrollPanelImage(obj.hApp);

            if highlightROI
                bwMask = createMask(obj.DrawCtrls.ROI);

                alphaData = obj.ROIAlphaData;
                alphaData(bwMask) = 1;
            else
                alphaData = 1;
            end
            
            him.AlphaData = alphaData;
        end
    end

    methods(Access=protected, Static)
        function codeStr = createMLCodeForROI(bbox)
            import images.internal.app.segmenter.image.web.SAMTab.matrix2dToString
            codeStr = "% Remove All markers, ROIs and reset Mask Logits" + newline() + ...
                     "fgPoints = [];" + newline() + ...
                     "bgPoints = [];" + newline() + ...
                     "bbox = " + matrix2dToString(bbox) + newline() + ...
                     "maskLogits = [];" + newline();
        
            if isempty(bbox)
                codeStr = codeStr + "BW = BW | false(imsz);" + newline() + newline();
            else
                codeStr = codeStr + images.internal.app.segmenter.image.web.SAMTab.createSAMSegmentObjectsCode() + ...
                                                newline() + newline();
            end
        end

        function codeStr = createSAMSegmentObjectsCode()
            codeStr =  "% Perform Segmentation using the MaskLogits from previous step " + ...
                       "and all Markers and/or ROIs" + newline() + ...
                       "[BWout,~,maskLogits] = " + ....
                       "segmentObjectsFromEmbeddings(sam,embeds," + ...
                       "imsz," + ...
                       "ForegroundPoints=fgPoints," + ...
                       "BackgroundPoints=bgPoints," + ...
                       "BoundingBox=bbox," + ...
                       "MaskLogits=maskLogits" + ...
                       ");" + newline();
        end

        function codeStr = matrix2dToString(pts, valsOnSingleLine, endWithColon)
            arguments
                pts (:, :)
                valsOnSingleLine (1, 1) logical = false
                endWithColon (1, 1) logical = true;
            end
            localNumPts = size(pts, 1);
            if isscalar(pts)
                codeStr = "";
            else
                codeStr = "[";
            end

            if valsOnSingleLine
                delim = ";";
            else
                delim = newline();
            end
            for cnt = 1:size(pts, 1)
                currPt = string(pts(cnt, :));
                codeStr = codeStr + strjoin(currPt, " ");
                if cnt < localNumPts
                    codeStr = codeStr + delim;
                end
            end
            if ~isscalar(pts)
                codeStr = codeStr + "]";
                if endWithColon
                    codeStr = codeStr + ";";
                end
            end
        end
    end
end

function codeStr = createSAMSetupCode(useGPU, isRGB)
    codeStr =  "% Load Segment Anything Model" + newline() + ...
               "sam = segmentAnythingModel();" + newline() + newline() + ...
               createImageEmbedsCode(useGPU, isRGB) + newline() + newline() + ...
               createDrawVarsInitCode();
end

function codeStr = createDrawVarsInitCode()
    codeStr = "% Initialize Variables that will track each step of the segmentation" + newline() + ...
               "fgPoints = [];" + newline() + ...
               "bgPoints = [];" + newline() + ...
               "bbox = [];" + newline() + ...
               "maskLogits = [];" + newline() + newline();
end

function codeStr = createImageEmbedsCode(useGPU, isRGB)
    if isRGB
        varName = "RGB";
    else
        varName = "X";
    end
    if useGPU
        codeStr = "if canUseGPU()" + newline() + ...
                  sprintf("\t") + varName + " = gpuArray(" + varName + ");" + ...
                  newline() + "end" + newline();
    else
        codeStr = "";
    end

    % Creating a separate copy of image for SAM operations. This is because
    % users can add on other segmentation methods after SAM. These methods
    % do not need rescale [0-255] versions of the image.
    codeStr = codeStr + "% SAM expects image data to be in the range [0-255]." + newline() + ...
                "samImage = 255*rescale(" + varName + ");" + newline() + newline();
    
    codeStr = codeStr + "% Extract Embeddings for the image to be segmented" + newline();
    codeStr = codeStr + ...
              "embeds = extractEmbeddings(sam, samImage);" + newline() + ...
              "imsz = size(samImage, [1 2]);" + newline() + newline();
end

% Copyright 2023-2024 The MathWorks, Inc.