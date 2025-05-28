function stats = computeNormalizationStats(mbq,mbqVarIndices,executionEnvironment, computationType,NV)

% Copyright 2021-2024 The MathWorks, Inc.

arguments
    mbq minibatchqueue
    mbqVarIndices {mustBeNumeric,mustBePositive,mustBeReal}
    executionEnvironment string {mustBeMember(executionEnvironment,["auto","parallel","gpu","cpu","multi-gpu"])} = "auto";
    computationType string {mustBeMember(computationType,["single","double"])} = "single";
    NV.NormalizationDimension string {mustBeMember(NV.NormalizationDimension,["channel","element"])} = "element";
end

mbqStats = copy(mbq);
mbqStats.PartialMiniBatch = 'return'; % Compute all the data
% Configure the mbq used for batching to the correct cpu vs. gpu state for
% the specified execution environment. The parallel vs. serial algorithm
% concern is managed separately.
if any(executionEnvironment == ["parallel","cpu"])
    mbqStats.OutputEnvironment = "cpu";
elseif any(executionEnvironment == ["gpu","multi-gpu"])
    mbqStats.OutputEnvironment = "gpu";
elseif executionEnvironment == "auto"
    mbqStats.OutputEnvironment = "auto";
else
    assert(false,"Unexpected execution environment");
end

batch = cell(1,mbqStats.NumOutputs);
[batch{:}] = next(mbqStats);
reset(mbqStats);

for idx = 1:numel(mbqVarIndices)
    assert(~isempty(batch{mbqVarIndices(idx)}.dims),'Input data must be labeled');
end

batch = batch(mbqVarIndices);
inputSizes = cellfun(@(x) size(x,1:finddim(x,'B')-1),batch,'UniformOutput',false);
spatialDims = cellfun(@(x) finddim(x,'S'),batch,UniformOutput=false);

% A dependency on the internal interface Accumulator and Accumulator
% factory and the precision object. This would need to go in the SDK to be used long term.
outputType = nnet.internal.cnn.util.Precision(computationType);
accumulator = nnet.internal.cnn.statistics.AccumulatorFactory.create(inputSizes,outputType);

if ismember(executionEnvironment,["parallel","multi-gpu"])
    accumulator = iComputeStatsParallel(mbqStats,batch,accumulator,mbqVarIndices,executionEnvironment);
else
    accumulator = iComputeStats(mbqStats,batch,accumulator,mbqVarIndices);
end

% Return a cell representation of the stats to avoid leaking the internal
% APIs we use to compute normalization stats.
numVars = length(accumulator);
stats = struct('Min',0,'Max',0,'Mean',0,'Std',0);
f = string(reshape(fields(stats),1,[]));
stats = repmat(stats,numVars);
for idx = 1:length(accumulator)
    for thisField = f
        statValue = getStatistic(accumulator{idx},thisField);
        if NV.NormalizationDimension == "channel"
            if thisField ~= "Std"
                statValue = iReduceSpatialDimensions(statValue,thisField,spatialDims{idx});
            else
                statValue = nnet.internal.cnn.layer.util.computeMeanOfStds(statValue,getStatistic(accumulator{idx},"Mean"),spatialDims{idx});
            end
        end
        stats(idx).(thisField) = gather(statValue);
    end
end

end

function valOut = iReduceSpatialDimensions(valIn,statName,spatialDims)

switch lower(statName)
    case "min"
        valOut = min(valIn,[],spatialDims);
    case "max"
        valOut = max(valIn,[],spatialDims);
    case "mean"
        valOut = mean(valIn,spatialDims);
    otherwise
        assert(false,"unexpected statistic name to reduce.");
end
end

function accumulator = iComputeStatsParallel(mbqStats,batch,accumulator,indices,executionEnvironment)
% Most basic possible parallel implementation. Balanced partition of data
% and merge individual accumulators when done. When this is folded into
% dltrain, would probably want to honor WorkerLoad here.

import images.dltrain.internal.*

pool = getParallelPool(executionEnvironment == "multi-gpu");
numWorkers = pool.NumWorkers;
perWorkerBatchSize = max(1,floor(mbqStats.MiniBatchSize/numWorkers));
deep.internal.sdk.setMiniBatchSize(mbqStats,perWorkerBatchSize);

spmd
    mbq = partition(mbqStats,numWorkers,spmdIndex);
    accumulator = iComputeStats(mbq,batch,accumulator,indices);
    accumulator = spmdReduce(@iMergeEachVariableInAccumulators,accumulator,1);
end

% Merge stats in the individual accumulators
accumulator = accumulator{1}; % Return the merged accumulator cell array;
end

function accumulator = iComputeStats(mbqStats,batch,accumulator,indices)
while hasdata(mbqStats)
   [batch{:}] = next(mbqStats);
   batch = batch(indices);
   for idx = 1:length(accumulator)
      % Some of the stats internal functions rely on 'omitman' which is
      % currently unsupported for dlarray inputs.
      batchVar = {extractdata(batch{idx})};
      accumulator{idx} = accumulate(accumulator{idx},batchVar);
   end 
end
end

function out = iMergeEachVariableInAccumulators(acc1Cell,acc2Cell)
% In the general case for N inputs, acc1Cell and acc2cell will be N length
% cell arrays of accumulators that have been computed on each worker.
% Return a cell array of merged accumulators in which the variables in the
% input accum cell array have been merged per variable.

assert(isequal(length(acc1Cell),length(acc2Cell)),'Expect cell arrays to be of same length');
numVars = length(acc1Cell);
out = cell(1,numVars);
for idx = 1:numVars
    out{idx} = merge(acc1Cell{idx},acc2Cell{idx});
end
end