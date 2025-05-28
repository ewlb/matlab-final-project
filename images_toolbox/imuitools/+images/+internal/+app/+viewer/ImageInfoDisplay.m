classdef ImageInfoDisplay < matlab.mixin.SetGet
% Helper class that handles the displaying image information in an app

%   Copyright 2023 The MathWorks, Inc.

    properties(GetAccess= ?imtest.apptest.imageViewerTest.PropertyAccessProvider, SetAccess=private)
        ImportedImageInfo     (1, 1)  images.internal.app.viewer.SrcImageInfo
        IsEnabled           (1, 1)  logical
    end

    properties (SetAccess = private, ...
                GetAccess = { ?uitest.factory.Tester, ...
                              ?imtest.apptest.imageViewerTest.PropertyAccessProvider})

        % Handle to the Figure Panels
        ImportedImageInfoFigPanel = []

        % Handle to the uitable objects displaying the information
        ImportedInfoTable
    end

    methods

        %------------------------------------------------------------------
        % Info
        %------------------------------------------------------------------
        function obj = ImageInfoDisplay(linfo)
            arguments
                linfo (1, 1) images.internal.app.viewer.SrcImageInfo ...
                                = images.internal.app.viewer.SrcImageInfo();
            end
            obj.ImportedImageInfo = linfo;

            obj.IsEnabled = false;
        end

        function updateImportedImageInfo(obj, linfo, options)
            arguments
                obj (1, 1) images.internal.app.viewer.ImageInfoDisplay
                linfo (1, 1) images.internal.app.viewer.SrcImageInfo

                % Tracks whether new image information has been provided OR
                % just a modification to the existing image via cropping or
                % contrast. For the latter, only the figure panel title
                % needs to be updated.
                options.IsNewImageInfo (1, 1) logical = true
            end

            obj.ImportedImageInfo = linfo;
            if obj.IsEnabled
                updateImportedImageInfoUI(obj, options.IsNewImageInfo);
            end
        end


        function enable(obj, app, tf)
            obj.IsEnabled = tf;

            if obj.IsEnabled
                if isempty(obj.ImportedImageInfoFigPanel)
                    createPanel(obj, app);
                end
                updateImportedImageInfoUI(obj);
                obj.ImportedImageInfoFigPanel.Opened = true;
            else
                if ~isempty(obj.ImportedImageInfoFigPanel)
                    obj.ImportedImageInfoFigPanel.Opened = false;
                end
            end
        end


    end

    % Creation Helpers
    methods (Access = private)
        function createPanel(obj, app)
            % Title will be populated based on the image data
            importedImageInfoPanel.Title = "";
            importedImageInfoPanel.Tag = "ImportedImageInfoPanel";
            importedImageInfoPanel.Region = "left";
            obj.ImportedImageInfoFigPanel = matlab.ui.internal.FigurePanel(importedImageInfoPanel);
            obj.ImportedImageInfoFigPanel.Opened = false;

            obj.ImportedInfoTable = createTable(obj.ImportedImageInfoFigPanel.Figure);
            app.add(obj.ImportedImageInfoFigPanel);
        end

        function updateImportedImageInfoUI(obj, isNewImageInfo)
            % Helper to update the values of the UITable displaying the
            % imported image information values

            arguments
                obj (1, 1) images.internal.app.viewer.ImageInfoDisplay
                isNewImageInfo (1, 1) logical = true
            end

            % Parse the image info only if the image data is updated
            importedInfo = obj.ImportedImageInfo;

            switch(importedInfo.SourceType)
                case "File"
                    if importedInfo.MaxNumImages > 1
                        figPanelTitle = getString( ...
                            message( "images:imageViewer:imageInfo", ...
                                    importedInfo.CurrIdx, ...
                                    importedInfo.MaxNumImages, ...
                                    importedInfo.Name ) );
                    else
                        figPanelTitle = importedInfo.Name;
                    end
                    if isNewImageInfo
                        obj.ImportedInfoTable.Data = parseInfo(importedInfo.Info);
                    end

                case "Workspace"

                    if importedInfo.Info.Datatype == "logical"
                        varNameStr = ...
                            getString(message("images:imageViewer:logicalMatrix"));
                    else
                        varNameStr = ...
                            getString(message("images:imageViewer:numericArray"));
                    end

                    if importedInfo.Name ~= ""
                        varNameStr = varNameStr + ": " + importedInfo.Name;
                    end

                    if importedInfo.MaxNumImages > 1
                        figPanelTitle = getString( ...
                            message( "images:imageViewer:imageInfo", ...
                                    importedInfo.CurrIdx, ...
                                    importedInfo.MaxNumImages, ...
                                    varNameStr ) );
                    else
                        figPanelTitle = varNameStr;
                    end
                    if isNewImageInfo
                        obj.ImportedInfoTable.Data = parseInfo(importedInfo.Info);
                    end

                otherwise
                    assert(false, "Unsupported Source Type");
            end

            modMethod = obj.ImportedImageInfo.ModificationMethod;
            
            if isempty(modMethod)
                obj.ImportedImageInfoFigPanel.Title = figPanelTitle;
            else
                % If any modifications were performed on the image, then
                % updated the title of the panel to reflect this
                modDesc = repmat("", [numel(modMethod) 1]);

                modDesc(modMethod == "Crop") = ...
                        getString(message("images:imageViewer:cropped"));
                modDesc(modMethod == "Contrast") = ...
                        getString(message("images:imageViewer:contrastAdjust"));
                modStr = strjoin(modDesc, "/");
                titleStr = ...
                        getString( message( "images:imageViewer:modifiedImageInfo", ...
                                        modStr, figPanelTitle ) );
                obj.ImportedImageInfoFigPanel.Title = titleStr;
            end
        end
    end
end

% Helper functions
function tblHandle = createTable(figHandle)
% Create a UI Table

    set( figHandle,...
         Units="pixels", ...
         HandleVisibility="off" );

    layoutGrid = uigridlayout( figHandle, ...
                               Padding=[2, 2, 2, 2], ...
                               ColumnWidth={'1x'}, ...
                               RowHeight={'1x'} );

    colNames = [ string(getString(message("images:imageViewer:infoAttrib")));
                 string(getString(message("images:imageViewer:infoValue"))) ];

    tblHandle = uitable( Parent=layoutGrid,...
                         FontSize=12,...
                         Enable="on",...
                         ColumnName=colNames,...
                         RowName={},...
                         Visible="on",...
                         SelectionType="row",...
                         Tag="LoadedImageInfoTable",...
                         Data={} );
end

function t = parseInfo(info) %#ok<INUSD>
% Helper function parse an INFO struct. This is needed to split the field
% names and values of an INFO struct into tables that can be used as data
% for the uitable

    dispLines = string(evalc("disp(info)"));
    dispLines = split(dispLines, newline());
    dispLines = strip(dispLines);
    dispLines(~contains(dispLines, ":")) = [];
    [fieldName, fieldVal] = arrayfun(@(x) splitField(x), dispLines);

    t = table(strip(fieldName), strip(fieldVal));
    t.Properties.VariableNames = ["FieldName", "FieldValue"];
end

function [fn, fv] = splitField(field)
% Helper function to split a string with the format "val1 : val2"
    idx = strfind(field, ":");
    idx = idx(1);
    fn = strip(extractBefore(field, idx));
    fv = strip(extractAfter(field, idx));
end
