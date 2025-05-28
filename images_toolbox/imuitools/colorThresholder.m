function colorThresholder(RGB)
%colorThresholder Threshold color image.
%   colorThresholder opens a color image thresholding app. The app can be
%   used to create a segmentation mask to a color image based on the
%   exploration of different color spaces.
%
%   colorThresholder(RGB) loads the truecolor image RGB into a color
%   thresholding app.
%
%   colorThresholder CLOSE closes all open color thresholder apps.
%
%   Class Support
%   -------------
%   RGB is a truecolor image of class uint8, uint16, single, or double.
%
%   See also imcontrast

%   Copyright 2013-2024 The MathWorks, Inc.


import matlab.internal.capability.Capability;
isRunningOnMLOnline = ~Capability.isSupported(Capability.LocalClient);
if isRunningOnMLOnline
    error(message('images:colorSegmentor:matlabOnlineNotSupported'));
end

if nargin > 0
    RGB = convertStringsToChars(RGB);
end

s = settings;

if(s.images.ColorThresholderUseAppContainer.ActiveValue)
    colorThreshFcn = @images.internal.app.colorThresholderWeb.ColorSegmentationTool;
    deleteTools = @images.internal.app.colorThresholderWeb.ColorSegmentationTool.deleteAllTools;
else
    colorThreshFcn = @images.internal.app.colorThresholder.ColorSegmentationTool;
    deleteTools = @images.internal.app.colorThresholder.ColorSegmentationTool.deleteAllTools;
end

if nargin == 0
    % Create a new Color Segmentation app.
    colorThreshFcn();
else
    if ischar(RGB)
        % Handle the 'close' request
        validatestring(RGB, {'close'}, mfilename);
        deleteTools(); 
    else
        supportedImageClasses = {'uint8','uint16','single','double'};
        supportedImageAttributes = {'real','nonsparse','nonempty','ndims',3};
        validateattributes(RGB,supportedImageClasses,supportedImageAttributes,'colorSegmentor','RGB');
        
        if size(RGB,3) ~= 3
            error(message('images:colorSegmentor:requireRGBInput'));
        end
        
        % Launch the app in lightweight mode for software rendering
        data = rendererinfo;
        
        isLightWeight = false;

        if(strcmp(data.Details.HardwareSupportLevel,'None'))
            isLightWeight = true;
        end

        if(s.images.ColorThresholderUseLightWeight.ActiveValue)
            isLightWeight = true;
        end
        
        colorThreshFcn(RGB, isLightWeight);
    end
        
end
