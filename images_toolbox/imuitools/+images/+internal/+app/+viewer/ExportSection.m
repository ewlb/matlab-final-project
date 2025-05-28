classdef (Sealed) ExportSection < handle
% Helper class that creates and manages the Export Section of the
% ImageViewer app Toolstrip

%   Copyright 2023 The MathWorks, Inc.    

    events
        ExportImageToWorkspaceReq
        ExportImageToFileReq
        ExportMeasurementReq
    end

    properties( SetAccess = ?images.internal.app.viewer.ImageViewer, ...
                 GetAccess = { ?uitest.factory.Tester, ...
                               ?images.internal.app.viewer.ImageViewer, ...
                               ?imtest.apptest.imageViewerTest.PropertyAccessProvider} )
        DataExportPopupList     matlab.ui.internal.toolstrip.PopupList
        DataExportSplitBtn      matlab.ui.internal.toolstrip.SplitButton
    end

    properties(GetAccess=public, SetAccess=private)
        CurrentState = struct.empty();
    end

    properties(Access=private, Constant)
        ControlsList = images.internal.app.viewer.createControlsList( ...
                            ?images.internal.app.viewer.ExportSection, ...
                            "Btn" );
    end

    methods(Access=public)
        function obj = ExportSection(mainTab)
            createExportSection(obj, mainTab);
        end

        function restoreState(obj, state)
            obj.DataExportSplitBtn.Enabled = state.DataExportSplitBtn;
        end
    end

    % Getters/Setters
    methods
        function val = get.CurrentState(obj)
            for cnt = 1:numel(obj.ControlsList)
                cname = obj.ControlsList(cnt);
                val.(cname) = obj.(cname).Enabled;
            end
        end
    end

    % Helper functions
    methods(Access=private)
        function createExportSection(obj, mainTab)
            import matlab.ui.internal.toolstrip.*

            section = addSection( mainTab, ...
                            getString(message("images:commonUIString:export")));

            column = section.addColumn();

            % Add list items to export final image to workspace/file
            imageToWkspace = ListItem( getString(message("images:imageViewer:toWkspace")), ...
                                        Icon('workspace') );
            imageToWkspace.ShowDescription = false;
            imageToWkspace.Tag = "ImageToWkspace";
            addlistener( imageToWkspace, "ItemPushed", ...
                         @(~,~) notify(obj, "ExportImageToWorkspaceReq") );

            imageToFile = ListItem( getString(message("images:imageViewer:toImageFile")), ...
                                        Icon('image') );
            imageToFile.ShowDescription = false;
            imageToFile.Tag = "ImageToFile";
            addlistener( imageToFile, "ItemPushed", ...
                         @(~,~) notify(obj, "ExportImageToFileReq") );

            imageExportPopupList = matlab.ui.internal.toolstrip.PopupList();

            add(imageExportPopupList, imageToWkspace);
            add(imageExportPopupList, imageToFile);

            % Add list items for:
            % Export Final Image (top-level)
            % Export Measurements
            exportFinalImage = ListItemWithPopup( ...
                                    getString(message("images:imageViewer:exportFinalImage")), ...
                                    Icon("export") );
            exportFinalImage.Popup = imageExportPopupList;
            exportFinalImage.ShowDescription = true;
            exportFinalImage.Tag = "ExportFinalImage";
            exportFinalImage.Description = ...
                    getString(message("images:imageViewer:exportFinalImageTooltip"));

            exportMeas = ListItem( getString(message("images:imageViewer:exportMeas")), ...
                                          Icon('workspace') );
            exportMeas.ShowDescription = true;
            exportMeas.Enabled = false;
            exportMeas.Tag = "ExportMeas";
            exportMeas.Description = ...
                    getString(message("images:imageViewer:exportMeasTooltip"));
            addlistener( exportMeas, "ItemPushed", ...
                         @(~,~) notify(obj, "ExportMeasurementReq") );


            obj.DataExportPopupList = matlab.ui.internal.toolstrip.PopupList();
            add(obj.DataExportPopupList, exportFinalImage);
            add(obj.DataExportPopupList, exportMeas);
            
            obj.DataExportSplitBtn = SplitButton( ...
                        getString(message("images:commonUIString:export")), ...
                        Icon("export") );
            obj.DataExportSplitBtn.Tag = "Export";
            obj.DataExportSplitBtn.Enabled = false;
            obj.DataExportSplitBtn.Description = ...
                        getString(message("images:imageViewer:exportTooltip"));
            obj.DataExportSplitBtn.Popup = obj.DataExportPopupList;
            addlistener( obj.DataExportSplitBtn, "ButtonPushed", ...
                         @(~,~) notify(obj, "ExportImageToWorkspaceReq") );
            column.add(obj.DataExportSplitBtn);
        end
    end
end