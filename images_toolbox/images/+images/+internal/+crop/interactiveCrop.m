function [spatial_rect,h_image,placement_cancelled] = interactiveCrop(h)
% INTERACTIVECROP Function to interactively crop an image.
%
% INTERNAL USE ONLY: Subject to change

% Copyright 2021 The MathWorks, Inc.

spatial_rect = [];
h_image = imhandles(h);
if numel(h_image) > 1
    h_image = h_image(1);
end
hAx = ancestor(h_image,'axes');

if isempty(h_image)
    error(message('images:imcrop:noImage'))
end

h_rect = iptui.imcropRect(hAx,[],h_image);
placement_cancelled = isempty(h_rect);
if placement_cancelled
    return;
end

spatial_rect = wait(h_rect);
if ~isempty(spatial_rect)
    % Slightly adjust spatial_rect so that we enclose appropriate pixels.
    % We still require the output of wait to determine whether or not
    % placement was cancelled.
    spatial_rect = h_rect.calculateClipRect(); 
else
    placement_cancelled = true;
end
% We are done with the interactive crop workflow. Delete the rectangle. Use
% isvalid to account for Cancel context menu item, which will have already
% deleted the imrect instance.
if isvalid(h_rect)
    h_rect.delete();
end

end %interactiveCrop