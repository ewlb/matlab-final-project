function [im, alpha] = exrread(fileName, options)

    arguments
        fileName (1, 1) string { mustBeEXR(fileName) }
        
        options.Channels  { mustBeA(options.Channels, ["char", "string", "cell"]), ...
                            mustBeValidChannelNames(options.Channels) } = string.empty()

        options.PartIdentifier (1, :) { mustBeA( options.PartIdentifier, ...
                                            ["char", "string", "numeric"]), ...
                                        mustBeValidPartID(options.PartIdentifier) } = 1
    end

    channelNames = string(options.Channels);
    if ~isempty(channelNames) && any(channelNames == "")
        error(message("images:exrfileio:ChannelNamesNonEmpty"));
    end

    partID = options.PartIdentifier;

    fullFileName = images.internal.io.absolutePathForReading(fileName);

    % Get only top-level and channel information about the file
    info = images.internal.builtins.exrinfo(fullFileName, true);

    % Validate non-default Part ID specified
    partID = convertCharsToStrings(partID);
    isNonDefaultPartID =  (isnumeric(partID) && partID ~= 1) || ...
                          (isstring(partID) && ~isempty(partID));
        
    if isNonDefaultPartID
        if isnumeric(partID)
            % User has supplied the part ID as a number. This ability is
            % needed because it is not mandatory for a part to have a name
            % property or for parts to have unique names.

            % Validate the partID supplied is within bounds
            if partID > numel(info)
                error(message("images:exrfileio:PartIDInvalid", numel(info)));
            end
        else
            % Indicates part ID was specified using a name
            partIDName = partID;
            partID = find([info.PartName] == partID, 1);
            if isempty(partID)
                error(message("images:exrfileio:PartNameNotFound", partIDName));
            end

            % Not necessary for parts to have unique names.
            if ~isscalar(partID)
                error(message("images:exrfileio:PartNameNotUnique", partIDName));
            end
        end
    else
        partID = 1;
    end

    % This flag is used to determine if the specified part contains YUV
    % data that needs to be converted to RGB.
    isConvertYUV2RGB = false;
    isReadAlpha = false;

    % Validate the channel name specified
    if ~isempty(channelNames)
        % If the user has specified channel names to read, ensure they are
        % present in the specified part.
        channelNamesInPart = [info(partID).ChannelInfo.Name];
        if ~all(ismember(channelNames, channelNamesInPart))
            error(message("images:exrfileio:ChannelNameNotFound", partID));
        end
        chansToRead = channelNames;
    else
        % User has not specified the channel name.
        % The behaviour in this case is to search the specified part for
        % an image to read in the order RGB > YUV > Y. Typically, any part
        % in an EXR file contains either RGB, YUV or Y image data and
        % optionally an A channel. If all these channels are present in a
        % part, then the priority order above will be used.
        % If the part contains only "Y" or "Y" and "A", then do not
        % convert to RGB.
        channelInfo = info(partID).ChannelInfo;

        if isChannelsPresent(["R", "G", "B"], channelInfo)
            chansToRead = ["R", "G", "B"];
        elseif isChannelsPresent(["Y", "RY", "BY"], channelInfo)
            chansToRead = string.empty();
            isConvertYUV2RGB = true;
        elseif isChannelsPresent("Y", channelInfo)
            chansToRead = "Y";
        else
            error(message("images:exrfileio:InvalidImageInPart", partID));
        end

        isReadAlpha = isChannelsPresent("A", channelInfo);
    end

    % This will hopefully be a temporary situation.
    if isConvertYUV2RGB && (partID > 1)
        error(message("images::exrfileio:YUV2RGBUnsupported"));
    end

    [imageData, alphaData] = ...
            images.internal.builtins.exrread( fullFileName, ...
                                              cellstr(chansToRead), ...
                                              partID - 1, ...
                                              isConvertYUV2RGB, ...
                                              isReadAlpha );

    % The data read in is in row-major order. These need to be permuted
    % suitably. 
    im = squeeze(permute(imageData, [3 2 1]));
    alpha = squeeze(permute(alphaData, [3 2 1]));

    % If the image data was read after converting YUV2RGB, the the Alpha
    % channel data is part of the imageData and needs to be separated.
    if isConvertYUV2RGB
        if isReadAlpha
            alpha = im(:, :, 4);
        end
        im = im(:, :, 1:3);
    end
end

function mustBeValidChannelNames(channels)
    % Channels can be character vector, string scalar, string vector or a
    % cellstr vector

    if isempty(channels)
        return;
    end

    validateattributes(channels, ["char", "string", "cell"], "vector");

    if iscell(channels)
        if ~iscellstr(convertContainedStringsToChars(channels))
            error(message("images:exrfileio:ChannelNamesCellStr"));
        end
    end

    if ischar(channels)
        validateattributes(channels, "char", "row");
    end
end

function mustBeValidPartID(partID)
    % PartID can be a string scalar, character vector or a numeric scalar

    validateattributes(partID, {'char', 'string', 'numeric'}, {});

    if isnumeric(partID)
        validateattributes(partID, {'numeric'}, {'scalar', 'integer', 'positive', 'finite'});
    else
        validateattributes(partID, {'char', 'string'}, {'scalartext'});
    end
    
end

function tf = isChannelsPresent(chanNamesToTest, chanInfo)
% Helper function that checks whether the specified channels are present in
% the expected set of channels. 
    chanNamesInPart = [chanInfo.Name];
    tf = all(ismember(chanNamesToTest, chanNamesInPart));
end

% Copyright 2022 The MathWorks, Inc.
