function [lum]=rgb2lum(rgb)
% [lum]=rgb2lum(rgb)
% rgb = 3-color image array (n,n,3)
% lum = grayscale array
% Peter D. Burns, pdburns@ieee.org 5 Nov. 2015

[~, ~, nc]= size(rgb);
if nc==3;
    cl = class(rgb);
    if isa(rgb,'double')~=1
        rgb = double(rgb);
    end
    
%   Standard NTSC conversion 
    lum = 0.2989*rgb(:,:,1) + 0.5870*rgb(:,:,2) + 0.1140*rgb(:,:,3);
    
    if strcmp(cl,'uint8')
        lum = uint8(lum);
    elseif strcmp(cl,'uint16')
        lum = uint16(lum);
    end
else lum=rgb;
end

