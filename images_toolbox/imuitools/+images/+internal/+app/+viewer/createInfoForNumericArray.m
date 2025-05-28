function s = createInfoForNumericArray(im)
% Helper function that creates a simple info struct for a numeric array.
% This information is displayed as the source information.

%   Copyright 2023 The MathWorks, Inc.

    s = struct( "Width", size(im, 2), ...
                "Height", size(im, 1), ...
                "NumChannels", size(im, 3), ...
                "Datatype", underlyingType(im) );
end