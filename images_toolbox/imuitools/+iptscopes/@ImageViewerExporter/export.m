function export(this)
%EXPORT Export to Image Viewer (imageViewer)

%   Copyright 2007-2023 The MathWorks, Inc.

hScope = this.Application;
hSrc   = hScope.DataSource;
hVideo = getExtension(this, 'Visuals', 'Video');

cMap = hVideo.ColorMap.Map;
dRange = get(hVideo.Axes,'CLim');

% Invoke ImageViewer such that the title bar of the app indicates the frame
% number being exported.  To do this, we first create a variable with the
% desired name, then launch the app on that variable.  Hence, the title
% must conform to a legal MATLAB variable name and it must not conflict
% with any other local variables in this context
if isa(hSrc,'Simulink.scopes.source.WiredSource')
    % For wired source, we need to get info from the source itself instead
    % of data handler
    varName = sprintf('%s_%.3f', hSrc.NameShort, getTimeOfDisplayData(hSrc));
    varName = uiservices.generateVariableName(varName);
else
    varName = getExportFrameName(hSrc.DataHandler);
end

% Create variable with this name:
imageData = get(hVideo.Image, "CData");

% If the app is already open, close it
% What we really want is to "reload" the copy of the app with new data, if
% we launched previously launched it ourselves.

% Check whether the image is to be exported into a new Image Viewer
% instance OR an existing instance needs to be re-used
isReuseApp = false;
if ~getValue(this.Config.PropertyDb, 'NewImageViewer') && ...
                                                ~isempty(this.IVAppList)

    % Remove any deleted app instances
    this.IVAppList(~isvalid(this.IVAppList)) = [];

    appDoneStatus = [this.IVAppList.IsAppUsageDone];

    % Perform some cleanup. Remove all closed apps from this list
    delete(this.IVAppList(appDoneStatus));
    this.IVAppList(appDoneStatus) = [];

    isReuseApp = ~isempty(this.IVAppList);
end

% Launch the app using the underlying implementation class. This is done to
% obtain a handle to the class to manage its lifetime appropriately
try
    doesCLimMatchDtypeRange = isequal(dRange, getrangefromclass(imageData));

    if ~isReuseApp
        if doesCLimMatchDtypeRange
            % The app uses the datatype range as the default display range.
            % Any  non-empty display range value provided will
            % automatically be treated as a custom range. Hence, passing
            % default value is avoided.
            ivApp = images.internal.app.viewer.ImageViewer( imageData, ...
                                UserColormap=cMap, ...
                                WkspaceSrcVarName=varName );
        else
            ivApp = images.internal.app.viewer.ImageViewer( imageData, ...
                                UserColormap=cMap, ...
                                DisplayRange=dRange, ...
                                WkspaceSrcVarName=varName );
        end

        if isempty(this.IVAppList)
            this.IVAppList = ivApp;
        else
            this.IVAppList(end+1) = ivApp;
        end
    else
        ivApp = this.IVAppList(end);
        if doesCLimMatchDtypeRange
            % The app uses the datatype range as the default display range.
            % Any  non-empty display range value provided will
            % automatically be treated as a custom range. Hence, passing
            % default value is avoided.
            updateSourceImage( ivApp, imageData, UserColormap=cMap, ...
                               WkspaceSrcVarName=varName );
        else
            updateSourceImage( ivApp, imageData, UserColormap=cMap, ...
                               DisplayRange=dRange, ...
                               WkspaceSrcVarName=varName );
        end
    end
catch ME
    error(message("images:imageViewer:imageViewerFailed", ME.message));
end

% [EOF]
