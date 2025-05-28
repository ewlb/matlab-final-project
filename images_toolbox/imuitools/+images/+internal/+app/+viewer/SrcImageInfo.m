classdef SrcImageInfo
% Helper class that stores information about the source image

% Copyright 2023 The MathWorks, Inc.

    properties
        % SourceType strings are for internal use and so do not require
        % translation
        SourceType (1, 1) string {mustBeMember(SourceType, ["File", "Workspace"])} = "File"
        Name (1, 1) string = ""
        Info (1, 1) struct = struct()
        CurrIdx (1, 1) double = 1
        MaxNumImages (1, 1) double = 1
        ModificationMethod string = string.empty();
    end

    methods
        function obj = SrcImageInfo( srcType, srcName, srcInfo, ...
                                currIdx, maxNumImages, modMethod )
            arguments
                srcType (1, 1) string = "Workspace"
                srcName (1, 1) string = ""
                srcInfo (1, 1) struct = struct()
                currIdx (1, 1) double = 1
                maxNumImages (1, 1) double = 1
                modMethod (:, :) string = ""
            end

            obj.SourceType = srcType;
            obj.Name = srcName;
            obj.Info = srcInfo;
            obj.CurrIdx = currIdx;
            obj.MaxNumImages = maxNumImages;
            obj.ModificationMethod = modMethod;
        end
    end
end