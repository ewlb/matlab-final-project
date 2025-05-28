classdef SAMAutoSegDefaultParams
% Stores the default values of the Automatic Segmentation Parameters

    % Default Values for Auto Seg Parameters
    properties(Access=public, Constant)
        DefaultMinObjAreaFrac = 0
        DefaultMaxObjAreaFrac = 0.95;
        DefaultPointGridSize = [32 32];
        DefaultPointGridSizeStr = "[32 32]";
        DefaultPointGridDSFactor = 2;
        DefaultPointBatchSize = 64;
        DefaultCropLevel = 1;
        DefaultScoreThreshold = 0.8;
        DefaultStrongestThreshold = 0.7;
    end

    methods(Access=public, Static)
        function params = getParams(imageSize)
            arguments
                imageSize = [];
            end

            params = getDefaultAutoSegParams();

            numPix = 0;
            if ~isempty(imageSize)
                numPix = imageSize(1)*imageSize(2);    
            end

            params.MinObjectArea = floor(params.MinObjectArea*numPix);
            params.MaxObjectArea = floor(params.MaxObjectArea*numPix);

        end
    end
end

function params = getDefaultAutoSegParams()
    import images.internal.app.utilities.semiautoseg.SAMAutoSegDefaultParams;

    params = struct( "MinObjectArea", SAMAutoSegDefaultParams.DefaultMinObjAreaFrac, ...
                "MaxObjectArea", SAMAutoSegDefaultParams.DefaultMaxObjAreaFrac, ...
                "PointGridSize", SAMAutoSegDefaultParams.DefaultPointGridSize, ...
                "PointGridDownscaleFactor", SAMAutoSegDefaultParams.DefaultPointGridDSFactor, ...
                "PointBatchSize", SAMAutoSegDefaultParams.DefaultPointBatchSize, ...
                "NumCropLevels", SAMAutoSegDefaultParams.DefaultCropLevel, ...
                "ScoreThreshold", SAMAutoSegDefaultParams.DefaultScoreThreshold, ...
                "SelectStrongestThreshold", SAMAutoSegDefaultParams.DefaultStrongestThreshold );
end

% Copyright 2024 The MathWorks, Inc.