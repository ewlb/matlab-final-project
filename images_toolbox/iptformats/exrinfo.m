function info = exrinfo(fileName)

    arguments
        fileName (1, 1) string { mustBeEXR(fileName) }
    end

    fullFileName = images.internal.io.absolutePathForReading(fileName);
    
    info = images.internal.builtins.exrinfo(fullFileName);
    
    for cnt = 1:numel(info)
        % Post process the ChannelInfo field
        info(cnt).ChannelInfo = postProcessChannelInfo(info(cnt).ChannelInfo);

        % Post process chromaticity values
        info(cnt).AttributeInfo.Chromaticities = ...
                    postProcessXYvals(info(cnt).AttributeInfo.Chromaticities);
    end

end

function out = postProcessChannelInfo(in)
    chanNames = [in.Name]';
    out = removevars(struct2table(in, "RowNames", chanNames), "Name");
end

function out = postProcessXYvals(xyVals)
    if isempty(xyVals)
        out = table.empty();
        return;
    end

    rowNames = fieldnames(xyVals);
    out = splitvars( cell2table( struct2cell(xyVals), ...
                                 "VariableNames", "xy", ...
                                 "RowNames", rowNames ), ...
                                 "xy", "NewVariableNames", ["x" "y"] );
end

%   Copyright 2022 The MathWorks, Inc.
