function bw = cc2bw(cc, options)
    arguments
        cc (1, 1) struct {checkCC}
        options.ObjectsToKeep {mustBeInteger, mustBeValidSelection} ...
                                                = 1:length(cc.PixelIdxList)
    end

    bw = false(cc.ImageSize);

    if isnumeric(options.ObjectsToKeep)
        % Avoid wasteful multiple copies of the input to output if the same
        % object is selected multiple times
        sel = unique(options.ObjectsToKeep);
    else
        sel = options.ObjectsToKeep;
    end

    pixIdxListToKeep = cc.PixelIdxList(sel);

    for k = 1:length(pixIdxListToKeep)
        bw(pixIdxListToKeep{k}) = true;
    end
end

function mustBeValidSelection(sel)
    % Allow empty selections. This can occur if the condition the user
    % specified resulted in no objects being selected.
    if ~isempty(sel)
        mustBeVector(sel);
    end
end

%   Copyright 2023 The MathWorks, Inc.