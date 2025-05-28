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
%   'DataFormat'                Dimension labels of the input data A and REF
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
%   Input arrays A and REF must be dlarray of underlyingType single or double.
%   Both A and REF must be of the same underlyingType. They must be nonsparse.
%   SSIMVAL is a scalar and SSIMMAP is an array of the same size as A. The
%   outputs are the same underlyingType as the input.
%
%   Notes
%   -----
%   1. SSIMVAL is 1 when A and REF are equivalent indicating highest
%      quality. Smaller values indicate deviations. For some combinations
%      of inputs and parameters, SSIMVAL can be negative.
%
%   2. When non-integer valued 'Exponents' are used, intermediate
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
%   % This example shows how to compute SSIM for dlarray inputs with
%   % spatial, channel, and batch dimensions.
%
%   ref = imread('pout.tif');
%   A = imgaussfilt(ref, 1.5, 'FilterSize', 11, 'Padding', 'replicate');
%
%   % Simulate a tensor with batch dimensions
%   A = repmat(A,[1 1 1 16]);
%   ref = repmat(ref,[1 1 1 16]);
%
%   A = dlarray(single(A),'SSCB');
%   ref = dlarray(single(ref),'SSCB');
%
%   ssimVal = ssim(A,ref);
%   
%   See also MULTISSIM, MULTISSIM3, PSNR.

%   Copyright 2013-2021 The MathWorks, Inc.

narginchk(2,12);

args = matlab.images.internal.stringToChar(varargin);

[A, ref, C, exponents, radius, filtSize, dataformat] = images.internal.qualitymetric.ssimParseInputs(args{:});

[A,ref,perm] = images.internal.qualitymetric.manageDlarrayLabels(A,ref,dataformat);

if isempty(A)
    ssimval = zeros(0, 'like', A);
    ssimmap = A;
    return;
end

if ~isempty(A.dims)
    numSpatialDims = numel(finddim(A,'S'));
else
    % Unlabeled inputs
    numSpatialDims = ndims(A);
end
    
if numSpatialDims == 2
    gaussFilterFcn = @(X) spatialGaussianFilter2d(X, double(radius), double(filtSize));
elseif numSpatialDims == 3
    gaussFilterFcn = @(X) spatialGaussianFilter3d(X, double(radius), double(filtSize));
else
    assert(false,'Unexpected number of spatial dimensions.');
end

% The definition of spatialGaussianFilterND requires that dimensions are
% stripped in order to get desired treatment of spatial and non-spatial
% dims. Cache the original dims and so that we can restore them.
dimsCached = A.dims;

[ssimval,ssimmap] = images.internal.qualitymetric.ssimalgo(A,ref,gaussFilterFcn,exponents,C,numSpatialDims);

% Remove dimensions from the dlarray if it was passed as unformatted.
if ~isempty(dataformat)
    ssimval = ipermute(stripdims(ssimval),perm);
    ssimmap = ipermute(stripdims(ssimmap),perm);
else
    ssimval = dlarray(ssimval,dimsCached);
    ssimmap = dlarray(ssimmap,dimsCached);
end

end

function A = spatialGaussianFilter2d(A, sigma, hsize)
[hCol,hRow] = createSeparableGaussianKernel(sigma, hsize);

typeA = underlyingType(A);
hCol = cast(dlarray(hCol),typeA);
hRow = cast(dlarray(hRow),typeA);

A = stripdims(A);
dataFormat = cat(2,'SS',repmat('U',1,ndims(A)-2));
A = dlconv(A,hRow,0,'Padding','same','PaddingValue','replicate','DataFormat',dataFormat);
A = dlconv(A,hCol,0,'Padding','same','PaddingValue','replicate','DataFormat',dataFormat);
end

function A = spatialGaussianFilter3d(A, sigma, hsize)
[hCol,hRow,hSlc] = createSeparableGaussianKernel(sigma, hsize);

typeA = underlyingType(A);
hCol = cast(dlarray(hCol),typeA);
hRow = cast(dlarray(hRow),typeA);
hSlc = cast(dlarray(hSlc),typeA);

A = stripdims(A);
extraUs = repmat('U',1,ndims(A)-3);
dataFormat2d = cat(2,'SSU',extraUs);
dataFormat3d = cat(2,'SSS',extraUs);
A = dlconv(A,hRow,0,'Padding','same','PaddingValue','replicate','DataFormat',dataFormat2d);
A = dlconv(A,hCol,0,'Padding','same','PaddingValue','replicate','DataFormat',dataFormat2d);
A = dlconv(A,hSlc,0,'Padding','same','PaddingValue','replicate','DataFormat',dataFormat3d);
end

function [hcol,hrow,hslc] = createSeparableGaussianKernel(sigma, hsize)

hcol = images.internal.createGaussianKernel(sigma(1), hsize(1));
hrow = reshape(hcol,1,[]);
hslc = reshape(hcol,1,1,[]);
end
