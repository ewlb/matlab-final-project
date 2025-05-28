function minPixSize = computeMinPixSizeForPixelRegion(srcImage)
% Helper function that computes the minimum screen pixel size at which
% pixel value text is displayed. This depends upon the datatype of the
% source image.

%   Copyright 2023, The MathWorks, Inc.

    switch(class(srcImage))
        case {"logical", "uint8", "int8", "single", "double"}
            minPixSize = 75;
        otherwise
            minPixSize = 100;
    end