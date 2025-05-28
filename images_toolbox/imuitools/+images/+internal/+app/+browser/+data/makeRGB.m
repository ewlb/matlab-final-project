function im = makeRGB(im)
% Convert input image into an RGB image (to help show a useful thumbnail)

% Copyright 2021 The MathWorks, Inc.

% Reduce to MxNxP
if ndims(im)>3
    % Pick first slice if hyperspectral/volume
    im = squeeze(im(:,:,:,1));
end

% Make it MxNx3
if size(im,3)~=3
    % Pick first from an N channel image
    im = im(:,:,1);
    % Grayscale - replicate to make gray looking RGB
    im = repmat(im, [1 1 3]);
end

% Convert to uint8
if ~isa(im,'uint8')
    % The main aim of the thumbnail browser is to show a 'representative'
    % image to indicate content. Rescaling the dynamic range is likely the
    % best in most non-uint8 cases.
    im = uint8(rescale(im, 0, 255));
end
