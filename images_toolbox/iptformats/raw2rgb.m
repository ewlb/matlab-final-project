function rgbImage = raw2rgb(fileName, options)

    arguments
        fileName (1, 1) string
        options.BitsPerSample (1, 1) double = 16
        
        options.ColorSpace (1, 1) string { mustBeMember( options.ColorSpace, ...
                                            { 'srgb', 'camera', ...
                                              'adobe-rgb-1998' } ) } = "srgb"

        options.WhiteBalanceMultipliers ...
                {validateWB(options.WhiteBalanceMultipliers)} = "AsTaken"
                                            
        options.ApplyContrastStretch (1, 1) logical = false
    end
    
    fullFileName = images.internal.io.absolutePathForReading(fileName);
    
    % Returns Row-Major oriented image for convenience
    if ischar(options.WhiteBalanceMultipliers) || isstring(options.WhiteBalanceMultipliers)
        wb = char(options.WhiteBalanceMultipliers);
    else
        % Libraw uses single-precision values.
        wb = single(options.WhiteBalanceMultipliers);
    end
    outImage = images.internal.builtins.raw2rgb( char(fullFileName), ...
                                                 options.BitsPerSample, ...
                                                 char(options.ColorSpace), ...
                                                 wb, ...
                                                 options.ApplyContrastStretch );
    
    % Transforms to column-major planar
    rgbImage = permute(outImage, [3 2 1]);
end

function validateWB(wbInput)
    % Validate the White Balance inputs provided by the user
    
    % Supported inputs are a row-vector of doubles or a string scalar
    validateattributes(wbInput, {'single', 'double', 'char', 'string'}, {'row'});
    
    if ischar(wbInput) || isstring(wbInput)
        validateattributes(wbInput, {'char', 'string'}, {'scalartext'});
        validatestring( wbInput, { 'AsTaken', ...
                                   'D65', ...
                                   'ComputeFromImage' } );
    else
        validateattributes(wbInput, {'single', 'double'}, {'finite', 'nonnan'});
    end
end

%   Copyright 2020-2022 The MathWorks, Inc.
