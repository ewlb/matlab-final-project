/* Copyright 2018-2022 The MathWorks, Inc. */


#ifndef BWLABEL_CUDA_HPP
#define BWLABEL_CUDA_HPP

#ifdef MATLAB_MEX_FILE
#include "tmwtypes.h"
#else
#include "rtwtypes.h"
#endif

#include "MWPtxUtils.hpp"

#include <cuda.h>
#include <stdio.h>

template<typename T>
const std::vector<const char*>& bwlabel_cuda_ptx_kernels();

const char* bwlabel_cuda_ptx_data();

static const dim3 threads1(256, 1, 1);

// faster to do all internal computations in 32bit and output 64bit final
static const dim3 threads2(32, 8); 

// Divide and round up
template<typename T>
__device__ __host__
static inline T divup(T const n, uint32_T const threads) {
    return (n + threads - 1) / threads;
}

template<typename T>
void bwlabel_cuda(double* d_labels_final,
                  double* d_num,
                  uint32_T* d_labels,
                  uint32_T* d_packing,
                  T* d_bw,
                  uint32_T nhood,
                  uint32_T nx,
                  uint32_T ny) {
    enum {
        InitializeKernel = 0,
        ScanningTrueKernel,
        ScanningFalseKernel,
        AnalysisKernel,
        PartialSumTrueKernel,
        PartialSumFalseKernel,
        FullSumKernel,
        FinalizeKernel
    };

    // load kernel
    static const char* ptxData = bwlabel_cuda_ptx_data();
    using nonConstT = typename std::remove_const<T>::type;
    static const std::vector<const char*>& kernelNames = bwlabel_cuda_ptx_kernels<nonConstT>();
    static CUmodule module;
    static std::vector<CUfunction> kernels;
    mw_ptx_utils::initialize(ptxData, kernelNames, module, kernels);
    
    CUdeviceptr d_modifiedPtr;
    size_t d_modifiedPtr_sz;
    cuModuleGetGlobal(&d_modifiedPtr, &d_modifiedPtr_sz, module, "d_modified");

    // calculate launch patterns
    uint32_T numel = nx * ny;
    uint32_T work = 16; // each thread does this much work
    uint32_T num_blocks = divup(numel, (work * threads1.x)); // total blocks required for this factor
    uint32_T blocks_y = divup(num_blocks, (256 * 256 - 1)); // avoid 64k grid boundary
    dim3 blocks1(divup(num_blocks, blocks_y), blocks_y); // 1D launches
    dim3 blocks2(divup(nx, threads2.x), divup(ny, threads2.y)); // 2D launches

    // initialize label fields
    void* initialize_args[] = {&d_labels, &d_bw, &numel};
    mw_ptx_utils::launchKernelWithCheck(kernels[InitializeKernel],
                                        blocks1, threads1,
                                        initialize_args);

    // flag: nonzero if modification made during pass, so need to iterate again
    uint32_T h_modified = 0;
    bool is8 = (nhood == 8);

    do {
        // scanning local neighborhood (set modified flag?)
        void* scanning_args[] = {&d_labels, (void*)&nx, (void*)&ny};
        if (is8) {
            mw_ptx_utils::launchKernelWithCheck(kernels[ScanningTrueKernel],
                                                blocks2, threads2,
                                                scanning_args);
        } else {
            mw_ptx_utils::launchKernelWithCheck(kernels[ScanningFalseKernel],
                                                blocks2, threads2,
                                                scanning_args);
        }

        // check if anything modified
        cuMemcpyDtoH(&h_modified, d_modifiedPtr, sizeof(uint32_T));

        // resolve root and update labels (reset flag)
        void *analysis_args[2] = {&d_labels, &numel};
        mw_ptx_utils::launchKernelWithCheck(kernels[AnalysisKernel],
                                            blocks1, threads1,
                                            analysis_args);

    } while (h_modified);

    // inclusive scan to determine packed labels

    // safe to use final output for the intermediate block sums (we
    // are done with this scratch before final write)
    uint32_T* d_blocksums = reinterpret_cast<uint32_T*>(d_labels_final);

    // cumulative sum within each block
    void* partial_sumFP_args[] = {&d_packing, &d_labels, &d_blocksums, &numel, &work};
    mw_ptx_utils::launchKernelWithCheck(kernels[PartialSumTrueKernel],
                                        blocks1, threads1,
                                        partial_sumFP_args);

    // cumulative sum across all blocks
    void* tmpVal = NULL;
    size_t tmpVal1 = (num_blocks + 1);
    size_t tmpVal2 = divup(num_blocks + 1, threads1.x);

    void* partial_sumSP_args[] = {&d_blocksums, &d_blocksums, &tmpVal, &tmpVal1, &tmpVal2};
    mw_ptx_utils::launchKernelWithCheck(kernels[PartialSumFalseKernel],
                                        dim3(1,1,1), threads1,
                                        partial_sumSP_args);

    // redistribute partial sums across all blocks
    void* full_sum_args[] = {&d_packing, &d_blocksums, &numel, &work};
    mw_ptx_utils::launchKernelWithCheck(kernels[FullSumKernel],
                                        blocks1, threads1,
                                        full_sum_args);

    // finalize labels into double-precision output
    void* finalize_args[] = {&d_labels_final, &d_num, &d_labels, &d_packing, &numel};
    mw_ptx_utils::launchKernelWithCheck(kernels[FinalizeKernel],
                                        blocks1, threads1,
                                        finalize_args);
}

#endif // BWLABEL_CUDA_HPP
