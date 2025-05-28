function [dx, dy, dz, leftPix, rightPix, upPix, downPix, frontPix, backPix] = ...
    calculateGradient(phi, pixIdx)
%calculateGradient Calculate gradient of 2D or 3D function on discrete grid.
% 
%   See also ActiveContourEvolver, ActiveContourSpeed, ActiveContourSpeedChanVese

% Copyright 2023 The MathWorks, Inc.

%#codegen

coder.inline('always');
coder.internal.prefer_const(phi, pixIdx);

imgSizeOne = size(phi);
is3D = (numel(imgSizeOne) == 3);
if ~is3D
    imgSize = [imgSizeOne 1];
else
    imgSize = imgSizeOne;
end
[r, c, z] = ind2sub(imgSize,pixIdx);

leftPix = phi(images.internal.coder.getNeighIdx([0 -1 0], imgSize, r, c, z));
rightPix = phi(images.internal.coder.getNeighIdx([0 1 0], imgSize, r, c, z));
upPix = phi(images.internal.coder.getNeighIdx([-1 0 0], imgSize, r, c, z));
downPix = phi(images.internal.coder.getNeighIdx([1 0 0], imgSize, r, c, z));
frontPix = phi(images.internal.coder.getNeighIdx([0 0 -1], imgSize, r, c, z));
backPix = phi(images.internal.coder.getNeighIdx([0 0 -1], imgSize, r, c, z));

dx = (leftPix - rightPix)/2;
dy = (upPix - downPix)/2;
dz = (frontPix - backPix)/2;