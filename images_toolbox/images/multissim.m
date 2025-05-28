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
%                       L = diff(getrangefromclass(A)). Note that when
%                       class of A is single or double, L = 1 by default.
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
%   % Compare two images and get the MS-SSIM for 5 scales
%   Iref = imread('pout.tif');
%   I = imnoise(Iref,'salt & pepper',0.05);
%   figure; montage({Iref,I});
%   score = multissim(I,Iref);
%
%   Example 2
%   ---------
%   % Compare two images and get the similarity metric map
%   Iref = imread('pout.tif');
%   I = Iref;
%   % Add noise to a localized part
%   I(1:100,1:100) = imnoise(Iref(1:100,1:100),'salt & pepper',0.05);
%   figure; montage({Iref,I});
%   [~, qualityMap] = multissim(I,Iref);
%   figure;montage(qualityMap,'Size',[1 5])
%
%   Example 3
%   ---------
%   % Set the desired ScaleWeights using the weights in reference [1]
%   Iref = imread('pout.tif');
%   I = imnoise(Iref,'salt & pepper',0.05);
%   figure; montage({Iref,I});
%   score = multissim(I,Iref,'ScaleWeights',[0.0448,0.2856,0.3001,0.2363,0.1333]);
%
%   See also ssim, multissim3, immse, psnr

%   Copyright 2019-2020 The MathWorks, Inc.


narginchk(2,10);

[I,Iref,numScales,scaleWeights,sigma,filtSize,C] = images.internal.parserMultissim('I','multissim',2,varargin{:});

supportedHalideType = ~isa(I,'gpuArray');
s = settings;
useHalide = s.images.UseHalide.ActiveValue && supportedHalideType && ismatrix(I);

if useHalide
    lowpassFilter = []; % defined in Halide code
    sigma = double(sigma);
    filtSize = double(filtSize);
    gaussFilter = images.internal.createGaussianKernel(sigma, filtSize);
    C = C(:);
else
    lowpassFilter = @(X)imfilter(X,ones(2)./4,'replicate','same');    
    gaussFilter = @(X)imgaussfilt(X,sigma,'FilterSize',filtSize,...
        'Padding','replicate');
end

numSpatialDims = 2;
if nargout > 1
    [score,qualityMap] = images.internal.algmultissim(I,Iref,gaussFilter,...
        lowpassFilter,C,numScales,scaleWeights,useHalide,numSpatialDims);
else
    score = images.internal.algmultissim(I,Iref,gaussFilter,...
        lowpassFilter,C,numScales,scaleWeights,useHalide,numSpatialDims);
end

end


