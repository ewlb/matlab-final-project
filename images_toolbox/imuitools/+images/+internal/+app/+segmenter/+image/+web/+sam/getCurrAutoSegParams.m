function params = getCurrAutoSegParams(ui, imageSize)
% Helper function that computes the Automatic Segmentation parameters used
% for the current segmentation

    if isempty(ui)
        params = images.internal.app.utilities.semiautoseg.SAMAutoSegDefaultParams.getParams(imageSize);
    else
        params = ui.AutoSegParams;
    end
end

% Copyright 2024 The MathWorks, Inc.