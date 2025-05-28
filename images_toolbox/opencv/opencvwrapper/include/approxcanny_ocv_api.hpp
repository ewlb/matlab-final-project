/* Copyright 2023 The MathWorks, inc. */
#ifndef _APPROXCANNY_OCV_
#define _APPROXCANNY_OCV_

#ifndef EXTERN_C
#  ifdef __cplusplus
#    define EXTERN_C extern "C"
#  else
#    define EXTERN_C extern
#  endif
#endif

#include "images_defines.h"


EXTERN_C LIBMWIPTRT_API
void canny_uint8_ocv(const uint8_T*,
                     int32_T,
                     int32_T,
                     real64_T,
                     real64_T,
                     uint8_T* dst);

EXTERN_C LIBMWIPTRT_API
void canny_uint8_ocv_RM(const uint8_T*,
                        int32_T,
                        int32_T,
                        real64_T,
                        real64_T,
                        uint8_T* dst);

#endif
