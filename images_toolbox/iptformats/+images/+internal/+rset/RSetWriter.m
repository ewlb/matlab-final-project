classdef RSetWriter < handle
%

% Copyright 2018-2020 The MathWorks, Inc.

    properties
        sourceImage
        filenameRSet
        tileSize
        metadata
        tileDims
        numSpanningTilesRows
        numSpanningTilesCols
        maxLevel
        ids
        virtualTileTableL0; 
    end
    methods
        function obj = RSetWriter(sourceImage, varargin)
            obj.sourceImage = matlab.images.internal.stringToChar(sourceImage);
            obj.buildFilename(varargin{:});
            obj.tileSize = 512;
            
        end
        
        function buildFilename(obj,varargin)

            if numel(varargin) > 0
                % the image adapter syntax requires an explicitly specified output
                % filename, so this code path will always be followed for image adapter
                % inputs.
                obj.filenameRSet = varargin{1};
                outputDir = fileparts(obj.filenameRSet);

            else
                % if a filename has been specified, we can generate an output filename
                % based on the input file.
                outputDir = pwd;
                [~, fname] = fileparts(obj.sourceImage);
                obj.filenameRSet = fullfile(outputDir, [fname '.rset']);
            end
            verifyOutputDir(outputDir);
        end
        
        function tileDims = getTileDims(obj)

            if (obj.metadata.SamplesPerPixel > 1)
                tileDims = [obj.tileSize, obj.tileSize, obj.metadata.SamplesPerPixel];
                if (obj.metadata.SamplesPerPixel ~= 3)
                    warning(message('images:rsetwrite:samplesPerPixel', obj.metadata.SamplesPerPixel));
                end
            else
                tileDims = [obj.tileSize, obj.tileSize];
            end
        end
        
        function [numSpanningTilesRows, numSpanningTilesCols, maxLevel] = computeRSetDetails(obj)

            numSpanningRows = 2 ^ ceil(log2(obj.metadata.Height));
            numSpanningTilesRows = numSpanningRows / obj.tileSize;

            numSpanningCols = 2 ^ ceil(log2(obj.metadata.Width));
            numSpanningTilesCols = numSpanningCols / obj.tileSize;

            min_dim = min(obj.metadata.Width, obj.metadata.Height);
            base_dim = 2 ^ ceil(log2(min_dim));
            base_tiles = base_dim / obj.tileSize;
            maxLevel = max(ceil(log2(base_tiles)), 1);

            % Handle small images.
            if ((obj.metadata.Height < 3) || (obj.metadata.Width < 3))

                error(message('images:rsetwrite:imageTooSmall'))

            elseif ((numSpanningTilesRows < 2) || (numSpanningTilesCols < 2))

                warning(message('images:rsetwrite:smallImage'))

                numSpanningTilesRows = max(numSpanningTilesRows, 2);
                numSpanningTilesCols = max(numSpanningTilesCols, 2);

            end
        end

        function ids = setupFile(obj, metadata)
            
            obj.metadata = metadata;
            
            obj.tileDims = obj.getTileDims();
            [obj.numSpanningTilesRows, obj.numSpanningTilesCols, obj.maxLevel] = ...
                obj.computeRSetDetails();
            
            obj.virtualTileTableL0= false(obj.numSpanningTilesRows, obj.numSpanningTilesCols);
            
            details = obj.metadata.details;
            % Identifiers common to all datasets.
            ids.file     = createFile(obj.filenameRSet);
            ids.dspace   = createDataspace(obj.tileDims);
            ids.propList = createDataspaceProps(obj.tileDims, details);

            % Build the root for all layer data.
            ids.rootID = H5G.create(ids.file, '/RSetData', 512);

            % Create a "virtual" dataset that padding tiles can use via reference
            % instead of bloating the file by writing the same tile.
            ids.virtualGroup = H5G.create(ids.rootID, 'Virtual', 32);
            zero_tile = zeros(obj.tileDims, details.mlType);
            padDsetID = H5D.create(ids.virtualGroup, 'padding', details.hdfType, ids.dspace, 'H5P_DEFAULT');
            H5D.write(padDsetID, 'H5ML_DEFAULT', ids.dspace, ids.dspace, 'H5P_DEFAULT', zero_tile);
            H5D.close(padDsetID);

            ids.dtypeRef = H5T.copy('H5T_STD_REF_OBJ');
            ids.ref = H5R.create(ids.virtualGroup, 'padding', 'H5R_OBJECT', -1);
            ids.dspaceRef = H5S.create('H5S_SCALAR');
            
            obj.ids = ids;
        end
        
        function groupID = createLevelGroup(obj, level)
            groupID = H5G.create(obj.ids.rootID, sprintf('L%d', level), 65536);
        end
        
        function status = isTilePresent(obj, datasetName)
            dataset = ['/RSetData/L0/' datasetName];
            status = H5L.exists(obj.ids.file, dataset, 'H5P_DEFAULT');
            
        end
        
        function data = readTile(obj,level, row, column, virtualTileTable)

            dsetName = sprintf('L%d/r%d_c%d', level, row, column);
            dset = H5D.open(obj.ids.rootID, dsetName);

            if (virtualTileTable(row+1, column+1))
                % Read a "virtual" padding tile that is stored elsewhere in the file.
                dsetDeref = H5R.dereference(dset, 'H5R_OBJECT', obj.ids.ref);
                data = H5D.read(dsetDeref, 'H5ML_DEFAULT', obj.ids.dspace, obj.ids.dspace, 'H5P_DEFAULT');
                H5D.close(dsetDeref);

            else
                data = H5D.read(dset, 'H5ML_DEFAULT', obj.ids.dspace, obj.ids.dspace, 'H5P_DEFAULT');
            end

            H5D.close(dset);
        end
        
        function data = padTile(obj,data)
            padAmount = [2*obj.tileSize - size(data,1), 2*obj.tileSize - size(data,2), 0];
            data = padarray(data, padAmount, 'post', 'replicate');
        end
        
        function writeTile(obj, data, groupID, datasetName)

            idx = obj.ids;
            dsetID = H5D.create(groupID, datasetName, obj.metadata.details.hdfType, idx.dspace, idx.propList);
            H5D.write(dsetID, 'H5ML_DEFAULT', idx.dspace, idx.dspace, 'H5P_DEFAULT', data);
            H5D.close(dsetID);
        end
        
        function overWriteTile(obj, data, groupID, datasetName)

            idx = obj.ids;
            dsetID = H5D.open(groupID, datasetName);
            H5D.write(dsetID, 'H5ML_DEFAULT', idx.dspace, idx.dspace, 'H5P_DEFAULT', data);
            H5D.close(dsetID);
        end

        function writeTileRef(obj, groupID, datasetName)

            ids = obj.ids;
            dsetID = H5D.create(groupID, datasetName, ids.dtypeRef, ids.dspaceRef, 'H5P_DEFAULT');
            H5D.write(dsetID, 'H5T_STD_REF_OBJ', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', ids.ref)
            H5D.close(dsetID);
        end
        
        function writeRegion(obj,xlims,ylims,data)
            
            if ((size(data,1) ~= 2*obj.tileSize) || (size(data,2) ~= 2*obj.tileSize))
                data = obj.padTile(data);
            end
            
            [rows, cols] = getL1SpanningTiles(obj.tileSize,xlims,ylims);
            for row = rows
                for col = cols
                    
                end
            end
        end
        
        function writeColormap(obj)
            
            cmap = obj.metadata.details.cmap;
            groupID = H5G.create(obj.ids.file, 'Colormap', 32);

            if (~isempty(cmap))
                dspaceID = H5S.create_simple(2, fliplr(size(cmap)), []);
                dsetID  = H5D.create(groupID, 'map', 'H5T_NATIVE_DOUBLE', dspaceID, 'H5P_DEFAULT');
                H5D.write(dsetID, 'H5ML_DEFAULT', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', cmap);
                H5D.close(dsetID);
                H5S.close(dspaceID);
            end

            H5G.close(groupID);
        end
        
        function writeAllMetadata(obj)
            writeMetadata(obj.ids.file, obj.sourceImage, obj.metadata, obj.tileSize, obj.maxLevel);
            writeVersion(obj.ids.file);
            H5G.create(obj.ids.rootID, '/BaseFileMetadata', 65536);
            closeIdentifiers(obj.ids);
            writeAllBasefileMetadata(obj.filenameRSet, obj.metadata.meta);
        end
        
        function out = resizeImage(obj,in)
            if isempty(obj.metadata.details.cmap)
                out = imresize(in, 0.5);
            else
                out = imresize(in, obj.metadata.details.cmap, 0.5, 'Colormap', 'original');
            end
        end
    end
end

function verifyOutputDir(outputDir)

    [success, attributes] = fileattrib(outputDir);
    if (~success)
        error(message('images:rsetwrite:nonexistentOutputDir', outputDir))
    elseif (~attributes.UserWrite)
        error(message('images:rsetwrite:outputDirPerms', outputDir))
    end
end

function h5Sid = createDataspace(tileDims)
h5Sid = H5S.create_simple(numel(tileDims), fliplr(tileDims), fliplr(tileDims));
end

function h5Fid = createFile(filenameRSet)
h5Fid = H5F.create(filenameRSet, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
end

function h5Pid = createDataspaceProps(tileDims, details)

    h5Pid = H5P.create('H5P_DATASET_CREATE');
    chunkSide = min(128, tileDims(1));

    if (numel(tileDims) == 2)
        chunkDims = [chunkSide, chunkSide];
    else
        % Reverse the tile dimensions to compensate for majority change.
        chunkDims = [tileDims(end:-1:3), chunkSide, chunkSide];
    end

    H5P.set_chunk(h5Pid, chunkDims);

    switch (class(details.mlType))
        case {'uint8', 'int8'}
            % Don't shuffle.
        otherwise
            H5P.set_shuffle(h5Pid);
    end
    H5P.set_deflate(h5Pid, 6);
end

function closeIdentifiers(ids)

% Close in opposite order of opening.
if (~isequal(ids.propList, 'H5P_DEFAULT'))
    H5P.close(ids.propList);
end

H5T.close(ids.dtypeRef);
H5S.close(ids.dspace);
H5S.close(ids.dspaceRef);
H5G.close(ids.virtualGroup);
H5G.close(ids.rootID);
H5F.close(ids.file);
end

function writeMetadata(h5Fid, sourceImage, imageMetadata, tileSize, maxLevel)

% Attach these values to the "/Metadata" group.
groupID = H5G.create(h5Fid, 'Metadata', 32);
dspaceID = H5S.create('H5S_SCALAR');

% The side length of each tile.
attrID = H5A.create(groupID, 'TileSize', 'H5T_NATIVE_DOUBLE', dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, 'H5ML_DEFAULT', tileSize);
H5A.close(attrID);

% The dimensions of the full-resolution image.
attrID = H5A.create(groupID, 'FullImageHeight', 'H5T_NATIVE_DOUBLE', dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, 'H5ML_DEFAULT', imageMetadata.Height);
H5A.close(attrID);

attrID = H5A.create(groupID, 'FullImageWidth', 'H5T_NATIVE_DOUBLE', dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, 'H5ML_DEFAULT', imageMetadata.Width);
H5A.close(attrID);

attrID = H5A.create(groupID, 'MaxLevel', 'H5T_NATIVE_DOUBLE', dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, 'H5ML_DEFAULT', maxLevel);
H5A.close(attrID);

% The name of the full resolution image file.
if isa(sourceImage,'ImageAdapter')
    source_name = [class(sourceImage),' object'];
else
    source_name = sourceImage;
end
stringType = H5T.copy('H5T_C_S1');
H5T.set_size(stringType, length(source_name));
H5T.set_strpad(stringType, 'H5T_STR_NULLTERM');
attrID = H5A.create(groupID, 'OriginalBaseFile', stringType, dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, stringType, source_name);
H5T.close(stringType);
H5A.close(attrID);

attrID = H5A.create(groupID, 'FileCreationTime', 'H5T_NATIVE_DOUBLE', dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, 'H5ML_DEFAULT', now);
H5A.close(attrID);

attrID = H5A.create(groupID, 'BaseFileCreationTime', 'H5T_NATIVE_DOUBLE', dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, 'H5ML_DEFAULT', imageMetadata.Datenum);
H5A.close(attrID);

H5S.close(dspaceID);
H5G.close(groupID);
end

function writeVersion(fileID)

groupID = H5G.create(fileID, 'FormatInfo', 32);
dspaceID = H5S.create('H5S_SCALAR');

stringType = H5T.copy('H5T_C_S1');
H5T.set_size(stringType, length('RSET'));
attrID = H5A.create(groupID, 'FileType', stringType, dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, stringType, 'RSET');
H5A.close(attrID);
H5T.close(stringType);

formatDescription = 'Multi-resolution, large imagery format';
stringType = H5T.copy('H5T_C_S1');
H5T.set_size(stringType, length(formatDescription));
attrID = H5A.create(groupID, 'Description', stringType, dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, stringType, formatDescription);
H5A.close(attrID);
H5T.close(stringType);

attrID = H5A.create(groupID, 'Version', 'H5T_NATIVE_DOUBLE', dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, 'H5ML_DEFAULT', iptui.RSet.currentRSetVersion);
H5A.close(attrID);

attrID = H5A.create(groupID, 'BackwardVersion', 'H5T_NATIVE_DOUBLE', dspaceID, 'H5P_DEFAULT');
H5A.write(attrID, 'H5ML_DEFAULT', iptui.RSet.backwardRSetVersion);
H5A.close(attrID);

H5S.close(dspaceID);
H5G.close(groupID);
end

function writeAllBasefileMetadata(filenameRSet, info)

% Write metadata found in the top-level of the source file's info
% structure, skipping empty values.  Do not recurse down the hierarchy.

f = fieldnames(info);

for i = 1:numel(f)
    
    attr = info(1).(f{i});
    
    if (~isempty(attr) && ...
            (ischar(attr) || isnumeric(attr)))
        
        % Attributes should be smaller than 16k bytes.
        attrDetails = whos('attr');
        if (attrDetails.bytes <= 16384)
            h5writeatt(filenameRSet, '/BaseFileMetadata', f{i}, attr);
        end
    end
end
end

