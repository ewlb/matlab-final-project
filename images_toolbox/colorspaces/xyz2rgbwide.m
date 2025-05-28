function rgb = xyz2rgbwide(xyz, bitsPerSample, options)
%XYZ2RGBWIDE Converts CIE 1931 XYZ to Wide Gamut RGB
%
%   RGB = XYZ2RGBWIDE(XYZ, BPS) converts CIE 1931 XYZ to Wide Gamut RGB
%   values. XYZ can be:
%   1. P-by-3 numeric matrix of color values (one color per row), OR
%   2. M-by-N-by-3 numeric array representing an image OR
%   3. M-by-N-by-3-by-F numeric array representing a stack of images.
%   Output color values are integers in the range [64, 940] for 10-bit data
%   or [256, 3760] for 12-bit data. The minimum value in the range maps to
%   black, and the maximum value in the range maps to white.
%
%   BPS is a numeric scalar that specifies the actual number of bits
%   required to represent each channel of the output. It can take values 10
%   or 12.
%
%   RGB = XYZ2RGBWIDE(XYZ, BPS, Name, Value) specifies additional options
%   with one or more name-value pair arguments: 
%
%       'ColorSpace'        - Color Space of the output RGB values.
%                            'BT.2020' (default) | 'BT.2100'
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
%   The type of XYZ can be single or double. RGB will always be uint16.
%
%   Notes
%   -----
%   [1] This function output only supports narrow-range RGB data in the
%       nominal data range of [64, 940] for 10-bit data and [256, 3760] for
%       12-bit data.
%
%   [2] BT.2100 uses two non-linear transfer functions:
%       PQ - Perceptual Quantization
%       HLG - Hybrid Log Gamma
%
%   Example 1
%   ---------
%   % Convert an XYZ color into 10-bit BT.2020
%  
%     xyz2rgbwide([0.25 0.40 0.10], 10);
%
%   Example 2
%   ---------
%   % Convert an XYZ color to 12-bit BT.2100
%  
%     xyz2rgbwide([0.25 0.40 0.10], 12, 'ColorSpace', 'BT.2100')
%
%   Example 3
%   ---------
%   % Convert an XYZ color to 10-bit BT.2100 using Hybrid Log Gamma
%  
%     xyz2rgbwide([0.25 0.40 0.10], 10, 'ColorSpace', 'BT.2100', 'LinearizationFcn', 'HLG')
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
%   See also RGBWIDE2XYZ, RGB2XYZ, XYZ2RGB, MAKECFORM, APPLYCFORM.

%   Copyright 2020 The MathWorks, Inc.

    arguments
        % Update this when musBeSpecificClass validator becomes available
        xyz { mustBeNumeric, mustBeReal, validateXYZ(xyz) }
        
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
    
    switch(options.ColorSpace)
        case 'BT.2020'
            converter = images.color.xyzToBT2020RGBConverter(options.WhitePoint);
            rgb = converter(xyz, bitsPerSample);
            
        case 'BT.2100'
            converter = images.color.xyzToBT2100RGBConverter(options.WhitePoint);
            rgb = converter(xyz, bitsPerSample, options.LinearizationFcn);
            
        otherwise
            assert(false, 'Invalid Color space');
    end
end

function validateXYZ(xyz)
% Validate that XYZ adheres to the following:
%   1. P-by-3 matrix of color values (one color per row), OR
%   2. M-by-N-by-3 numeric array representing an image OR
%   3. M-by-N-by-3-by-F numeric array representing a stack of images.

    images.color.internal.validateInputDataPropsWideGamut( xyz, ...
                                        {'single', 'double'}, mfilename);
end
