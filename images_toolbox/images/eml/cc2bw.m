function bw = cc2bw(cc, options) %#codegen
    arguments
        cc (1, 1) struct
        options.ObjectsToKeep {mustBeInteger, mustBeValidSelection} ...
                                                = 1:length(cc.PixelIdxList)
    end

    % Do not use coder.nullcopy as it results in an uninitialized array.
    % Not all elements of BW are being explicitly set to TRUE or FALSE.
    bw = false(cc.ImageSize);

    if isempty(options.ObjectsToKeep)
        return;
    end

    % Paren indexing of cell arrays not allowed in codegen. Hence, this
    % code pattern is being used
    if islogical(options.ObjectsToKeep)
        selection = options.ObjectsToKeep;
        numObjsToRetain = numel(find(selection));

        % Loop over the number of output objects to avoid wasteful
        % traversal of all objects.
        inCnt = 1;
        for cnt = 1:numObjsToRetain
            while ~selection(inCnt)
                inCnt = inCnt + 1;
            end
            
            bw(cc.PixelIdxList{inCnt}) = true;
            inCnt = inCnt + 1;
        end
    else
        % Avoid wasteful multiple copies of the input to output if the same
        % object is selected multiple times
        selection = unique(options.ObjectsToKeep);
        numObjsToRetain = numel(selection);

        for cnt = 1:numObjsToRetain
            bw(cc.PixelIdxList{selection(cnt)}) = true;
        end
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