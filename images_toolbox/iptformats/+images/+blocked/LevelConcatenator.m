classdef LevelConcatenator < images.blocked.Adapter

    properties (Access = private)
        Images (1,:) blockedImage
        Info (1,1) struct
        ImageIndex (1,:) double
        IOLevels (1,:) double
    end

    methods

        function obj = LevelConcatenator(bimArray)            

            % All levels should have the same number of dimensions
            allDims = vertcat(bimArray.NumDimensions);
            if ~all(allDims(1)==allDims)
                error(message('images:blockedImage:NotSameDims'))
            end

            obj.Images = bimArray;
            
            % Initialize with info from the first
            obj.Info = bimArray(1).Adapter.getInfo();

            % Keep track of images and corresponding levels
            obj.ImageIndex = ones(1,numel(obj.Info.Datatype));
            obj.IOLevels = 1:numel(obj.Info.Datatype);

            % Merge info from the rest
            for ind = 2:numel(bimArray)
                info = bimArray(ind).Adapter.getInfo();
                obj.Info.Size = [obj.Info.Size; info.Size];
                obj.Info.IOBlockSize = [obj.Info.IOBlockSize; info.IOBlockSize];
                obj.Info.Datatype = [obj.Info.Datatype(:); info.Datatype(:)];
                obj.ImageIndex = [obj.ImageIndex ind*ones(1,numel(info.Datatype))];
                obj.IOLevels = [obj.IOLevels 1:numel(info.Datatype)];
            end
        end

        function openToRead(~, ~)
            % Nothing to do
        end

        function info = getInfo(obj)
            info = obj.Info;
        end

        function data = getIOBlock(obj, ioBlockSub, level)
            % Delegate to the appropriate image
            bim = obj.Images(obj.ImageIndex(level));
            % And appropriate level of that image
            imageLevel = obj.IOLevels(level);
            data = bim.Adapter.getIOBlock(ioBlockSub,imageLevel);
        end
    end
end

%   Copyright 2022 The MathWorks, Inc.