classdef MATBlocks < images.blocked.internal.DirOfBlockFiles
    methods

        function obj = MATBlocks()
            obj.BlockFileExtension = ".mat";
        end

        function data = getIOBlock(obj, ioBlockSub, level)
            blockFileName = images.blocked.internal.baseBlockFileName(obj.Location, level, ioBlockSub) + obj.BlockFileExtension;
            if isfile(blockFileName)
                data = load(blockFileName);
                data = data.data;
            else
                % Data missing, blockedImage will return initial value filled blocks.
                data = [];
            end
        end

        function setIOBlock(obj, ioBlockSub, level, data)
            fileName = images.blocked.internal.baseBlockFileName(obj.Location, level, ioBlockSub) + obj.BlockFileExtension;
            save(fileName, 'data');
        end

    end
end
%   Copyright 2020-2022 The MathWorks, Inc.
