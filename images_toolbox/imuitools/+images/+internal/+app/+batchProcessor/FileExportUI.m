classdef FileExportUI < images.internal.app.utilities.OkCancelDialog
% Dialog UI Class that manages the exporting to image files, the results of
% applying the batch function in the imageBatchProcessor

%   Copyright 2021-2024 The MathWorks, Inc.

    properties(SetAccess=private, GetAccess=public)
        % Table that tracks to which file format does each image type
        % output needs to be exported to. It is a NumImages x 1 table.
        OutputImageExportSelection = table.empty();
        OutputImageDir = '';
    end
    
    % Initial values passed into the UI. The caller passes in these values
    % as the state of the UI is maintained across multiple invocations for
    % the same session. These values are required to bring up the UI with
    % the suitably initial state.
    properties(Access=private)
        InitImageExportSelection
        InitOutputImageDir
    end
    
    % Handles to UI Elements. These do not change and hence not required
    % for testing
    properties(Access=private)
        ImagesToExportPanel;
        OutputDirPanel;
    end
    
    % Handles to UI Elements required for testing
    properties(SetAccess=private, GetAccess=?uitest.factory.Tester)
        % Tracks the handles to all uidropdown elements
        % Needed to enable/disable the OK button
        ImageFmtSelectDropDown;
        OutputDirEditField;
        OutputDirBrowseButton;
        Tag = 'FileExportUITag';
    end

    properties(Access=private, Constant)
        DialogSize = [300 300];

        SupportedOutputImageExtns = cellstr([""; images.internal.app.utilities.supportedWriteFormats()]);
        
        % Defining some constants to layout the dialog
        HorizMargin = 5;
        TopMargin = 5;
        InterPanelSpacing = 5;
        SpaceAboveOkBtn = 10;
        OutputDirPanelHeight = 50;
    end
    
    methods
        function obj = FileExportUI(dialogStartLoc, initExportSelection, initOutDir)
            
            obj@images.internal.app.utilities.OkCancelDialog( dialogStartLoc, ...
                getString(message('images:imageBatchProcessor:exportToFiles')) );
            
            obj.Size = obj.DialogSize;
            
            % Set the initial values. Required to reset the values if the
            % dialog box is canceled after making changes to the fields
            obj.InitImageExportSelection = initExportSelection;
            obj.InitOutputImageDir = initOutDir;
            
            obj.restoreInitialValues();
            
            obj.createDialog();
        end
    end
    
    methods(Access=protected)
        function okClicked(obj)
            obj.OutputImageDir = obj.OutputDirEditField.Value;
            
            % Scan all the drop-down menu items and identify the value set
            % for each variable.
            for cnt = 1:numel(obj.ImageFmtSelectDropDown)
                imageVarName = extractBefore( obj.ImageFmtSelectDropDown(cnt).Tag, ...
                                                'DropDownTag' );
                
                obj.OutputImageExportSelection{imageVarName, 1} = ...
                                { obj.ImageFmtSelectDropDown(cnt).Value };
            end
            
            okClicked@images.internal.app.utilities.OkCancelDialog(obj);
        end
        
        function cancelClicked(obj)
            % Upon cancel, any changes made to the UI are not to be
            % retained.
            restoreInitialValues(obj);
            cancelClicked@images.internal.app.utilities.OkCancelDialog(obj);
        end
    end
    
    methods(Access=private)
        function createDialog(obj)
            obj.create();
            
            dialogWidth = obj.DialogSize(1);
            dialogHeight = obj.DialogSize(2);
            
            % There are two panels stacked one on top of the other.
            % Choose Image Fields to export and the file type
            % Output Directory where the images are written to
            
            % Create a UIPanel for the "Output Location"
            % The layout of this panel is:
            % Text box for location | Browse Button
            outputDirPanelPos = [ obj.HorizMargin, ...
                                  obj.Ok.Position(2) + obj.Ok.Position(4) + obj.SpaceAboveOkBtn, ...
                                  dialogWidth - 2*obj.HorizMargin, ...
                                  obj.OutputDirPanelHeight ];
            outputDirPanel = uipanel( obj.FigureHandle, ...
                            'Title', getString(message('images:imageBatchProcessor:enterOutputDirName')), ...
                            'Position', outputDirPanelPos, ...
                            'Tag', 'OutputDirPanel', ...
                            'FontName', 'Helvetica', ...
                            'FontSize', 12, ...
                            'FontWeight', 'bold', ...
                            'Visible', 'on' );
     
            % Create a grid layout for choosing the output location
            outputLocUG = uigridlayout( outputDirPanel, ...
                                        [1 2], ...
                                        'RowHeight', {'fit', 'fit'}, ...
                                        'ColumnWidth', {'3x' '1x'}, ...
                                        'Padding', [2 2 2 2] );
            
            % Add an edit field
            obj.OutputDirEditField = uieditfield( outputLocUG, ...
                                              'Value', obj.OutputImageDir, ...
                                              'HorizontalAlignment', 'left', ...
                                              'FontSize', 12, ...
                                              'FontName','Helvetica', ...
                                              'Editable', true, ...
                                              'Visible', 'on', ...
                                              'Tag', 'OutputDirEditField' );
            obj.OutputDirEditField.Layout.Row = 1;
            obj.OutputDirEditField.Layout.Column = 1;
            
            % Add a Browse button
            obj.OutputDirBrowseButton = uibutton( 'push', ...
                                     'Parent', outputLocUG, ...
                                     'Tag', 'OutputDirBrowseButton', ...
                                     'Text', getString(message('images:commonUIString:browse')), ...
                                     'FontSize', 12, ...
                                     'FontName','Helvetica', ...,
                                     'Visible', 'on', ...
                                     'ButtonPushedFcn', @obj.browseButtonPressed);
            obj.OutputDirBrowseButton.Layout.Row = 1;
            obj.OutputDirBrowseButton.Layout.Column = 2;
            
            % Create a UIPanel for the "Images to Export"
            imagesToExportPanelLoc = [ obj.HorizMargin, ...
                                       outputDirPanelPos(2) ...
                                            + obj.OutputDirPanelHeight ...
                                            + obj.InterPanelSpacing, ...
                                       dialogWidth - 2*obj.HorizMargin, ...
                                       dialogHeight - outputDirPanelPos(2) ...
                                            - obj.OutputDirPanelHeight ...
                                            - obj.InterPanelSpacing ...
                                            - obj.TopMargin ];
            imagesToExportPanel = uipanel( obj.FigureHandle, ...
                            'Position', imagesToExportPanelLoc, ...
                            'Title', getString(message('images:imageBatchProcessor:exportToFiles')), ...
                            'Tag', 'ImagesToExportPanel', ...
                            'FontName', 'Helvetica', ...
                            'FontSize', 12, ...
                            'FontWeight', 'bold', ...
                            'Visible', 'on' );
            
            % Create a grid-layout for choosing the images that are to be
            % exported and the file formats to which they should be
            % exported
            allImageResultNames = obj.InitImageExportSelection.Row;
            numImageResults = numel(allImageResultNames);
            chooseImageUG = uigridlayout( imagesToExportPanel, ...
                                          [numImageResults 2], ...
                                          'RowHeight', repmat({'fit'}, numImageResults, 1), ...
                                          'ColumnWidth', {'2x', '1x'}, ...
                                          'Padding', [2 2 2 2], ...
                                          'Scrollable', 'on' );
            
            initOutputImageFileTypes = obj.InitImageExportSelection.OutputImageFileTypes;
            obj.Ok.Enable = ~all( cellfun(@(x) isempty(x), initOutputImageFileTypes) );
            
            % Creating an array to store the checkboxes that are to be
            % created.
            obj.ImageFmtSelectDropDown = gobjects(numImageResults, 1);
            for cnt = 1:numImageResults
                imageResult = allImageResultNames{cnt};
                
                % Create a status label
                lbl = uilabel( chooseImageUG, ...
                               'Text', imageResult, ...
                               'Tag', sprintf('%sTag', imageResult), ...
                               'FontName', 'Helvetica', ...
                               'FontSize', 12, ...
                               'Visible', 'on' );
                lbl.Layout.Row = cnt;
                lbl.Layout.Column = 1;
                
                % Create a Drop-Down menu
                
                dd = uidropdown( chooseImageUG, ...
                                 'Items', obj.SupportedOutputImageExtns, ...
                                 'Value', initOutputImageFileTypes{cnt}, ...
                                 'FontName', 'Helvetica', ...
                                 'FontSize', 12, ...
                                 'Tag', sprintf('%sDropDownTag', imageResult), ...
                                 'Visible', 'on', ...
                                 'ValueChangedFcn', @obj.imageExtnChanged );
                dd.Layout.Row = cnt;
                dd.Layout.Column = 2;
                
                obj.ImageFmtSelectDropDown(cnt) = dd;
            end
            
            
        end
        
        function restoreInitialValues(obj)
            obj.OutputImageExportSelection = obj.InitImageExportSelection;
            obj.OutputImageDir = obj.InitOutputImageDir;
        end
        
        function imageExtnChanged(obj, ~, eventData)
            if strcmpi(eventData.Value, eventData.PreviousValue)
                return;
            end
            
            % Enable/disable the OK button depending upon the selection in
            % the drop-down
            obj.Ok.Enable = ~all( arrayfun( @(x) isempty(x.Value), ...
                                        obj.ImageFmtSelectDropDown ) );
        end
        
        function browseButtonPressed(obj, ~, ~)
            selPath = uigetdir( obj.OutputImageDir, ...
                                getString(message('images:imageBatchProcessor:loadImages')) );
                            
            if selPath == 0
                return;
            end
            
            obj.OutputImageDir = selPath;
            obj.OutputDirEditField.Value = obj.OutputImageDir;
        end
    end
end
