function ycbcr = rgbwide2ycbcrImpl(rgb, bitsPerSample)  %#codegen
%Implements the actual conversion. Used by both simulation and codegen
%versions of the function

%   Copyright 2020, The MathWorks Inc.
    
    % Check if the input is a Px3 color list OR an RGB image
    % Not using ISMATRIX due to a gotcha with varsize inputs in codegen
    % mode.
    isInputColorList = coder.const(numel(size(rgb)) == 2);
    
    bitsPerSampleLocal = double(bitsPerSample);
    % TRUE => Simulation and Col-Major Codegen follow this path
    if coder.isColumnMajor 
        rgbNormalized = normalizeRGB(rgb, bitsPerSampleLocal);
    
        if isInputColorList
            rgbLocal = reshape(rgbNormalized, [size(rgbNormalized, 1) 1 size(rgbNormalized, 2)]);
        else
            rgbLocal = rgbNormalized;
        end

        yCbCrLocal = coder.nullcopy( zeros(size(rgbLocal), class(rgbLocal)) );

        yCbCrLocal(:, :, 1) = imlincomb( 0.2627, rgbLocal(:, :, 1), ...
                                         0.6780, rgbLocal(:, :, 2), ...
                                         0.0593, rgbLocal(:, :, 3) );

        yCbCrLocal(:, :, 2) = ( rgbLocal(:, :, 3) - yCbCrLocal(:, :, 1) ) / 1.8814;
        yCbCrLocal(:, :, 3) = ( rgbLocal(:, :, 1) - yCbCrLocal(:, :, 1) ) / 1.4746;

        if isa(rgb, 'gpuArray')
            ycbcrImage = zeros(size(rgbLocal), 'like', rgb);
        else
            ycbcrImage = coder.nullcopy( zeros(size(rgbLocal), 'uint16') );
        end
        
        ycbcrImage(:, :, 1) = uint16( (219*yCbCrLocal(:, :, 1) + 16)*2^(bitsPerSampleLocal - 8) );
        ycbcrImage(:, :, 2) = uint16( (224*yCbCrLocal(:, :, 2) + 128)*2^(bitsPerSampleLocal - 8) );
        ycbcrImage(:, :, 3) = uint16( (224*yCbCrLocal(:, :, 3) + 128)*2^(bitsPerSampleLocal - 8) );
    else
        blackLevel = 64;
        nominalPeak = 940;

        if bitsPerSampleLocal == 12
            blackLevel = 256;
            nominalPeak = 3760;
        end
        nominalRange = nominalPeak - blackLevel;
        
        if isInputColorList
            rgbLocal = reshape(rgb, [size(rgb, 1) 1 size(rgb, 2)]);
        else
            rgbLocal = rgb;
        end
        
        [height, width, numChannels] = size(rgbLocal);
        
        ycbcrImage = coder.nullcopy( zeros(size(rgbLocal), 'uint16') );
        normalizedRGBPixel = coder.nullcopy( zeros([1 numChannels], 'single') );
        tempYCbCr = coder.nullcopy( zeros([1 numChannels], 'single') );
        for y = 1:height
            
            for x = 1:width
                for c = 1:numChannels % Normaloizing values in a given range
                    normalizedRGBPixel(c) = ...
                        ( single(rgbLocal(y, x, c)) - blackLevel ) / nominalRange;
                end
                
                % Compute Y
                tempYCbCr(1) = imlincomb( 0.2627, normalizedRGBPixel(1), ...
                                          0.6780, normalizedRGBPixel(2), ...
                                          0.0593, normalizedRGBPixel(3) );
                           
                % Compute Cb
                tempYCbCr(2) = ( normalizedRGBPixel(3) - tempYCbCr(1) ) / 1.8814;
                
                % Compute Cr
                tempYCbCr(3) = ( normalizedRGBPixel(1) - tempYCbCr(1) ) / 1.4746;
                
                % Convert them to uint16
                ycbcrImage(y, x, 1) = uint16( (219*tempYCbCr(1) + 16)*2^(bitsPerSampleLocal - 8) );
                ycbcrImage(y, x, 2) = uint16( (224*tempYCbCr(2) + 128)*2^(bitsPerSampleLocal - 8) );
                ycbcrImage(y, x, 3) = uint16( (224*tempYCbCr(3) + 128)*2^(bitsPerSampleLocal - 8) );
            end
        end
    end
    
    if isInputColorList
        ycbcr = reshape(ycbcrImage, [size(ycbcrImage, 1) size(ycbcrImage, 3)]);
    else
        ycbcr = ycbcrImage;
    end
end

function out = normalizeRGB(rgb, bitsPerSample)
    blackLevel = 64;
    nominalPeak = 940;
    
    if bitsPerSample == 12
        blackLevel = 256;
        nominalPeak = 3760;
    end
    
    out = ( single(rgb) - blackLevel ) / (nominalPeak - blackLevel);
end
