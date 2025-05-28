classdef GenericImageBlocks < images.blocked.internal.DirOfBlockFiles
    %GenericImageBlocks - Store each block as an image file in a folder
    % ADAPTER = images.blocked.GenericImageBlocks() creates an
    % images.blocked.Adapter instance for use in blockedImage functions.
    % Use this adapter to save an image in a folder with individual
    % files per block. Image is stored in a folder which contains a .mat
    % file with information about the image (including image size,
    % blocksize, type). This top level folder has one subfolder per
    % resolution level (L1, L2..LN). These subfolders contain image
    % format files for each block. The file format used must be one that is
    % supported by imwrite.
    % Default file format is "png".
    %
    % GenericImageBlocks properties
    %   BlockFormat - Image file format for each block of data
    %
    % Data supported:
    %   Restricted to the format chosen. See section for chosen format in
    %   imwrite for more detail.
    %   This adapter supports multiple resolutions (levels).
    %
    % blockedImage/apply support:
    %   Supports "UseParallel"   - Yes
    %   Supports "Resume"        - Yes
    %
    % Example 1
    % ---------
    % % Save image data in a folder with one TIFF file per block
    %   bim = blockedImage('tumor_091R.tif');
    %   wa = images.blocked.GenericImageBlocks();
    %   wa.BlockFormat = "tif";
    %   write(bim, "dirOfTIFFs", "Adapter", wa);
    %   % blockedImage automatically picks the right adapter:
    %   bt = blockedImage("dirOfTIFFs");
    %
    % See also images.blocked.Adapter, blockedImage, imwrite, imread
    
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties (Dependent)
        %BlockFormat Image file format for each block of data
        %  A scalar string specifying the image file format for each block
        %  of data. This is represented by the file extension string that
        %  IMREAD and IMWRITE support. See output of IMFORMATS.
        %  Default value is "png".
        BlockFormat(1,1) string
    end
    
    properties (Hidden)
        WriteArguments (1,:) cell
    end
    
    % get/set
    methods
        function fmt = get.BlockFormat(obj)
            % skip the .
            fmt = extractAfter(obj.BlockFileExtension,1);
        end
        function set.BlockFormat(obj, fmt)
            arguments
                obj (1,1) images.blocked.GenericImageBlocks
                fmt (1,1) string
            end
            
            if isa(obj, 'images.blocked.JPEGBlocks')
                if ~(strcmp(fmt, 'jpg')||strcmp(fmt, 'jpeg'))
                    error(message('images:blockedImage:cantChangeExtension'))
                end
            elseif isa(obj, 'images.blocked.PNGBlocks')
                if ~strcmp(fmt, 'png')
                    error(message('images:blockedImage:cantChangeExtension'))
                end
            end
            
            % Validate against registered formats
            fmts = imformats();
            extCells = cat(2,fmts.ext);
            if ~any(strcmp(fmt, extCells(:)))
                error(message('images:blockedImage:unsupportedFormat', fmt))
            end
            obj.BlockFileExtension = "." +fmt;
        end
    end
    
    % Read methods
    methods
        
        function obj = GenericImageBlocks()
            if isa(obj, 'images.blocked.JPEGBlocks')
                obj.BlockFormat = 'jpeg';
            else
                obj.BlockFormat = 'png';
            end
        end
        
        function data = getIOBlock(obj, ioBlockSub, level)
            blockFileName = images.blocked.internal.baseBlockFileName(obj.Location,level, ioBlockSub) + obj.BlockFileExtension;
            if isfile(blockFileName)
                data = imread(blockFileName);
            else
                data = [];
            end
        end
    end
    
    % Write methods
    methods
        function openToWrite(obj, dstFolder, info, level)
            for lInd = 1:size(info.Size,1)
                isLogicalMN = info.Datatype(lInd)=="logical" && size(info.IOBlockSize(lInd,:),2)==2;
                isUint8MNOrMNP = info.Datatype(lInd)=="uint8" ...
                    && (size(info.IOBlockSize(lInd,:),2)==2 ...
                        || size(info.IOBlockSize(lInd,:),2)==3  &&  (info.IOBlockSize(lInd,3)==3||info.IOBlockSize(lInd,3)==1));
                if ~(isLogicalMN || isUint8MNOrMNP)
                    error(message('images:blockedImage:onlyGrayOrRGB'))
                end
            end
            
            if ~any(strcmp(class(info.InitialValue), images.internal.iptlogicalnumerictypes))
                error(message('images:blockedImage:unsupportedByAdapter', class(obj), class(info.InitialValue)))
            end
            openToWrite@images.blocked.internal.DirOfBlockFiles(obj, dstFolder, info, level);
        end
        
        function setIOBlock(obj, ioBlockSub, level, data)
            fileName = images.blocked.internal.baseBlockFileName(obj.Location, level, ioBlockSub) + obj.BlockFileExtension;
            imwrite(data, fileName, obj.WriteArguments{:});
        end
    end
    
end
