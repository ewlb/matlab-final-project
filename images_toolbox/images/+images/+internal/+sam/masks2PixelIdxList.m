function PixelIdxList = masks2PixelIdxList(masks)
% Convert masks to sparse pixelIdxList

%   Copyright 2023-2024 The MathWorks, Inc.
    numMasks = size(masks,3);
    linIdx = find(masks);

    [r,c,d] = ind2sub(size(masks), linIdx);

    PixelIdxList = cell(1,numMasks);
    
    for i = 1:numMasks
        pts_mask_i = (d==i);
        PixelIdxList{i} = sub2ind([size(masks,1) size(masks,2)], ...
                                                   r(pts_mask_i), c(pts_mask_i));
    end
end