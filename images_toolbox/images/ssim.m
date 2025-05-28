function [ssimval, ssimmap] = ssim(varargin)
%SSIM Structural Similarity Index for measuring image quality
%   SSIMVAL = SSIM(A, REF) calculates the Structural Similarity Index
%   (SSIM) value for image A, with the image REF as the reference. A and
%   REF can be 2D grayscale or 3D volume images, and must be of the same
%   size and class. The similarity metric, SSIMVAL, is a double valued
%   scalar. A value of 1 corresponds to the highest quality (when A and
%   REF are equivalent).
%
%   [SSIMVAL, SSIMMAP] = SSIM(A, REF) also returns the local SSIM value for
%   each pixel in SSIMMAP. SSIMMAP has the same size as A.
%
%   [SSIMVAL, SSIMMAP] = SSIM(A, REF, NAME1, VAL1,...) calculates the SSIM
%   value using name-value pairs to control aspects of the computation.
%   Parameter names can be abbreviated.
%
%   Parameters include:
%
%   'Radius'                 - Specifies the standard deviation of
%                              isotropic Gaussian function used for
%                              weighting the neighborhood pixels around a
%                              pixel for estimating local statistics. This
%                              weighting is used to avoid blocking
%                              artifacts in estimating local statistics.
%                              The default value is 1.5.
%
%   'DynamicRange'           - Positive scalar, L, that specifies the
%                              dynamic range of the input image. By
%                              default, L is chosen based on the class of
%                              the input image A, as L =
%                              diff(getrangefromclass(A)). Note that when
%                              class of A is single or double, L = 1 by
%                              default.
%
%   'RegularizationConstants'- Three-element vector, [C1 C2 C3], of
%                              non-negative real numbers that specifies the
%                              regularization constants for the luminance,
%                              contrast, and structural terms (see [1]),
%                              respectively. The regularization constants
%                              are used to avoid instability for image
%                              regions where the local mean or standard
%                              deviation is close to zero. Therefore, small
%                              non-zero values should be used for these
%                              constants. By default, C1 = (0.01*L).^2, C2
%                              = (0.03*L).^2, and C3 = C2/2, where L is the
%                              specified 'DynamicRange' value. If a value
%                              of 'DynamicRange' is not specified, the
%                              default value is used (see name-value pair
%                              'DynamicRange').
%
%   'Exponents'               - Three-element vector [alpha beta gamma],
%                               of non-negative real numbers that specifies
%                               the exponents for the luminance, contrast,
%                               and structural terms (see [1]),
%                               respectively. By default, all the three
%                               exponents are 1, i.e. the vector is [1 1
%                               1].
%
%   'DataFormat'              - Dimension labels of the input data A and REF
%                               specified as a string scalar or character
%                               vector. The format options 'S','C', and 'B' 
%                               are supported. The options 'S', 'C' and 'B' 
%                               correspond to spatial, channel, and batch 
%                               dimensions, respectively. A separate SSIMVA
%                               SSIMVAL and SSIMMAP output will be returned
%                               for each non-spatial dimension.
%
%   Class Support
%   -------------
%   Input arrays A and REF must be one of the following classes: uint8,
%   int16, uint16, single, or double. Both A and REF must be of the same
%   class. They must be nonsparse. SSIMVAL is a scalar and SSIMMAP is an
%   array of the same size as A. Both SSIMVAL and SSIMMAP are of class
%   double, unless A and REF are of class single in which case SSIMVAL and
%   SSIMMAP are of class single.
%
%   Notes
%   -----
%   1. A and REF can be arrays of up to three dimensions. All 3D arrays
%      are considered 3D volumetric images. RGB images will also be
%      processed as 3D volumetric images.
%
%   2. Input image A and reference image REF are converted to
%      floating-point type for internal computation.
%
%   3. For signed-integer images (int16), an offset is applied to bring the
%      gray values in the non-negative range before computing the SSIM
%      index.
%
%   4. SSIMVAL is 1 when A and REF are equivalent indicating highest
%      quality. Smaller values indicate deviations. For some combinations
%      of inputs and parameters, SSIMVAL can be negative.
%
%   5. When non-integer valued 'Exponents' are used, intermediate
%      luminance, contrast and structural terms are clamped to [0, inf]
%      range to prevent complex valued outputs.
%
%   References:
%   -----------
%   [1] Z. Wang, A. C. Bovik, H. R. Sheikh, and E. P. Simoncelli, "Image
%       Quality Assessment: From Error Visibility to Structural
%       Similarity," IEEE Transactions on Image Processing, Volume 13,
%       Issue 4, pp. 600- 612, 2004.
%
%   Example
%   ---------
%   % This example shows how to compute SSIM value for a blurred image 
%   % given the original reference image.
%
%   ref = imread('pout.tif');
%   A = imgaussfilt(ref, 1.5, 'FilterSize', 11, 'Padding', 'replicate');
%
%   subplot(1,2,1); imshow(ref); title('Reference Image');
%   subplot(1,2,2); imshow(A);   title('Blurred Image');
%
%   [ssimval, ssimmap] = ssim(A,ref);
%
%   fprintf('The SSIM value is %0.4f.\n',ssimval);
%
%   figure, imshow(ssimmap,[]);
%   title(sprintf('SSIM Index Map - Mean SSIM Value is %0.4f',ssimval));
%   
%   See also IMMSE, MEAN, MEDIAN, PSNR, SUM, VAR.

%   Copyright 2013-2021 The MathWorks, Inc.

narginchk(2,12);

args = matlab.images.internal.stringToChar(varargin);

[A, ref, C, exponents, radius, filtSize, dataformat] = images.internal.qualitymetric.ssimParseInputs(args{:});
 
% Validate ndims of A differently depending on whether or not DataFormat
% specified to preserve behavior pre introduction of DataFormat Name/Value.
if isempty(dataformat)
    if (ndims(A) > 3)
        error(message('images:ssim:supportedDimsUnformattedInput'))
    else
        dataformat = repmat('S',1,ndims(A));
    end
else
    if (sum(dataformat == 'S') > 3) || (sum(dataformat == 'S') < 2)
        error(message('images:ssim:unsupportedDataFormatSpatialDims')); 
    end
end

if isempty(A)
    ssimval = zeros(0, 'like', A);
    ssimmap = A;
    return;
end

numSpatialDims = sum(dataformat == 'S');
if numSpatialDims == 2
    gaussFilterFcn = @(X)imgaussfilt(X, radius, 'FilterSize', filtSize, 'Padding','replicate');
elseif numSpatialDims == 3
    gaussFilterFcn = @(X) spatialGaussianFilter(X, double(radius), double(filtSize), 'replicate');
else
    assert(false,'Unexpected number of spatial dimensions.');
end

[ssimval,ssimmap] = images.internal.qualitymetric.ssimalgo(A,ref,gaussFilterFcn,exponents,C,numSpatialDims);

end

function A = spatialGaussianFilter(A, sigma, hsize, padding)
[hCol,hRow,hSlc] = createSeparableGaussianKernel(sigma, hsize);

A = imfilter(A, hRow, padding, 'conv', 'same');
A = imfilter(A, hCol, padding, 'conv', 'same');
A = imfilter(A, hSlc, padding, 'conv', 'same'); 
end

function [hcol,hrow,hslc] = createSeparableGaussianKernel(sigma, hsize)

hcol = images.internal.createGaussianKernel(sigma(1), hsize(1));
hrow = reshape(hcol,1,[]);
hslc = reshape(hcol,1,1,[]);
end
