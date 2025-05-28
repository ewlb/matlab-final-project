function tf = isImage(im)
%

% Copyright 2014-2015 The MathWorks, Inc.

tf = ( isnumeric(im) || islogical(im) )...
        && (size(im,1)>1 && size(im,2)>1 ... 
        && ndims(im)<4 ...
        && (size(im,3)==1||size(im,3)==3));
end
