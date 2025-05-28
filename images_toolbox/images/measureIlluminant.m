function illum = measureIlluminant(im, roiPosition, options)

    arguments
        im  (:, :, 3) {mustBeA(im, ["uint8", "uint16", "single", "double"])}
        roiPosition (:, 4) {images.internal.testchart.mustBeValidROI}
        options.ColorSpace (1, 1) string = "srgb"
    end

    inColorSpace = validatestring( options.ColorSpace, ...
                                   [ "srgb", "adobe-rgb-1998", ...
                                     "prophoto-rgb" ] );

    im = rgb2lin(im, ColorSpace=inColorSpace);

    illumMask = images.internal.testchart.createROIMask(im, roiPosition);

    illum = illumgray(im, [0 0], Mask=illumMask);

end

% Copyright 2017-2023 The MathWorks, Inc.