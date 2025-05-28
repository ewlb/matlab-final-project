classdef TIFF3D < images.blocked.Adapter
    properties (Access = private)
        FileName (1,1) string
        Size double
    end

    properties(SetAccess=private)
        IOBlockSize double
    end

    properties (Hidden)
        TiffInfo (1,:) struct
    end

    methods
        function obj = TIFF3D(options)
            arguments
                options.IOBlockSize (1,:) double {mustBePositive, mustBeInteger} = []
            end
            obj.IOBlockSize = options.IOBlockSize;
        end

        function openToRead(obj, tiffFileName)
            obj.FileName = tiffFileName;
        end

        function info = getInfo(obj)
            if isempty(obj.TiffInfo)
                % Avoid issuing lots of the same warning.
                w = warning('off', 'imageio:tiffutils:libtiffWarning');
                oc = onCleanup(@() warning(w));
                obj.TiffInfo = matlab.io.internal.imagesci.imtifinfo(obj.FileName);
            end

            % ImageJ files have only one IFD, so need to look at other tags
            [isImageJ, numFrames] = images.internal.tiff.isImageJTiff(obj.TiffInfo);
            if ~isImageJ
                numFrames = numel(obj.TiffInfo);
            end

            numChannels = numel(obj.TiffInfo(1).BitsPerSample);
            if numChannels>1
                % RGB or multi channel stack
                info.Size = [obj.TiffInfo(1).Height, obj.TiffInfo(1).Width, numFrames, numChannels];
            else
                info.Size = [obj.TiffInfo(1).Height, obj.TiffInfo(1).Width, numFrames];
            end

            obj.Size = info.Size;

            % If not explicitly set, use arbitrary defaults from file meta
            % data.
            if isempty(obj.IOBlockSize)
                if isempty(obj.TiffInfo(1).TileLength)
                    % Stripped tiff, pick full size. 3 is arbitrary.
                    obj.IOBlockSize = [info.Size(1:2), 3];
                else
                    % Choice of 8 is arbitrary, large enough to ensure
                    % enough nhood for most processing, small enough to be
                    % performant.
                    obj.IOBlockSize = [obj.TiffInfo(1).TileLength, obj.TiffInfo(1).TileWidth 8];
                end
            end
            if numChannels>1
                obj.IOBlockSize = [obj.IOBlockSize, numChannels];
            end
            info.IOBlockSize = obj.IOBlockSize;

            tiffR = matlab.io.internal.TiffReader(obj.FileName);
            dtype = string(tiffR.MLType);
            info.Datatype = dtype;
            info.InitialValue = cast(0, info.Datatype(1));
        end

        function block = getIOBlock(obj, ioBlockSub, ~)
            % Convert ioblockSub (which is in terms of IOBlockSize) into a
            % 'PixelRegion' coordinate.
            regionStart = (ioBlockSub-1).*obj.IOBlockSize + 1;
            regionEnd = (ioBlockSub).*obj.IOBlockSize;

            % Limit to end of data
            regionEnd = min(regionEnd, obj.Size);

            rows = [regionStart(1), regionEnd(1)];
            cols = [regionStart(2), regionEnd(2)];
            slices = [regionStart(3), regionEnd(3)];

            args.PixelRegion = {rows, cols, slices};
            block = images.internal.tiff.readVolume(args, obj.TiffInfo);
        end
    end
end

%   Copyright 2024 The MathWorks, Inc.
