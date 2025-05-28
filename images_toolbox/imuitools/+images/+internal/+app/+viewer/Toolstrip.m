classdef (Sealed) Toolstrip < handle
% Helper class that creates and manages the Toolstrip of the ImageViewer
% app.

%   Copyright 2023 The MathWorks, Inc.

    events
        SelectedTabChanged

        CropRequested
        CropApplied
        CropCancelled
    end

    properties ( SetAccess = ?images.internal.app.viewer.ImageViewer, ...
                 GetAccess = { ?uitest.factory.Tester, ...
                               ?images.internal.app.viewer.ImageViewer, ...
                               ?imtest.apptest.imageViewerTest.PropertyAccessProvider} )
        % TabGroup
        AppTabGroup             matlab.ui.internal.toolstrip.TabGroup
        
        % Tabs in the app
        ViewerTab               images.internal.app.viewer.ViewerTab
        ContrastTab             images.internal.app.viewer.ContrastTab
        ColormapTab             images.internal.app.viewer.ColormapTab
    end

    properties(GetAccess=public, SetAccess=private)
        % Stores the current state of the toolstrip controls of the entire
        % app
        CurrentState = struct.empty();
    end

    properties(Access=private)
        % Cache the toolstrip state of the app before the latest change was
        % made to it.
        CachedState = struct.empty();
    end

    methods
        function obj = Toolstrip(app)
            obj.AppTabGroup = matlab.ui.internal.toolstrip.TabGroup();
            obj.AppTabGroup.Tag = "ImageViewerTabGroup";

            addTabGroup(app, obj.AppTabGroup);
            addlistener( obj.AppTabGroup, "SelectedTabChanged", ...
                         @(~, evt) reactToTabChanged(obj, evt) );

            obj.ViewerTab = images.internal.app.viewer.ViewerTab(obj.AppTabGroup);
            obj.ContrastTab = images.internal.app.viewer.ContrastTab();
            obj.ColormapTab = images.internal.app.viewer.ColormapTab();

            wireUpListeners(obj);
        end

        function delete(obj)
            delete(obj.ViewerTab);
            delete(obj.ContrastTab);
            delete(obj.ColormapTab);
        end
    end

    % Getters/SettersfS
    methods
        function val = get.CurrentState(obj)
            % Determine the state of all the toolstrip tabs
            val.ViewerTabState = obj.ViewerTab.CurrentState;
            val.ContrastTabState = obj.ContrastTab.CurrentState;
            val.ColormapTabState = obj.ColormapTab.CurrentState;
        end
    end

    % Interface methods
    methods(Access=public)
        function updateOnSrcChange(obj, im, cmap, interp, isNewImage)
            arguments
                obj (1, 1) images.internal.app.viewer.Toolstrip
                im = []
                cmap = []
                interp (1, 1) string = "nearest"
                isNewImage (1, 1) logical = true
            end

            updateOnSrcChange(obj.ViewerTab, im, interp);
            updateOnSrcChange(obj.ContrastTab, im, obj.AppTabGroup, 2);

            if isNewImage
                updateOnSrcChange(obj.ColormapTab, im, cmap, obj.AppTabGroup, 3);
            else
                isEnabled = ~( isempty(im) || (size(im, 3) ~= 1) );
                if isEnabled
                    enableAll(obj.ColormapTab);
                end
            end
        end

        function enableAll(obj)
            enableAll(obj.ViewerTab);
            enableAll(obj.ContrastTab);
            enableAll(obj.ColormapTab);
        end

        function disableAll(obj)
            disableAll(obj.ViewerTab);
            disableAll(obj.ContrastTab);
            disableAll(obj.ColormapTab);
        end

        function restoreState(obj, state)
            restoreState(obj.ViewerTab, state.ViewerTabState);
            restoreState(obj.ContrastTab, state.ContrastTabState);
            restoreState(obj.ColormapTab, state.ColormapTabState);
        end
    end

    % Callback methods for all controls present in the Main Tab
    methods (Access = private)
        function reactToTabChanged(obj, evt)
            evtData = images.internal.app.viewer.ViewerEventData(evt.EventData.NewValue.Tag);
            notify(obj, "SelectedTabChanged", evtData);
        end

        function reactToCropRequested(obj, evt)
            % Disable all App Controls except Crop Apply/Cancel when Crop
            % is requested. Hence, cache the existing app state to allow
            % restoring to this once crop is completed
            obj.CachedState = obj.CurrentState;
            obj.CachedState.ViewerTabState = evt.Data;

            disableAll(obj.ContrastTab);
            disableAll(obj.ColormapTab);

            notify( obj, "CropRequested", ...
                images.internal.app.viewer.ViewerEventData(obj.CachedState) );
        end

        function reactToCropApplied(obj)
            % Restore the app to its existing state when a crop operation
            % is applied. The main app will further update the toolstrip
            % state based on the new image that is loaded

            notify(obj, "CropApplied");
        end

        function reactToCropCancelled(obj)
            % Restore the app to its existing state when a crop operation
            % is cancelled.
            
            restoreState(obj, obj.CachedState);
            obj.CachedState = struct.empty();

            notify(obj, "CropCancelled");
        end
    end

    % Helpers
    methods(Access=private)
        function wireUpListeners(obj)
            addlistener( obj.ViewerTab, "CropRequested", ...
                            @(~, evt) reactToCropRequested(obj, evt) );
            addlistener( obj.ViewerTab, "CropApplied", ...
                            @(~, ~) reactToCropApplied(obj) );
            addlistener( obj.ViewerTab, "CropCancelled", ...
                            @(~, ~) reactToCropCancelled(obj) );
        end
    end
end