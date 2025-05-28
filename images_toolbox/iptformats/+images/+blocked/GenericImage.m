classdef GenericImage < images.blocked.Adapter
    %GenericImage - Store blocks in a single image file
    % ADAPTER = images.blocked.GenericImage() creates an
    % images.blocked.Adapter instances for use in blockedImage functions.
    % Use this adapter to read and store an image as a single block in a
    % single image file. Additional information in UserData, if any, is
    % stored alongside in a .mat file with the same file name.
    %
    % images.Blocked.GenericImage properties:
    %   Extension - The preferred file extension
    %
    % Note: All data is read/written as a single IO block. The blockedImage
    % interface can still provide blocked read access to this image by
    % using a smaller BlockSize, but the image, in-full, is loaded into
    % main memory in the background.
    %
    % Data supported:
    %   logical or uint8 MxN.
    %   uint8 MxNx3.
    %   This adapter does not support multiple resolutions (levels).
    %
    % blockedImage/apply support:
    %   Supports "UseParallel"   - No
    %   Supports "Resume"        - Limited. Only useful when processing an
    %                              array of blockedImages
    %
    % Example 1
    % ---------
    % % Save a single level image data in a single PNG file
    %   bim = blockedImage('tumor_091R.tif');
    %   wa = images.blocked.GenericImage();
    %   write(bim, "L3.png", "Adapter", wa, "Levels", 3);
    %   % blockedImage automatically picks the right adapter:
    %   bgi = blockedImage("L3.png");
    %
    % See also images.blocked.Adapter, blockedImage
    
    %   Copyright 2020-2021 The MathWorks, Inc.
    
    
    properties
        %Extension The preferred file extension
        % A scalar string specifying the preferred extension for
        % this adapter. blockedImage/apply uses this when creating the
        % output locations automatically.
        % Default value is "png"
        Extension (1,1) string = "png"
    end
    
    properties (Hidden, Dependent)
        % Added for backwards compatibility.
        Format (1,1) string
    end
    
    properties (SetAccess = protected, GetAccess = public)
        FileName(1,1) string
    end
    
    properties (Access = private)
        Info(1,1) struct
    end
    
    % Read methods
    methods
        function openToRead(obj, fileName)
            obj.FileName = fileName;
        end
        
        function info = getInfo(obj)
            % Load the sidecar .mat file if present
            desc = images.blocked.internal.loadDescription(obj.FileName);
            if isfield(desc, 'Info')
                info = desc.Info;
                return
            end
            
            % Else, query file
            try
                if endsWith(obj.FileName, '.jpg')||endsWith(obj.FileName, '.jpeg')
                    baseline_only = true;
                    finfo = matlab.io.internal.imagesci.imjpginfo(obj.FileName, baseline_only);
                elseif endsWith(obj.FileName, '.png')
                    resilient = true;
                    finfo = matlab.internal.imagesci.pnginfoc(char(obj.FileName),resilient);
                else
                    finfo = imfinfo(obj.FileName);
                end
            catch ME
                if isequal(ME.identifier, 'MATLAB:imagesci:imfinfo:whatFormat')
                    % Better error for files with content unsupported by
                    % imfinfo:
                    error(message('images:blockedImage:unsupportedEXT', obj.FileName));
                else
                    rethrow(ME)
                end
            end
            
            if numel(finfo)>1
                error(message('images:blockedImage:singleResolutionOnly'));
            end
            
            info.Size = [finfo.Height, finfo.Width];
            
            if finfo.BitDepth == 8
                info.Datatype = "uint8";
            elseif finfo.BitDepth == 24
                info.Datatype = "uint8";
                % uint8 RGB
                info.Size(3) = 3;
            elseif finfo.BitDepth == 1
                info.Datatype = "logical";
            else
                error(message('images:blockedImage:unsupportedMeta', obj.FileName));
            end
            
            % Full image in a single block.
            info.IOBlockSize = info.Size;
            info.InitialValue = cast(0, info.Datatype);
        end
        
        function data = getIOBlock(obj, ioBlockSub, ~)
            if ~all(ioBlockSub==1)
                error(message('images:blockedImage:singleBlockOnly'))
            end
            data = imread(obj.FileName);
        end
    end
    
    % Write methods
    methods
        function openToWrite(obj, fileName, info, ~)
            isMulti = size(info.Size,1)>1;
            if isMulti
                error(message('images:blockedImage:onlySingleResolutionGrayOrRGB'))
            end
            
            isLogicalMN = info.Datatype=="logical" && size(info.Size,2)==2;
            isUint8MNOrMNP = info.Datatype=="uint8" && (size(info.Size,2)==2 || size(info.Size,2)==3&&info.Size(3)==3);
            if ~(isLogicalMN || isUint8MNOrMNP)
                error(message('images:blockedImage:onlySingleResolutionGrayOrRGB'))
            end
            
            loc = fileparts(char(fileName));
            images.blocked.internal.createFolder(loc);
            
            obj.FileName = fileName;
            obj.Info = info;
            
            desc.Info = info;
            desc.Adapter = obj;
            images.blocked.internal.saveDescription(obj.FileName, desc);
        end
        
        function setIOBlock(obj, ioBlockSub, ~, data)
            if ~all(ioBlockSub==1)
                error(message('images:blockedImage:singleBlockOnly'))
            end
            imwrite(data, obj.FileName);
        end
        
        function ioBlockSubs = alreadyWritten(obj, ~)
            ioBlockSubs = [];
            if isfile(obj.FileName)
                % This data format has all data in a single block stored in
                % a single file.
                ioBlockSubs = ones(1, size(obj.Info.Size,2));
            end
        end
    end
    
    methods
        function set.Format(obj, format)
            obj.Extension = format;
        end
        function format = get.Format(obj)
            format = obj.Extension;
        end
    end
    
end
