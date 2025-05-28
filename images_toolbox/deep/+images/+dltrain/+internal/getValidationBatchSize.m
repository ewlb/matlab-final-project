function validationBatchSize = getValidationBatchSize(isParallelTraining,useGpu,miniBatchSize)

%   Copyright 2022 The MathWorks, Inc.

if isParallelTraining
    myPool = images.dltrain.internal.getParallelPool(useGpu);
    numWorkers = myPool.NumWorkers;
    % Since we currently only use one worker for evaluating the validation
    % set, we need to adjust the batch size to be a proportional to one
    % worker, otherwise we risk out of memory.
    if miniBatchSize<numWorkers
        error(message('images:dltrain:miniBatchSizeSmallerThanNumWorkers'));
    else
        validationBatchSize = floor(miniBatchSize/numWorkers);
    end
else
    validationBatchSize = miniBatchSize;
end
end