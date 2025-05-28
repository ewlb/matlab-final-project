classdef FileImageLoader < images.internal.app.viewer.ImageLoader
% Helper class that loads an image from a supported image file.

%   Copyright 2023 The MathWorks, Inc.

    % Constructor
    methods
        function obj = FileImageLoader(fileName)
            obj@images.internal.app.viewer.ImageLoader(fileName);

            try
                obj.ImageInfo = images.internal.app.utilities.readAllIPTFormatsInfo(fileName);
                obj.MaxNumFrames = computeMaxNumFrames(obj.ImageInfo);
                createLoadedImageInfo(obj);
            catch ME
                throwAsCaller(ME);
            end
        end
    end

    % Implementation of Abstract Methods
    methods(Access=public)
        function isHDR = isHDRImagery(obj)
            isHDR = images.internal.hdr.ishdr(obj.ImageSrcName) || ...
                                                isexr(obj.ImageSrcName);
        end
    end

    % Implementation of internal abstract methods
    methods(Access=protected)
        function [im, cmap] = readImageImpl(obj)
            try
                [im, cmap] = ...
                    images.internal.app.utilities.readAllIPTFormats( obj.ImageSrcName, ...
                                ImageIndex=obj.CurrImageIndex );
            catch ME
                throwAsCaller(ME);
            end
        end

        function [type, name, info] = getInfoImpl(obj)

            % Internally used string. No need for translation.
            type = "File";

            [~, fname, fext] = fileparts(obj.ImageSrcName);
            name = fname + fext;

            info = getCurrentInfo(obj);
        end
    end

    methods(Access=private)
        function outinfo = getCurrentInfo(obj)
        % Helper function to extract the appropriate info struct

            if isscalar(obj.ImageInfo)
                % DICOM files can have multiple frames but return a scalar
                % INFO struct.
                outinfo = obj.ImageInfo;
            else
                outinfo = obj.ImageInfo(obj.CurrImageIndex);
            end
        end
    end
end

function maxNumFrames = computeMaxNumFrames(fileInfo)
% Helper that computes the maximum number of frames in a file

    assert( ~isempty(fileInfo), "INFO struct cannot be empty" );

    % DICOM files can have multiple frames but the INFO struct is scalar.
    % Hence, the NumberOfFrams field must be queried.
    maxNumFrames = numel(fileInfo);
    if isfield(fileInfo, "NumberOfFrames")
        maxNumFrames = fileInfo.NumberOfFrames;
    end
end 
