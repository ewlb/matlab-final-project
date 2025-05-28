function validateBatchFcnSetting(settingsVal)
% Helper function that validates the BatchFcn settings.

%   Copyright 2022, The MathWorks, Inc.

    validateattributes(settingsVal, "table", {'ncols', 2});
    mustBeMember(settingsVal.Properties.VariableNames, ["FullFcnName", "IsInclInfo"]);
    mustBeA(settingsVal.FullFcnName, "string");
    mustBeA(settingsVal.IsInclInfo, "logical");
end