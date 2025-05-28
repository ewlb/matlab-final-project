classdef SAMMgr < handle
    % Class that manages the lifetime of the SAM object and image
    % embeddings for the Image Segmenter App
    % Loading SAM and computing embeddings take a non-trivial amount of
    % time especially on CPU. 
    % SAM is used in multiple tabs in the Image Segmenter App. This class
    % helps improve the performance

    properties(Access=private)
        % Holds the SAM object
        SAMNet = [];

        % Stores the Image embeddings. This is only used by Prompt-based
        % SAM
        ImageEmbeds (:, :, :) = []

        % Image Size
        ImageSize (:, 2) = []

        % Progress Dialog for Automatic Segmentation
        AutoSegProgressDlg (:, :) matlab.ui.dialog.ProgressDialog = ...
                                matlab.ui.dialog.ProgressDialog.empty()
    end

    methods(Access=private)
        function obj = SAMMgr()
        end
    end

    methods(Access=public, Static)
        function obj = getInstance()
            persistent localObj
            if isempty(localObj)
                localObj = images.internal.app.segmenter.image.web.sam.SAMMgr();
            end

            obj = localObj;
        end
    end

    methods(Access=public)
        function delete(obj)
            obj.SAMNet = [];
        end

        function [isSuccess, useGPU, isEnableUseGPU] = ...
                                    init( obj, im, app )
            % Helper function that computes embeddings for use in the Image
            % Segmenter App
        
            import images.internal.app.segmenter.image.web.getMessageString;
        
            obj.ImageSize = size(im, [1 2]);

            % Check if GPU can be used for computing embeddings
            [useGPU, isEnableUseGPU] = images.internal.app.segmenter.image.web.sam.canUseGPU(app);

            % If SAM has not been already loaded, then load it into memory
            dlg = [];
            if app.Visible
                initSAMMsg = string(getMessageString("initSAMProgress"));
                dlg = uiprogressdlg( app, Message="", ...
                                 Title=getMessageString("appName"), ...
                                 Indeterminate=true, Cancelable=false );
            end
            if isempty(obj.SAMNet)
                if app.Visible
                    loadSAMMsg = getMessageString("loadSAMProgress");
                    dlg.Message = initSAMMsg + loadSAMMsg;
                end
                loadSAM(obj, app);
            end
        
            isSuccess = ~isempty(obj.SAMNet);
            if isSuccess
                % SAM instance was created successfully. Now try to compute
                % the embeddings if requested
        
                if isempty(obj.ImageEmbeds)
                    % Move the image to the GPU before computing embeddings
                    if useGPU
                        im = gpuArray(im);
                    end
                    if app.Visible
                        extractEmbedsMsg = getMessageString("extractEmbedsProgress");
                        dlg.Message = initSAMMsg + extractEmbedsMsg;
                    end
                    obj.ImageEmbeds = computeEmbeddings(obj, im, app);
                end

                isSuccess = ~isempty(obj.ImageEmbeds);
            end

            if ~isempty(dlg)
                close(dlg);
            end
        end

        function clearEmbeddings(obj)
            obj.ImageEmbeds = [];
        end

        function [mask, maskLogits] = segmentUsingPrompts( obj, maskLogits, ...
                                        fgPoints, bgPoints, bbox, useGPU )
            isPerformSeg = ~( isempty(fgPoints) && isempty(bbox) );
            if isPerformSeg
                assert( ~isempty(obj.SAMNet), ...
                        "SAM Network must be initialization before segmentation" );
                assert( ~isempty(obj.ImageEmbeds), ...
                        "Embedings must be computed before segmentation" );

                if useGPU
                    obj.ImageEmbeds = gpuArray(obj.ImageEmbeds);
                else
                    obj.ImageEmbeds = gather(obj.ImageEmbeds);
                end

                [mask, ~, maskLogits] = ...
                    segmentObjectsFromEmbeddings( obj.SAMNet, ...
                                        obj.ImageEmbeds, obj.ImageSize, ...
                                        ForegroundPoints=fgPoints, ...
                                        BackgroundPoints=bgPoints, ...
                                        BoundingBox=bbox, ...
                                        MaskLogits=maskLogits );
            else
                mask = false(obj.ImageSize(1), obj.ImageSize(2));
                maskLogits = [];
            end
        end

        function [L, isCanceled, isError] = segmentAllObjects( obj, im, ...
                                                    params, useGPU, app )
            import images.internal.app.segmenter.image.web.getMessageString;
            import images.internal.app.segmenter.image.web.sam.displayErrorDialog;
            import images.internal.app.segmenter.image.web.sam.refineBorders;
        
            try
                L = [];
                isCanceled = false;
                isError = false;
                autoSegEL = event.listener.empty();
                if ~isempty(params)
                    assert( ~isempty(obj.SAMNet), ...
                        "SAM Network must be initialization before segmentation" );
                    msgStr = string(getMessageString("samAutoSegProgDlg"));
                    if ~useGPU
                        envVal = "cpu";
        
                        % Check if a valid GPU is available. If YES, it means the
                        % user has explicitly disabled GPU usage. Show the GPU
                        % specific message only in that case.
                        if canUseGPU()
                            msgStr = msgStr + newline() + newline() + ...
                                    getMessageString("samAutoSegProgDlgUseGPU");
                        end
                    else
                        envVal = "gpu";
                    end
                    params.ExecutionEnvironment = envVal;
                    params.Verbose = false;
                    params.PointGridMask = true( obj.ImageSize(1), ...
                                                 obj.ImageSize(2) );
        
                    obj.AutoSegProgressDlg = uiprogressdlg( app, ...
                                        Message=msgStr, ...
                                        Title=getMessageString("appName"), ...
                                        Indeterminate=true, ...
                                        Cancelable=true );

                    % Attach a listener and clear it up within this
                    % function to ensure it does not remain active for the
                    % entire life-time of the App or the SAM object.
                    autoSegEL = addlistener( obj.SAMNet, ...
                                        "PointBatchProcessed", ...
                                        @(~, ~) reactToAutoSegBatchDone(obj) );

                    % SAM expects image data to be in the range [0-255]
                    im = 255*rescale(im);
                    cc = segmentObjects(obj.SAMNet, im, params);
                    
                    if cc.NumObjects > 0
                        % Using the default labelmatrix behaviour to select
                        % the labels for overlapping regions 
                        L = labelmatrix(cc);
                        L = refineBorders(L);
                    else
                        isCanceled =  obj.AutoSegProgressDlg.CancelRequested;
                    end
                end
            catch ME
                isError = true;
                displayErrorDialog(app, ME.message);
            end

            delete(autoSegEL);
            close(obj.AutoSegProgressDlg);
            obj.AutoSegProgressDlg = matlab.ui.dialog.ProgressDialog.empty();
        end
    end

    methods(Access=private)
        function loadSAM(obj, app)
            import images.internal.app.segmenter.image.web.sam.createNet;
            import images.internal.app.segmenter.image.web.sam.displayErrorDialog;
            try
                obj.SAMNet = createNet();
            catch ME
                displayErrorDialog(app, ME.message);
            end
        end

        function embeds = computeEmbeddings(obj, im, app)
            % Compute embeddings for the specified image
            import images.internal.app.segmenter.image.web.sam.displayErrorDialog;
            try
                im = 255*rescale(im);
                embeds = extractEmbeddings(obj.SAMNet, im);
            catch ME
                embeds = [];
                displayErrorDialog(app, ME.message);
            end
        end

        function reactToAutoSegBatchDone(obj)
            if obj.AutoSegProgressDlg.CancelRequested
                stop(obj.SAMNet);
            end
        end
    end
end

% Copyright 2023-2024 The MathWorks, Inc.
