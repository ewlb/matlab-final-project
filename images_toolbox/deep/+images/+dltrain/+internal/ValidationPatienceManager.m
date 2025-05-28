classdef ValidationPatienceManager < handle

    %   Copyright 2022-2023 The MathWorks, Inc.

    properties
        NumValidationCyclesWithoutImprovement = 1;
        Patience
        BestValidationMetric
        MaximizeObjective;
        ComparisonFunction
    end

    events
        ValidationPatienceStopTraining
    end

    methods
        function self = ValidationPatienceManager(patience,maximizeObjective)
            self.Patience = patience;
            self.MaximizeObjective = maximizeObjective;
            
            if maximizeObjective
                self.BestValidationMetric = -inf;
                self.ComparisonFunction = @gt;
            else
                self.BestValidationMetric = inf;
                self.ComparisonFunction = @lt;
            end
        end

        function self = step(self,metricVal,evtData)
            if evtData.IsValidationIteration
                if self.ComparisonFunction(metricVal, self.BestValidationMetric)
                    self.BestValidationMetric = metricVal;
                    self.NumValidationCyclesWithoutImprovement = 1; % Reset patience count.
                else
                    self.NumValidationCyclesWithoutImprovement = self.NumValidationCyclesWithoutImprovement + 1;
                end

                if self.NumValidationCyclesWithoutImprovement > self.Patience
                    notify(self,'ValidationPatienceStopTraining');
                end
            end
        end
    end
end