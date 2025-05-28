function [score, qualityMap] = multissim(varargin)
%MULTISSIM Multi-Scale Structural Similarity Index for image quality
%   SCORE = MULTISSIM(I,Iref) calculates the Multi-Scale Structural
%   Similarity Index (MS-SSIM) for image I using Iref as the reference
%   image. The similarity SCORE is a scalar value. A value of 1 corresponds
%   to the highest quality (when I and Iref are equivalent).
%
%   The Structural Similarity Index Metric (SSIM) measures perceived image
%   quality by quantifying the structural similarity of two images. 
%   Multi-Scale SSIM measures the structural similarity of the images at
%   varying scales, which can be more robust to variations in viewing
%   conditions.
%
%   [SCORE,QUALITYMAP] = MULTISSIM(I,Iref) also returns the local MS-SSIM
%   value for each pixel in I. QUALITYMAP is a cell array containing maps
%   for each scaled versions of I, with each map the same size as the
%   scaled version. Each value in QUALITYMAP reflects the quality value
%   for the corresponding pixel.
%
%   ___ = MULTISSIM(I,Iref,Name,Value) calculates MS-SSIM, using name-value
%   pairs to control aspects of the computation.
%
%   Parameters include:
%
%   'NumScales'         Number of scales used to calculate MS-SSIM, 
%                       specified as a positive integer. By default,
%                       multissim calculates the score using 5 scales. The
%                       number of scales must be a positive integer.
%                       Setting NumScales to 1 is equivalent to using the
%                       ssim function with the Exponents property set to
%                       [1 1 1]. The number of scales is limited by the
%                       size of the input images. The image is scaled
%                       (NumScales - 1) times. Every time it is scaled,
%                       multissim downsamples the image by a factor of 2.
%
%   'ScaleWeights'      The relative values across the scales, specified as
%                       a vector of positive elements. The length of the
%                       ScaleWeights vector depends on the number of
%                       scales, since each element corresponds to each
%                       scale starting with the original size of the image
%                       and downsampling to the next scale by a factor of
%                       2. The ScaleWeights values are normalized to 1. By
%                       default, ScaleWeights is equal to
%                       fspecial('gaussian',[1,numScales],1). multissim
%                       uses a Gaussian distribution because the human
%                       visual sensitivity peaks at middle frequencies and
%                       decreases in both directions.
%
%   'Sigma'             Standard deviation of isotropic Gaussian function,
%                       specified as a positive scalar. This value is used
%                       for weighting the neighborhood pixels around a
%                       pixel for estimating local statistics. multissim
%                       uses this weighting to avoid blocking artifacts in
%                       estimating local statistics. The default value is
%                       1.5.
%
%   'DynamicRange'      Positive scalar, L, that specifies the dynamic
%                       range of the input image. By default, L is chosen 
%                       based on the class of the input image A, as
%                       L = diff(getrangefromclass(A)). For dlarray inputs,
%                       L is 1 by default.
%
%   Class Support
%   -------------
%   I must be a real, non-sparse M-by-N grayscale image of class single,
%   double, int16, uint8, uint16. Iref must be the same class and size as
%   I. Double precision arithmetic is used for double valued input images,
%   all other types are computed using single precision.
%
%   References
%   ----------
%   [1] Wang, Z., Simoncelli, E.P., Bovik, A.C. "Multiscale structural
%   similarity for image quality assessment." Asilomar Conference on
%   Signals, Systems & Computers, 2003.
%
%   Example 1
%   ---------
%   % Compare a batch of images and associated reference images
%   Iref = im2single(imread('pout.tif'));
%   I = imnoise(Iref,'salt & pepper',0.05);
%   Iref = dlarray(repmat(Iref,[1 1 1 32]),'SSCB');
%   I = dlarray(repmat(I,[1 1 1 32]),'SSCB');
%   score = multissim(I,Iref);
%  
%   See also ssim, multissim3, immse, psnr

%   Copyright 2019-2020 The MathWorks, Inc.

narginchk(2,10);
[I,Iref,numScales,scaleWeights,sigma,filterSize,C] = images.internal.parserMultissim('I','multissim',2,varargin{:});

iCheckLabels(I,Iref);

lowpassFilter = @(x) boxFilter(x);
gaussFilter = @(x) spatialGaussianFilter(x,sigma,filterSize);

numSpatialDims = 2;
if nargout > 1
    [score,qualityMap] = images.internal.algmultissim(I,Iref,gaussFilter,...
        lowpassFilter,C,numScales,scaleWeights,false,numSpatialDims);
    
    if ~isempty(I.dims)
       for idx = 1:numel(qualityMap)
          qualityMap{idx} = dlarray(qualityMap{idx},I.dims); 
       end
    end
else
    score = images.internal.algmultissim(I,Iref,gaussFilter,...
        lowpassFilter,C,numScales,scaleWeights,false,numSpatialDims);
end

if ~isempty(I.dims)
    score = dlarray(score,I.dims);
end

end

function y = boxFilter(x)
h = ones(2,'like',x)./4;
h = dlarray(h);
y = dlconv(x,h,0,'Padding','same','PaddingValue','replicate','DataFormat','SSU');
end

function [hcol,hrow] = createSeparableGaussianKernel(sigma, hsize)
hcol = images.internal.createGaussianKernel(double(sigma(1)), double(hsize(1)));
hrow = reshape(hcol,1,[]);
end

function A = spatialGaussianFilter(A, sigma, hsize)
[hCol,hRow] = createSeparableGaussianKernel(sigma, hsize);

typeA = underlyingType(A);
hCol = cast(dlarray(hCol),typeA);
hRow = cast(dlarray(hRow),typeA);

A = dlconv(A,hRow,0,'Padding','same','PaddingValue','replicate','DataFormat','SSU');
A = dlconv(A,hCol,0,'Padding','same','PaddingValue','replicate','DataFormat','SSU');
end

function iCheckLabels(I,Iref)
if (isa(I,'dlarray') && isa(Iref,'dlarray')) && ~isequal(I.dims,Iref.dims)
    error(message('images:multissim:formatDisagreement'));
end

if ~isempty(I.dims)   
    if numel(finddim(I,'S')) ~= 2
        error(message('images:multissim:onlySupportTwoSpatialDims'))
    end
    
    supportedLabels = 'SCB'; % Don't support T and U currently.
    isInSet = ismember(I.dims, supportedLabels);
    if ~all(isInSet)
        error(message('images:multissim:unsupportedFormat'));
    end
end

end

