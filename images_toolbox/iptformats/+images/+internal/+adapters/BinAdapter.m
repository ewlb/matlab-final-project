classdef BinAdapter < images.internal.adapters.BigImageAdapter
% Access the data source based on read or write mode.

% Copyright 2019-2020 The MathWorks, Inc.
    
    properties
        UnloadedValue = []
        
        % Not used, just saved to ensure de-serialization has access to
        % this info.
        SpatialReferencing = imref2d.empty()
    end
    
    
    methods
        function obj = BinAdapter(dataSource_, mode_, unloadedValue)
            obj.DataSource = dataSource_;
            obj.Mode = mode_;
            
            if nargin==3
                % Required to return unloaded tiles for 'virtual' images
                obj.UnloadedValue = unloadedValue;
            end
            
            if mode_=='r'
                assert(isfolder(obj.DataSource))
                if ~exist(fullfile(obj.DataSource,'description.mat'),'file')
                    error(message('images:bigimage:notAValidDir'));
                end
                obj.readMetaData();
                
            else % a or w
                if mode_=='w'
                    try
                        rmdir(obj.DataSource,'s');
                    catch
                    end
                end
                if ~isfolder(obj.DataSource)
                    try
                        mkdir(obj.DataSource);
                    catch
                        error(message('images:bigimage:couldNotCreate', obj.DataSource));
                    end
                end
            end
        end
        
        
        function data = readBlock(obj, level, blockStart)
            fileName = [num2str(level),...
                '_', num2str(blockStart(1)),...
                '_',num2str(blockStart(2)),'.bin'];
            fid = fopen(fullfile(obj.DataSource, fileName));
            
            readType = char(obj.PixelDatatype);
            
            if fid==-1
                % Unloaded value comes from bigimage and has the
                % appropriate number of channels in it.
                data = repmat(obj.UnloadedValue, obj.IOBlockSize(level,:));
            else
                % Read blocksize
                numDims = fread(fid, 1, 'double');
                blockSize = fread(fid, numDims, 'double');
                blockSize = blockSize';
                % Data
                data = fread(fid,inf, [readType, '=>', readType]);
                fclose(fid);
                data = reshape(data, blockSize);
            end
        end
        
        function writeMetadata(obj,resolutionLevelSizes, blockSize, channels, PixelDatatype, ~)
            if exist(fullfile(obj.DataSource,'description.mat'),'file')
                meta = obj.loadMetaData();
            else
                meta.CreationTime = datestr(now);
            end
            
            meta.ResolutionLevels = resolutionLevelSizes;
            meta.IOBlockSize = blockSize;
            
            meta.Channels = channels;
            meta.PixelDatatype = PixelDatatype;
            save(fullfile(obj.DataSource,'description.mat'), 'meta');
            
            % Refresh object properties
            obj.readMetaData();
        end
        
        function appendMetadata(obj,resolutionLevelSizes, blockSize, channels, PixelDatatype, ~)
            if exist(fullfile(obj.DataSource,'description.mat'),'file')
                meta = obj.loadMetaData();
            else
                meta.CreationTime = datestr(now);
            end
            
            % Append
            if isfield(meta, 'ResolutionLevels')
                meta.ResolutionLevels(end+1,:) = resolutionLevelSizes;
            else
                meta.ResolutionLevels = resolutionLevelSizes;
            end
            
            if isfield(meta, 'IOBlockSize')
                meta.IOBlockSize(end+1,:) = blockSize;
            else
                meta.IOBlockSize = blockSize;
            end
            
            meta.Channels = channels;
            meta.PixelDatatype = PixelDatatype;
            save(fullfile(obj.DataSource,'description.mat'), 'meta');
            
            % Refresh object properties
            obj.readMetaData();
        end
        
        function writeBlock(obj, level, blockStart, data)
            blockSize = obj.IOBlockSize(level,:);
            
            % Pad interior blocks, trim excess outside image extents
            if ~isequal(size(data,[1 2]),blockSize)                
                imageSize = [obj.Height(level), obj.Width(level)];
                blockEndInImage = blockStart + blockSize - 1;
                clippedBlockEndInImage = min(blockEndInImage, imageSize);
                requiredBlockSize = clippedBlockEndInImage-blockStart+1;
                
                % This pads out if needed
                unloadedValue = cast(obj.UnloadedValue, 'like', data);
                data_ = repmat(unloadedValue, requiredBlockSize);
                
                % Copy over only valid part (i.e trim)
                reqInds = min(size(data_,[1 2]), size(data,[1 2]));
                data_(1:reqInds(1), 1:reqInds(2),:) = data(1:reqInds(1), 1:reqInds(2),:);
                
                data = data_;
            end
            
            fileName = [num2str(level),...
                '_', num2str(blockStart(1)),...
                '_',num2str(blockStart(2)),'.bin'];
            fid = fopen(fullfile(obj.DataSource,fileName),'w');
            % Store block size (which could be partial)
            fwrite(fid, numel(size(data)), 'double');
            fwrite(fid, size(data), 'double');
            % Store data
            fwrite(fid, data, class(data));
            fclose(fid);
            
            obj.updateNNZ(level, blockStart, data, true);
        end
        
        function finalizeWrite(obj)
            % Write unloaded value and spatial referencing
            lstruct = load(fullfile(obj.DataSource,'description.mat'));
            meta = lstruct.meta;
            meta.UnloadedValue = obj.UnloadedValue;
            meta.SpatialReferencing = obj.SpatialReferencing;
            save(fullfile(obj.DataSource,'description.mat'), 'meta');
        end
    end
    
    
    methods (Access = private)
        
        function readMetaData(obj)
            % Refresh obj properties
            meta = obj.loadMetaData();
            
            obj.Height= meta.ResolutionLevels(:,1);
            obj.Width = meta.ResolutionLevels(:,2);
            obj.IOBlockSize = meta.IOBlockSize;
            obj.PixelDatatype = meta.PixelDatatype;
            obj.Channels = meta.Channels;
            
            if isfield(meta, 'SpatialReferencing')
                obj.SpatialReferencing = meta.SpatialReferencing;
            end
            
            if isfield(meta, 'UnloadedValue')
                obj.UnloadedValue = meta.UnloadedValue;
            end
            
        end
        
        function meta = loadMetaData(obj)
            % Network latencies/race conditions could result in this
            % file entry being present, but contents not ready. This is
            % always temporary and will eventually settle.
            notLoaded = true;
            while notLoaded
                try
                    lstruct = load(fullfile(obj.DataSource,'description.mat'));
                    meta = lstruct.meta;
                    notLoaded = false;
                catch ALL %#ok<NASGU>
                end
            end
            
        end
    end
    
end

