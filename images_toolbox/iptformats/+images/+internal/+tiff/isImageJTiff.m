function [tf, numFrames] = isImageJTiff(tiffInfo)

% ImageJ files are larger than 4GB, have an ImageDescription tag, and
% within that tag contain "ImageJ" and the number of images. For example:
% 'ImageJ=1.52i↵images=1300↵slices=1300↵unit=\u00B5m↵spacing=2.0009↵loop=false↵min=0.0↵max=11459.0↵'

tf = false;
numFrames = [];

if tiffInfo(1).FileSize > intmax('uint32') && ...
        isfield(tiffInfo, 'ImageDescription') && ...
        isequal(tiffInfo(1).ImageDescription(1:6), 'ImageJ')
    
    numFramesStr = regexp(tiffInfo(1).ImageDescription, 'images=(\d*)', 'tokens');
    
    if ~isempty(numFramesStr)
        numFrames = str2double(numFramesStr{1}{1});
        if numFrames > 1
            tf = true;
        else
            tf = false;
        end
    else
        tf = false;
    end
end
end

% Copyright 2020-2024 The MathWorks, Inc.