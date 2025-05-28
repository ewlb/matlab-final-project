// Copyright 2013-2019 The MathWorks, Inc.

#ifndef IMRECONSTRUCT_CUDA_HPP
#define IMRECONSTRUCT_CUDA_HPP

#include "MWPtxUtils.hpp"
#include "gpu_imreconstruct_types.hpp"
#include "smemutil.hpp"

#ifdef MATLAB_MEX_FILE
#include "tmwtypes.h"
#else
#include "rtwtypes.h"
#endif

#include <assert.h>
#include <cuda.h>
#include <stdio.h>

//Number of threads is tied to the datatype.
//Use a template struct to enforce this relation.
template<typename T>
struct NumThreads{ static const size_t value = 32;};

// Instantiate number of threads
template<> struct NumThreads<bool>{ static const size_t value = 64;};
template<> struct NumThreads<uint8_T>{ static const size_t value = 64;};
template<> struct NumThreads<int8_T>{ static const size_t value = 64;};
template<> struct NumThreads<uint16_T>{ static const size_t value = 64;};
template<> struct NumThreads<int16_T>{ static const size_t value = 64;};
template<> struct NumThreads<uint32_T>{ static const size_t value = 32;};
template<> struct NumThreads<int32_T>{ static const size_t value = 32;};
template<> struct NumThreads<real32_T>{ static const size_t value = 32;};
template<> struct NumThreads<real64_T>{ static const size_t value = 32;};

template<typename T>
const std::vector<const char*>& imreconstruct_cuda_ptx_kernels();

const char* imreconstruct_cuda_ptx_data();


template <typename T>
void imreconstruct_cuda(
        T const * const dMarker,
        T const * const dMask,
        size_t    const nX,
        size_t    const nY,
        real64_T  const conn,
        T       * const dResult
){
    
    static const std::vector<const char*>& mangledNames = imreconstruct_cuda_ptx_kernels<T>();
    static const char* ptxData = imreconstruct_cuda_ptx_data();
    static CUmodule module;
    static std::vector<CUfunction> kernels;
    mw_ptx_utils::initialize(ptxData, mangledNames, module, kernels);

    // Eg - 32 threads copy a region of 32x32 to smem. Only 30x30 (tile size) will have full nhoods.
    static const size_t TILESIZE = (NumThreads<T>::value-2);

    dim3 threadsPerBlock(NumThreads<T>::value);
    dim3 blocksPerGrid(uint16_T((nX+TILESIZE-1)/TILESIZE), uint16_T((nY+TILESIZE-1)/TILESIZE));

    // Number of tiles in image (including partial ones on right and bottom edges)
    const size_t numTiles       = ((nX+TILESIZE-1)/TILESIZE) * ((nY+TILESIZE-1)/TILESIZE);
    const size_t numTilesInX    = ((nX+TILESIZE-1)/TILESIZE);

    uint32_T* dProcessTileFlag = NULL;
    cudaMalloc(&dProcessTileFlag,    sizeof(uint32_T)*numTiles);
    
    // A value of 1 indicates that the corresponding tile needs to be processed
    cudaMemset( dProcessTileFlag, 1, sizeof(uint32_T)*numTiles);
    
    uint32_T* dGlobalChange = NULL;
    cudaMalloc(&dGlobalChange, sizeof(uint32_T));
    
    //Initialize output, computation happens in place in the dResult variable.
    cudaMemcpy((void*)dResult, (const void*)dMarker, sizeof(T)*nX*nY, cudaMemcpyDeviceToDevice);
    

    uint32_t globalChange = 1;

    if(conn==8){
        while(globalChange){
            //Re-launch kernel till whole image stabilizes
           cudaMemset( dGlobalChange, 0, sizeof(uint32_T));
           
            void* conn8KernelArgs[] = {(void*)&dResult, (void*)&dMask, (void*)&nX, (void*)&nY, 
                                       (void*)&dProcessTileFlag, (void*)&numTiles, (void*)&numTilesInX, (void*)&dGlobalChange}; 
           
            mw_ptx_utils::launchKernelWithCheck(kernels[CONN8], blocksPerGrid, threadsPerBlock, conn8KernelArgs, 0, NULL, NULL);                                                

            cudaDeviceSynchronize();

            // Read status of global change flag from device back to CPU to decide if we need to re-launch kernel.
            cudaMemcpy((void*)&globalChange,(const void*)dGlobalChange, sizeof(uint32_T), cudaMemcpyDeviceToHost);
            
        }
    }else if(conn==4){
        while(globalChange){
            cudaMemset( dGlobalChange, 0, sizeof(uint32_T));
            
            void* conn4KernelArgs[] = {(void*)&dResult, (void*)&dMask, (void*)&nX, (void*)&nY, 
                                       (void*)&dProcessTileFlag, (void*)&numTiles, (void*)&numTilesInX, (void*)&dGlobalChange}; 
           
            mw_ptx_utils::launchKernelWithCheck(kernels[CONN4], blocksPerGrid, threadsPerBlock, conn4KernelArgs, 0, NULL, NULL);

            cudaDeviceSynchronize();

            cudaMemcpy((void*)&globalChange,(const void*)dGlobalChange, sizeof(uint32_T), cudaMemcpyDeviceToHost);
            
        }
    }else{
        //Unsupported connectivity
        assert(false);
    }

    cudaFree(dProcessTileFlag);
    cudaFree(dGlobalChange);
}

#endif
