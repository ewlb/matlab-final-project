classdef DICOMBrowser < handle
    %

    % Copyright 2021-2023 The MathWorks, Inc.
    
    properties (Access = private, Hidden, Transient)
        browserModel images.internal.app.dicom.BrowserModel
        browserController images.internal.app.dicomJT.BrowserController
    end
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private, Transient)
        browserView images.internal.app.dicomJT.BrowserView
    end
    
    methods
        function obj = DICOMBrowser(location)
            
            obj.browserView = images.internal.app.dicomJT.BrowserView;
            obj.browserModel = images.internal.app.dicom.BrowserModel;
            obj.browserController = images.internal.app.dicomJT.BrowserController(obj.browserModel, obj.browserView);
            
            if nargin > 0
                try
                    obj.browserView.App.Busy = true;
                    obj.browserModel.loadNewCollection(location)
                    obj.browserView.App.Busy = false;
                catch ME
                    obj.browserView.App.Busy = false;
                        dialogTitle = getString(message('images:DICOMBrowser:errorDialogTitle'));
                        uialert(obj.browserView.App, ME.message, dialogTitle)
                end
            end   
            imageslib.internal.apputil.manageToolInstances('add', 'DICOMBrowser', obj.browserView.App)
            % Tie lifecycle of DICOMBrowser class to destruction of the
            % app in the View.
            addlistener(obj.browserView.App, 'StateChanged', @(~,~) obj.closeCallback());
        end
        
        function closeCallback(obj)
            % Clears instance when App terminated
            import matlab.ui.container.internal.appcontainer.*;
            if obj.browserView.App.State == AppState.TERMINATED
                imageslib.internal.apputil.manageToolInstances('remove', 'DICOMBrowser', obj.browserView.App)
                delete(obj.browserView)
                delete(obj.browserModel)
                delete(obj.browserController)
                delete(obj)
            end
        end
    end
end

            
