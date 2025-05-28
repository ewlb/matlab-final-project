classdef SAMRefineTab < images.internal.app.segmenter.image.web.SAMTab
%   SAM Tab when it is opened in Refine Mode

    % Public Interface
    methods(Access=public)
        function obj = SAMRefineTab(toolGroup, tabGroup, theToolstrip, theApp, varargin)
            % Call base class constructor
            obj@images.internal.app.segmenter.image.web.SAMTab( ...
                        toolGroup, tabGroup, theToolstrip, ...
                        theApp, varargin{:} )
        end
    end

    % Implementation of Abstract Methods
    methods(Access=public)
        function setMode(obj, mode)
            import images.internal.app.segmenter.image.web.AppMode;
            switch(mode)
                case { AppMode.NoImageLoaded, AppMode.ImageLoaded, ...
                        AppMode.SAMDone }
                    setMode@images.internal.app.segmenter.image.web.SAMTab(obj, mode);

                case AppMode.SAMRefineTabOpened
                    if ~setupTabForSegmentation(obj)
                        onClose(obj);
                    else
                        obj.hAppContainer.Busy = true;
                        appBusyOC = onCleanup( @() set(obj.hAppContainer, ...
                                                    "Busy", false) );
                        handleLoadedMask(obj);
                    end

                otherwise
                    % App contains modes not relevant for this Tab
            end
        end
    end

    % Overriding the Layout section 
    methods(Access=protected)
        function layoutTab(obj)
            layoutUseGPUSection(obj);
            layoutDrawingMarkersSection(obj);
            layoutApplyCloseSection(obj);
        end

        function layoutApplyCloseSection(obj)
            import images.internal.app.segmenter.image.web.getMessageString;
                        
            useApplyAndClose = true;
            obj.ApplyCloseMgr = iptui.internal.ApplyCloseManager(obj.hTab, ...
                    getMessageString("samTabShortName"), useApplyAndClose );
            obj.ApplyCloseSection = obj.ApplyCloseMgr.Section;
            
            addlistener( obj.ApplyCloseMgr.ApplyButton, "ButtonPushed", ...
                                                @(~, ~) reactToApplyBtn(obj) );
            addlistener( obj.ApplyCloseMgr.CloseButton, "ButtonPushed", ...
                                                @(~,~) onClose(obj) );
        end

        function createBox(obj)
            createROI(obj, Deletable=false);
        end

        function mask = getBinaryMask(obj)
            mask = getScrollPanelPreview(obj.hApp);
        end

        function hideTab(obj)
            showSegmentTab(obj.hToolstrip);
            hideSAMRefineTab(obj.hToolstrip);
        end

        function setupDefaultTabSegState(~)
            % No action
        end

        function cleanupOnSegDoneImpl(~)
            % No action
        end
    end

    % Callbacks
    methods(Access=private)
        function reactToApplyBtn(obj)
            % In Refine Mode, the input mask is updated. The generated code
            % must reflect that.
            obj.CurrSessMLCode = obj.CurrSessMLCode + ...
                                            "BW = BWout;" + newline();
            onApply(obj);
            onClose(obj);
        end
    end


    methods(Access=private)
        function handleLoadedMask(obj)
            % An ROI is drawn around the existing mask to refine it
            bbox = computeMaskBbox(getCurrentMask(obj.hApp));
            obj.CurrSessMLCode = createCodeForRefineMask() + ...
                            obj.createSAMSegmentObjectsCode() + newline();
            
            createBox(obj);
            obj.DrawCtrls.ROI.Position = bbox;
            updateROIDisplay(obj, true);

            [mask, maskSrc] = applySegmentation(obj);
            setTempHistory(obj, mask, maskSrc);
        end
    end
end

function bbox = computeMaskBbox(binaryMask)
    bbox = [];
    if isempty(binaryMask)
        return;
    end

    rprops = regionprops(binaryMask, "BoundingBox");

    % An assert is OK because this check is made upstream of the SAM Tab.
    % Launching SAM Tab is disabled if mask has multiple regions
    assert( isscalar(rprops), "Refine mask supports only single region" );

    bbox = rprops.BoundingBox;
end

function codeStr = createCodeForRefineMask()
    codeStr = "fgPoints = [];" + newline() + "bgPoints = [];" + newline() + ...
              "maskLogits = [];" + newline() + ...
              "rprops = regionprops(BW, ""BoundingBox"");" + newline() + ...
              "bbox = rprops.BoundingBox;" + newline();
end

% Copyright 2023-2024 The MathWorks, Inc.