function J = alginpaintExemplar(I,mask,fillOrder,patchSize)
% main algorithm for exemplar based inpainting
%
%     'FillOrder'         FillOrder determines the order while filling the
%                         selected region. Possible values are 'gradient'
%                         and 'tensor'.
%
%     'PatchSize'         'PatchSize' specifies the size of the patch used
%                         for the best patch selection.

%   Copyright 2019-2020 The MathWorks, Inc.

classToUse = class(I);
img = single(I);
origImg = img;
ind = reshape(1:size(img,1)*size(img,2),size(img,1),size(img,2))-1;
sz = [size(img,1) size(img,2)]; % image size
sourceRegion = ~mask;

% gradient in normal direction
[Ix, Iy] = gradient(img);
Ix = sum(Ix,3)/(3*255); Iy = sum(Iy,3)/(3*255);
temp = Ix; Ix = -Iy; Iy = temp;  % Rotate gradient 90 degrees

% initialize confidence term and data term
confTerm = single(sourceRegion);
dataTerm = single(repmat(-0.1,sz));

if numel(patchSize) == 1
    w1 = floor((patchSize-1)/2); % window size for patch
    w2 = w1;
    numelPatch = patchSize*patchSize;
elseif numel(patchSize) == 2
    w1 = floor((patchSize(1)-1)/2); % window size for patch
    w2 = floor((patchSize(2)-1)/2);
    numelPatch = patchSize(1)*patchSize(2);
end

% find out mask boundary (patches to be filled first)
[Nx,Ny] = gradient(single(~mask));
absGrad = Nx.^2 + Ny.^2;
dR = find(absGrad>0); % updated with new boundary
dR = dR-1; % adjust c index
newPoint = dR; % contain all new points of a patch
newPointSize = numel(newPoint);
pointToInpaint = sum(mask(:)); % total no. of pixels to inpaint

[label,numBlob] = bwlabel(mask);
st = regionprops(mask, 'BoundingBox');
win = 4*max(patchSize); % search region (4*default win size)
searchRegion = [];
for index = 1:numBlob
    tempsearchRegion = floor([max(st(index).BoundingBox(2)-win,1), min(st(index).BoundingBox(2)+win+st(index).BoundingBox(4),sz(1)) ...
        max(st(index).BoundingBox(1)-win,1), min(st(index).BoundingBox(1)+win+st(index).BoundingBox(3),sz(2))]);
    searchRegion = [searchRegion tempsearchRegion]; %#ok<AGROW>
end
searchRegion = searchRegion-1;
dRsize = size(dR,1);
newdR = zeros(numel(mask),1);
newdR(1:dRsize) = dR;
if strcmp(fillOrder,'gradient')
    fillOrder = 1;
else
    fillOrder = 2;
end
% main processing
img = images.internal.builtins.inpaintExemplar(img,origImg,mask,pointToInpaint,single(newdR),dRsize,Nx,Ny, single(newPoint), newPointSize,...
    w1, w2, confTerm, dataTerm, Ix, Iy, numelPatch, single(ind), absGrad, sourceRegion, single(searchRegion), single(label), fillOrder);
J = cast(img,classToUse);



