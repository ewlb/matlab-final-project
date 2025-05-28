classdef DirOfBlockFiles <images.blocked.Adapter
    
    % Common methods for all shipping adapters which store one block in one
    % file.
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties (Access = protected)
        Location(1,1) string
        Info(1,1) struct
        % Must include '.'        
        BlockFileExtension(1,1) string
    end
    
    methods
        function openToRead(obj, srcFolder)
            obj.Location = string(srcFolder);
            
            % This format saves description information in a mat file in
            % the folder. Load it
            descFile = fullfile(srcFolder,'description.mat');
            if ~isfile(descFile)
                error(message('images:blockedImage:invalidSourceFolder', srcFolder))
            end
            
            desc = images.blocked.internal.loadDescription(srcFolder);
            if ~isa(obj, class(desc.Adapter))
                error(message('images:blockedImage:incompatibleSource', srcFolder, class(obj)))
            end
            
            if ~isfield(desc,'Adapter') || ~isa(desc.Adapter,'images.blocked.Adapter')
                error(message('images:blockedImage:invalidDescription', srcFolder))
            end
            
            obj.Info = desc.Info;
        end
        
        function info = getInfo(obj)
            info = obj.Info;
        end
        
        function openInParallelToAppend(obj, dstFolder)
            % Same implementation as read above, load info data from the
            % existing destination.
            obj.openToRead(dstFolder);
        end
        
        function openToWrite(obj, dstFolder, info, ~)
            obj.Location = dstFolder;
            obj.Info = info;
            images.blocked.internal.createFolder(dstFolder);
            
            description.Info = info;
            description.Adapter = obj;
            
            % Save updated description
            descFile = fullfile(obj.Location,'description.mat');
            save(descFile,'-struct','description');                        
            
            % Create the level specific folders
            for level = 1:size(info.Size,1)
                lvlFolder = fullfile(dstFolder, ['L', num2str(level)]);
                images.blocked.internal.createFolder(lvlFolder);
            end
        end
        
        function ioBlockSubs = alreadyWritten(obj, level)        
            % Create a list of existing files            
            dummyBlockSub = 0;
            destLocation = char(images.blocked.internal.baseBlockFileName(obj.Location, level,dummyBlockSub));
            % Remove the dummy block sub to get the destination folder with
            % the level sub folder.
            destLocation = destLocation(1:end-1);
            existingFiles = dir([destLocation, '*' char(obj.BlockFileExtension)]);
                        
            if isempty(existingFiles)
                ioBlockSubs = [];
            else
                % Extract blocksubs from the existing file names
                fileNames = {existingFiles.name}';
                ioBlockSubStrings = strrep(fileNames,obj.BlockFileExtension,'');
                ioBlockSubs = cellfun(@(str) str2double(strsplit(str, '_')),...
                    ioBlockSubStrings,'UniformOutput', false);
                % Files which dont match the above scheme show up as nans
                validFiles = ~cellfun(@(x)any(isnan(x)),ioBlockSubs);
                ioBlockSubs = cell2mat(ioBlockSubs(validFiles));
            end
        end
    end    
end