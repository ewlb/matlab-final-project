function mustHaveNumChannels(im, allowedNumChannels)
% Validate the image has only specified number of channels

    numChans = size(im, 3);
    if ~ismember(numChans, allowedNumChannels)
        error(message("images:common:UnsupportedNumChannels"));
    end
end

% Copyright 2017-2023 The MathWorks, Inc.