classdef ImageLoader < matlab.mixin.SetGetExactNames
% Abstract Helper base class that supports loading an image from the
% suitable source. This supports reading multi-page sources

%   Copyright 2023 The MathWorks, Inc.


    properties(Access=public, Dependent)
        CurrImageIndex (1, 1) double
    end

    properties(GetAccess=public, SetAccess=private)
        % Information that is used in the Image Info Display. This can be
        % computed when the loader is created or updated to improve
        % performance.
        LoadedImageInfo
    end

    properties(GetAccess=public, SetAccess=protected)
        MaxNumFrames (1, 1) double = 1
        ImageSrcName (1, 1) string = ""
        ImageInfo    (:, 1) struct = struct()
    end

    % Manage any modifications made to the frames read from the source. 
    properties(SetAccess=private, GetAccess=protected)
        % Maps Frame Index -> Modified Frame
        ModifiedFrames = dictionary([], {});

        % Maps Frame Index -> Dictionary Containing metadata for crop and
        % contrast
        ModificationMethod = dictionary([], {});
    end

    properties(Access=private)
        CurrImageIndexInternal (1, 1) double = 1
    end

    methods
        function obj = ImageLoader(srcName)
            obj.ImageSrcName = srcName;
        end
    end

    % Setters
    methods
        function set.CurrImageIndex(obj, val)
            mustBePositive(val);
            mustBeLessThanOrEqual(val, obj.MaxNumFrames);

            obj.CurrImageIndexInternal = val;
        end

        function val = get.CurrImageIndex(obj)
            val = obj.CurrImageIndexInternal;
        end
    end

    methods(Access=public)
        function [im, cmap] = readImage(obj)
            % Read the current image frame from the source

            if isKey(obj.ModifiedFrames, obj.CurrImageIndex)
                % If the current frame has been modified, do not read it
                % directly from the source.
                [im, cmap] = deal(obj.ModifiedFrames{obj.CurrImageIndex}{:});
            else
                [im, cmap] = readImageImpl(obj);
            end
        end

        function updateImage(obj, im, cmap, options)
            % Update the current frame due to a modification made

            arguments
                obj (1, 1) images.internal.app.viewer.ImageLoader
                im
                cmap (:, 3) double
                options.Modification (1, 1) string { ...
                            mustBeMember( options.Modification, ...
                                            ["Crop", "Contrast"] ) }
                options.ModificationInfo = []
            end

            modMethod = options.Modification;
            modInfo = options.ModificationInfo;

            % Store the data in the last modification made to the frame
            currIndex = obj.CurrImageIndexInternal;
            obj.ModifiedFrames(currIndex) = {{im, cmap}};

            % Store the modification method along with any modification
            % metadata that is needed
            if isKey(obj.ModificationMethod, currIndex)
                % Currently storing only the last crop and contrast
                % operation performed on the image frame
                
                currFrameMods = obj.ModificationMethod{currIndex};

                % If the contrast range specified is NaN, it indicates the
                % contrast has been undone. Remove the entry
                if modMethod == "Contrast" && any(isnan(modInfo))
                    currFrameMods(modMethod) = [];
                else
                    currFrameMods(modMethod) = {modInfo};
                end

                obj.ModificationMethod{currIndex} = currFrameMods;
            else
                currMod = dictionary(modMethod, {modInfo});
                obj.ModificationMethod{currIndex} = currMod;
            end

            createLoadedImageInfo(obj);
        end
    end

    methods(Access=public, Static)
        function loader = create(imageSource, options)
            arguments
                imageSource
                options.Colormap (:, 3)
                options.SrcVarName (1, 1) string
            end
            if isnumeric(imageSource) || islogical(imageSource)
                if ~isfield(options, "Colormap")
                    options.Colormap =  zeros(0, 3, "double");
                end
                if ~isfield(options, "SrcVarName")
                    options.SrcVarName = "";
                end
                loader = images.internal.app.viewer.WorkspaceImageLoader( imageSource, ...
                                Colormap=options.Colormap, ...
                                SrcVarName=options.SrcVarName );
            elseif ischar(imageSource) || isstring(imageSource)
                if isfield(options, "Colormap") || isfield(options, "SrcVarName")
                    % Assert is sufficient as this will be called by
                    % internal code
                    assert(false, "These are not applicable for file sources");
                end
                loader = images.internal.app.viewer.FileImageLoader(imageSource);
            else
                assert(false, "Invalid Image Source");
            end
        end
    end

    methods(Abstract)
        isHDR = isHDRImagery(obj);
    end

    methods(Abstract, Access=protected)
        [type, name, info] = getInfoImpl(obj);
        [im, cmap] = readImageImpl(obj);
    end

    methods(Access=protected, Sealed)
        function createLoadedImageInfo(obj)
            % Create the information about the current frame
            
            [type, name, info] = getInfoImpl(obj);

            currIndex = obj.CurrImageIndexInternal;

            if isKey(obj.ModificationMethod, currIndex)
                modMethods = keys(obj.ModificationMethod{currIndex});
            else
                modMethods = string.empty();
            end

            obj.LoadedImageInfo = ...
                        images.internal.app.viewer.SrcImageInfo( ...
                                                type, name, info, ...
                                                currIndex, ...
                                                obj.MaxNumFrames, ...
                                                modMethods );
        end
    end
end
