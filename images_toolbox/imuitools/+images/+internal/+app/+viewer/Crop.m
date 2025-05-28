classdef Crop < matlab.mixin.SetGet
% Helper class that handles the crop operations for the ImageViewer app.
% This helper does not require any knowledge of the app but only the image
% handle from which the image will be cropped from.

% Copyright 2023 The MathWorks, Inc.

    properties (Dependent)
        IsEnabled             (1,1) logical
    end

    properties (Dependent, SetAccess = private)
        Position
    end

    properties (SetAccess = private, ...
            GetAccess = ?imtest.apptest.imageViewerTest.PropertyAccessProvider)
        ImageHandle
        ROI
    end

    properties (Access = private)
        IsEnabledInternal = false;
    end

    events
        ExportROI
    end

    methods

        %------------------------------------------------------------------
        % Crop
        %------------------------------------------------------------------
        function obj = Crop(imageHandle)
            obj.ImageHandle = imageHandle;

            parentFig = ancestor(imageHandle.AxesHandle, "figure", "toplevel");
            roiContextMenu = uicontextmenu(parentFig);

            uimenu( roiContextMenu, ...
                    Label=getString(message('images:imroi:fixAspectRatio')), ...
                    Checked="off", ...
                    Tag="FixAspectRatioROI", ...
                    MenuSelectedFcn=@(src, ~) reactToFixAspectROI(obj, src) );

            % Update the context Menu to add support for exporting the
            % selected rectangle
            exportMenu = uimenu( roiContextMenu, ...
                            Label=getString(message("images:imageViewer:exportSelect")), ...
                            Tag="CropExportROI" );

            uimenu( exportMenu, ...
                    Label=getString(message("images:imageViewer:exportSelectToWkspace")), ...
                    Tag="CropExportROIToWkspace", ...
                    MenuSelectedFcn=@(~, evt) reactToExportROI(obj, evt) );

            uimenu( exportMenu, ...
                    Label=getString(message("images:imageViewer:exportSelectToImageFile")), ...
                    Tag="CropExportROIToImage", ...
                    MenuSelectedFcn=@(~, evt) reactToExportROI(obj, evt) );

            obj.ROI = images.roi.Rectangle( FaceAlpha=0, ...
                            Parent=imageHandle.AxesHandle, ...
                            Visible="off", ...
                            Deletable=false, ...
                            LineWidth=3, ...
                            LabelAlpha=1, ...
                            LabelTextColor=[0,0,0], ...
                            ContextMenu = roiContextMenu );

            addlistener( obj.ROI, "MovingROI", ...
                         @(src,evt) reactToROIMove(obj,evt) );
        end

        function delete(obj)
            delete(obj.ROI);
        end
    end

    % Helper functions
    methods (Access = private)
        function showROI(obj)
            % Display the ROI

            % Obtain the current view limits
            xlim = obj.ImageHandle.XLim;
            ylim = obj.ImageHandle.YLim;

            viewWidth = xlim(2) - xlim(1);
            viewHeight = ylim(2) - ylim(1);

            % Set to 90% of the current view limits. 
            % Starting X and Y positions will be at 5% from the left and
            % top corner of the current view
            startFrac = 0.05;
            xstart = startFrac*viewWidth + xlim(1);
            ystart = startFrac*viewHeight + ylim(1);

            widthFrac = 0.9;
            roiWidth = widthFrac*viewWidth;
            roiHeight = widthFrac*viewHeight;

            obj.ROI.Position = [xstart ystart roiWidth roiHeight];

            imageDims = size(obj.ImageHandle.ImageHandle.CData, [1 2]);
            obj.ROI.Label = computeLabelStr( obj.ROI.Position, ...
                                            imageDims(2), imageDims(1) );
            obj.ROI.Visible = "on";
        end

        function hideROI(obj)
            obj.ROI.Visible = 'off';
        end

    end

    % Getters/Setters
    methods
        function set.IsEnabled(obj, TF)
            obj.IsEnabledInternal = TF;
            if obj.IsEnabledInternal
                showROI(obj);
            else
                hideROI(obj);
            end
        end

        function TF = get.IsEnabled(obj)
            TF = obj.IsEnabledInternal;
        end

        function pos = get.Position(obj)
            pos = obj.ROI.Position;
        end

    end

    % Callbacks/Helpers
    methods(Access=private)
        function reactToFixAspectROI(obj, src)
            % Toggle whether the ROI's aspect ratio must be fixed or not

            obj.ROI.FixedAspectRatio = ~obj.ROI.FixedAspectRatio;
            src.Checked = obj.ROI.FixedAspectRatio;
        end

        function reactToROIMove(obj, evt)
            % Update the Label on the ROI
            
            imageDims = size(obj.ImageHandle.ImageHandle.CData, [1 2]);
            obj.ROI.Label = computeLabelStr( evt.CurrentPosition, ...
                                            imageDims(2), imageDims(1) );
        end

        function reactToExportROI(obj, evt)
            % Callback for handling exporting the ROI

            if evt.Source.Tag == "CropExportROIToWkspace"
                outTarget = "workspace";
            else
                outTarget = "file";
            end

            data = struct("Target", outTarget, "Position", obj.Position);
            
            eventData = images.internal.app.viewer.ViewerEventData(data);
            notify(obj, "ExportROI", eventData);
        end
    end
end

function labelStr = computeLabelStr(roiPosition, imageWidth, imageHeight)
% Helper function that computes the ROI size in pixels for display

    [rstart, cstart, rend, cend] = ...
       images.internal.crop.computeImageIndices(roiPosition, 1, 1, 1, 1);

    % The ROI dimensions in pixels will include both the start and end
    % pixels in the ROI. So it will be one more than the computed values
    roiWidth = cend-cstart+1;
    roiHeight = rend-rstart+1;

    % Clamping the values to the dimensions of the image being displayed.
    roiWidth = min(roiWidth, imageWidth);
    roiHeight = min(roiHeight, imageHeight);

    labelStr = roiWidth + " x " + roiHeight + " px";
end
