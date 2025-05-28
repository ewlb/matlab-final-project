function [curvature, varargout] = calculateCurvature(phi, pixIdx)
%calculateCurvature Calculate curvature of 2D or 3D function on discrete grid.
% 
%   See also ActiveContourEvolver, ActiveContourSpeed, ActiveContourSpeedChanVese

% Copyright 2023 The MathWorks, Inc.


%#codegen

coder.inline('always');
coder.internal.prefer_const(phi, pixIdx);

nout = max(nargout,1)-1;

coder.internal.errorIf(nout>1, 'images:validate:tooManyInputs',mfilename);

imgSizeOne = size(phi);
is3D = (numel(imgSizeOne) == 3);
if ~is3D
    imgSize = [imgSizeOne 1];
else
    imgSize = imgSizeOne;
end
[r, c, z] = ind2sub(imgSize,pixIdx);

% Get all the pixels
pix = phi(pixIdx);

% Get first order derivatives through calculateGradient()
[dx, dy, dz, leftPix, rightPix, upPix, downPix, frontPix, backPix] = ...
    images.internal.coder.calculateGradient(phi, pixIdx);

% Get other neighbors for higher order derivative computation
ulPix = phi(images.internal.coder.getNeighIdx([-1 -1 0], imgSize, r, c, z));
urPix = phi(images.internal.coder.getNeighIdx([-1 1 0], imgSize, r, c, z));
dlPix = phi(images.internal.coder.getNeighIdx([1 -1 0], imgSize, r, c, z));
drPix = phi(images.internal.coder.getNeighIdx([1 1 0], imgSize, r, c, z));
lfPix = phi(images.internal.coder.getNeighIdx([0 -1 -1], imgSize, r, c, z));
lbPix = phi(images.internal.coder.getNeighIdx([0 -1 1], imgSize, r, c, z));
rfPix = phi(images.internal.coder.getNeighIdx([0 1 -1], imgSize, r, c, z));
rbPix = phi(images.internal.coder.getNeighIdx([0 1 1], imgSize, r, c, z));
ufPix = phi(images.internal.coder.getNeighIdx([-1 0 -1], imgSize, r, c, z));
ubPix = phi(images.internal.coder.getNeighIdx([-1 0 1], imgSize, r, c, z));
dfPix = phi(images.internal.coder.getNeighIdx([1 0 -1], imgSize, r, c, z));
dbPix = phi(images.internal.coder.getNeighIdx([1 0 1], imgSize, r, c, z));

% Higher order derivatives
dxx = leftPix - 2*pix + rightPix;
dyy = upPix - 2*pix + downPix; 
dzz = frontPix - 2*pix + backPix;
dxy = (ulPix + drPix - urPix - dlPix)/4;
dxz = (lfPix + rbPix - rfPix - lbPix)/4;
dyz = (ufPix + dbPix - dfPix - ubPix)/4;

% Compute curvature
curvature = (dxx.*(dy.^2 + dz.^2) + dyy.*(dx.^2 + dz.^2) + ...
    dzz.*(dx.^2 + dy.^2) - 2*dx.*dy.*dxy - 2*dx.*dz.*dxz - 2*dy.*dz.*dyz)./ ...
    (dx.^2 + dy.^2 + dz.^2 + eps);

if nout == 1
   if is3D
       varargout{1} = [dx dy dz];
   else
       varargout{1} = [dx dy];
   end
end
end