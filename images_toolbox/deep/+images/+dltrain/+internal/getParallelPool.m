function pool = getParallelPool(useGPU)
% Have requested an SDK version of this function already:
% g2430439

% Default to open pool if available
pool = gcp('nocreate');

if isempty(pool)
    if useGPU
        availableGpus = nnz(parallel.gpu.GPUDevice.isAvailable(1:gpuDeviceCount));
        numGpus = max(1, availableGpus);
        pool = parpool('local',numGpus); % As many local workers as available GPUs
    else
        pool = parpool(); % Use default pool.
    end
end
end