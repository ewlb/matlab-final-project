classdef JPEG2000 < images.blocked.Adapter

    properties
        IOBlockSize (1,:) double  = [1024 1024]
    end

    properties (Access = private)
        FileName (1,1) string
        Info
    end

    methods

        function obj = openToRead(obj, fileName)
            obj.FileName = fileName;
            finfo = imfinfo(fileName);
            obj.Info.UserData = finfo;
            
            % Read one pixel to determine class since info structure does
            % not contain sign information
            onePixel = imread(fileName,'PixelRegion', {[1 1],[1 1]});
            dataType = string(class(onePixel));
            numChannels = size(onePixel,3);

            % Extend IOBlockSize if required
            if numChannels>1 && numel(obj.IOBlockSize)==2
                obj.IOBlockSize = [obj.IOBlockSize, numChannels];
            end
            if numel(obj.IOBlockSize)~=ndims(onePixel)
                error(message('images:blockedImage:incorrectJP2kIOBlockSize', ndims(onePixel)))
            end

            obj.Info.InitialValue = cast(0, dataType);

            % Number of resolution levels == WaveletDecompositionLevels
            for levelIndex = 1:finfo.WaveletDecompositionLevels+1
                levelIndex0Based = levelIndex-1;
                obj.Info.Size(levelIndex,:) = ceil([finfo.Height, finfo.Width]/2^levelIndex0Based);
                obj.Info.IOBlockSize(levelIndex,:) = obj.IOBlockSize;
                obj.Info.Datatype(levelIndex) = dataType;
            end

            % Number of channels is number of BitsPerSample entries
            numChannels = numel(finfo.BitsPerSample);
            if numChannels>1
                obj.Info.Size(:,3) = numChannels;
                obj.Info.IOBlockSize(:,3) = numChannels;
            end            
        end


        function info = getInfo(obj)
            info = obj.Info;
        end


        function block = getIOBlock(obj, ioBlockSub, level)
            % Move to 0 based indexing
            levelIndex0Based = level-1;

            % Convert the block subscripts to row/col start and end of the
            % image.
            ioBlockSize = obj.Info.IOBlockSize(level,:);
            rstart = (ioBlockSub(1)-1)*ioBlockSize(1)+1;
            cstart = (ioBlockSub(2)-1)*ioBlockSize(2)+1;
            rend = rstart+ioBlockSize(1)-1;
            cend = cstart+ioBlockSize(2)-1;

            % Delegate to imread with PixelRegion
            block = imread(obj.FileName,...
                "PixelRegion", {[rstart, rend], [cstart, cend]},...
                "ReductionLevel", levelIndex0Based);
        end
    end
end

%   Copyright 2022 The MathWorks, Inc.