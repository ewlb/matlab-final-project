function win = centerCropWindow2d(inputSize,targetSize)
%centerCropWindow2d Create center cropping window.
%   win = centerCropWindow2d(inputSize,targetSize) takes an input image size,
%   inputSize, and a desired output size, targetSize. The inputs inputSize 
%   and targetSize may be two element or three element vectors. If specified 
%   sizes have three elements, the third element is interpreted as a channel 
%   dimension. The output, win, is an images.spatialref.Rectangle object.
% 
%   Example
%   ---------
%   % Center crop input image to desired target size
%   A = imread('kobi.png');
%   targetSize = [1000,1000];
%   win = centerCropWindow2d(size(A),targetSize);
%   [r,c] = deal(win.YLimits(1):win.YLimits(2),win.XLimits(1):win.XLimits(2));
%   Acrop = A(r,c,:);
%   figure
%   montage({A,Acrop});
%
%   See also randomCropWindow2d, centerCropWindow3d, randomCropWindow3d

%   Copyright 2019, The MathWorks, Inc.

narginchk(2,2)

inputSize = manageChannelDims(inputSize);
targetSize = manageChannelDims(targetSize);

validateattributes(inputSize,{'numeric'},{'vector','numel',2,'integer','nonsparse','real'});
validateattributes(targetSize,{'numeric'},{'vector','numel',2,'integer','nonsparse','real'});

if any(targetSize > inputSize)
    error(message('images:cropwindow:targetSizeTooBigForInputImageSize'));
end

% When in a dimension inputDim-targetDim is non-even, we arbitrarily choose
% ceil when forming the cropping window.
startPos = 1 + ceil((inputSize - targetSize)/2);

xLimits = [startPos(2),startPos(2)+targetSize(2)-1];
yLimits = [startPos(1),startPos(1)+targetSize(1)-1];
win = images.spatialref.Rectangle(xLimits,yLimits);

end

function szOut = manageChannelDims(sz)

if isvector(sz) && numel(sz) == 3
    szOut = sz(1:2);
else
    szOut = sz;
end

end