function [textureSFR, testPSD, refPSD] = ...
                    measureTexture(im, textureROI, uniformROI)
    arguments (Repeating)
        im (:, :, :) { mustBeNumeric, ...
                        images.internal.testchart.mustHaveNumChannels(im, [1 3]) }
        textureROI (1, 4) {images.internal.testchart.mustBeValidROI(textureROI)}
        uniformROI (1, 4) {images.internal.testchart.mustBeValidROI(uniformROI)}
    end

    narginchk(3, 6);
    nargoutchk(0, 3);

    % Extract the test image inputs
    testImage = im{1};
    testTextureRegion = imcrop(testImage, textureROI{1});
    testUniformRegion = imcrop(testImage, uniformROI{1});

    if ~isscalar(im)
        % Indicates that reference image values are also provided i.e. 6
        % input argument syntax
        refImage = im{2};
        refTextureRegion = imcrop(refImage, textureROI{2});
        refUniformRegion = imcrop(refImage, uniformROI{2});
    else
        refImage = [];
        refTextureRegion = [];
        refUniformRegion = [];
    end

    if ~isempty(refImage) && (size(testImage, 3) ~= size(refImage, 3))
        error(message("images:measureTexture:numChannelsMismatch"));
    end

    % Compute the MTF/SFR. This is 3p code that is copied into the internal
    % namespace during build.
    [sfr, rnps, tnps, freq] = ...
        images.internal.deadleaves.texture_mtf( ...
                                refTextureRegion, refUniformRegion, ...
                                testTextureRegion, testUniformRegion );

    % Create tables using the values
    textureSFR = mat2table(sfr, freq, "SFR_");

    if nargout > 1
        testPSD = mat2table(tnps, freq, "PSD_");
    end

    if nargout > 2
        refPSD = mat2table(rnps, freq, "PSD_");
    end
end

function t = mat2table(mat, freq, prefix)
% Helper function that creates a table from 2D matrices.
    if size(mat, 2) == 4
        varNames = ["F", prefix + ["R", "G", "B", "Y"]];
        t = table( freq, mat(:, 1), mat(:, 2), mat(:, 3), mat(:, 4), ...
                                        VariableNames=varNames );
    else
        varNames = ["F", prefix + "I"];
        t = table(freq, mat, VariableNames=varNames);
    end
end

% Copyright 2024 The MathWorks, Inc.