classdef TIFF < images.blocked.Adapter
    properties
        Extension (1,1) string = "tiff"

        Compression = Tiff.Compression.LZW
    end


    properties (Access = private)
        FileName (1,1) string
        ITRObject = [];   % For read
        TIFFObject = [];  % For write
        ActiveReadLevel(1,1) double
        SizeInBlocks double
        Info(1,1) struct
        DirectoryNumbersAlreadyCreated (1,:) double
    end

    % Read methods
    methods
        function openToRead(obj, tiffFileName)
            obj.FileName = tiffFileName;

            try
                obj.ITRObject = matlab.io.internal.BigImageTiffReader(obj.FileName);
            catch ME
                % Escape the \ from sprintf
                msg = strrep(ME.message, '\','\\');
                newException = MException('images:bigimages:couldNotReadUserData', msg);
                throw(newException)
            end

            obj.getInfo();

            % Find the 'finest' level (most pixels)
            numPixels = prod(obj.Info.Size,2);
            [~, finestLevel] = max(numPixels);

            % Re/open the finest level by default
            obj.ITRObject = matlab.io.internal.BigImageTiffReader(...
                obj.FileName,"ImageIndex", finestLevel);
            obj.ActiveReadLevel = finestLevel;
        end

        function info = getInfo(obj)
            % Read info only once (saves time on loadobj)
            if ~isequal(obj.Info, struct())
                info = obj.Info;
                return
            end

            desc = images.blocked.internal.loadDescription(obj.FileName);
            if isfield(desc, 'Info')
                % Load previously saved side car information from the .mat
                % file.
                obj.Info = desc.Info;
                imageSize = obj.Info.Size;
                ioBlockSize = obj.Info.IOBlockSize;
            else
                % Query the file
                allAreGrayScale = true;
                for ind = 1:obj.ITRObject.NumImages
                    obj.ITRObject = matlab.io.internal.BigImageTiffReader(obj.FileName, "ImageIndex", ind);
                    imageSize(ind,:) = [obj.ITRObject.ImageHeight, ...
                        obj.ITRObject.ImageWidth, ...
                        obj.ITRObject.SamplesPerPixel]; %#ok<AGROW>
                    ioBlockSize(ind,:) = [obj.ITRObject.SliceHeight,...
                        obj.ITRObject.SliceWidth, ...
                        obj.ITRObject.SamplesPerPixel]; %#ok<AGROW>
                    datatype(ind) = obj.ITRObject.MLType; %#ok<AGROW>
                    allAreGrayScale = allAreGrayScale & obj.ITRObject.SamplesPerPixel==1;
                end

                if allAreGrayScale % Expose as 2D in blockedImage
                    imageSize(:,3) = [];
                    ioBlockSize(:,3) = [];
                end

                obj.Info.Size = imageSize;
                obj.Info.IOBlockSize = ioBlockSize;
                obj.Info.Datatype = datatype;
                obj.Info.InitialValue = cast(0, obj.Info.Datatype(1));
            end

            obj.SizeInBlocks = ceil(imageSize./ioBlockSize);

            info = obj.Info;
        end

        function data = getIOBlock(obj, ioBlockSub, level)
            if level ~= obj.ActiveReadLevel
                obj.ITRObject = matlab.io.internal.BigImageTiffReader(...
                    obj.FileName, "ImageIndex", level);
                obj.ActiveReadLevel = level;
            end
            % col-major order
            sliceInd = (ioBlockSub(1)-1)*obj.SizeInBlocks(level,2) + ioBlockSub(2);
            data = obj.ITRObject.readCompleteSlice(sliceInd);
        end
    end

    methods
        function  openToWrite(obj, destination, info, level)
            obj.Info = info;
            obj.FileName = destination;

            if ~(size(info.Size, 2)==2 || size(info.Size, 2)==3)
                obj.deleteFile();
                error(message('images:blockedImage:grayAndRGBTIFFOnly'))
            end

            if any(mod(info.IOBlockSize(level,1:2),16))
                obj.deleteFile();
                error(message('images:blockedImage:blockSizeNotMod16'))
            end

            try
                if isfile(destination)
                    % Previously opened for writing, flush previous
                    % contents first.
                    obj.TIFFObject.rewriteDirectory();

                    if ismember(level, obj.DirectoryNumbersAlreadyCreated)
                        % Already created, just switch to it.
                        obj.TIFFObject.setDirectory(level);
                        return;
                    else
                        % Continue on to create a new directory for this
                        % level.
                        obj.DirectoryNumbersAlreadyCreated(end+1) = level;
                    end
                else
                    path = fileparts(destination);
                    images.blocked.internal.createFolder(path);
                    % Always bigTIFF
                    obj.TIFFObject = Tiff(destination, 'w8');
                    obj.DirectoryNumbersAlreadyCreated = level;
                end
            catch WRITEEXP
                obj.deleteFile();
                EXP = MException('images:bigimage:couldNotCreate',...
                    message('images:bigimage:couldNotCreate', destination));
                EXP = EXP.addCause(WRITEEXP);
                throw(EXP)
            end

            desc.Info = info;
            if ~isDefaultInfo(info)
                % There is custom UserData/WorldStart/End, so save that in
                % side channel .mat file.
                images.blocked.internal.saveDescription(obj.FileName, desc);
            end

            % Setup the tags
            tagStruct.ImageLength = info.Size(level,1);
            tagStruct.ImageWidth = info.Size(level,2);

            if size(info.Size,2)==2 || info.Size(level,3) == 1
                tagStruct.Photometric = Tiff.Photometric.MinIsBlack;
                tagStruct.SamplesPerPixel = 1;
                tagStruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
            elseif info.Size(level,3) == 3
                tagStruct.Photometric = Tiff.Photometric.RGB;
                tagStruct.SamplesPerPixel = 3;
                tagStruct.PlanarConfiguration = Tiff.PlanarConfiguration.Separate;
            else
                obj.deleteFile();
                error(message('images:bigimage:tiffChannelCount'))
            end

            switch info.Datatype(level)
                case 'logical'
                    tagStruct.BitsPerSample = 1;
                case {'uint8', 'int8'}
                    tagStruct.BitsPerSample = 8;
                case {'uint16', 'int16'}
                    tagStruct.BitsPerSample = 16;
                case {'uint32', 'int32', 'single'}
                    tagStruct.BitsPerSample = 32;
                case {'double'}
                    tagStruct.BitsPerSample = 64;
                otherwise
                    obj.deleteFile();
                    error(message('images:blockedImage:unsupportedTIFF'))
            end

            switch info.Datatype(level)
                case {'logical', 'uint8', 'uint16', 'uint32'}
                    tagStruct.SampleFormat = Tiff.SampleFormat.UInt;
                case {'int8', 'int16', 'int32'}
                    tagStruct.SampleFormat = Tiff.SampleFormat.Int;
                case {'single','double'}
                    tagStruct.SampleFormat = Tiff.SampleFormat.IEEEFP;
                otherwise
                    obj.deleteFile();
                    error(message('images:blockedImage:unsupportedTIFF'))
            end

            tagStruct.TileWidth = info.IOBlockSize(level,2);
            tagStruct.TileLength = info.IOBlockSize(level,1);
            tagStruct.Compression = obj.Compression;
            tagStruct.Software = 'MATLAB blockedImage';

            obj.TIFFObject.setTag(tagStruct);
            obj.SizeInBlocks = ceil(info.Size./info.IOBlockSize);
        end

        function setIOBlock(obj, ioBlockSub, level, data)
            regionPoint = (ioBlockSub(1:2)-1).*obj.Info.IOBlockSize(level,1:2) + 1;
            if size(data,3) == 1
                tileNumber = obj.TIFFObject.computeTile(regionPoint);
                obj.TIFFObject.writeEncodedTile(tileNumber, data)
            else
                for pInd=1:size(data,3)
                    % Chunky
                    tileNumber = obj.TIFFObject.computeTile(regionPoint, pInd);
                    obj.TIFFObject.writeEncodedTile(tileNumber, data(:,:,pInd))
                end
            end
        end

        function close(obj)
            if ~isempty(obj.TIFFObject)
                % Close the writer object
                obj.TIFFObject.close();
            end
            delete(obj.ITRObject)
        end
    end

    methods (Access = private)
        function deleteFile(obj)
            % Close TIFF object and attempt to delete any output file
            % created. (No action in CATCH, hence no-op)
            try %#ok<TRYNC>
                close(obj)
            end
            if isfile(obj.FileName)
                try %#ok<TRYNC>
                    delete(obj.FileName)
                end
            end
            [~, fname, ~]= fileparts(obj.FileName);
            descFile = fname+".mat";
            if isfile(descFile)
                try %#ok<TRYNC>
                    delete(descFile)
                end
            end
        end
    end
end

function tf = isDefaultInfo(info)
% Check if info contains default information
tf = isequal(info.UserData, struct())...
    && all(info.WorldStart==0.5,'all')...
    && all(info.WorldEnd == info.Size(1,:)+0.5,'all');
end

%   Copyright 2020-2022 The MathWorks, Inc.
