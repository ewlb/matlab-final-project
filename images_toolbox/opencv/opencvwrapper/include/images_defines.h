// Copyright 2023 The MathWorks, Inc.
#ifndef images_defines_h
#define images_defines_h

/* All symbols in this module are intentionally exported. */
#ifdef _MSC_VER
#define LIBMWIPTRT_API __declspec(dllexport)
#else
#define LIBMWIPTRT_API
#endif

#ifndef EXTERN_C
#  ifdef __cplusplus
#    define EXTERN_C extern "C"
#  else
#    define EXTERN_C extern
#  endif
#endif

#ifdef MATLAB_MEX_FILE
    #include "tmwtypes.h" /* mwSize is defined here */
#else
#include "stddef.h"
typedef size_t mwSize;  /* unsigned pointer-width integer */

#include "rtwtypes.h"
#endif

#endif
