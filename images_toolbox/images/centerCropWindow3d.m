function win = centerCropWindow3d(inputSize,targetSize)
%centerCropWindow3d Create center cropping window.
%   win = centerCropWindow3d(inputSize,targetSize) takes an input image size,
%   inputSize, and a desired output size, targetSize. The inputs inputSize 
%   and targetSize may be three element or four element vectors. If specified 
%   sizes have three elements, the fourth element is interpreted as a channel 
%   dimension. The output, win, is an images.spatialref.Cuboid object.
% 
%   Example
%   ---------
%   % Center crop input image to desired target size
%   S = load('mri.mat','D');
%   volumeData = squeeze(S.D);
%   targetSize = [10,10,10];
%   win = centerCropWindow3d(size(volumeData),targetSize);
%   r = win.YLimits(1):win.YLimits(2);
%   c = win.XLimits(1):win.XLimits(2);
%   p = win.ZLimits(1):win.ZLimits(2);
%   croppedVolume = volumeData(r,c,p);
%   figure
%   volshow(croppedVolume);
%
%   See also randomCropWindow3d, centerCropWindow2d, randomCropWindow2d

%   Copyright 2019, The MathWorks, Inc.

narginchk(2,2)

inputSize = manageChannelDims(inputSize);
targetSize = manageChannelDims(targetSize);

validateattributes(inputSize,{'numeric'},{'vector','numel',3,'integer','nonsparse','real'});
validateattributes(targetSize,{'numeric'},{'vector','numel',3,'integer','nonsparse','real'});

if any(targetSize > inputSize)
    error(message('images:cropwindow:targetSizeTooBigForInputImageSize'));
end

% When in a dimension inputDim-targetDim is non-even, we arbitrarily choose
% ceil when forming the cropping window.
startPos = 1 + ceil((inputSize - targetSize)/2);

xLimits = [startPos(2),startPos(2)+targetSize(2)-1];
yLimits = [startPos(1),startPos(1)+targetSize(1)-1];
zLimits = [startPos(3),startPos(3)+targetSize(3)-1];
win = images.spatialref.Cuboid(xLimits,yLimits,zLimits);

end

function szOut = manageChannelDims(sz)

if isvector(sz) && numel(sz) == 4
    szOut = sz(1:3);
else
    szOut = sz;
end

end