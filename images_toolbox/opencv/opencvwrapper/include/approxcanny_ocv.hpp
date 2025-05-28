// Copyright 2023 The MathWorks, Inc.

#include "opencv2/opencv.hpp"

using namespace std;
void computeThresholds(cv::Mat *magGrad, int & low, int & high, double maxval, double minval);

void approxcannycanny( const uchar* srcOne1, uchar* dstOne, int nRows, int nCols,
                      double low_thresh, double high_thresh,
                      int aperture_size)
{
    uchar *srcOne = (uchar*)srcOne1;
    cv::Mat src(nRows, nCols, CV_8UC1, srcOne);
    cv::Mat dst(nRows, nCols, CV_8UC1, dstOne);

    if (low_thresh > high_thresh)
        std::swap(low_thresh, high_thresh);

    const int cn = src.channels();
    cv::Mat dx(src.rows, src.cols, CV_16SC(cn));
    cv::Mat dy(src.rows, src.cols, CV_16SC(cn));

    cv::Sobel(src, dx, CV_16S, 1, 0, aperture_size, 1.0f, 0.0f, cv::BORDER_REPLICATE);
    cv::Sobel(src, dy, CV_16S, 0, 1, aperture_size, 1.0f, 0.0f, cv::BORDER_REPLICATE);

    // begin custom threshold computation.
    int low = 0;
    int high = 255;

    // Unsigned 16 bit because abs will make sure all values are positive.
    cv::Mat magGrad(src.rows, src.cols, CV_16UC(cn));
    magGrad = cv::abs(dx) + cv::abs(dy);
    magGrad.convertTo(magGrad, CV_16U);

    double maxval = 1.0;
    double minval = 0.0;
    cv::minMaxLoc(magGrad, &minval, &maxval);

    if ((low_thresh == -1.0) && (high_thresh == -1.0))
    {
        computeThresholds(&magGrad, low, high, maxval, minval);
    }
    else
    {
        low = cvFloor(low_thresh * (maxval - minval));
        high = cvFloor(high_thresh * (maxval - minval));
    }
    // end custom threshold computation.

    ptrdiff_t mapstep = src.cols + 2;
    cv::AutoBuffer<uchar> buffer((src.cols+2)*(src.rows+2) + cn * mapstep * 3 * sizeof(int));

    int* mag_buf[3];
    mag_buf[0] = (int*)(uchar*)buffer;
    mag_buf[1] = mag_buf[0] + mapstep*cn;
    mag_buf[2] = mag_buf[1] + mapstep*cn;
    memset(mag_buf[0], 0, /* cn* */mapstep*sizeof(int));

    uchar* map = (uchar*)(mag_buf[2] + mapstep*cn);
    memset(map, 1, mapstep);
    memset(map + mapstep*(src.rows + 1), 1, mapstep);

    int maxsize = std::max(1 << 10, src.cols * src.rows / 10);
    std::vector<uchar*> stack(maxsize);
    uchar **stack_top = &stack[0];
    uchar **stack_bottom = &stack[0];

    /* sector numbers
    (Top-Left Origin)

    1   2   3
    *  *  *
    * * *
    0*******0
    * * *
    *  *  *
    3   2   1
    */

    #define CANNY_PUSH(d)    *(d) = uchar(2), *stack_top++ = (d)
    #define CANNY_POP(d)     (d) = *--stack_top

    // calculate magnitude and angle of gradient, perform non-maxima suppression.
    // fill the map with one of the following values:
    //   0 - the pixel might belong to an edge
    //   1 - the pixel can not belong to an edge
    //   2 - the pixel does belong to an edge
    for (int i = 0; i <= src.rows; i++)
    {
        int* _norm = mag_buf[(i > 0) + 1] + 1;
        if (i < src.rows)
        {
            short* _dx = dx.ptr<short>(i);
            short* _dy = dy.ptr<short>(i);

            // Compute the L1 gradient in _norm.
            for (int j = 0; j < src.cols*cn; j++)
                _norm[j] = std::abs(int(_dx[j])) + std::abs(int(_dy[j]));

            if (cn > 1)
            {
                for(int j = 0, jn = 0; j < src.cols; ++j, jn += cn)
                {
                    int maxIdx = jn;
                    for(int k = 1; k < cn; ++k)
                        if(_norm[jn + k] > _norm[maxIdx]) maxIdx = jn + k;
                    _norm[j] = _norm[maxIdx];
                    _dx[j] = _dx[maxIdx];
                    _dy[j] = _dy[maxIdx];
                }
            }
            _norm[-1] = _norm[src.cols] = 0;
        }
        else
            memset(_norm-1, 0, /* cn* */mapstep*sizeof(int));

        // at the very beginning we do not have a complete ring
        // buffer of 3 magnitude rows for non-maxima suppression
        if (i == 0)
            continue;

        uchar* _map = map + mapstep*i + 1;
        _map[-1] = _map[src.cols] = 1;

        int* _mag = mag_buf[1] + 1; // take the central row
        ptrdiff_t magstep1 = mag_buf[2] - mag_buf[1];
        ptrdiff_t magstep2 = mag_buf[0] - mag_buf[1];

        const short* _x = dx.ptr<short>(i-1);
        const short* _y = dy.ptr<short>(i-1);

        if ((stack_top - stack_bottom) + src.cols > maxsize)
        {
            int sz = (int)(stack_top - stack_bottom);
            maxsize = maxsize * 3/2;
            stack.resize(maxsize);
            stack_bottom = &stack[0];
            stack_top = stack_bottom + sz;
        }

        int prev_flag = 0;
        for (int j = 0; j < src.cols; j++)
        {
            #define CANNY_SHIFT 15
            const int TG22 = (int)(0.4142135623730950488016887242097*(1<<CANNY_SHIFT) + 0.5);

            int m = _mag[j];

            if (m > low)
            {
                int xs = _x[j];
                int ys = _y[j];
                int x = std::abs(xs);
                int y = std::abs(ys) << CANNY_SHIFT;

                int tg22x = x * TG22;

                if (y < tg22x)
                {
                    if (m > _mag[j-1] && m >= _mag[j+1]) goto __ocv_canny_push;
                }
                else
                {
                    int tg67x = tg22x + (x << (CANNY_SHIFT+1));
                    if (y > tg67x)
                    {
                        if (m > _mag[j+magstep2] && m >= _mag[j+magstep1]) goto __ocv_canny_push;
                    }
                    else
                    {
                        int s = (xs ^ ys) < 0 ? -1 : 1;
                        if (m > _mag[j+magstep2-s] && m > _mag[j+magstep1+s]) goto __ocv_canny_push;
                    }
                }
            }
            prev_flag = 0;
            _map[j] = uchar(1);
            continue;
            __ocv_canny_push:
            if (!prev_flag && m > high && _map[j-mapstep] != 2)
            {
                CANNY_PUSH(_map + j);
                prev_flag = 1;
            }
            else
                _map[j] = 0;
        }

        // scroll the ring buffer
        _mag = mag_buf[0];
        mag_buf[0] = mag_buf[1];
        mag_buf[1] = mag_buf[2];
        mag_buf[2] = _mag;
    }

    // now track the edges (hysteresis thresholding)
    while (stack_top > stack_bottom)
    {
        uchar* m;
        if ((stack_top - stack_bottom) + 8 > maxsize)
        {
            int sz = (int)(stack_top - stack_bottom);
            maxsize = maxsize * 3/2;
            stack.resize(maxsize);
            stack_bottom = &stack[0];
            stack_top = stack_bottom + sz;
        }

        CANNY_POP(m);

        if (!m[-1])         CANNY_PUSH(m - 1);
        if (!m[1])          CANNY_PUSH(m + 1);
        if (!m[-mapstep-1]) CANNY_PUSH(m - mapstep - 1);
        if (!m[-mapstep])   CANNY_PUSH(m - mapstep);
        if (!m[-mapstep+1]) CANNY_PUSH(m - mapstep + 1);
        if (!m[mapstep-1])  CANNY_PUSH(m + mapstep - 1);
        if (!m[mapstep])    CANNY_PUSH(m + mapstep);
        if (!m[mapstep+1])  CANNY_PUSH(m + mapstep + 1);
    }

    // the final pass, form the final image
    const uchar* pmap = map + mapstep + 1;
    uchar* pdst = dst.ptr();
    for (int i = 0; i < src.rows; i++, pmap += mapstep, pdst += dst.step)
    {
        for (int j = 0; j < src.cols; j++)
            pdst[j] = (uchar)-(pmap[j] >> 1);
    }
}

void computeThresholds(cv::Mat *magGrad, int & low, int & high, double maxval, double minval)
{
    // Setup openCV version of thresholding cumulative histogram.
    const int histSize[] = { 64 };          // fixed number of bins
    float range[] = { 0.0f , static_cast<float>(maxval) };        // range of magGrad values
    const int channels[] = { 0 };           // 0 channels
    const float * histRange = { range };    // calcHist expects this format
    const int numImages = 1;
    const int histDims = 1;                 // 1 dimensional histogram

    // if max gradient == min gradient, return 0 for high and low gradients.
    if(maxval == minval)
    {
        high = 0;
        low = 0;
        return;
    }

    // Calculate histogram
    cv::MatND hist;
    cv::calcHist(magGrad, numImages, channels,
                 cv::Mat(), // no mask used.
                 hist, histDims, histSize,
                 &histRange,
                 true, false); // uniform, no accumulation

    // For CDF: add all pdf entries.
    double magSum = cv::sum( *magGrad )[0];
    float allSum = cv::sum(hist)[0];
    float highThresh = 0.7f * allSum;

    // initialize rolling sum:
    float highL1L2factor = 4.8f;
    float rollingSum = 0.0f;

    rollingSum = 0.0f;
    for (int idx = 0; idx < *histSize; idx++)
    {
        // for each bin, add current entry to currlevel.
        float currlevel = hist.at<float>(idx);
        rollingSum += currlevel;

        // check if rolling sum is close to 0.7:
        float difference = highThresh - rollingSum;

        if (difference <= 0)
        {
            float index = idx + (difference / currlevel);
            high = cvRound((index / (*histSize)) * maxval * highL1L2factor);
            if (high > cvRound(maxval))
            {
                high = cvRound(maxval);
            }
            else if(high < 0)
            {
                high = 0;
            }
            low = cvRound(high*0.4f);
            break;
        }
    }
}
