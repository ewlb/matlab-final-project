function out = overlappingBox(ref, boxes)
% ref - [xmin xmax ymin ymax]
% boxes -  ordered matrix of [xmin1 xmax1 ymin1 ymax1; ...
%                             xmin2 xmax2 ymin2 ymax2 ...]
% Order defines the stacking order of the ROIs, the latter one in the matrix
% is always on top.

% Copyright 2019-2020 The MathWorks, Inc.

tempX = bounding1D([ref(1) ref(2)],[boxes(:,1) boxes(:,2)]);
tempY= bounding1D([ref(3) ref(4)],[boxes(:,3) boxes(:,4)]);
out = find(tempX & tempY);
end

function interim = bounding1D(ref1D,inp)
% Condition refmin < inpmax AND inpmin < refmax 
 interim = ref1D(1) < inp(:,2) & inp(:,1) < ref1D(2) ;
end
