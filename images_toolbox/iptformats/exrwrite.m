function exrwrite(im, fileName, options)

    arguments
        im { mustBeA(im, ["numeric", "cell"]), mustBeValidImageData(im) }

        fileName (1, 1) string { mustBeA(fileName, ["char", "string"]), ...
                                 mustHaveValidExtension(fileName) }

        options.AppendToFile (1, 1) logical = false

        options.Channels { mustBeA(options.Channels, ["char", "string", "cell"]), ...
                           mustBeValidChannelNames(options.Channels, im) } = computeDefaultChannels(im)

        options.OutputType { mustBeA(options.OutputType, ["char", "string", "cell"]), ...
                              mustBeValidOutputType(options.OutputType, im) } = "half"

        options.Alpha (:, :) { mustBeNumeric(options.Alpha), ...
                               mustBeValidAlpha(options.Alpha, im) }

        options.DisplayWindow (1, 4) double { mustBeInteger, ...
                                              mustBeValidWindow( options.DisplayWindow, ...
                                                                 "DisplayWindow" ) } = computeWindowSize(im)

        options.DataWindow (1, 4) double { mustBeInteger, ...
                                           mustBeValidWindow(options.DataWindow, "DataWindow"), ...
                                           mustBeValidDataWindow(options.DataWindow, im) } = computeWindowSize(im)

        options.TileDimensions (1, 2) double { mustBeInteger, ...
                                               mustBePositive, ...
                                               mustBeValidTileDims(options.TileDimensions, im) }
                                            
        options.LineOrder (1, 1) string = "TopDown"

        options.Compression (1, 1) string = "ZIP"
        
        options.PartName (1, 1) string { mustBeA(options.PartName, ["char", "string"]) } = ""

        options.ViewName (1, 1) string { mustBeA(options.ViewName, ["char", "string"]) } = ""

        options.Attributes (1, 1) struct
    end

    options.Channels = string(options.Channels);
    options.OutputType = string(options.OutputType);
    if (numel(options.OutputType) ~= 1) && ...
        (numel(options.OutputType) ~= numel(options.Channels))
        error(message("images:exrfileio:NumChannelTypesMismatch"));
    end
    
    % Partial values and non-exact case support is required for the
    % name-value pair values. Hence, using validatestring outside the
    % arguments block to validate the values supplied. The Name validation
    % is automatically done.
    options.LineOrder = validatestring(options.LineOrder, ["TopDown", "BottomUp"]);
    options.Compression = validatestring( options.Compression, ...
                                            [ "None", "RLE", "ZIPS", ...
                                              "ZIP", "PIZ", "PXR24", ...
                                              "B44", "B44A", "DWAA", ...
                                              "DWAB" ] );

    if options.AppendToFile
        [srcLoc, targetLoc] = configureForAppend(fileName);
    else
        srcLoc = "";
        targetLoc = fileName;
    end

    % EXR Library APIs when called from MATLAB do not work as expected when
    % the path specified starts with "~". See g2688734 for details. Adding
    % code to resolve the full path.
    if ~ispc && startsWith(targetLoc, "~")
        targetLoc = resolveHomeDir(targetLoc);
    end

    isTrulyAppend = srcLoc ~= "";

    % Cleanup function to delete the temporary file in the event of any
    % error.
    removeTempFileFcn = onCleanup( @() removeTempFileIfAppend(srcLoc) );

    % Alpha name-value pair cannot be supplied in conjunction with a
    % channel list containing the "A" channel
    if isfield(options, "Alpha")
        % Alpha channel specified by the user
        if any(contains(options.Channels, "A"))
            error(message("images:exrfileio:NoAlphaIfChanListContainsA"));
        end
    else
        options.Alpha = zeros(0, 0, "single");
    end

    if ~isfield(options, "TileDimensions")
        options.TileDimensions = [];
    end

    % Certain properties such as Chromaticities have been post processed in
    % MATLAB and converted to a format different than returned by the
    % builtin. These need to be restored before calling the builtin due to
    % the lack of C++ APIs.
    if isfield(options, "Attributes")
        options.Attributes = preprocessAttribs(options.Attributes);
        options.Attributes = convertContainedStringsToChars(options.Attributes);
    else
        options.Attributes = struct.empty();
    end

    numChannels = computeNumChannels(im);

    % Ensure the channel type is specified for each channel before passing
    % it to the builtin to make the code simpler.
    if isscalar(options.OutputType)
        options.OutputType = repmat(options.OutputType, [numChannels, 1]);
    end

    % Determine the sub-sampling factors. This value must be provided for
    % every channel being written.
    if iscell(im) && ~isscalar(im)
        subSamplingFactor = zeros(numChannels, 2);

        subSamplingFactor(1, :) = [1 1];

        subSamplingFactor(2:end, :) = ...
                    repmat(size(im{1}) ./ size(im{2}), [numChannels-1 1]);
    else
        subSamplingFactor = [];
    end

    % Convert image data to row-major order before writing
    im = convertInputImageDataForWriting(im, options.OutputType);
    options.Alpha = convertInputImageDataForWriting(options.Alpha, "half");

    try
        % Call to the builtin here
        images.internal.builtins.exrwrite( srcLoc, targetLoc, fileName, ...
                                    im, options.Alpha, ...
                                    options.Channels, ...
                                    options.OutputType, ...
                                    options.DisplayWindow, options.DataWindow, ...
                                    subSamplingFactor, ...
                                    options.TileDimensions, ...
                                    options.LineOrder == "TopDown", ...
                                    options.Compression, ...
                                    options.PartName, options.ViewName, ...
                                    options.Attributes );

        % If an append operation is actually happening, copy the written
        % file to the actual output location
        if isTrulyAppend
            movefile(targetLoc, fileName);
        end
    catch ME
        % The existing file might be been corrupted due to the error.
        % Hence, restore the existing file.
        if isTrulyAppend
            copyfile(srcLoc, fileName);

            % Delete the target file if it was created
            if exist(targetLoc, "file") == 2
                delete(targetLoc);
            end
        end
        rethrow(ME);
    end

end

function mustBeValidImageData(im)

    % Validation function for the image data input supplied by the user
    % IM can be:
    % 1. MxNxP numeric array OR
    % 2. P-element cell vector containing 2D numeric matrices
    % where where P can be 1 or 3 or numel(channels). 

    if iscell(im)
        if ~isvector(im)
            error(message("images:exrfileio:CellInputsMustBeVectorOfNumericNonEmptyMatrix"));
        end

        % Ensure that each element of the cell array is 2D, numeric matrix
        isValid2D = cellfun(@(x) isnumeric(x) && ismatrix(x) && ~isempty(x), im);
        if ~all(isValid2D)
            error(message("images:exrfileio:CellInputsMustBeVectorOfNumericNonEmptyMatrix"));
        end

        isHalf = cellfun(@(x) isa(x, 'half'), im);
        if any(isHalf)
            error(message("images:exrfileio:HalfTypeInputsNotSupported"));
        end

        % If cell array of matrices are provided, the following constraints
        % hold:
        % 1. All matrices must have the same dimensions. This implies no
        % subsampling
        % 2. Matrices in elements 2:end must have same dimensions. They can
        % differ from element 1 by an integer factor to indicate subsampled
        % channels.
        if numel(im) > 1
            % Enforce constraint (2) above
            cellfun( @(x) isequal(size(im{2}), size(x)), im(2:end) );

            subSamplingFactor = size(im{1}) ./ size(im{2});
            if ~isequal(floor(subSamplingFactor), subSamplingFactor)
                error(message("images:exrfileio:XYSubSamplingNonIntegral"));
            end
        end
    else
        % Must be numeric.
        validateattributes(im, "numeric", ["nonempty", "3d"]);
        if isa(im, "half")
            error(message("images:exrfileio:HalfTypeInputsNotSupported"));
        end
    end
end

function mustHaveValidExtension(fileName)
    % Helper function to ensure that filename has a valid extension

    if fileName == ""
        error(message("images:exrfileio:FileNameEmpty"));
    end

    if ~endsWith(fileName, ".exr")
        error(message("images:exrfileio:FileNameUnsupportedExtn"));
    end
end

function mustBeValidChannelNames(channelNames, im)
    % Helper function that validates the channel names provided by the user

    if iscell(im)
        numChannelsInData = numel(im);
    else
        numChannelsInData = size(im, 3);
    end

    % If channel names are not specified by the user, then either RGB or
    % Grayscale image is written to the file depending upon the number of
    % channels in the input.
    if isempty(channelNames)
        if ~ismember(numChannelsInData, [1 3])
            error(message("images:exrfileio:DefaultImageMustBeRGBOrGray"));
        end
        return;
    end

    images.internal.openexr.mustBeListOfStrings(channelNames);

    chNames = string(convertContainedStringsToChars(channelNames));

    if any(chNames == "")
        error(message("images:exrfileio:ChannelNamesNonEmpty"));
    end

    if ~isequal(unique(chNames, "rows", "stable"), chNames)
        error(message("images:exrfileio:ChannelNamesMustBeUnique"));
    end

    if numChannelsInData ~= numel(chNames)
        error(message("images:exrfileio:NumChannelsMismatchWithData"));
    end
end

function mustBeValidOutputType(outputType, im)
    % Helper function that validates the channel datatypes requested to be
    % written to the file.

    images.internal.openexr.mustBeListOfStrings(outputType);

    outputType = string( convertContainedStringsToChars(outputType) );

    % If the input image is numeric, then user must specify the same
    % datatype to write for all channels
    if isnumeric(im)
        if ~isscalar(outputType) || any(outputType ~= outputType(1))
            error(message("images:exrfileio:NumericInputsAllChannelTypesNotSame"));
        end
    end

    mustBeMember( string(convertContainedStringsToChars(outputType)),...
                  ["half", "uint32", "single"] );
end

function mustBeValidAlpha(alpha, im)
    if iscell(im)
        localim = im{1};
    else
        localim = im;
    end

    if ~isequal(size(alpha), size(localim, [1 2]))
        error(message("images:exrfileio:AlphaChannelIncorrectDimensions"));
    end
end

function mustBeValidWindow(win, winType)
    % Helper function that ensures the display and/or data window are valid

    if win(3) < win(1)
        error(message("images:exrfileio:InvalidWindowLimits", winType, "X"));
    end

    if win(4) < win(2)
        error(message("images:exrfileio:InvalidWindowLimits", winType, "Y"));
    end
end

function mustBeValidDataWindow(dataWin, im)
    % Helper function that ensures the data window dimensions provided by
    % the user matches the height and width of the image data provided.

    dataWinWidth = dataWin(3) - dataWin(1) + 1;
    dataWinHeight = dataWin(4) - dataWin(2) + 1;

    if iscell(im)
        localim = im{1};
    else
        localim = im;
    end

    if (dataWinWidth ~= size(localim, 2)) || ...
            (dataWinHeight ~= size(localim, 1))
        error(message("images:exrfileio:DataWindowIncorrectSize"));
    end
end

function mustBeValidTileDims(tileDims, im)
    % Helper function to validate the tile dimensions specified

    if iscell(im)
        localim = im{1};
    else
        localim = im;
    end

    [height, width] = size(localim, [1 2]);

    if tileDims(2) > height || tileDims(1) > width
        error(message("images:exrfileio:TileDimensionsIncorrect"));
    end
end

function channels = computeDefaultChannels(im)
    % Compute the default channel names that will be written to the file if
    % not supplied by the user

    numChannels = computeNumChannels(im);

    switch(numChannels)
        case 1
            channels = "Y";
        case 3
            channels = ["R"; "G"; "B"];
        otherwise
            % Users must provide the channel list in this case. This will
            % be handled in the validator.
            channels = string.empty();
    end

end

function out = computeWindowSize(im)
    % Helper function that computes the default data and display windows if
    % the user does not supply one.

    if iscell(im)
        localim = im{1};
    else
        localim = im;
    end
    out = [ 0 0 size(localim, 2)-1 size(localim, 1)-1 ];
end

function [srcLoc, targetLoc] = configureForAppend(origFileName)
    % Helper function that configures the source and target file locations
    % when append mode is requested.

    % If append is requested, confirm if the file already exists. If not,
    % create the file which means it is not truly append mode
    
    % Read permissions are needed even when appending to the file. The
    % OpenEXR library does not have an "append" mode. We are simulating an
    % append operation by rewriting the contents of the existing file into
    % a new multipart file and adding the data currently provided by the
    % user.
    fp = fopen(origFileName, "r");
    if fp == -1
        % Indicates that file with origFileName does not exist. This means
        % a new file has to be created. Hence, there is no append operation
        % to be performed.
        srcLoc = "";
        targetLoc = origFileName;
        return;
    end

    % FOPEN opens files anywhere on the path. However, for writing, we do
    % not write to files anywhere on the path. We expect the user to
    % specify the full or relative path from PWD. The check below is to
    % ensure the file opened by FOPEN is the one specified.
    computedFullFileName = string(fopen(fp));
    fclose(fp);

    % Obtain the full path to the original file name provided by the user.
    [~, fa] = fileattrib(origFileName);
    
    if fa.Name ~= computedFullFileName
        % Indicates that file with origFileName does not exist. This means
        % a new file has to be created. Hence, there is no append operation
        % to be performed.
        srcLoc = "";
        targetLoc = origFileName;
        return;
    end

    % Confirm the file being appended to is a valid EXR file
    if ~isexr(origFileName)
        error(message("images:exrfileio:InvalidEXRFile"));
    end

    % Copy the original file to the tempdir. Additionally, write out the
    % new file to tempdir. Once the file writing is complete, copy to the
    % target location. This appears to give the best performance during
    % append operation.
    [origPath, origNameOnly, origExt] = fileparts(string(fa.Name));
    srcLoc = fullfile(origPath, origNameOnly + "_copy" + origExt);
    targetLoc = fullfile(tempdir, origNameOnly + "_work" + origExt);

    try
        movefile(origFileName, srcLoc);
    catch
        % Guard against lack of diskspace or some other unforseen event
        error(message("images:exrfileio:UnableToCreateCopyToAppend"));
    end
end

function removeTempFileIfAppend(fileName)
    % Cleanup function that deletes the temporary file that is created when
    % append mode is requested

    % Append operation is not being performed
    if fileName == ""
        return;
    end

    delete(fileName);
end

function out = preprocessAttribs(in)
    % Helper function that undoes the post-processing done by exrinfo to
    % the attributes read from the file. Reason for this is that many
    % constructs such as table/date-time do not have C++ APIs.

    out = in;

    % Convert the Chromaticities table into a struct
    if isfield(in, "Chromaticities")
        out.Chromaticities = xytable2struct(in.Chromaticities);
    end
end

function out = xytable2struct(in)
    % Helper function that converts the chromaticities table into a struct
    % that can be handled by the builtin code.

    if isempty(in)
        out = struct.empty();
        return;
    end

    in1 = mergevars(in, ["x" "y"], "NewVariableName", "xy");

    structArgs = cell(height(in1)*2, 1);
    
    structArgs(1:2:end) = in1.Properties.RowNames;
    structArgs(2:2:end) = table2cell(in1);

    out = struct(structArgs{:});
end

function out = convertInputImageDataForWriting(in, outputType)
    % Helper function that converts the datatype of the input data to match
    % the type being written to the file. Additionally performs row-major
    % to column-major conversion

    if isempty(in)
        out = in;
        return;
    end

    if isnumeric(in)
        if outputType(1) == "half"
            % Convert the data to half precision but store the result in a
            % uint16 container.
            out = images.internal.builtins.convertToHalf(in, "uint16");
        else
            convFunc = str2func(outputType(1));
            out = convFunc(in);
        end
        % Convert to row-major interleaved
        out = permute(out, [3 2 1]);
    else
        out = cell(size(in));
        for cnt = 1:numel(outputType)
            if outputType(cnt) == "half"
                % Convert the data to half precision but store the result
                % in a uint16 container. 
                out{cnt} = images.internal.builtins.convertToHalf(in{cnt}, "uint16");
            else
                convFunc = str2func(outputType(cnt));
                out{cnt} = convFunc(in{cnt});
            end
        end

        % Convert to row-major interleaved
        % Every element of the cell array is a 2D matrix.
        out = cellfun( @(x) x', out, "UniformOutput", false);
    end    
end

function numChannels = computeNumChannels(im)
    % Helper function that computed the number of channels in the input
    % image data

    if iscell(im)
        numChannels = numel(im);
    else
        numChannels = size(im, 3);
    end
end

function outName = resolveHomeDir(inName)
    % Helper function that resolves the "~" into the full home directory
    % name

    [~, homeDirInfo] = fileattrib("~");
    outName = fullfile(homeDirInfo.Name, extractAfter(inName, 2));
end

%   Copyright 2022 The MathWorks, Inc.
