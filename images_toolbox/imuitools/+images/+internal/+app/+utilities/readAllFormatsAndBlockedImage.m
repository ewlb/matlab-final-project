function [im, cmap] = readAllFormatsAndBlockedImage(filename)
% Helper function that reads all IPT Formats and also uses blockedImage API
% to read TIFF files

% Copyright 2022 The MathWorks, Inc.
    
    % Verify if the file exists
    try
        filename = images.internal.io.absolutePathForReading(filename);
    catch ME
        throwAsCaller(ME);
    end
     
    try
        im = []; cmap = [];
        if isBlockedImage(filename)
            [im, cmap] = blockedImageWrapper(filename);
        end
    catch
        % Swallow this exception for now
    end

    % IM is empty if:
    % 1. filename is not a blocked image
    % 2. Error reading filename using the blockedImage API.
    if isempty(im)
        try 
            [im, cmap] = images.internal.app.utilities.readAllIPTFormats(filename);
        catch ME
            throwAsCaller(ME);
        end
    end
end

%------------------------------------------------------------
function tf = isBlockedImage(fileName)
% Helper function that checks if the input file can be treated as a blocked
% image. 
    tf = endsWith(fileName, [".tif", ".tiff", "description.mat"]);

    % The blockedImage wrapper does not really handle indexed TIFF files
    % correctly.
    if tf && ~endsWith(fileName, "description.mat")
        try 
            info = imfinfo(fileName);
            % If the file has a colormap, then do not use the blockedImage
            % interface to read the file.
            tf = ~isfield(info(1), "Colormap") || isempty(info(1).Colormap);
        catch
            tf = false;
        end
    end
end

%------------------------------------------------------------
function [im, cmap] = blockedImageWrapper(fileName)
% Read the coarsest level of a blockedImage only if its a .tif, .tiff or a
% description.mat file

    try
        bim = blockedImage(fileName);
        im = gather(bim, 'Level', bim.NumLevels);
        cmap = [];
    catch
        % Swallow this exception
    end
end