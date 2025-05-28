classdef MetricLogger < handle
    % MetricLogger computes and records metrics for both training and
    % validation. Interested clients may listen to updates to the metric log via
    % LogUpdate events.

    %   Copyright 2021-2023 The MathWorks, Inc.
   
    properties (Access = protected)
        Metrics
        MetricNames
        NumLogCols
        LogEntryStruct
        ValidationQueue
        NumNetworkInputs
        NumNetworkOutputs
        NumValidationPredictOutputs
        LossMetricName
        ObjectiveMetricName
    end
    
    properties (Access = public)
        MetricLog
    end
    
    properties (SetAccess = protected)
        ColumnNames
        BestNetwork
        BestNetworkIteration double
    end

    properties (Access = private)
        BestValidationLoss = inf;
        NeedToMaximizeObjective = false;
    end
    
    events
       LogUpdate 
    end
    
    methods
        
        function self = MetricLogger(metrics,valQueue,lossMetricName,objectiveMetricName,network,trainingQueue)
            
            if nargin == 0
                return
            end
                        
            metricNamesCell = iGetMetricNames(metrics);
            self.MetricNames = horzcat(metricNamesCell{:});
            self.Metrics = metrics;
            self.NumNetworkInputs = length(network.InputNames);
            self.NumNetworkOutputs = length(network.OutputNames);

            if isa(network,'images.dltrain.internal.ValidationTimeInferable')
                self.NumValidationPredictOutputs = numOutputsPredictForValidation(network);
            end

            % Populate the set of training metrics we will log as the
            % subset that aren't validation only.
            isValidationOnlyMetric = cellfun(@(f) isa(f,'images.dltrain.internal.Metric') && f.ValidationOnly, self.Metrics);
            nonValidationOnlyMetricNames = metricNamesCell(~isValidationOnlyMetric);
            nonValidationOnlyMetricNames = horzcat(nonValidationOnlyMetricNames{:});
            fullMetricNames = "Training" + nonValidationOnlyMetricNames;
            
            if ~isempty(valQueue)
                validationNames = "Validation" + self.MetricNames;
                fullMetricNames = horzcat(fullMetricNames,validationNames);
                self.ValidationQueue = valQueue;
            end

            self.LossMetricName = lossMetricName;
            self.ObjectiveMetricName = objectiveMetricName;

            % Determine whether we will need to minimize or maximize the
            % metric when tracking OutputNetwork.
            self.NeedToMaximizeObjective = self.Metrics{self.ObjectiveMetricName == string(self.MetricNames)}.Maximize;
            if isempty(self.NeedToMaximizeObjective)
                self.NeedToMaximizeObjective = false;
            end

            % Initialize BestValidationLoss according to worst case
            % objective value of the polarity for which we are
            % optimization.
            if self.NeedToMaximizeObjective
                self.BestValidationLoss = -Inf;
            else
                self.BestValidationLoss = Inf;
            end
            
            self.ColumnNames = horzcat("Epoch","Iteration","TimeElapsed","LearnRate",fullMetricNames);
            self.NumLogCols = numel(self.ColumnNames);
            
            args = reshape(cellstr(self.ColumnNames),1,[]);
            args = cat(1,args,repmat({nan},1,self.NumLogCols));
            
            self.LogEntryStruct = struct(args{:});

            iVerifyMetricTypes(self.Metrics);
            initializeMetrics(self,network,trainingQueue);
        end

        function initializeMetrics(self,network,trainingQueue)
          
            batch = cell(1,trainingQueue.NumOutputs);
            outputs = cell(1,self.NumNetworkOutputs);
            outputsFromPredictSemantics = cell(1,self.NumNetworkOutputs);

            [batch{:}] = next(trainingQueue);
            reset(trainingQueue);
            inputs = batch(1:self.NumNetworkInputs);
            targets = batch(self.NumNetworkInputs+1:end);

            % First, check whether any of the metrics are Validation only.
            % For validation only metrics only, we we allow metrics to
            % specify that they should be computed with predict semantics.
            % For this case we have to compute Y for the metrics using
            % either predictForValidation or predict, depending on whether
            % the task network implements
            % images.dltrain.internal.ValidationTimeInferable to customize
            % what predict behavior should mean.
            metricsValidationOnlyWithPredictSemantics = cellfun(@(c) isa(c,'images.dltrain.internal.Metric') && c.ValidationOnly && c.InferenceMethodMode=="predictForValidation",self.Metrics);
            if any(metricsValidationOnlyWithPredictSemantics)
                if ~isempty(self.NumValidationPredictOutputs)
                        outputsFromPredictSemantics = cell(1,self.NumValidationPredictOutputs);
                        [outputsFromPredictSemantics{:}] = predictForValidation(network,inputs{:});
                    else
                        [outputsFromPredictSemantics{:}] = predict(network,inputs{:});
                end
            end

            % In dltrain all other metrics are evaluated against forward
            % semantics of network
            if any(~metricsValidationOnlyWithPredictSemantics)
                [outputs{:}] = forward(network,inputs{:});
            end

            % If a user supplies a metric that doesn't make sense for a
            % given trainer, there is a possibility that initialize will
            % fail. Provide a general error message that this metric failed
            % to initialize.
            try
                for idx = 1:length(self.Metrics)
                    metric = self.Metrics{idx};
                    if metricsValidationOnlyWithPredictSemantics(idx)
                        self.Metrics{idx} = initialize(metric,outputsFromPredictSemantics{:},targets{:});
                    else
                        self.Metrics{idx} = initialize(metric,outputs{:},targets{:});
                    end
                end
            catch ME
                error(message("images:dltrain:metricFailedToInitialize",metric.Name));
            end
        end
        
        function evaluateMetrics(self,evtData)
                        
            % Struct with appropriate fields and empty values
            logEntry = self.LogEntryStruct;
            logEntry.Iteration = evtData.Iteration;
            logEntry.LearnRate = evtData.LearnRate;
            logEntry.Epoch = evtData.Epoch;
            logEntry.TimeElapsed = duration(0,0,toc(evtData.StartTime),'Format','hh:mm:ss');

            for f = 1:length(self.Metrics)
                metric = self.Metrics{f};
                for thisMetric = metric.Name
                    if thisMetric == self.LossMetricName
                        % When training loss used as a metric, we don't need to recompute it.
                        logEntry.("Training"+thisMetric) = iGatherToCPU(evtData.Loss);
                    elseif isfield(evtData.LossData,thisMetric)
                        % If a metric has already been computed in the
                        % LossData, use it rather than recomputing. Use Case:
                        % MaskRCNN.
                        logEntry.("Training"+thisMetric) = iGatherToCPU(evtData.LossData.(thisMetric));
                    else % All other metrics
                        if ~metric.ValidationOnly
                            self.Metrics{f} = reset(self.Metrics{f});
                            metric = update(metric,evtData.NetworkOutputs{:},evtData.Targets{:});
                            metricVal = evaluate(metric);
                            logEntry.("Training"+thisMetric) = iGatherToCPU(metricVal);
                        end
                    end
                end
            end
            
            if evtData.IsValidationIteration
                logEntry = evaluateValidationMetrics(self,evtData,logEntry);
            end
            
            self.MetricLog = cat(1,self.MetricLog,logEntry);
            
            % Notify interested clients that the log as been updated
            notify(self,'LogUpdate',images.dltrain.internal.LogUpdateEventData(logEntry,evtData.IsValidationIteration)); 
        end
        
        function logEntry = evaluateValidationMetrics(self,evtData,logEntry)
    
            batch = cell(1,self.ValidationQueue.NumOutputs);
            
            numNetworkInputs = self.NumNetworkInputs;
            numNetworkOutputs = self.NumNetworkOutputs;

            outputs = cell(1,numNetworkOutputs);

            % Only used for a subset of validation only metrics that
            % inherit from images.dltrain.internal.ValidationTimeInferable
            % and specify that predict semantics should be used.
            outputsFromPredictSemantics = cell(1,numNetworkOutputs);
            
            reset(self.ValidationQueue);

            % Reset state of each of the metric objects
            for idx = 1:length(self.Metrics)
                metric = self.Metrics{idx};
                self.Metrics{idx} = reset(metric);
            end

            % Iterate through the validation set and update metrics as we
            % go.
            while hasdata(self.ValidationQueue)
                [batch{:}] = next(self.ValidationQueue);
                inputs = batch(1:numNetworkInputs);
                targets = batch(numNetworkInputs+1:end);
                [outputs{:}] = forward(evtData.Network,inputs{:});

                for idx = 1:length(self.Metrics)
                    metric = self.Metrics{idx};
                    % IPCV metrics can declare that they require predict
                    % semantics for validation with a default of using
                    % forward semantics
                    if (isa(metric,'images.dltrain.internal.Metric') && (metric.InferenceMethodMode == "predictForValidation"))
                        % IPCV task networks can override or define what it means to
                        % use "predict" semantics (e.g. detect() is what
                        % you'd want for an object detector).
                        if isa(evtData.Network,'images.dltrain.internal.ValidationTimeInferable')
                            outputsFromPredictSemantics = cell(1,evtData.Network.numOutputsPredictForValidation);
                            [outputsFromPredictSemantics{:}] = predictForValidation(evtData.Network,inputs{:});
                        else
                            % Default to predict()
                            [outputsFromPredictSemantics{:}] = predict(evtData.Network,inputs{:});
                        end
                        break % You only compute the predict() semantics once for each batch if any of the metrics require them
                    end
                end

    
                % Update each of the metrics according to the necessary
                % kind of forward/predict semantics they require.
                for idx = 1:length(self.Metrics)
                    metric = self.Metrics{idx};
                    if metric.InferenceMethodMode == "forward"
                        self.Metrics{idx} = update(metric,outputs{:},targets{:});
                    else
                        self.Metrics{idx} = update(metric,outputsFromPredictSemantics{:},targets{:});
                    end
                end
            end

            % For each of the metrics, do the final reduction to form final
            % metric value and add the final metric value to the logEntry.
            %
            % Some metric objects may return multiple metric outputs from
            % the same evaluate call.
            for idx = 1:length(self.Metrics)
                metric = self.Metrics{idx};
                metricNamesForThisMetric = iGetMetricNames(self.Metrics(idx));
                metricNamesForThisMetric = horzcat(metricNamesForThisMetric{:});
                outputsForThisMetric = cell(1,length(metricNamesForThisMetric));
                [outputsForThisMetric{:}] = evaluate(metric);
                valMetricName = "Validation"+metricNamesForThisMetric;
                for n = 1:length(outputsForThisMetric)
                    logEntry.(valMetricName(n)) = iGatherToCPU(outputsForThisMetric{n});
                end
            end

            % Finally, BestNetwork according to the validation loss metric
            valObjectiveMetricName = "Validation"+self.ObjectiveMetricName;
            if iIsNewMetricValueImproved(logEntry.(valObjectiveMetricName),self.BestValidationLoss,self.NeedToMaximizeObjective)
                self.BestValidationLoss = logEntry.(valObjectiveMetricName);
                self.BestNetwork = evtData.Network; % Cache network
                self.BestNetworkIteration = evtData.Iteration;
            end
        end 
    end
end

function TF = iIsNewMetricValueImproved(newVal,previousVal,isMaximization)
% For OutputNetwork purposes whether or not the metric is improved depends
% on the state of the Maximize property of the Metric of name
% ObjectiveMetricName when the OutputNetwork is 'auto' or
% 'best-validation'.

TF = (isMaximization && (newVal >= previousVal)) ||...
     (~isMaximization) && (newVal <= previousVal);

end

function val = iGatherToCPU(val)
if isa(val,'dlarray')
    val = extractdata(val);
end
val = gather(val);
end

function names = iGetMetricNames(metrics)
    names = cellfun(@(c) reshape(c.Name,1,[]),metrics,UniformOutput=false);
end

function iVerifyMetricTypes(metrics)

for idx = 1:length(metrics)
    if ~(isa(metrics{idx},'deep.internal.metric.BuiltIn') || isa(metrics{idx},'images.dltrain.internal.Metric'))
        error(message("images:dltrain:metricsMustBeBuiltIn"));
    end
end

end

