classdef Metric < deep.Metric
%   Copyright 2023 The MathWorks, Inc.

properties (Hidden)
    % Used to declare a Metric as validation-only, meaning that it will
    % only be evaluated on the validation set
    ValidationOnly = false;

    % The inference method that should be used to obtain Y when computing
    % metric. Valid values are ["forward","predictForValidation"].
    InferenceMethodMode = "forward"
end

end