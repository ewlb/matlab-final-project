classdef ParallelTrainer < handle
    % Network trainer for parallel training in dltrain

    %   Copyright 2021-2022 The MathWorks, Inc.

    properties (SetAccess = private)
        Network
        LossFcn
        IterationCount double
        EpochCount double
        TrainingOptions {isa(TrainingOptions,'nnet.cnn.TrainingOptions')}
        StartTime uint64
    end

    properties (Access = private)
        DataQueue minibatchqueue
        Solver
        UseGPU logical
        L2RegularizationFactors
        StopTrainingQueue parallel.pool.PollableDataQueue
        LRScheduler
    end

    events
        IterationEnd
        EpochEnd
        TrainingEnd
    end

    methods

        function self = ParallelTrainer(trainQueue,network,lossFcn,options,useGpu)
            self.DataQueue = copy(trainQueue);
            self.LossFcn = lossFcn;
            self.Network = network;
            self.Solver = images.dltrain.internal.solverFactory(options);
            self.LRScheduler = deep.internal.learnrate.createLearnRateSchedule(options);
            self.TrainingOptions = options;
            self.IterationCount = 0;
            self.EpochCount = 1;
            self.UseGPU = useGpu;
            self.L2RegularizationFactors = images.dltrain.internal.buildL2FactorPerLearnable(network.Layers,network.Learnables,options.L2Regularization);
        end

        function stop(self)
            send(self.StopTrainingQueue,'stop');
        end

        function net = fit(self)

            import images.dltrain.internal.*

            % Always start from begin of queue
            reset(self.DataQueue);

            % Make sure full datastore is shuffled prior to partitioning.
            if self.TrainingOptions.Shuffle ~= "never"
                shuffle(self.DataQueue);
            end

            myPool = getParallelPool(self.UseGPU);
            numWorkers = myPool.NumWorkers;

            % Make sure minibatchsize is greater than or equal to the
            % number of workers.
            if self.TrainingOptions.MiniBatchSize<numWorkers
                error(message('images:dltrain:miniBatchSizeSmallerThanNumWorkers'));
            end

            % This assumes uniform WorkerLoad: In the future this will need
            % to be abstracted.
            workerMiniBatchSize = floor(self.TrainingOptions.MiniBatchSize ./ repmat(numWorkers,1,numWorkers));
            remainder = self.TrainingOptions.MiniBatchSize - sum(workerMiniBatchSize);
            workerMiniBatchSize = workerMiniBatchSize + [ones(1,remainder) zeros(1,numWorkers-remainder)];

            % Create a DataQueue on the client side. This is used to push
            % information from the workers to the client side to be then
            % rebroadcast from the client side to maintain the same events
            % interface for the ParallelTrainer and SerialTrainer.
            eventQueue = parallel.pool.DataQueue;
            afterEach(eventQueue,@(x) notify(self,x{end},IterationEndEventData(x{1:end-1})));

            % Create another DataQueue on the workers side. This is used
            % solely to push stop training requests from the client to the
            % workers.
            spmd
                stopTrainingEventQueue = parallel.pool.PollableDataQueue;
            end

            %Cache stop queue for just worker 1 on client side, we just need
            % to be able to communicate with one worker to signal stop.
            self.StopTrainingQueue = stopTrainingEventQueue{1};

            spmd

                % Partition the mini batch queue on each worker and set the
                % mini batch size appropriately.
                workerDataQueue = partition(self.DataQueue,numWorkers,spmdIndex);
                deep.internal.sdk.setMiniBatchSize(workerDataQueue,workerMiniBatchSize(spmdIndex));

                workerNet = self.Network;

                batch = cell(1,workerDataQueue.NumOutputs);
                numNetworkInputs = numel(self.Network.InputNames);
                numNetworkOutputs = numel(self.Network.OutputNames);
                self.IterationCount = 0;
                self.EpochCount = 1;

                clipGradientsFun = images.dltrain.internal.gradientThresholderFactory(self.TrainingOptions.GradientThresholdMethod,self.TrainingOptions.GradientThreshold);
                l2Regularizer = l2RegularizationFactory(self.TrainingOptions.L2Regularization);

                self.StartTime = tic;

                % Since the only real client in the system now ultimately is
                % the verbose output listening to the log, we only need to
                % broadcast events from the workers at the rate of the
                % verbose frequency, or the CheckpointFrequency, whichever smaller, as a performance optimization. Revisit
                % this when we add plotting/etc. Ideally would prefer to not
                % be culling events.
                iterationEventFrequency = self.TrainingOptions.VerboseFrequency;
                if self.TrainingOptions.CheckpointFrequencyUnit == "iteration"
                    iterationEventFrequency = min(iterationEventFrequency,self.TrainingOptions.CheckpointFrequency);
                end

                stopRequested = false;
                for epoch = 1:self.TrainingOptions.MaxEpochs

                    while spmdReduce(@and,hasdata(workerDataQueue)) && ~stopRequested
                        [batch{:}] = next(workerDataQueue);
                        inputs = batch(1:numNetworkInputs);
                        targets = batch(numNetworkInputs+1:end);
                        [loss,grad,state,networkOutputs,lossData] = dlfeval(@modelGradients,workerNet,self.LossFcn,...
                            numNetworkOutputs,inputs,targets,...
                            self.L2RegularizationFactors,...
                            clipGradientsFun,numWorkers,l2Regularizer);

                        self.IterationCount = self.IterationCount + 1;

                        [self.LRScheduler,self.Solver.LearnRate] = deep.internal.learnrate.Utilities.safelyUpdate(self.LRScheduler,...
                            self.TrainingOptions.InitialLearnRate,...
                            self.IterationCount,...
                            self.EpochCount);

                        % grad and state are already syncronized at this
                        % point within dlfeval above
                        workerNet = self.Solver.update(workerNet,grad);

                        workerNet.State = state;

                        stopRequested = spmdPlus(stopTrainingEventQueue.QueueLength) > 0;

                        if spmdIndex == 1

                            isValidationIteration = ~isempty(self.TrainingOptions.ValidationData) &&...
                                (~mod(self.IterationCount,self.TrainingOptions.ValidationFrequency) ||...
                                (self.IterationCount == 1) ||...
                                stopRequested);

                            % Broadcast if it is a validation iteration or if we need to based on iterationEventFrequency
                            % used to throttle data send over queue.
                            broadcastEvent = isValidationIteration || (~mod(self.IterationCount,iterationEventFrequency) || (self.IterationCount == 1));
           
                            if broadcastEvent
                                data = iIterationEndEventDataCell(self.IterationCount,loss,...
                                    networkOutputs,targets,workerNet,self.EpochCount,...
                                    self.TrainingOptions.MaxEpochs,self.StartTime,isValidationIteration,'IterationEnd',...
                                    lossData,self.Solver.LearnRate);

                                send(eventQueue,data)
                            end
                        end
                    end

                    self.EpochCount = self.EpochCount + 1;

                    if spmdIndex == 1
                        data = iIterationEndEventDataCell(self.IterationCount,...
                            loss,networkOutputs,targets,workerNet,self.EpochCount,...
                            self.TrainingOptions.MaxEpochs,self.StartTime,false,'EpochEnd',...
                            lossData,self.Solver.LearnRate);

                        send(eventQueue,data);
                    end

                    if stopRequested
                        % If stop was called on the trainer, break out of
                        % the epoch loop.
                        break;
                    else
                        % Manage shuffle state of the data to prepare for
                        % more epochs
                        reset(workerDataQueue);
                        if self.TrainingOptions.Shuffle == "every-epoch"
                            shuffle(workerDataQueue);
                        end
                    end
                end % foreach epoch

                if spmdIndex == 1
                    data{end} = 'TrainingEnd';
                    send(eventQueue,data);
                end
            end
            net = workerNet{1};
        end

    end

    methods (Static) 

        function state = aggregateState(state,factor)
            % Static to make unit testable

            numrows = size(state,1);

            j = 1;
            while j <= numrows
                isBatchNormalizationState = state.Parameter(j) == "TrainedMean"...
                    && state.Parameter(j+1) == "TrainedVariance"...
                    && state.Layer(j) == state.Layer(j+1);

                if isBatchNormalizationState
                    meanVal = state.Value{j};
                    varVal = state.Value{j+1};

                    % Calculate combined mean
                    combinedMean = spmdPlus(factor*meanVal);

                    % Caclulate combined variance terms to sum
                    combinedVarTerm = factor.*(varVal + (meanVal - combinedMean).^2);

                    % Update state
                    state.Value{j} = combinedMean;
                    state.Value{j+1} = spmdPlus(combinedVarTerm);
                    j = j+2;
                else
                    % Other kinds of state, just use simple mean.
                    state.Value{j} = weightedSumAggregationFcn(state.Value{j},factor);
                    j = j+1;
                end
            end
        end
    end
end

function [loss,grad,state,networkOutputs,lossData] = modelGradients(net,...
    lossFcn,numNetworkOutputs,inputs,targets,regularizationFactors,clipGradients,...
    numWorkers,l2Regularizer)
% Expects lossFcn of the form: loss =
% lossFcn(Y1act,Y2act,YNact,Y1exp,Y2exp,YNexp).
%
% Order of inputs and outputs is are described by net.InputNames and
% net.OutputNames.

networkOutputs = cell(1,numNetworkOutputs);
[networkOutputs{:},state] = forward(net,inputs{:});

if isa(lossFcn,'images.dltrain.internal.Loss')
    [loss,lossData] = lossFcn.lossFcn(networkOutputs{:},targets{:});
else % a function
    loss = lossFcn(networkOutputs{:},targets{:});
    lossData = struct([]);
end

grad = dlgradient(loss,net.Learnables);

% Aggregate loss, state, and gradients
weightingFactor = 1/numWorkers;

% Take the mean of the loss across the workers
loss = weightedSumAggregationFcn(loss,weightingFactor);
updateFcn = @(x) weightedSumAggregationFcn(x,weightingFactor);

% Take the mean of the gradients across the workers
grad = dlupdate(updateFcn,grad);

% Aggregate state across the workers
state = images.dltrain.internal.ParallelTrainer.aggregateState(state,weightingFactor);

% Apply L2 regularization to gradients
grad = l2Regularizer(grad,net.Learnables,regularizationFactors);

% Apply gradient clipping
grad = clipGradients(grad);

% Aggregate lossData
if ~isempty(lossData)
    lossData = structfun(@(x) weightedSumAggregationFcn(x,weightingFactor),lossData,'UniformOutput',false);
end

end

function x = weightedSumAggregationFcn(x,factor)
x = spmdPlus(iExtractData(x) * factor);
end

function s = iIterationEndEventDataCell(iterationCount,loss,...
    networkOutputs,targets,workerNet,epochCount,...
    maxEpochs,startTime,validationData,eventType,...
    lossData,learnRate)

s = {iterationCount,loss,networkOutputs,targets,workerNet,epochCount,...
    maxEpochs,startTime,validationData,lossData,learnRate,eventType};

end

function v = iExtractData(v)
if isa(v,'dlarray')
    v = extractdata(v);
end
end





