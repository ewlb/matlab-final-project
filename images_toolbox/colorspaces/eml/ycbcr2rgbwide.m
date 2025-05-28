function rgb = ycbcr2rgbwide(ycbcr, bitsPerSample) %#codegen
%CODEGEN version of YCBCR2RGBWIDE

%   Copyright 2020, The MathWorks, Inc.

    % Validate the input data 
    images.color.internal.validateInputDataPropsWideGamut( ycbcr, ...
                                                {'uint16'}, ...
                                                coder.const(mfilename), ...
                                                'YCBCR' );
                                            
    % Validate BPS
    validateattributes(bitsPerSample, {'numeric'}, {'scalar'});
    mustBeMember(bitsPerSample, [10, 12]);
    
    rgb = images.color.internal.ycbcr2rgbwideImpl(ycbcr, bitsPerSample);