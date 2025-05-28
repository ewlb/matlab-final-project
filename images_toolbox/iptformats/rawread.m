function cfaImage = rawread(fileName, options)

    arguments
        fileName (1, 1) string
        options.VisibleImageOnly (1, 1) logical = true
    end
    
    fullFileName = images.internal.io.absolutePathForReading(char(fileName));
    
    % Returns Row-Major oriented image for convenience
    cfaImage = images.internal.builtins.rawread( fullFileName, ...
                                                 options.VisibleImageOnly );
    
	% Transform into column-major
    if size(cfaImage, 3) == 1
        cfaImage = cfaImage';
    else
        % Foveon sensors and some DNG files return 3-channel images
        cfaImage = permute(cfaImage, [3 2 1]);
    end
end

%   Copyright 2020-2022 The MathWorks, Inc.