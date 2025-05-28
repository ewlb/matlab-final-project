classdef H5 < images.blocked.Adapter          
    properties
        Extension (1,1) string = "h5"
        
        GZIPLevel (1,1) {mustBeInteger, mustBeInRange(GZIPLevel, 0,9)} = 1        
    end
    
    properties (Access = private)
        Location(1,1) string
        Info(1,1) struct
    end    
    
    % Read methods
    methods
        function openToRead(obj, source)
            obj.Location = string(source);
        end
        
        function info = getInfo(obj)
            desc = images.blocked.internal.loadDescription(obj.Location);
            
            if isfield(desc, 'Info')
                info = desc.Info;
            else                
                try
                    info.Size = h5readatt(char(obj.Location), '/blockedImage','Size');
                    info.IOBlockSize = h5readatt(char(obj.Location), '/blockedImage','IOBlockSize');
                    
                    if iscolumn(info.Size)
                        % HDF5 quirk.
                        info.Size = info.Size';
                    end
                    if iscolumn(info.IOBlockSize)
                        info.IOBlockSize = info.IOBlockSize';
                    end
                    
                    info.Datatype = h5readatt(char(obj.Location), '/blockedImage','Datatype');
                catch
                    error(message('images:blockedImage:invalidH5', obj.Location))
                end
                info.InitialValue = cast(0, info.Datatype(1));                
            end
            
            obj.Info = info;
        end
        
        function data = getIOBlock(obj, ioBlockSub, level)
            start = (ioBlockSub-1).*obj.Info.IOBlockSize(level,:) + 1;
            blockSize = obj.Info.IOBlockSize(level,:);
            edge = start + blockSize - 1;
            edge = min(obj.Info.Size(level,:), edge);
            blockSize = edge - start + 1;
            data = h5read(obj.Location, ['/blockedImage/L',num2str(level)],...
                start, blockSize);
        end
    end
    
    % Write methods
    methods
        function openToWrite(obj, dstFileName, info, ~)
            if ~any(strcmp(class(info.InitialValue), images.internal.iptlogicalnumerictypes))
                error(message('images:blockedImage:unsupportedByAdapter', class(obj), class(info.InitialValue)))
            end
            
            obj.Location = string(dstFileName);
            obj.Info = info;
            
            locFolder = fileparts(dstFileName);
            images.blocked.internal.createFolder(locFolder);                        
            
            if any(info.IOBlockSize>info.Size,'all')
                error(message('images:blockedImage:h5BlockSizeLargerThanImageSize'));
            end
            
            if ~isfile(obj.Location)
                % Create all the levels upfront
                for level = 1:size(info.Size,1)
                    dataType = info.Datatype(level);
                    if dataType=="logical"
                        dataType = 'uint8';
                    end
                    
                    h5create(obj.Location, ['/blockedImage/L',num2str(level)],...
                        info.Size(level,:), ...
                        'Datatype', dataType,...
                        'ChunkSize', info.IOBlockSize(level,:),...
                        'Deflate', obj.GZIPLevel);
                end
                % Update info
                h5writeatt(obj.Location, '/blockedImage', 'Size', info.Size);
                h5writeatt(obj.Location, '/blockedImage', 'IOBlockSize', info.IOBlockSize);
                h5writeatt(obj.Location, '/blockedImage', 'Datatype', info.Datatype);                
            end
            
            desc.Info = info;
            desc.Adapter = obj;
            images.blocked.internal.saveDescription(obj.Location, desc);
        end
        
        function setIOBlock(obj, ioBlockSub, level, data)
            if islogical(data)
                data = uint8(data);
            end
            start = (ioBlockSub-1).*obj.Info.IOBlockSize(level,:) + 1;
            h5write(obj.Location, ['/blockedImage/L',num2str(level)], data, ...
                start, size(data,1:numel(start)));
        end
    end
end

%   Copyright 2020-2022 The MathWorks, Inc.
