function xyz = rgbwide2xyz(rgb, bitsPerSample, options)
%RGBWIDE2XYZ Converts Wide Gamut RGB to CIE 1931 XYZ
%
%   XYZ = RGBWIDE2XYZ(RGB, BPS) converts Wide Gamut RGB values to CIE 1931
%   XYZ values. RGB can be:
%   1. P-by-3 matrix of color values (one color per row), OR
%   2. M-by-N-by-3 numeric array representing an image OR
%   3. M-by-N-by-3-by-F numeric array representing a stack of images.
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
%   XYZ = RGBWIDE2XYZ(RGB, BPS, Name, Value) specifies additional options
%   with one or more name-value pair arguments:
%
%       'ColorSpace'        - Color Space of the input RGB values.
%                             'BT.2020' (default) | 'BT.2100'
%
%       'WhitePoint'        - Reference white point.
%                             1-by-3 vector | 'a' | 'c' | 'd50' | 'd55' |
%                             'd65' (default) | 'icc' | 'e'
%
%       'LinearizationFcn'  - Transfer function to be used for the
%                             transformation. This applies only for BT.2100
%                             color space. 
%                             'PQ' (default) | 'HLG'
%
%   Class Support
%   -------------
%   RGB must be uint16. The output XYZ will be double.
%
%   Notes
%   -----
%   [1] This function only supports narrow-range RGB data in the nominal
%       data range of [64, 940] for 10-bit data and [256, 3760] for 12-bit
%       data. 
%
%   [2] Only pixels with RGB values within the nominal range, are
%       guaranteed to be mapped to realizable colors.
%
%   [3] BT.2100 uses two non-linear transfer functions:
%       PQ - Perceptual Quantization
%       HLG - Hybrid Log Gamma
%
%   Example 1
%   ---------
%   % Convert 10-bit BT.2020 Green to XYZ
%  
%     rgbwide2xyz(uint16([64 940 64]), 10)
%
%   Example 2
%   ---------
%   % Convert 12-bit BT.2100 Blue to XYZ
%  
%     rgbwide2xyz(uint16([64 64 940]), 12, 'ColorSpace', 'BT.2100')
%
%   Example 3
%   ---------
%   % Convert 10-bit BT.2100 White to XYZ using Hybrid Log Gamma
%  
%     rgbwide2xyz(uint16([940 940 940]), 10, 'ColorSpace', 'BT.2100', 'LinearizationFcn', 'HLG')
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
%   [3] Rec. ITU-R BT.2390-7 (07/2019), "HIGH DYNAMIC RANGE TELEVISION FOR
%       PRODUCTION AND INTERNATIONAL PROGRAMME EXCHANGE"
%
%   See also XYZ2RGBWIDE, RGB2XYZ, XYZ2RGB, MAKECFORM, APPLYCFORM.
 
%   Copyright 2020 The MathWorks, Inc.

    arguments
        rgb { mustBeNumeric, mustBeReal, validateRGB(rgb) }
        
        bitsPerSample (1, 1) double { mustBeMember(bitsPerSample, [10, 12]) }
        
        % Validation done in the converter. It can be a character vector,
        % string scalar or a 1x3 numeric array
        options.WhitePoint = whitepoint('d65') 
        
        options.ColorSpace (1, :) string { mustBeMember( options.ColorSpace, ...
                                            {'BT.2020', 'BT.2100'} ) } = 'BT.2020'
        
        % Default value not specified on purpose to allow for better error
        % checking
        options.LinearizationFcn (1, :) string { mustBeMember( options.LinearizationFcn, ...
                                                    {'PQ', 'HLG'} ) }  
    end

    options = convertContainedStringsToChars(options);
    options = images.color.internal.validateInputsForBT2020AndBT2100(options, mfilename);
    
    switch options.ColorSpace
        case 'BT.2020'
            converter = images.color.bt2020RGBToXYZConverter(options.WhitePoint);
            xyz = converter(rgb, bitsPerSample);
            
        case 'BT.2100'
            converter = images.color.bt2100RGBToXYZConverter(options.WhitePoint);
            xyz = converter(rgb, bitsPerSample, options.LinearizationFcn);
            
        otherwise
            assert(false, 'Invalid Color space');
    end
end

function validateRGB(rgb)
% Validate that RGB adheres to the following:
%   1. P-by-3 matrix of color values (one color per row), OR
%   2. M-by-N-by-3 numeric array representing an image OR
%   3. M-by-N-by-3-by-F numeric array representing a stack of images.

    images.color.internal.validateInputDataPropsWideGamut( rgb, ...
                                                {'uint16'}, mfilename );
end

