function img = readPreviewImage(fileName)
% Helper function that reads a preview image from a file. The return value
% IMG can be the following:
%   MxNx3 - True color image present in the file OR
%           Indexed image present in file has colormap applied to it
%
%   MxN   - Grayscale image present in the file OR
%           Multi-channel (2 or >3 channels) images has the first channel
%           extracted

%   Copyright 2021-2022, The MathWorks, Inc.

    % Any exceptions will be handled by the caller.
    [img, cmap] = images.internal.app.utilities.readAllIPTFormats(fileName);
    img = images.internal.app.utilities.makeRGB(img, cmap);
end