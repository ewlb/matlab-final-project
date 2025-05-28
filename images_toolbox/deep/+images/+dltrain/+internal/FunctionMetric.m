classdef FunctionMetric < deep.internal.metric.FunctionMetric & images.dltrain.internal.Metric
    %   Copyright 2023 The MathWorks, Inc.

    methods
        function self = FunctionMetric(fun,name)
            self@deep.internal.metric.FunctionMetric(fun,name);
        end
    end

end