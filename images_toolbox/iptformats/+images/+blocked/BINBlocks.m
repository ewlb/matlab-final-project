classdef BINBlocks < images.blocked.internal.DirOfBlockFiles          
    methods
        
        function obj = BINBlocks()
            obj.BlockFileExtension = ".bin";
        end
        
        function data = getIOBlock(obj, ioBlockSub, level)
            
            %
            
            % This will get called frequently - code is tilted toward
            % performance without extensive error checks. The folder is
            % already checked for read permissions prior, so its unlikely
            % that the fopen command will fail. Similarly, the folder is
            % already validated to be a 'binblock' folder, so its unlikely
            % that the fread commands will fail (unless the contents have
            % been tampered (very unlikely)).
            
            blockFileName = images.blocked.internal.baseBlockFileName(obj.Location, level, ioBlockSub) + obj.BlockFileExtension;
            fid = fopen(blockFileName);
            if fid~=-1
                readType = char(obj.Info.Datatype(level));                
                numDims = fread(fid, 1, 'double');
                blockSize = fread(fid, numDims, 'double');
                blockSize = blockSize';
                % Data
                data = fread(fid,inf, [readType, '=>', readType]);                
                fclose(fid);
                data = reshape(data, blockSize);
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
            fid = fopen(fileName,'w');
            if (fid==-1)
                % Either no write permissions, or disk space is full
                error(message('images:blockedImage:unableToWriteBlock', fileName));
            end
            % Store block size (which could be partial)
            fwrite(fid, numel(size(data)), 'double');
            fwrite(fid, size(data), 'double');
            % Store data
            fwrite(fid, data, class(data));            
            fclose(fid);
        end
    end
    
end


%   Copyright 2020-2022 The MathWorks, Inc.