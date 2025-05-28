// Copyright 2023 The MathWorks, Inc.
#include "include/approxcanny_ocv.hpp"
#include "include/approxcanny_ocv_api.hpp"

void canny_uint8_ocv(const uint8_T* src,int nRows, int nCols,
                     real64_T lowThresh,
                     real64_T highThresh,
                     uint8_T* dst)
{
    int aperture_size = 3;
    approxcannycanny(src, dst,nRows, nCols,
                     lowThresh, highThresh,
                     aperture_size);
}

void canny_uint8_ocv_RM(const uint8_T* src,int nRows, int nCols,
                        real64_T lowThresh,
                        real64_T highThresh,
                        uint8_T* dst)
{
    int aperture_size = 3;
    approxcannycanny(src, dst,nRows, nCols,
                     lowThresh, highThresh,
                     aperture_size);
}