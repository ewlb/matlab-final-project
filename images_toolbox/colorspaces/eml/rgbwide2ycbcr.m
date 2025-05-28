function ycbcr = rgbwide2ycbcr(rgb, bitsPerSample) %#codegen
%CODEGEN version of RGBWIDE2YCBCR

%   Copyright 2020, The MathWorks, Inc.

    % Validate the input data 
    images.color.internal.validateInputDataPropsWideGamut( rgb, ...
                                                {'uint16'}, ...
                                                coder.const(mfilename), ...
                                                'RGB' );
                                            
    % Validate BPS
    validateattributes(bitsPerSample, {'numeric'}, {'scalar'});
    mustBeMember(bitsPerSample, [10, 12]);
    
    ycbcr = images.color.internal.rgbwide2ycbcrImpl(rgb, bitsPerSample);