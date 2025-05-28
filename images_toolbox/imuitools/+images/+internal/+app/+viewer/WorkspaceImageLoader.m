classdef WorkspaceImageLoader < images.internal.app.viewer.ImageLoader
% Helper class that loads an image from the workspace. This helper supports
% loading a stack of images from the workspace.

%   Copyright 2023 The MathWorks, Inc.

    properties(Access=private)
        LoadedImage (:, :, :, :) {mustBeNumericOrLogical} = zeros(0, 0, 0, 0)
        Colormap (:, 3) double = zeros(0, 3)
    end

    % Constructor
    methods
        function obj = WorkspaceImageLoader(im, options)
            arguments
                im
                options.Colormap (:, 3) = zeros(0, 3)
                options.SrcVarName (1, 1) string = ""
            end

            obj@images.internal.app.viewer.ImageLoader(options.SrcVarName);


            validateattributes( im, ["numeric", "logical"], ...
                                { 'nonempty', 'nonsparse', 'real', ...
                                  'size', [NaN NaN NaN NaN] }, ...
                                "imageViewer", "im" );
            if islogical(im)
                if size(im, 3) ~= 1
                    error(getString(message("images:imageViewer:logicalOneChannel")));
                end
            else
                if ~ismember(size(im, 3) , [1 3])
                    error(getString(message("images:imageViewer:input1or3Channels")));
                end
            end

            if size(im, 3) == 3 && ~isempty(options.Colormap)
                error(getString(message("images:imageViewer:colormap1channel")));
            end

            obj.LoadedImage = im;
            obj.MaxNumFrames = size(im, 4);
            obj.Colormap = options.Colormap;

            obj.ImageInfo = images.internal.app.viewer.createInfoForNumericArray(im);

            createLoadedImageInfo(obj);
        end
    end

    % Implementation of Abstract Methods
    methods(Access=public)
        function isHDR = isHDRImagery(~)
            isHDR = false;
        end
    end

    % Implementation of internal Abstract Methods
    methods(Access=protected)
        function [im, cmap] = readImageImpl(obj)
            im = obj.LoadedImage(:, :, :, obj.CurrImageIndex);
            cmap = obj.Colormap;
        end

        function [type, name, info] = getInfoImpl(obj)

            % Internally used string. No need for translation.
            type = "Workspace";
            name = obj.ImageSrcName;
            info = obj.ImageInfo;
        end
    end
end

