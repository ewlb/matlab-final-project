classdef H5Blocks < images.blocked.internal.DirOfBlockFiles           
    properties
        GZIPLevel (1,1) {mustBeInteger, mustBeInRange(GZIPLevel, 0,9)} = 1
    end
    
    methods
        
        function obj = H5Blocks()
            obj.BlockFileExtension = ".h5";
        end
        
        function data = getIOBlock(obj, ioBlockSub, level)
            blockFileName = images.blocked.internal.baseBlockFileName(obj.Location, level, ioBlockSub) + obj.BlockFileExtension;
            if isfile(blockFileName)
                data = h5read(blockFileName, '/block');
            else
                % Data missing, blockedImage will return 0ed blocks.
                data = [];
            end
        end
        
        function openToWrite(obj, dstFolder, info, level)
            if ~any(strcmp(class(info.InitialValue), images.internal.iptlogicalnumerictypes))
                error(message('images:blockedImage:unsupportedByAdapter', class(obj), class(info.InitialValue)))
            end
            openToWrite@images.blocked.internal.DirOfBlockFiles(obj, dstFolder, info, level);
        end
        
        function setIOBlock(obj, ioBlockSub, level, data)
            fileName = images.blocked.internal.baseBlockFileName(obj.Location, level, ioBlockSub) + obj.BlockFileExtension;
            if islogical(data)
                % HDF5 does not support logical.
                dataType = 'uint8';
                data = uint8(data);
            else
                dataType = class(data);
            end
            if ~isfile(fileName)
                h5create(fileName, '/block', size(data),...
                    'Datatype', dataType,...
                    'Chunksize', size(data),...
                    'Deflate', obj.GZIPLevel);
            end
            h5write(fileName, '/block', data);
        end
    end
end

%   Copyright 2020-2022 The MathWorks, Inc.