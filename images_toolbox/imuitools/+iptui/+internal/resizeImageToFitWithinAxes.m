function I = resizeImageToFitWithinAxes(hAx,I)
%

%   Copyright 2022 The MathWorks, Inc.

axesPixelPosition = getpixelposition(hAx); % Returns x,y,w,h
% To maintain outputSize compatibility with imresize - return sizes and
% ratios in [h,w] order
axesSizeInPixels = axesPixelPosition([4 3]); % Returns h,w
imSize = size(I); % Returns h,w


sizeRatio = axesSizeInPixels ./ imSize(1:2);
[minRatio,dim] = min(sizeRatio);
needToDownsample = minRatio < 1;
% If the image grid in pixels is larger than the axes in pixels
% along the limiting dimension, resize the input image with
% anti-aliasing.
if needToDownsample
    % We use the feature of imresize in which [NaN numCols] or [numRows Nan] is
    % interpreted as resize to this number of rows,cols and preserve aspect
    % ratio.
    imresizeOutputSize = nan(1,2);
    imresizeOutputSize(dim) = axesSizeInPixels(dim);
    
    I = imresize(I,imresizeOutputSize);
end