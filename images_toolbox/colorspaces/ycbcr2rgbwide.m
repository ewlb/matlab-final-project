function rgb  = ycbcr2rgbwide(ycbcr, bitsPerSample)
%YCBCR2RGBWIDE Convert YCbCr color values into Wide Gamut RGB colorspace
%
%   RGB = YCBCR2RGBWIDE(YCBCR, BPS) converts non-constant lumninance YCbCr
%   values into RGB values in BT.2020 and BT.2100 wide gamut colorspaces.
%   YCbCr can be:
%   1. P-by-3 matrix of colors (one color per line) OR
%   2. M-by-N-by-3 array representing an image
%   Output color values are integers in the range [64, 940] for 10-bit data
%   or [256, 3760] for 12-bit data. The minimum value in the range maps to
%   black, and the maximum value in the range maps to white. This function
%   does not support full-range of 10-bit and 12-bit RGB values, [0, 1023]
%   and [0, 4095], respectively.
%
%   BPS is a numeric scalar that specifies the actual number of bits
%   required to represent each channel of the input. It can take values 10
%   or 12.
%
%   Class Support
%   -------------
%   YCBCR must be uint16. The output RGB will also be uint16.
%
%   Notes
%   -----
%   [1] This function output only supports narrow-range RGB data in the
%       nominal data range of [64, 940] for 10-bit data and [256, 3760] for
%       12-bit data. 
%
%   [2] For BT.2020 and BT.2100, the data ranges of the YCbCr values are
%       shown in the table below.
%           Component               10-bit            12-bit
%           ---------             ----------       -----------
%               Y                  [64, 940]       [256, 3760]
%            Cb, Cr                [64, 960]       [256, 3840]
%
%   [3] Only pixels with non-constant luminance YCbCr values in the range
%       specified above will be mapped into valid RGB values.
%
%   Example 1
%   ---------
%   % Convert 12-bit YCbCr in BT.2020/BT.2100 to RGB
%
%      YCBCRLIST = uint16([3760 2048 2048]);
%      RGBLIST = ycbcr2rgbwide(YCBCRLIST, 12);
%
%   Example 2
%   ---------
%   % Convert 10-bit YCBCR image in BT.2020/BT.2100 to RGB
%
%      YCBCR = reshape(uint16([64 512 512; 940 512 512]), [2 1 3]);
%      RGB = ycbcr2rgbwide(YCBCR, 10);
%
%   References:
%   ----------
%   [1] Rec. ITU-R BT.2020-2 (10/2015), "PARAMETER VALUES FOR ULTRA-HIGH
%       DEFINITION TELEVISION SYSTEMS FOR PRODUCTION AND INTERNATIONAL
%       PROGRAMME EXCHANGE"
%
%   [2] Rec. ITU-R BT.2100-2 (07/2018), "IMAGE PARAMETER VALUES FOR HIGH
%       DYNAMIC RANGE TELEVISION FOR USE IN PRODUCTION AND INTERNATIONAL
%       PROGRAMME EXCHANGE"
%
%   See also RGBWIDE2YCBCR, RGB2YCBCR, YCBCR2RGB.

%   Copyright 2020 The MathWorks, Inc.
    arguments
        ycbcr { mustBeNumeric, mustBeReal, validateYCbCr(ycbcr) }
        
        bitsPerSample (1, 1) double { mustBeMember(bitsPerSample, [10, 12]) }
    end
    
    rgb = images.color.internal.ycbcr2rgbwideImpl(ycbcr, bitsPerSample);
end

function validateYCbCr(ycbcr)
%   YCbCr can be: 
%   1. P-by-3 matrix of colors (one color per line) OR
%   2. M-by-N-by-3 numeric array representing an image

    images.color.internal.validateInputDataPropsWideGamut( ycbcr, ...
                                                {'uint16'}, mfilename );
end
