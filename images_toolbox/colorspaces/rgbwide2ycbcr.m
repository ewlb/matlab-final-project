function ycbcr = rgbwide2ycbcr(rgb, bitsPerSample)
%RGBWIDE2YCBCR Convert Wide Gamut RGB color values into YCbCr colorspace
%
%   YCBCR = RGBWIDE2YCBCR(RGB, BPS) converts RGB values in the BT.2020 and
%   BT.2100 wide gamut colorspaces into non-constant lumninance YCbCr. 
%   RGB can be: 
%   1. P-by-3 matrix of colors (one color per line) OR
%   2. M-by-N-by-3 numeric array representing an image
%   Input color values are integers in the range [64, 940] for 10-bit data
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
%   RGB must be uint16. The output YCBCR will also be uint16.
%
%   Notes
%   -----
%   [1] This function only supports narrow-range RGB data in the nominal
%       data range of [64, 940] for 10-bit data and [256, 3760] for 12-bit
%       data. 
%
%   [2] Only pixels with RGB values within the nominal range are guaranteed
%       to be mapped to valid YCbCr values.
%
%   [3] For BT.2020 and BT.2100, the data ranges of the YCbCr values are
%       shown in the table below.
%           Component               10-bit            12-bit
%           ---------             ----------       -----------
%               Y                  [64, 940]       [256, 3760]
%            Cb, Cr                [64, 960]       [256, 3840]
%
%   Example 1
%   ---------
%   % Convert 10-bit white color in BT.2020/BT.2100 to YCbCr
%
%      RGBLIST = uint16([940 940 940]);
%      YCBCRLIST = rgbwide2ycbcr(RGBLIST, 10);
%
%   Example 2
%   ---------
%   % Convert 12-bit RGB image in BT.2020/BT.2100 to YCbCr
%
%      % Create a 12-bit BT.2020 RGB image for input
%      IM = imread('peppers.png');
%      XYZ = rgb2xyz(IM);
%      RGB = xyz2rgbwide(XYZ, 12);
%
%      % Convert to YCBCR
%      YCBCR = rgbwide2ycbcr(RGB, 12);
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
%   See also YCBCR2RGBWIDE, RGB2YCBCR, YCBCR2RGB.

%   Copyright 2020 The MathWorks, Inc.
    arguments
        rgb { mustBeNumeric, mustBeReal, validateRGB(rgb) }
        
        bitsPerSample (1, 1) double { mustBeMember(bitsPerSample, [10, 12]) }
    end
    
    ycbcr = images.color.internal.rgbwide2ycbcrImpl(rgb, bitsPerSample);
end

function validateRGB(rgb)
%   RGB can be: 
%   1. P-by-3 matrix of colors (one color per line) OR
%   2. M-by-N-by-3 numeric array representing an image

    images.color.internal.validateInputDataPropsWideGamut( rgb, ...
                                                {'uint16'}, mfilename );
end
