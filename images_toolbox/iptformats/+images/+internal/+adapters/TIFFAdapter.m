classdef TIFFAdapter < images.internal.adapters.BigImageAdapter
    %
    
    % Copyright 2018-2022 The MathWorks, Inc.
    
    properties (Access = private)
        NumLevels
        
        TIFFObject = [];
        ActiveIFD
        IsChunky
        RowsNative
        ColumnsNative
        NumChannels
        MLType
        IsStripped = false
        
        CurrentDirectory = 1;
        
        ResolutionLevelSizes
        CreatedLevels = [];
        
        SamplesPerPixelForCurrentLevel
        
        % Default compression while writing
        Compression = Tiff.Compression.LZW
    end
    
    
    methods
        
        function obj = TIFFAdapter(dataSource, mode_, compression)
            obj.DataSource = dataSource;
            obj.Mode = validatestring(mode_, {'r', 'w'}, mfilename, 'Mode');
            
            if(obj.Mode=='r')
                try
                    obj.SourceMetadata = imfinfo(obj.DataSource);
                catch ME
                    newException = MException('images:bigimages:couldNotReadMetadata', ME.message);
                    throw(newException)
                end
                
                % Warn if TIFF file is a single strip image
                for ind = 1:numel(obj.SourceMetadata)
                    if numel(obj.SourceMetadata(ind).StripOffsets) == 1
                        warning(message('images:bigimage:singleStripTiff', ind, obj.SourceMetadata(1).Filename));
                    end
                end
                
                % Ensure all images in file have the same channels and type
                numChannels = [obj.SourceMetadata.SamplesPerPixel];
                bps = [obj.SourceMetadata.BitsPerSample];
                if ~all(numChannels(1) == numChannels) || ~all(bps(1)==bps)
                    warning(message('images:bigimage:tiffImagesDoNotMatch'));
                end
                
                [obj.Channels, obj.PixelDatatype] = determineImageDetails(obj.SourceMetadata);
                [obj.Height, obj.Width] = determineImageSizes(obj.SourceMetadata);
                
                obj.NumLevels = numel(obj.SourceMetadata);
                
                pWarnState = warning('off', 'imageio:tiffutils:libtiffWarning');
                obj.TIFFObject = Tiff(dataSource, 'r');
                warning(pWarnState);
                
                obj.SamplesPerPixelForCurrentLevel = obj.TIFFObject.getTag('SamplesPerPixel');
                obj.IsChunky = obj.TIFFObject.getTag(obj.TIFFObject.TagID.PlanarConfiguration) == Tiff.PlanarConfiguration.Chunky;
                obj.NumChannels = obj.TIFFObject.getTag(obj.TIFFObject.TagID.SamplesPerPixel);
                obj.MLType = getMATLABType(obj.TIFFObject);
                obj.updateRowCols;
                
                obj.IsStripped = cellfun(@isempty, {obj.SourceMetadata.TileWidth});
                
            else
                % Write mode, always write bigTiff, since we are usually
                % dealing with large data. And always interleaved (chunky)
                % since thats the Tiff baseline spec.
                try
                    obj.TIFFObject = Tiff(dataSource, 'w8');
                catch WRITEEXP
                    EXP = MException('images:bigimage:couldNotCreate',...
                        message('images:bigimage:couldNotCreate', obj.DataSource));
                    EXP = EXP.addCause(WRITEEXP);
                    throw(EXP)
                end
                obj.IsChunky = true;
                if nargin==3
                    obj.setCompression(compression);
                end
            end
            
            for ind = 1:numel(obj.SourceMetadata)
                if ~isempty(obj.SourceMetadata(ind).StripOffsets)
                    % striped
                    obj.IOBlockSize(ind,:) = [obj.SourceMetadata(ind).RowsPerStrip, obj.SourceMetadata(ind).Width];
                else
                    % tiled
                    obj.IOBlockSize(ind,:) = [obj.SourceMetadata(ind).TileLength, obj.SourceMetadata(ind).TileWidth];
                end
            end
        end
        
        function delete(obj)
            if ~isempty(obj.TIFFObject)
                obj.TIFFObject.close();
            end
        end
        
        function s = saveobj(obj)
            s.DataSource = obj.DataSource;
            s.Mode = obj.Mode;
            if (obj.Mode=='w')
                assert(false, 'Cannot save a w mode TIFF Adapter');
            end
        end
        
        function data = readBlock(obj, level, blockStart)
            
            % "level" is image/IFD number
            if isempty(obj.ActiveIFD) || (obj.ActiveIFD ~= level)
                pWarnState = warning('off', 'imageio:tiffutils:libtiffWarning');
                obj.TIFFObject.setDirectory(level);
                warning(pWarnState);
                                
                obj.SamplesPerPixelForCurrentLevel = obj.TIFFObject.getTag('SamplesPerPixel');
                obj.ActiveIFD = level;
            end
            obj.updateRowCols();
            
            if obj.TIFFObject.isTiled
                if obj.SamplesPerPixelForCurrentLevel == 3 && obj.PixelDatatype=="uint8"
                    data = obj.TIFFObject.readRGBATile(blockStart(1), blockStart(2));
                elseif obj.NumChannels == 1                    
                    tileNum = obj.TIFFObject.computeTile([blockStart(1), blockStart(2)]);
                    oneTile = obj.TIFFObject.readEncodedTile(tileNum);
                    [r,c,~] = size(oneTile);
                    data(1:r, 1:c) = oneTile;
                else                   
                    if obj.IsChunky
                        tileNum = obj.TIFFObject.computeTile([blockStart(1), blockStart(2)]);
                        oneTile = obj.TIFFObject.readEncodedTile(tileNum);
                        [r,c,~] = size(oneTile);
                        data(1:r, 1:c, :) = oneTile;
                    else
                        for i = 1:obj.NumChannels
                            tileNum = obj.TIFFObject.computeTile([blockStart(1), blockStart(2)], i);
                            oneTile = obj.TIFFObject.readEncodedTile(tileNum);
                            [r,c,~] = size(oneTile);                            
                            data(1:r, 1:c, i) = oneTile; %#ok<AGROW>
                        end
                    end
                    
                    if (r ~= obj.RowsNative) || (c ~= obj.ColumnsNative)
                        data = data(1:r, 1:c, :);
                    end
                end
            else
                if obj.NumChannels == 3 && obj.PixelDatatype=="uint8"
                    data = obj.TIFFObject.readRGBAStrip(blockStart(1));
                else                    
                    if obj.IsChunky
                        stripNum = obj.TIFFObject.computeStrip(blockStart(1));
                        oneStrip = obj.TIFFObject.readEncodedStrip(stripNum);
                        [r,c,~] = size(oneStrip);
                        data(1:r, 1:c, :) = oneStrip;
                    else
                        for i = 1:obj.NumChannels
                            stripNum = obj.TIFFObject.computeStrip(blockStart(1), i);
                            oneStrip = obj.TIFFObject.readEncodedStrip(stripNum);
                            [r,c,~] = size(oneStrip);
                            data(1:r, 1:c, i) = oneStrip; %#ok<AGROW>
                        end
                    end                    
                end
            end            
            
            if getTag(obj.TIFFObject, 'Photometric') == Tiff.Photometric.MinIsWhite ...
                    && islogical(data)
                % g1901885 - The Tiff library flips the raw binary data.
                % Most likely not what users intent - use raw data instead
                % by undoing the flip
                data = ~data;
            end            
            obj.updateNNZ(level, blockStart, data, false);
        end
        
        
        function data = readRegion(obj, level, regionStartIntrinsic, regionEndIntrinsic)
            if obj.IsStripped(level)
                % imread (which uses rtifc) is faster than reading
                % individual strips using the Tiff object.
                rows = [regionStartIntrinsic(1), regionEndIntrinsic(1)];
                cols = [regionStartIntrinsic(2), regionEndIntrinsic(2)];
                data = imread(obj.SourceMetadata(1).Filename, 'PixelRegion', {rows, cols},'Index', level, 'Info', obj.SourceMetadata);
            else
                data = readRegion@images.internal.adapters.BigImageAdapter(obj, level, regionStartIntrinsic, regionEndIntrinsic);
            end
        end
        
        function pctNNZ = computeRegionNNZ(obj, level, regionStartIntrinsic, regionEndIntrinsic)
            if obj.IsStripped(level)
                data = obj.readRegion(level, regionStartIntrinsic, regionEndIntrinsic);
                pctNNZ = nnz(data)/numel(data);
            else
                pctNNZ = computeRegionNNZ@images.internal.adapters.BigImageAdapter(obj, level, regionStartIntrinsic, regionEndIntrinsic);
            end
        end
        
        function appendMetadata(obj, resolutionLevelSizes, tileSize, channels, pixelClass, metadata)
            if ~isempty(metadata)
                obj.SourceMetadata(1).AllValues = metadata;
            else
                obj.SourceMetadata(1).AllValues = struct([]);
            end
            
            validateattributes(resolutionLevelSizes, {'numeric'},...
                {'2d', 'ncols', 2, 'positive', 'finite', 'nonsparse', 'integer'})
            validateattributes(tileSize, {'numeric'}, ...
                {'row', 'numel', 2, 'positive', 'finite', 'nonsparse', 'integer'});
            validateattributes(channels, {'numeric'}, ...
                {'scalar', 'real', 'positive', 'integer'});
            
            obj.NumChannels = channels;
            obj.MLType = validatestring(pixelClass, ...
                {'logical', 'uint8', 'uint16', 'uint32', 'int8', 'int16', 'int32', 'single', 'double'});
            obj.SourceMetadata.Channels = channels;
            obj.SourceMetadata.PixelDatatype = obj.MLType;
            if isfield(obj.SourceMetadata,'Height')
                obj.SourceMetadata.Height(end+1) = resolutionLevelSizes(:,1);
            else
                obj.SourceMetadata.Height = resolutionLevelSizes(:,1);
            end
            if isfield(obj.SourceMetadata,'Width')
                obj.SourceMetadata.Width(end+1) = resolutionLevelSizes(:,2);
            else
                obj.SourceMetadata.Width = resolutionLevelSizes(:,2);
            end
            obj.ResolutionLevelSizes = resolutionLevelSizes;
            obj.NumLevels = size(resolutionLevelSizes,1);
            obj.RowsNative = tileSize(1);
            obj.ColumnsNative = tileSize(2);
        end
        
        function writeBlock(obj, level, regionStartIntrinsic, data)
            % It is advisable to write one entire level ("image" in TIFF
            % parlance) at a time starting in the upper-left and proceeding
            % row-wise first and then down the image. This will yield
            % optimal file organization.                       
            if ~any(level == obj.CreatedLevels)
                obj.prepareToWriteLevel(level)
            end
            
            T = obj.TIFFObject;
            
            if level ~= obj.CurrentDirectory
                try
                    T.setDirectory(level)
                catch
                    % It probably succeeded anyway.
                end
            end
            
            if obj.IsChunky
                tileNumber = T.computeTile(regionStartIntrinsic);
                T.writeEncodedTile(tileNumber, data)
            else
                for i=1:obj.NumChannels
                    tileNumber = T.computeTile(regionStartIntrinsic, i);
                    T.writeEncodedTile(tileNumber, data(:,:,i))
                end
            end
        end
        
        function finalizeWrite(obj)
            obj.TIFFObject.close();
        end
    end
    
    
    methods (Static)
        function obj = loadobj(s)
            obj = images.internal.adapters.TIFFAdapter(s.DataSource, s.Mode);
        end
    end
    
    
    methods (Access = private)
        function setCompression(obj, compression)
            compression = validatestring(compression,["LZW", "PackBits", "Deflate", "JPEG", "None"], mfilename);            
            obj.Compression = Tiff.Compression.(compression);
        end
        
        function updateRowCols(obj)
            if isempty(obj.TIFFObject) || contains(obj.Mode,'w')
                return
            end
            % Each image of a Tiff object can be either Tiled or Row based,
            % so update the values each time its needed
            if obj.TIFFObject.isTiled
                obj.RowsNative = obj.TIFFObject.getTag(obj.TIFFObject.TagID.TileLength);
                obj.ColumnsNative = obj.TIFFObject.getTag(obj.TIFFObject.TagID.TileWidth);
            else
                obj.RowsNative = obj.TIFFObject.getTag(obj.TIFFObject.TagID.RowsPerStrip);
                obj.ColumnsNative = obj.TIFFObject.getTag(obj.TIFFObject.TagID.ImageWidth);
            end
        end
        
        
        function prepareToWriteLevel (obj, level)
            
            T = obj.TIFFObject;
            T.close()
            T = Tiff(obj.DataSource, 'a');
            obj.TIFFObject = T;
            
            tagStruct.ImageLength = obj.SourceMetadata.Height(level);
            tagStruct.ImageWidth = obj.SourceMetadata.Width(level);
            
            if obj.NumChannels == 1
                tagStruct.Photometric = Tiff.Photometric.MinIsBlack;
                tagStruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
                obj.IsChunky = true;
            elseif obj.NumChannels == 3
                tagStruct.Photometric = Tiff.Photometric.RGB;
                tagStruct.PlanarConfiguration = Tiff.PlanarConfiguration.Separate;
                obj.IsChunky = false;
            else
                error(message('images:bigimage:tiffChannelCount'))
            end
            
            switch obj.MLType
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
                    assert(false)
            end
            
            tagStruct.SamplesPerPixel = obj.NumChannels;
            tagStruct.SampleFormat = getSampleFormat(obj.MLType);
            tagStruct.TileWidth = obj.ColumnsNative;
            tagStruct.TileLength = obj.RowsNative;
            tagStruct.Compression = obj.Compression;
            tagStruct.Software = 'MATLAB bigimage';
            
            T.setTag(tagStruct);
            
            obj.CurrentDirectory = level;
            obj.CreatedLevels = [obj.CreatedLevels level];
        end
    end
end


function [channels, pixelDatatype] = determineImageDetails(rawMetadata)

% Pick meta data from the finest level
[~, finestLevel] = max([rawMetadata.Width].*[rawMetadata.Height]);

channels = numel(rawMetadata(finestLevel).BitsPerSample);

% Assumption - bps for all channels are the same. Should hold for most sane
% data sources, though TIFF's can technically have them be different, in
% which case this logic will pick the first to report one to report as the
% ClassUnderlying.
bitsPersample = rawMetadata(finestLevel).BitsPerSample(1);
unsigned = isPixelUnsigned(rawMetadata(finestLevel));

if bitsPersample == 1
    pixelDatatype = "logical";
elseif bitsPersample <= 8
    if unsigned
        pixelDatatype = "uint8";
    else
        pixelDatatype = "int8";
    end
elseif bitsPersample <= 16
    if unsigned
        pixelDatatype = "uint16";
    else
        pixelDatatype = "int16";
    end
elseif bitsPersample == 32
    pixelDatatype = "single";
    if isfield(rawMetadata(finestLevel), 'SampleFormat') && ~isempty(rawMetadata(finestLevel).SampleFormat)
        if strcmp('Unsigned integer', rawMetadata(finestLevel).SampleFormat)
            pixelDatatype = "uint32";
        end
        if strcmp('Two''s complement signed integer', rawMetadata(finestLevel).SampleFormat)
            pixelDatatype = "int32";
        end
    end
elseif bitsPersample == 64
    pixelDatatype = "double";
else
end

end


function tf = isPixelUnsigned(rawMetadata)

if isfield(rawMetadata, 'SampleFormat') && ~isempty(rawMetadata.SampleFormat)
    if iscell(rawMetadata.SampleFormat)
        sf = rawMetadata.SampleFormat{1};
    else
        sf = rawMetadata.SampleFormat;
    end
        
    switch sf
        case 'Unsigned integer'
            tf = true;
        case 'Two''s complement signed integer'
            tf = false;
        otherwise
            tf = true;
    end
else
    tf = true;
end

end


function [heights, widths] = determineImageSizes(rawMetadata)

heights = zeros(size(rawMetadata));
widths = heights;

for idx = 1:numel(rawMetadata)
    heights(idx) = rawMetadata(idx).Height;
    widths(idx) = rawMetadata(idx).Width;
end
end


function MLType = getMATLABType(T)

bps = T.getTag(T.TagID.BitsPerSample);
fmt = T.getTag(T.TagID.SampleFormat);

if bps == 1
    % Special case for 1-bit images --> logical
    MLType = 'logical';
    return
elseif bps <= 8
    MLContainerSize = 8;
elseif bps <= 16
    MLContainerSize = 16;
elseif bps <= 32
    MLContainerSize = 32;
elseif bps <= 64
    MLContainerSize = 64;
else
    error(message('images:bigimage:tiffUnsupportedFormat'))
end

switch fmt
    case 1  % UInt
        MLType = sprintf('uint%d', MLContainerSize);
    case 2  % Int
        MLType = sprintf('int%d', MLContainerSize);
    case 3  % IEEEFP
        if bps == 32
            MLType = 'single';
        elseif bps == 64
            MLType = 'double';
        else
            error(message('images:bigimage:tiffUnsupportedFormat'))
        end
        %     case 4  % Void
        %     case 5  % ComplexInt
        %     case 6  % ComplexIEEEFP
    otherwise
        error(message('images:bigimage:tiffUnsupportedFormat'))
end
end


function tiffFormat = getSampleFormat(pixelClass)

switch pixelClass
    case {'logical', 'uint8', 'uint16', 'uint32'}
        tiffFormat = Tiff.SampleFormat.UInt;
    case {'int8', 'int16', 'int32'}
        tiffFormat = Tiff.SampleFormat.Int;
    case {'single','double'}
        tiffFormat = Tiff.SampleFormat.IEEEFP;
    otherwise
        assert(false)
end

end
