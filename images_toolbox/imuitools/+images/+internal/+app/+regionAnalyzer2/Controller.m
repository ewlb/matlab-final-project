classdef Controller < handle
    %

    % Copyright 2020 The MathWorks, Inc.

    properties
        Model
        View
    end
    
    methods
        
        function self = Controller(model,view)
            self.Model = model;
            self.View = view;
            
            listenToView(self);
            listenToModel(self);
        end
                
        function listenToView(self)
            addlistener(self.View,'ImportFromWorkspace',@(~,ed) loadFromWorkspace(self.Model,ed.VarName));
            addlistener(self.View,'ImportFromFile',@(~,ed) loadFromFile(self.Model,ed.Filename));
            addlistener(self.View,'TableRegionSelected',@(~,ed) set(self.Model,'TableRowsSelected',ed.TableRowIndices));
            addlistener(self.View,'ExcludeBorderCheckboxValueChanged',@(~,ed) set(self.Model,'ExcludeBordersEnabled',ed.EventData.NewValue));
            addlistener(self.View,'FillHolesCheckboxValueChanged',@(~,ed) set(self.Model,'FillHolesEnabled',ed.EventData.NewValue));
            addlistener(self.View,'PropertyViewChange',@(~,ed) set(self.Model,'SelectedPropertyState',ed.EnabledPropertyState));
            addlistener(self.View,'ExportImageToWorkspace',@(~,~) broadcastCurrentImageDataForExport(self.Model));
            addlistener(self.View,'ExportPropertiesToWorkspace',@(~,~) broadcastCurrentRegionDataForExport(self.Model));
            addlistener(self.View,'GenerateCode',@(~,~) generateCode(self.Model));
            addlistener(self.View,'FilterRegionDialogRequest',@(~,~) broadcastFilterData(self.Model));
            addlistener(self.View,'FilterUpdate',@(~,ed) modifyFilterData(self.Model,ed));
            addlistener(self.View,'FilterPropertyUpdate',@(~,ed) modifyFilterProperty(self.Model,ed));
            addlistener(self.View,'FilterTypeUpdate',@(~,ed) modifyFilterType(self.Model,ed));
        end
        
        function listenToModel(self)
            addlistener(self.Model,'NewImageDataEvent',@(~,ed) initializeView(self.View,ed));
            addlistener(self.Model,'SelectedRegionUpdateEvent',@(~,ed) updateSelectedRegions(self.View,ed.BW,ed.SelectionMask));
            addlistener(self.Model,'ImageDataModifiedEvent',@(~,ed) updateView(self.View,ed));
            addlistener(self.Model,'UnableToLoadFileEvent',@(~,ed) displayFileLoadFailedDlg(self.View,ed.ErrorMessage));
            addlistener(self.Model,'ExportImageDataEvent',@(~,ed) displayExportImageDlg(self.View,ed.BW));
            addlistener(self.Model,'ExportRegionDataEvent',@(~,ed) displayExportRegionDlg(self.View,ed.RegionData));
            addlistener(self.Model,'CodeGeneratedEvent',@(~,ed) displayGeneratedCode(self.View,ed.CodeString));
            addlistener(self.Model,'FilteredMaxRegionsEvent',@(~,~) displayTooManyRegionsDlg(self.View));
            addlistener(self.Model,'FilterDataUpdate',@(~,ed) displayFilterRegionDlg(self.View,ed.FilterData,ed.RegionDataMin,ed.RegionDataMax,ed.PropIncrements));
        end
    end
    
end