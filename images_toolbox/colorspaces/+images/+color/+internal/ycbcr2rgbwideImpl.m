function rgb = ycbcr2rgbwideImpl(ycbcr, bitsPerSample) %#codegen
%Implements the actual conversion. Used by both simulation and codegen
%versions of the function

%   Copyright 2020, The MathWorks Inc.

    % Define the signal ranges
    % Please refer to the BT.2020/BT.2100 spec
    bitsPerSampleLocal = double(bitsPerSample);
    chromazero = 2^(bitsPerSampleLocal - 1);
    
    if bitsPerSampleLocal == 10
        % Signal range for YCbcr signal
        yzero = 64; ypeak = 940;
        yrange = (ypeak - yzero);
        chromarange = 960 - 64;
        
        % Signal range for RGB Signal
        blackLevel = 64;
        nominalPeak = 940;
    else 
        % Signal range for YCbCr signal
        yzero = 256; ypeak = 3760;
        yrange = (ypeak - yzero);
        chromarange = 3840 - 256;
        
        % Signal range for RGB Signal
        blackLevel = 256;
        nominalPeak = 3760;
    end
    nominalRange = nominalPeak - blackLevel;
    
    % % Check if the input is a Px3 color list OR an RGB image
    % Not using ISMATRIX due to a gotcha with varsize inputs in codegen
    % mode.
    isInputColorList = coder.const(numel(size(ycbcr)) == 2);
    
    if isInputColorList
        ycbcrImage = reshape(ycbcr, [size(ycbcr, 1) 1 size(ycbcr, 2)]);
    else
        ycbcrImage = ycbcr;
    end
    
    % TRUE => Simulation and Col-Major Codegen follow this path
    if coder.isColumnMajor
        % Normalize the image into the range [0, 1]
        ycbcrImageNormalized = normalizeYCbCr(ycbcrImage, yzero, yrange, chromazero, chromarange);
        
        % Create an RGB image to store the intermediate results
        rgbImageLocal = coder.nullcopy( zeros( size(ycbcrImageNormalized), ...
                                               class(ycbcrImageNormalized) ) );

        % Compute R
        rgbImageLocal(:, :, 1) = 1.4746*ycbcrImageNormalized(:, :, 3) + ...
                                        ycbcrImageNormalized(:, :, 1);

        % Compute B
        rgbImageLocal(:, :, 3) = 1.8814*ycbcrImageNormalized(:, :, 2) + ...
                                        ycbcrImageNormalized(:, :, 1);

        % Compute G
        rgbImageLocal(:, :, 2) = ( ycbcrImageNormalized(:, :, 1) - ...
                                   0.2627*rgbImageLocal(:, :, 1) - ...
                                   0.0593*rgbImageLocal(:, :, 3) ) / 0.6780;


        % Need to convert the RGB values into uint16
        rgbImage = uint16(rgbImageLocal*nominalRange + blackLevel);
    else
        rgbImage = coder.nullcopy( zeros(size(ycbcrImage), 'uint16') );
        
        [height, width, numChannels] = size(ycbcrImage);
        
        normalizedYCbCr = coder.nullcopy( zeros(1, numChannels, 'single') );
        tempVal = normalizedYCbCr;
        for y = 1:height
            for x = 1:width
                for c = 1:numChannels
                    normalizedYCbCr(1) = ( single(ycbcrImage(y, x, 1)) - yzero ) / yrange;
                    normalizedYCbCr(2) = ( single(ycbcrImage(y, x, 2)) - chromazero ) / chromarange;
                    normalizedYCbCr(3) = ( single(ycbcrImage(y, x, 3)) - chromazero ) / chromarange;
                end
                
                % Compute R, G, B
                tempVal(1) = 1.4746*normalizedYCbCr(3) + normalizedYCbCr(1);
                tempVal(3) = 1.8814*normalizedYCbCr(2) + normalizedYCbCr(1);
                tempVal(2) = ( normalizedYCbCr(1) - 0.2627*tempVal(1) - 0.0593*tempVal(3) ) / 0.6780;
                
                % Convert the RGB values into uint16
                for c = 1:numChannels
                    rgbImage(y, x, c) = uint16(tempVal(c)*nominalRange + blackLevel);
                end
            end
        end
    end
    
    if isInputColorList
        rgb = reshape(rgbImage, [size(rgbImage, 1) size(rgbImage, 3)]);
    else
        rgb = rgbImage;
    end
end

function out = normalizeYCbCr(in, yzero, yrange, chromazero, chromarange)
    if isa(in, 'gpuArray')
        out = gpuArray.zeros(size(in), 'single');
    else
        out = coder.nullcopy( zeros(size(in), 'single') );
    end
    

    out(:, :, 1) = ( single(in(:, :, 1)) - yzero ) / yrange;
    out(:, :, 2:3) = ( single(in(:, :, 2:3)) - chromazero ) / chromarange;
end
