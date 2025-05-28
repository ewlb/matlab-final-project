function [regionIndices, regionLengths] = pixIdxList2RegionInfo(pixIdxList) %#codegen
    % CC returned by SIM version of bwconncomp does not contain
    % RegionLengths and RegionIndices fields. Hence, computing
    % it here to ensure compatibility.

    regionLengths = coder.internal.indexInt(zeros(numel(pixIdxList), 1));
    for cnt = 1:numel(pixIdxList)
        regionLengths(cnt) = length(pixIdxList{cnt});
    end
    idxCount = [0;cumsum(regionLengths)];

    totalNumIndices = idxCount(end);

    regionIndices = coder.nullcopy(zeros(totalNumIndices, 1));
    startIdx = coder.internal.indexInt(1);
    for cnt = 1:numel(regionLengths)
        regionIndices(startIdx:startIdx+regionLengths(cnt)-1) = ...
                                                        pixIdxList{cnt};
        startIdx = startIdx + regionLengths(cnt);
    end
end

%   Copyright 2023 The MathWorks, Inc.