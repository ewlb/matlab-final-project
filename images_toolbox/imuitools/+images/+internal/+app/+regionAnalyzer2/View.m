classdef View < handle
    %

    % Copyright 2020-2023 The MathWorks, Inc.
    
    properties (GetAccess = {?uitest.factory.Tester})
        Container
    end
    
    properties (Dependent,SetAccess = private)
        AppState
    end
    
    properties (GetAccess = {?uitest.factory.Tester})
        ImageDisplayFigure
        ImageDisplay
        Table
        FilterDlg
    end
    
    properties (GetAccess = private)
        TabGroup
        AnalysisTab
        LoadImageSection
        RegionFilteringSection
        TableViewSection
        TableViewPanel
        ExportSection
    end
    
    properties (GetAccess = private)
        LoadImageButton
        ExportButton
    end
    
    properties (GetAccess = private)
        ExcludeBorderCheckbox
        FillHolesCheckbox
        FilterButton
    end
    
    properties (GetAccess = private)
        SelectPropsButton
        PropertyPickerPanel
        TableViewCheckboxes
        PropertyPickerPopup
    end
    
    properties (Access = private)
        SelectedRegionColormap
    end
    
    properties (GetAccess = {?uitest.factory.Tester})
        LoadFromWorkspaceDlg
        ExportImageDlg
        ExportPropsDlg
    end
    
    events
        ImportFromWorkspace
        ImportFromFile
        TableRegionSelected
        PropertyViewChange
        ExportImageToWorkspace
        ExportPropertiesToWorkspace
        GenerateCode
        FilterRegionDialogRequest
        FilterUpdate
        FilterPropertyUpdate
        FilterTypeUpdate
        ExcludeBorderCheckboxValueChanged
        FillHolesCheckboxValueChanged
    end
    
    methods
        
        function h = get.AppState(self)
            h = self.Container.State;
        end
        
        function self = View
            
            % Used by draw method of image display for managing overlay of
            % selection mask on image.
            self.SelectedRegionColormap = zeros(256,3);
            self.SelectedRegionColormap(2,:) = [1 0 0];
            
            buildAppContainer(self);
            
            self.TabGroup = matlab.ui.internal.toolstrip.TabGroup();
            self.TabGroup.Tag = 'regionAnalyzerTabGroup';
            
            % Create toolstrip components.
            self.AnalysisTab = self.TabGroup.addTab(message('images:regionAnalyzer:analysisTabTitle').getString());
            self.AnalysisTab.Tag = 'AnalysisTab';
            
            self.LoadImageSection = self.layoutLoadImageSection(self.AnalysisTab);
            self.RegionFilteringSection = self.layoutRegionFilteringSection(self.AnalysisTab);
            self.TableViewSection = self.layoutTableViewSection(self.AnalysisTab);
            
            self.ExportSection = self.layoutExportSection(self.AnalysisTab);
            
            self.Container.addTabGroup(self.TabGroup); % Add tab group to container
            
            createFigure(self);
            
            self.Container.Visible = true;
            
            createTableViewPanel(self);
                        
            imageslib.internal.apputil.manageToolInstances('add', 'imageRegionAnalyzer', self);
            addlistener(self,'ObjectBeingDestroyed',@(hobj,evt) close(self.Container));
            addlistener(self,'ObjectBeingDestroyed',@(hobj,evt) closeFilterDlg(self));
            addlistener(self.Container,'StateChanged',@(hobj,evt) manageAppClosedByUser(self));
        end

        function manageAppClosedByUser(self)
            if self.AppState == "TERMINATED"
                closeFilterDlg(self);
            end
        end
        
        function closeFilterDlg(self)
            if ~isempty(self.FilterDlg)  && ...
                ishandle(self.FilterDlg.FigureHandle)
                close(self.FilterDlg);
            end
        end
        
        function createFigure(self)
            
            import matlab.ui.internal.toolstrip.*
            import matlab.ui.internal.*;
            
            % Add a document group
            group = FigureDocumentGroup();
            group.Title = "Figures";  % This line can be removed once the FigureDocumentGroup is modified to have a default title
            self.Container.add(group);
            
            % Add a figure-based document
            figOptions.Title = getString(message('images:regionAnalyzer:analyzeRegions'));
            figOptions.DocumentGroupTag = group.Tag;
            document = FigureDocument(figOptions);
            document.Closable = false;
            self.Container.add(document);
            
            document.Figure.AutoResizeChildren = 'off';
            self.ImageDisplayFigure = document.Figure;
            
            hpanel = uipanel('Units','pixels', 'Position',[1 1 self.ImageDisplayFigure.Position(3:4)],...
                'BorderType', 'none',...
                'AutoResizeChildren','off','Parent',...
                self.ImageDisplayFigure);
            
            self.ImageDisplayFigure.SizeChangedFcn = @(hobj,evt) iAdjustPanelPosition(hpanel,self.ImageDisplay,evt);
            
            self.ImageDisplay = images.internal.app.utilities.Image(hpanel);
            
            addlistener(self.ImageDisplayFigure,'WindowScrollWheel',@(src,evt) scroll(self.ImageDisplay,evt.VerticalScrollCount));
            addlistener(self.ImageDisplayFigure,'WindowMouseMotion',@(src,evt) motionCallback(self,src,evt));
            
        end
           
        function motionCallback(self,src,evt)
            
            hitObject = ancestor(evt.HitObject,'figure');
            
            if hitObject == self.ImageDisplayFigure
                if wasClickOnAxesToolbar(self,evt)
                    images.roi.setBackgroundPointer(src,'arrow');
                elseif isa(evt.HitObject,'matlab.graphics.primitive.Image')
                    if isprop(evt.HitObject,'InteractionMode')
                        switch evt.HitObject.InteractionMode
                            case ''
                                images.roi.setBackgroundPointer(src,'arrow');
                            case 'pan'
                                images.roi.setBackgroundPointer(src,'custom',matlab.graphics.interaction.internal.getPointerCData('pan_both'),[16,16]);
                            case 'zoomin'
                                images.roi.setBackgroundPointer(src,'custom',matlab.graphics.interaction.internal.getPointerCData('zoomin_unconstrained'),[16,16]);
                            case 'zoomout'
                                images.roi.setBackgroundPointer(src,'custom',matlab.graphics.interaction.internal.getPointerCData('zoomout_both'),[16,16]);
                        end
                    else
                        images.roi.setBackgroundPointer(src,'arrow');
                    end
                else
                    images.roi.setBackgroundPointer(src,'arrow');
                end
            else
                images.roi.setBackgroundPointer(src,'arrow');
            end
            
        end
        
        function TF = wasClickOnAxesToolbar(~,evt)
            TF = ~isempty(ancestor(evt.HitObject,'matlab.graphics.controls.AxesToolbar'));
        end
        
        
        function createTableViewPanel(self)
            panelOptions.Title = getString(message('images:regionAnalyzer:regionProperties'));

            panelOptions.Region = "right";
            self.TableViewPanel = matlab.ui.internal.FigurePanel(panelOptions);
            self.Container.add(self.TableViewPanel);
        end
        
        function buildAppContainer(self)
            appName = getString(message('images:regionAnalyzer:appName'));
            
            [~, uniqueName] = fileparts(tempname);
            
            [x,y,width,height] = imageslib.internal.app.utilities.ScreenUtilities.getInitialToolPosition();
            appOptions.WindowBounds = [x,y,width,height];
            appOptions.Tag = uniqueName;
            appOptions.Title = appName;
            appOptions.Product = "Image Processing Toolbox";
            appOptions.Scope = "Image Region Analyzer";
            appOptions.EnableTheming = true;
            
            self.Container = matlab.ui.container.internal.AppContainer(appOptions);
            self.Container.CanCloseFcn = @(hobj,evt) manageClose(self,hobj);
            
            % Turn off tiling options that don't work well in this app.
            self.Container.UserDocumentTilingEnabled = false;
        end
        
        function hSection = layoutLoadImageSection(self, parentTab)
            
            import matlab.ui.internal.toolstrip.*
            
            hSection = parentTab.addSection(getString(message('images:colorSegmentor:loadImage')));
            hSection.Tag = 'LoadImage';
            
            c = hSection.addColumn();
            
            self.LoadImageButton = SplitButton(getString(message('images:colorSegmentor:loadImageSplitButtonTitle')),...
                Icon('import_data'));
            
            self.LoadImageButton.Enabled = true;
            
            self.LoadImageButton.Tag = 'btnLoadImage';
            self.LoadImageButton.Description = getString(message('images:colorSegmentor:loadImageSplitButtonTitle'));
            popup = matlab.ui.internal.toolstrip.PopupList;
            
            loadFromFilePopupItem = ListItem(getString(message('images:colorSegmentor:loadImageFromFile')),Icon('folder'));
            loadFromFilePopupItem.ShowDescription = false;
            loadFromFilePopupItem.Tag = 'loadFromFilePopup';
            loadFromWorkspacePopupItem = ListItem(getString(message('images:colorSegmentor:loadImageFromWorkspace')),Icon('workspace'));
            loadFromWorkspacePopupItem.ShowDescription = false;
            loadFromWorkspacePopupItem.Tag = 'loadFromWSPopup';

            popup.add(loadFromFilePopupItem);
            popup.add(loadFromWorkspacePopupItem);
            self.LoadImageButton.Popup = popup;
            c.add(self.LoadImageButton);
            
            addlistener(self.LoadImageButton,'ButtonPushed',@(hobj,evt) self.loadFromFile());
            addlistener(loadFromFilePopupItem,'ItemPushed',@(hobj,evt) self.loadFromFile());
            addlistener(loadFromWorkspacePopupItem,'ItemPushed',@(hobj,evt) self.loadFromWorkspace());
        end
        
        function hSection = layoutRegionFilteringSection(self, parentTab)
            
            import matlab.ui.internal.toolstrip.*
            
            hSection = parentTab.addSection(getString(message('images:regionAnalyzer:regionFilteringTitle')));
            hSection.Tag = 'RegionFiltering';
            
            c = hSection.addColumn();
            
            self.ExcludeBorderCheckbox = CheckBox(getString(message('images:regionAnalyzer:excludeBorderLabel')));
            self.ExcludeBorderCheckbox.Description = getString(message('images:regionAnalyzer:excludeBorderTooltip'));
            self.ExcludeBorderCheckbox.Tag = 'chkExcludeBorder';
            self.ExcludeBorderCheckbox.Enabled = false;
            addlistener(self.ExcludeBorderCheckbox,'ValueChanged',@(hobj,evt) notify(self,'ExcludeBorderCheckboxValueChanged',evt));
            
            self.FillHolesCheckbox = CheckBox(getString(message('images:regionAnalyzer:fillHolesLabel')));
            self.FillHolesCheckbox.Description = getString(message('images:regionAnalyzer:fillHolesTooltip'));
            self.FillHolesCheckbox.Tag = 'chkFillHoles';
            self.FillHolesCheckbox.Enabled = false;
            addlistener(self.FillHolesCheckbox,'ValueChanged',@(hobj,evt) notify(self,'FillHolesCheckboxValueChanged',evt));

            c.add(self.ExcludeBorderCheckbox);
            c.add(self.FillHolesCheckbox);
            
            c = hSection.addColumn();
                        
            self.FilterButton = Button(getString(message('images:regionAnalyzer:filterLabel')),...
                Icon('filterMask'));
            
            self.FilterButton.Enabled = false;
            self.FilterButton.Tag = 'filterBtn';
            self.FilterButton.Description = getString(message('images:regionAnalyzer:filterTooltip'));
            
            self.FilterButton.ButtonPushedFcn = @(~,~) notify(self,'FilterRegionDialogRequest');
            c.add(self.FilterButton);
            
        end
        
        function hSection = layoutTableViewSection(self, parentTab)
            
            import matlab.ui.internal.toolstrip.*
            
            hSection = parentTab.addSection(getString(message('images:regionAnalyzer:propertiesTitle')));
            hSection.Tag = 'TableView';
            c = hSection.addColumn();          
            
            self.SelectPropsButton = DropDownButton(...
                getString(message('images:regionAnalyzer:propertiesLabel')), ...
                Icon('properties'));
                        
            [propNames, numProps] = iGetPropNames();
            
            self.PropertyPickerPopup = matlab.ui.internal.toolstrip.PopupList();
            
            % Add the checkbox components.
            self.TableViewCheckboxes = matlab.ui.internal.toolstrip.ListItemWithCheckBox.empty(0,numProps);
            for idx = 1:numProps
                theProp = propNames{idx};
                hCheckbox = matlab.ui.internal.toolstrip.ListItemWithCheckBox(theProp);
                hCheckbox.Tag = ['chk' theProp];
                self.PropertyPickerPopup.add(hCheckbox);
                addlistener(hCheckbox,'ValueChanged',@(hobj,evt) managePropertyCheckboxValueChanged(self,hobj,evt));
                self.TableViewCheckboxes(idx) = hCheckbox;
            end
            
            self.SelectPropsButton.Popup = self.PropertyPickerPopup;
            self.SelectPropsButton.Description = getString(message('images:regionAnalyzer:propertiesTooltip'));
            self.SelectPropsButton.Tag = 'selectPropsButton';
            self.SelectPropsButton.Enabled = false;
            
            c.add(self.SelectPropsButton);
        end
        
        function hSection = layoutExportSection(self, parentTab)
            
            import matlab.ui.internal.toolstrip.*
            
            hSection = parentTab.addSection(getString(message('images:colorSegmentor:export')));
            hSection.Tag = 'Export';
            
            c = hSection.addColumn();
            c.Tag = 'columnExport';
            
            self.ExportButton = SplitButton(getString(message('images:regionAnalyzer:export')),Icon('export'));
            
            addlistener(self.ExportButton, 'ButtonPushed',@(hobj,evt) notify(self,'ExportImageToWorkspace'));
            self.ExportButton.Tag = 'btnExport';
            self.ExportButton.Description = getString(message('images:colorSegmentor:exportButtonTooltip'));
            
            % popup = matlab.ui.internal.toolstrip.PopupList('IconSize',16);
            popup = matlab.ui.internal.toolstrip.PopupList;
            
            createMaskPopupItem = ListItem(getString(message('images:regionAnalyzer:exportImage')),Icon('export_image'));
            createMaskPopupItem.Tag = 'exportImagePopupItem';
            createMaskPopupItem.ShowDescription = false;
            popup.add(createMaskPopupItem);
            
            createPropsPopupItem = ListItem(getString(message('images:regionAnalyzer:exportProps')),Icon('export_properties'));
            createPropsPopupItem.ShowDescription = false;
            createPropsPopupItem.Tag = 'exportPropsPopupItem';
            popup.add(createPropsPopupItem);
            
            createFunctionPopupItem = ListItem(getString(message('images:colorSegmentor:exportFunction')),Icon('export_function'));
            createFunctionPopupItem.ShowDescription = false;
            createFunctionPopupItem.Tag = 'exportFunctionPopupItem';
            popup.add(createFunctionPopupItem);
            
            self.ExportButton.Enabled = false;
            self.ExportButton.Popup = popup;
            
            addlistener(createMaskPopupItem,'ItemPushed',@(~,~) notify(self,'ExportImageToWorkspace'));
            addlistener(createPropsPopupItem,'ItemPushed',@(~,~) notify(self,'ExportPropertiesToWorkspace'));
            addlistener(createFunctionPopupItem,'ItemPushed',@(~,~) notify(self,'GenerateCode'));
            
            c.add(self.ExportButton);
            
        end
        
    end
    
    methods
        
        function updateSelectedRegions(self,I,BW)
            displayImageWithSelectionRegionMask(self,I,BW);
        end
        
        function displayFileLoadFailedDlg(self,messageStr)
            uialert(self.Container,...
                messageStr,...
                getString(message('images:volumeViewer:invalidFile')),...
                'Modal',false);
        end
                
        function displayExportImageDlg(self,BW)
            
            loc = imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.Container);
            
            self.ExportImageDlg = images.internal.app.utilities.ExportToWorkspaceDialog(loc,...
                string(getString(message("images:imExportToWorkspace:exportToWorkspace"))),...
                "BW", string(getString(message('images:colorSegmentor:binaryMask'))));
            
            self.ExportImageDlg.FigureHandle.Visible = true;
            
            wait(self.ExportImageDlg);
            
            if ~self.ExportImageDlg.Canceled
                if self.ExportImageDlg.VariableSelected(1)
                    assignin('base',self.ExportImageDlg.VariableName(1),BW);
                end
            end
            
        end
        
        function displayTooManyRegionsDlg(self)            
            uialert(self.Container,...
                getString(message('images:regionAnalyzer:tooManyObjects', 1000)),...
                getString(message('images:regionAnalyzer:tooManyObjectsTitle')),...
                'Modal',false);
        end
        
        function displayExportRegionDlg(self,tbl)
            
            loc = imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.Container);
            
            structStr = string(getString(message('images:regionAnalyzer:propsStruct')));
            tableStr = string(getString(message('images:regionAnalyzer:propsTable')));
            
            self.ExportPropsDlg = images.internal.app.utilities.ExportToWorkspaceDialog(loc,...
                string(getString(message("images:imExportToWorkspace:exportToWorkspace"))),...
                ["propsStruct","propsTable"], [structStr,tableStr]);
            
            self.ExportPropsDlg.FigureHandle.Visible = true;
            
            wait(self.ExportPropsDlg);
            
            if ~self.ExportPropsDlg.Canceled
                if self.ExportPropsDlg.VariableSelected(1)
                    assignin('base',self.ExportPropsDlg.VariableName(1),table2struct(tbl));
                end
                if self.ExportPropsDlg.VariableSelected(2)
                    assignin('base',self.ExportPropsDlg.VariableName(2),tbl);
                end
            end 
        end
        
            
        function displayFilterRegionDlg(self, filterData, regionMinData, regionMaxData, propIncrements)
            
            import images.internal.app.regionAnalyzer2.*
            
            dialogLoc = imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.Container);
            
            if ~isempty(self.FilterDlg) && ishandle(self.FilterDlg.FigureHandle)
                bringToForeground(self.FilterDlg);
            else
                % Create a new dialog
                titleStr = getString(message('images:regionAnalyzer:filterRegions'));
                self.FilterDlg = FilterDialog(dialogLoc,titleStr);
                addlistener(self.FilterDlg,'FilterUpdateEvent',@(hobj,evt) notify(self,'FilterUpdate',evt));
                addlistener(self.FilterDlg,'FilterPropertyUpdateEvent',@(hobj,evt) notify(self,'FilterPropertyUpdate',evt));
                addlistener(self.FilterDlg,'FilterTypeUpdateEvent',@(hobj,evt) notify(self,'FilterTypeUpdate',evt));
            end
            
            updateWithNewData(self.FilterDlg,filterData, regionMinData, regionMaxData, propIncrements);
                        
        end
              
        function initializeView(self,newImageEventData)
            self.ImageDisplay.Visible = true;
            self.ImageDisplay.Enabled = true;
            enableControls(self);
            
            self.ExcludeBorderCheckbox.Value = newImageEventData.ExcludeBorders;
            self.FillHolesCheckbox.Value = newImageEventData.FillHoles;
            updateSelectedRegions(self,newImageEventData.ModifiedBW,false(size(newImageEventData.ModifiedBW)));
            displayImage(self,newImageEventData.ModifiedBW);
            displayTable(self,newImageEventData.RegionData);
            setTableViewCheckboxState(self,newImageEventData.SelectedPropertyState);
            closeFilterDlg(self);
            updateFilterRanges(self,newImageEventData.FilterData);
        end
        
        function updateView(self,newImageEventData)
            %Lighter weight update. Should only be called after initializeView
            % has been called.
            displayImage(self,newImageEventData.ModifiedBW);
            self.Table.Data = newImageEventData.RegionData;
            updateFilterRanges(self,newImageEventData.FilterData);
        end
        
        function displayGeneratedCode(~,codestr)
            editorDoc = matlab.desktop.editor.newDocument(codestr);
            editorDoc.smartIndentContents;
        end
        
    end
    
    methods (Access = private)
        
        function updateFilterRanges(self,filterData)
            if ~isempty(self.FilterDlg) && ishandle(self.FilterDlg)
                filterData = arrayfun(@(x) x.Range,filterData,'UniformOutput',false);
                filterData = cell2mat(filterData);
                updateFilterLimits(self.FilterDlg,filterData);
            end
        end
        
        function managePropertyCheckboxValueChanged(self,~,~)
            import images.internal.app.regionAnalyzer2.*
            
            names = {self.TableViewCheckboxes(:).Text};
            values = {self.TableViewCheckboxes.Value};
            
            notify(self,'PropertyViewChange',PropertyViewChangeEventData(cell2struct(values,names,2)));
        end
        
        function tableSelectionCallback(self, ~, evt)
            import images.internal.app.regionAnalyzer2.*
            
            rowsSelected = evt.Indices(:,1);
            notify(self,'TableRegionSelected',TableRegionSelectedEventData(rowsSelected));
        end
        
        function setTableViewCheckboxState(self,stateStruct)
            for idx = 1:length(self.TableViewCheckboxes)
                self.TableViewCheckboxes(idx).Value = stateStruct.(self.TableViewCheckboxes(idx).Text);
            end
        end
        
        function displayImage(self,I)
            draw(self.ImageDisplay,I,[],[],[]);
        end
        
        function displayImageWithSelectionRegionMask(self,I,BW)
             draw(self.ImageDisplay,I,BW,self.SelectedRegionColormap,[]);
        end
        
        function displayTable(self,tableData)
            self.Table = uitable(...
                'Data', tableData, ...
                'Parent', self.TableViewPanel.Figure, ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1],...
                'Tag','PropertiesTable',...
                'ColumnSortable',true,...
                'CellSelectionCallback', @(obj,evt) tableSelectionCallback(self, obj, evt));
        end
        
        function enableControls(self)
            self.LoadImageButton.Enabled = true;
            self.ExcludeBorderCheckbox.Enabled = true;
            self.FillHolesCheckbox.Enabled = true;
            self.SelectPropsButton.Enabled = true;
            self.ExportButton.Enabled = true;
            self.FilterButton.Enabled = true;
        end
        
        function loadFromWorkspace(self)
            dialogLoc = imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(self.Container);
            dialogTitle = getString(message('images:privateUIString:importFromWorkspace'));
            self.LoadFromWorkspaceDlg = images.internal.app.utilities.VariableDialog(dialogLoc,dialogTitle,'','logicalImage');
            
            self.LoadFromWorkspaceDlg.FigureHandle.Tag = 'loadFromWSDialog';
            
            wait(self.LoadFromWorkspaceDlg);
            
            if ~self.LoadFromWorkspaceDlg.Canceled
                %imgData = evalin('base',self.LoadFromWorkspaceDlg.SelectedVariable);
                notify(self,'ImportFromWorkspace',...
                    images.internal.app.regionAnalyzer2.ImportFromWorkspaceEventData(self.LoadFromWorkspaceDlg.SelectedVariable));
            end  
        end
        
        function loadFromFile(self)
            [filename,userCanceled] = imgetfile();
            if ~userCanceled
                self.notify('ImportFromFile',images.internal.app.regionAnalyzer2.ImportFromFileEventData(filename));
            end
        end
        
        function TF = manageClose(self,~)  
            TF = true;
            imageslib.internal.apputil.manageToolInstances('remove', 'imageRegionAnalyzer', self);
        end
    end
    
    methods (Static)
        function deleteAllTools
            imageslib.internal.apputil.manageToolInstances('deleteAll', 'imageRegionAnalyzer');
        end
    end
    
end

function [props, numForDisplay] = iGetPropNames

props = {'Area'      'Circularity'     'ConvexArea'        'Eccentricity', ...
    'EquivDiameter'  'EulerNumber'       'Extent', ...
    'FilledArea'     'MajorAxisLength'   'MinorAxisLength', ...
    'Orientation'    'Perimeter'         'Solidity', ...
    'PixelIdxList'};
numForDisplay = 13;

end


function iAdjustPanelPosition(hpanel,imageDisplay,evt)
hpanel.Position = [1 1 evt.Source.Position(3:4)];
resize(imageDisplay);
end
