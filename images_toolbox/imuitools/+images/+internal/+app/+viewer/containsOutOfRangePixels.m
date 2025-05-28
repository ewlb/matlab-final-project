function tf = containsOutOfRangePixels(im)
% Helper function that determines if an image input contains out of range
% pixels

%   Copyright 2023 The Mathworks, Inc.

    tf = false;
    if isfloat(im)
        minVal = min(im, [], "all");
        maxVal = max(im, [], "all");
        range = getrangefromclass(im);
        tf = (minVal < range(1)) || (maxVal > range(2));
    end
end