function [net,info] = dltrain(queue,net,options,lossFcn,metrics,lossMetricName, NameValueArgs)
% high level trainer for dlnetwork and dlnetwork-like networks

%   Copyright 2021-2023 The MathWorks, Inc.

arguments
   queue minibatchqueue
   net {images.dltrain.internal.isValidNetwork}
   options {isa(options,'nnet.cnn.TrainingOptions')}
   lossFcn {isValidLoss}
   metrics cell {isValidMetricsCell}
   lossMetricName string
   NameValueArgs.ExperimentMonitor {mustBeScalarOrEmpty} = []
end

import images.dltrain.internal.*;

% Validate the relationships between options in training metrics
validateRelations(options);

metrics = iConvertMetricsToCellOfMetricObjectsForm(metrics);

iMustBeValidLossMetricName(metrics,lossMetricName);

iValidateSupportedTrainingOptions(options);

% Configure mbq according to trainingOptions. Would also want ability to
% set batch size here.
queue.DispatchInBackground = options.DispatchInBackground;
queue.PreprocessingEnvironment = options.PreprocessingEnvironment;
[~,useGpu] = iGetOutputEnvironment(options.ExecutionEnvironment);

% Define the appropriate trainer based on serial vs. parallel training
parallelTraining = ( (options.ExecutionEnvironment == "multi-gpu") || (options.ExecutionEnvironment == "parallel") );
if ~parallelTraining
    networkTrainer = SerialTrainer(queue,net,lossFcn,options);
else
    networkTrainer = ParallelTrainer(queue,net,lossFcn,options,useGpu);
end

% Create a minibatchqueue for the validation data if needed. Configure the
% queue the same way as the training queue.
if ~isempty(options.ValidationData)
    valQueue = iCreateValidationQueue(options.ValidationData,queue,getValidationBatchSize(parallelTraining,useGpu,options.MiniBatchSize));
else
    valQueue = minibatchqueue.empty();
end

if options.ObjectiveMetricName ~= "loss"
    objectiveMetricName = options.ObjectiveMetricName;
else
    objectiveMetricName = lossMetricName; % Use the loss name as the default
end

logger = MetricLogger(metrics,valQueue,lossMetricName,objectiveMetricName,net,queue);

% The metric logger listens to IterationEnd events from the trainer and
% forms a file-backed log of iteration,loss and all additional specified
% metrics.
addlistener(networkTrainer,'IterationEnd',@(~,evtData) logger.evaluateMetrics(evtData));

if options.Verbose
   verboseDisplayer = VerboseDisplay(logger.ColumnNames,options.VerboseFrequency);
   addlistener(logger,'LogUpdate',@(logger,evtData) updateDisplay(verboseDisplayer,evtData));
end

if(~isempty(NameValueArgs.ExperimentMonitor))
    monitor = NameValueArgs.ExperimentMonitor;
    configureMonitor(monitor,networkTrainer,options.ValidationData,metrics,logger);
end

if options.Plots == "training-progress"
    monitor = trainingProgressMonitor();
    
    monitor.Info = ["Epoch","Iteration","LearnRate"];
    monitor.XLabel = "Iteration";
    configureMonitor(monitor,networkTrainer,options.ValidationData,metrics,logger);
end

if ~isempty(options.ValidationData)   
   if isfinite(options.ValidationPatience)
       metricNames = iGetMetricNames(metrics);
       metricNames = horzcat(metricNames{:});
       needToMaximizeMetric = metrics{metricNames==objectiveMetricName}.Maximize;
       patienceManager = ValidationPatienceManager(options.ValidationPatience,needToMaximizeMetric);
       addlistener(logger,'LogUpdate',@(hobj,evt) step(patienceManager,evt.MetricsStruct.("Validation"+objectiveMetricName),evt));
       addlistener(patienceManager,'ValidationPatienceStopTraining',@(hobj,evt) stop(networkTrainer));
       if options.Plots == "training-progress"
            addlistener(patienceManager,'ValidationPatienceStopTraining',@(hobj,evt) stop(monitor,getString(message('images:dltrain:validationPatienceReached')))); 
       end
   end
end

% OutputFcn
if ~isempty(options.OutputFcn)
    addlistener(logger,'LogUpdate',@(hobj,evt) iCallOutputFcn(options.OutputFcn,networkTrainer,evt));
end

% CheckpointPath
if ~isempty(options.CheckpointPath)
    checkpointSaver = CheckpointSaver(options.CheckpointPath,options.CheckpointFrequency,options.CheckpointFrequencyUnit);
    if options.CheckpointFrequencyUnit == "epoch"
        addlistener(networkTrainer,'EpochEnd',@(trainer,evtData) saveCheckpoint(checkpointSaver,evtData.Network,evtData));
    elseif options.CheckpointFrequencyUnit == "iteration"
        addlistener(networkTrainer,'IterationEnd',@(trainer,evtData) saveCheckpoint(checkpointSaver,evtData.Network,evtData));
    else
        assert(false,"Unexpected CheckpointFrequencyUnit option in trainingOptions.");
    end
end

% OutputNetwork. Return the OutputNetwork according to trainingOptions.
% Populate an OutputNetworkIteration field in the output struct array as a
% logical based on whether an iteration is where the BestNetwork was
% computed.
net = fit(networkTrainer);
info = logger.MetricLog;
info = arrayfun(@(s) setfield(s,'OutputNetworkIteration',false),info);

outputNetworkOption = options.OutputNetwork;
if outputNetworkOption == "auto"
    if ~isempty(options.ValidationData)
        outputNetworkOption = "best-validation";
    else
        outputNetworkOption = "last-iteration";
    end
elseif outputNetworkOption == "best-validation-loss"
    outputNetworkOption = "best-validation";
end

if outputNetworkOption == "last-iteration"
    info(end).OutputNetworkIteration = true;
elseif outputNetworkOption == "best-validation"
    net = logger.BestNetwork;
    info([info.Iteration] == logger.BestNetworkIteration).OutputNetworkIteration = true;
else
    assert(false,"Unexpected OutputNetwork value in trainingOptions.");
end

end

function configureMonitor(monitor,networkTrainer,validationData,metrics,logger)

addlistener(monitor, 'Stop', 'PostSet',@(~,~) stopTraining(networkTrainer, monitor));

metricNamesCell = iGetMetricNames(metrics);
isValidationOnlyMetric = cellfun(@(f) isa(f,'images.dltrain.internal.Metric') && f.ValidationOnly, metrics);
monitorMetrics = metricNamesCell(~isValidationOnlyMetric);
monitorMetrics = horzcat(monitorMetrics{:});
monitorMetrics = "Training" + monitorMetrics;

if(~isempty(validationData))
    monitorMetrics = [monitorMetrics,"Validation"+horzcat(metricNamesCell{:})];
    monitor.Metrics = monitorMetrics;
    for idx = 1:length(metrics)
        metricName = metrics{idx}.Name;
        for m = 1:length(metricName)
            if ~isValidationOnlyMetric(idx)
                monitor.groupSubPlot(metricName(m), ["Training"+metricName(m),"Validation"+metricName(m)]);
            end
        end
    end
else
    monitor.Metrics = monitorMetrics;
end
addlistener(logger,'LogUpdate',@(logger,evtData) updateProgressMonitor(evtData,monitor,networkTrainer));
end

function stopTraining(networkTrainer, monitor)
stop(networkTrainer);

% The trainingProgressMonitor depends on listening to the Stop property
% getter to detect when the user stops training and disable the button.
% If we don't detect the Stop getter, the stop button will keep spinning
% forever. However, this assumes the user is doing the following: 
% if monitor.Stop then break. Because dltrain listens to the PostSet event 
% instead. We need to trigger the Stop getter to ensure the stop button gets
% diabled.
monitor.Stop;
end

function updateProgressMonitor(evtData, monitor, trainer)

    % The progress monitor can't take missing values in recordMetrics, so
    % cull the event data so that only metrics that we actually have good
    % data for are part of the recordMetrics call. (i.e. validation metrics
    % are often missing according to ValidationFrequency).
    metricArgList = {};
    for i=1:2:numel(monitor.Metrics)*2
        metricName = monitor.Metrics(ceil(i/2));
        if ~isnan(evtData.MetricsStruct.(metricName))
            metricArgList(end+1:end+2) = {metricName,evtData.MetricsStruct.(metricName)};
        end
    end

    recordMetrics(monitor,evtData.MetricsStruct.Iteration, ...
                   metricArgList{:});

    if isa(monitor,'deep.TrainingProgressMonitor')
        updateInfo(monitor,"Epoch",evtData.MetricsStruct.Epoch,...
            "Iteration",evtData.MetricsStruct.Iteration, ...
            "LearnRate",evtData.MetricsStruct.LearnRate);
    end

    % Set experiment progress
    monitor.Progress = (evtData.MetricsStruct.Epoch/trainer.TrainingOptions.MaxEpochs)*100;

end

function [outputEnvironment,useGPU] = iGetOutputEnvironment(executionEnvironment)
% Bind the training options environment to the appropriate output
% environment for minibatchqueue. Also return logical of whether or not GPU
% is being used.

if (executionEnvironment == "parallel") || (executionEnvironment == "cpu")
    outputEnvironment = "cpu";
    useGPU = false;
elseif executionEnvironment == "auto"
    outputEnvironment = "auto";
    useGPU = canUseGPU();
else
    outputEnvironment = "gpu";
    useGPU = true;
end

end

function iCallOutputFcn(outputFcn,trainer,evtData)
if outputFcn(evtData.MetricsStruct)
    stop(trainer);
end
end

function iMustBeValidLossMetricName(metrics,lossMetricName)
metricNames = iGetMetricNames(metrics);
metricNames = horzcat(metricNames{:});
validatestring(lossMetricName,metricNames);
end

function names = iGetMetricNames(metrics)
names = cellfun(@(c) reshape(c.Name,1,[]),metrics,UniformOutput=false);
end

function validationQueue = iCreateValidationQueue(dsVal,mbqtrain,validationBatchSize)
validationQueue = minibatchqueue(dsVal,mbqtrain.NumOutputs,...
    'MiniBatchSize',validationBatchSize,...
    'MiniBatchFcn', mbqtrain.MiniBatchFcn,...
    'OutputCast', mbqtrain.OutputCast,...
    'OutputAsDlarray', mbqtrain.OutputAsDlarray,...
    'DispatchInBackground',mbqtrain.DispatchInBackground,...
    'MiniBatchFormat',mbqtrain.MiniBatchFormat,...
    'OutputEnvironment',mbqtrain.OutputEnvironment,...
    'PreprocessingEnvironment',mbqtrain.PreprocessingEnvironment);
end

function iValidateSupportedTrainingOptions(options)

if ~isempty(options.WorkerLoad) && ~all(options.WorkerLoad(1) == options.WorkerLoad)
    error(messages('images:dltrain:trainingOptionsWorkerLoad'))
end

if options.BatchNormalizationStatistics == "population"
    error(message('images:dltrain:trainingOptionsBatchNormalizationStatistics'));
end

if options.ResetInputNormalization
    error(message('images:dltrain:trainingOptionsResetInputNormalization'));
end

if options.DispatchInBackground && any(options.ExecutionEnvironment == ["multi-gpu","parallel"])
    error(message('images:dltrain:dispatchInBackgroundWithParallelTraining'));
end

if (options.OutputNetwork == "best-validation-loss") && isempty(options.ValidationData)
    error(message('images:dltrain:bestValidationLossRequiresValidationData'));
end

end

function TF = isValidLoss(loss)
    TF = isa(loss,'function_handle') || isa(loss,'images.dltrain.internal.Loss');
end

function TF = isValidMetricsCell(metrics)
    allMetricObjectsInList = all(cellfun(@(c) isa(c,'deep.Metric'),metrics));
    TF = true;
    if allMetricObjectsInList
        names = cellfun(@(c) reshape(string(c.Name),1,[]),metrics,UniformOutput=false);
        names = horzcat(names{:});
        uniqueNames = unique(names);
        assert(length(uniqueNames)==length(names),"metrics may not have duplicate Name property");
    else
        TF = false;
    end
end


function metrics = iConvertMetricsToCellOfMetricObjectsForm(metrics)
    if ~isa(metrics,'cell')
        metrics = {metrics};
    end

    stringConverter = nnet.internal.cnn.util.StringToMetricObjectConverter;

    for idx = 1:length(metrics)
        thisMetric = metrics{idx};
        if isa(thisMetric,"function_handle")
            thisMetric = deep.internal.metric.FunctionMetric(thisMetric,fun2str(thisMetric));
        elseif isa(thisMetric,'char') || isa(thisMetric,"string")
            thisMetric = stringConverter.getMetricObject(thisMetric);
        else
            % no-op
        end
        metrics{idx} = thisMetric;
    end
end