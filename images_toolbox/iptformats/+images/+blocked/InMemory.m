classdef InMemory < images.blocked.Adapter           
    properties (Hidden)
        % 'Hidden' since blockedImage needs access to it while converting a
        % 'w' mode image to 'r' mode.
        % Cell array - one element per level
        Data(1,:) cell
    end
    
    properties(Access = private)
        Info(1,1) struct
        NumDimensions double
    end
    
    % Read methods
    methods
        function openToRead(obj, source)
            % source is numeric, logical, struct or categorical
            if iscell(source)
                obj.Data = source;
            else
                obj.Data{1} = source;
            end
            for lInd = 1:numel(obj.Data)
                obj.Info.Size(lInd,:) = size(obj.Data{lInd});
                % The 'smallest' unit is a single element, but since its all
                % in-memory, serving the whole image as one block is more
                % efficient.
                obj.Info.IOBlockSize(lInd,:) = size(obj.Data{lInd});
                obj.Info.Datatype(lInd) = string(class(obj.Data{lInd}));
            end
                        
            % Key off of first level only
            source = obj.Data{1};
            if isnumeric(source) || islogical(source)

                obj.Info.InitialValue = cast(0, 'like', source);
            elseif iscategorical(source)
                % <undefined> of the same 'type'.
                obj.Info.InitialValue = categorical(nan,...
                    1:numel(categories(source)), categories(source));
            elseif isstruct(source)
                % Initial value is a scalar stuct with the same
                % field names, but empty values.
                firstStructElem = source(1);
                fields = fieldnames(firstStructElem);
                structParams = cell(1,2*numel(fields));
                structParams(1:2:end) = fields;
                obj.Info.InitialValue = struct(structParams{:});
            else
                % Arbitrary, just pick the first element.
                obj.Info.InitialValue = source(1);
            end

            
            obj.Info.UserData = struct();
            obj.NumDimensions = size(obj.Info.Size,2);
        end
        
        function info = getInfo(obj)
            info = obj.Info;
        end
        
        function data = getIOBlock(obj, ioBlockSub, level)
            startSubs = (ioBlockSub-1).*obj.Info.IOBlockSize(level,:)+1;
            endSubs = startSubs + obj.Info.IOBlockSize(level,:) - 1;
            if any(startSubs>obj.Info.Size(level,:))
                % Out of bounds
                data = [];
            else
                data = obj.getRegion(startSubs, endSubs, level);
            end
        end
        
        function data = getRegion(obj, startSubs, endSubs, level)
            if all(startSubs==1,'all') && all(endSubs==obj.Info.Size,'all')
                % Default blocksize is full image, so an apply call with
                % the default will read the full image as a region/block
                data = obj.Data{level};
            else
                levelData = obj.Data{level};
                switch obj.NumDimensions
                    case 2
                        data = levelData(startSubs(1):endSubs(1),...
                            startSubs(2):endSubs(2));
                    case 3
                        data = levelData(startSubs(1):endSubs(1),...
                            startSubs(2):endSubs(2),...
                            startSubs(3):endSubs(3));
                    case 4
                        data = levelData(startSubs(1):endSubs(1),...
                            startSubs(2):endSubs(2),...
                            startSubs(3):endSubs(3),...
                            startSubs(4):endSubs(4));
                    otherwise
                        indStruct = obj.makeIndStruct(startSubs, endSubs);
                        data = subsref(levelData, indStruct);
                end
            end
        end
        
        function data = getFullImage(obj, level)
            data = obj.Data{level};
        end
    end
    
    % Write methods
    methods
        function openToWrite(obj, ~, info, ~)
            if isempty(obj.Data)
                % Initialize only once
                obj.Info = info;
                obj.NumDimensions = size(info.Size,2);
                for lInd = 1:size(obj.Info.Size,1)
                    obj.Data{lInd} = repmat(info.InitialValue, info.Size(lInd,:));
                end
            end
        end
        
        function setIOBlock(obj, ioBlockSub, level, data)
            startSubs = (ioBlockSub-1).*obj.Info.IOBlockSize(level,:)+1;
            
            % Add trailing 1's to data's size if needed. i.e make MxN a
            % MxNx1 in case the data is 3D.
            dataSize = size(data, 1:obj.NumDimensions);
            endSubs = startSubs + dataSize - 1;
            
            
            if all(startSubs==1,'all') && all(endSubs==obj.Info.Size(level,:),'all')
                obj.Data{level} = data;
            else
                levelData = obj.Data{level};
                obj.Data{level} = []; 
                switch obj.NumDimensions
                    case 2
                        levelData(startSubs(1):endSubs(1),...
                            startSubs(2):endSubs(2)) = data;
                    case 3
                        levelData(startSubs(1):endSubs(1),...
                            startSubs(2):endSubs(2),...
                            startSubs(3):endSubs(3)) = data;
                    case 4
                        levelData(startSubs(1):endSubs(1),...
                            startSubs(2):endSubs(2),...
                            startSubs(3):endSubs(3),...
                            startSubs(4):endSubs(4)) = data;
                    otherwise
                        indStruct = obj.makeIndStruct(startSubs, endSubs);
                        levelData = subsasgn(levelData, indStruct, data);
                end
                obj.Data{level} = levelData;
            end
        end
    end
    
    % Private helper methods
    methods (Access = private)
        function indStruct = makeIndStruct(obj, pixelStartSubs, pixelEndSubs)
            % Make index struct for subsref/asgn
            indStruct.type = '()';
            indStruct.subs = cell(1,obj.NumDimensions);
            for dInd = 1:obj.NumDimensions
                indStruct.subs{dInd} = pixelStartSubs(dInd):pixelEndSubs(dInd);
            end
        end
    end
end

%   Copyright 2020-2023 The MathWorks, Inc.
