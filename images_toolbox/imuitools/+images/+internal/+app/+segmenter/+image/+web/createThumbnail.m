function thumbnail = createThumbnail(fullSizeImage)
%createThumbnail  Create standard-sized thumbnail.

% Copyright 2015-2019 The MathWorks, Inc.

thumbnailSize = images.internal.app.segmenter.image.web.getThumbnailSize(); %px

% Resize and preserve the aspect ratio.
if(size(fullSizeImage,1) > size(fullSizeImage,2))
    thumbnail = imresize(fullSizeImage, [thumbnailSize, NaN], 'nearest');
else
    thumbnail = imresize(fullSizeImage, [NaN, thumbnailSize], 'nearest');
end

end
