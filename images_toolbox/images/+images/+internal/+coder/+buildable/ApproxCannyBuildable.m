classdef ApproxCannyBuildable < coder.ExternalDependency %#codegen
    % ApproxCannyBuildable - Approxcanny  implementation library

    % Copyright 2023 The MathWorks, Inc.

    methods (Static)

        function name = getDescriptiveName(~)
            name = 'ApproxCannyBuildable';
        end

        function b = isSupportedContext(~)
            b = true; % supports non-host target
        end

        function updateBuildInfo(buildInfo, context)
            buildInfo.addIncludePaths({fullfile(matlabroot,'toolbox', ...
                'images','opencv','opencvwrapper','include'), ...
                fullfile(matlabroot,'toolbox', ...
                'images','opencv','opencvcg', 'include'), ...
                fullfile(matlabroot,'toolbox', ...
                'images','builtins','src','imagesocv', 'include')} );
            srcPaths = fullfile(matlabroot,'toolbox', ...
                'images','opencv','opencvwrapper');
            buildInfo.addSourceFiles({'approxcanny_ocv.cpp'},srcPaths);
            buildInfo.addSourcePaths(srcPaths, 'CVT_GROUP');

            buildInfo.addIncludeFiles({'images_defines.h', ...
                'approxcanny_ocv.hpp', ...
                'approxcanny_ocv_api.hpp'}); % no need 'rtwtypes.h'

            images.internal.coder.buildable.portableOpenCVImagesBuildInfo(buildInfo, context, ...
                'approxcanny_ocv');
        end

        %------------------------------------------------------------------
        % write all supported data-type specific function calls
        function out = canny_uint8_ocv(imageSrc, threshOne, threshTwo)

            coder.inline('always');
            coder.cinclude('approxcanny_ocv_api.hpp');

            nRows = int32(size(imageSrc, 1)); % original (before transpose)
            nCols = int32(size(imageSrc, 2)); % original (before transpose)
            outSize = [nRows nCols];

            out = coder.nullcopy(zeros(outSize,'uint8'));

            if coder.isColumnMajor
                coder.ceval('-col', 'canny_uint8_ocv',...
                    coder.ref(imageSrc), ...
                    nCols, nRows,...
                    threshOne, threshTwo, ...
                    coder.ref(out));
            else
                coder.ceval('-row', 'canny_uint8_ocv_RM',...
                    coder.ref(imageSrc), ...
                    nRows, nCols, ...
                    threshOne, threshTwo, ...
                    coder.ref(out));
            end

        end
    end
end
