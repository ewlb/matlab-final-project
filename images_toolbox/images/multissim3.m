function [score, qualityMap] = multissim3(varargin)
%MULTISSIM3 Multi-Scale Structural Similarity Index for image quality
%   SCORE = MULTISSIM3(V,Vref) calculates the Multi-Scale Structural
%   Similarity Index (MS-SSIM) value for a 3D volume V using Vref as the
%   reference. The similarity SCORE is a scalar value. A value of 1
%   corresponds to the highest quality (when V and Vref are equivalent).
%
%   The Structural Similarity Index Metric (SSIM) measures perceived image
%   quality by quantifying the structural similarity of two images. 
%   Multi-Scale SSIM measures the structural similarity of the images at
%   varying scales, which can be more robust to variations in viewing
%   conditions.
%
%   [SCORE,QUALITYMAP] = MULTISSIM3(V,Vref) also returns the local MS-SSIM
%   value for each pixel in V. QUALITYMAP is a cell array containing maps
%   for each scaled versions of V, with each map the same size as the
%   scaled version. Each value in QUALITYMAP reflects the quality value
%   for the corresponding pixel.
%
%   ___ = MULTISSIM3(V,Vref,Name,Value) calculates MS-SSIM, using
%   name-value pairs to control aspects of the computation.
%
%   Parameters include:
%
%   'NumScales'         Number of scales used to calculate MS-SSIM, 
%                       specified as a positive integer. By default,
%                       multissim3 calculates the score using 5 scales. The
%                       number of scales must be a positive integer.
%                       Setting NumScales to 1 is equivalent to using the
%                       ssim function with the Exponents property set to
%                       [1 1 1]. The number of scales is limited by the
%                       size of the input images. The image is scaled
%                       (NumScales - 1) times. Every time it is scaled,
%                       multissim3 downsamples the image by a factor of 2.
%
%   'ScaleWeights'      The relative values across the scales, specified as
%                       a vector of positive elements. The length of the
%                       ScaleWeights vector depends on the number of
%                       scales, since each element corresponds to each
%                       scale starting with the original size of the image
%                       and downsampling to the next scale by a factor of
%                       2. The ScaleWeights values are normalized to 1. By
%                       default, ScaleWeights is equal to
%                       fspecial('gaussian',[1,numScales],1). multissim3
%                       uses a Gaussian distribution because the human
%                       visual sensitivity peaks at middle frequencies and
%                       decreases in both directions.
%
%   'Sigma'             Standard deviation of isotropic Gaussian function,
%                       specified as a positive scalar. This value is used
%                       for weighting the neighborhood pixels around a
%                       pixel for estimating local statistics. multissim3
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
%   V must be a real, non-sparse 3D volume of class single, double, int16,
%   uint8, uint16. Vref must be the same class and size as V. Double
%   precision arithmetic is used for double valued input volumes, all other
%   types are computed using single precision.
%
%   References
%   ----------
%   [1] Wang, Z., Simoncelli, E.P., Bovik, A.C. "Multiscale structural
%   similarity for image quality assessment." Asilomar Conference on
%   Signals, Systems & Computers, 2003.
%
%   Example 1
%   ---------
%   % Compare two 3D volumes and get the MS-SSIM for 5 scales
%   load mri D
%   Vref = squeeze(D);
%   V = imnoise(Vref,'salt & pepper',0.05);
%   score = multissim3(V,Vref);
%
%   Example 2
%   ---------
%   % Compare two volumes and get the similarity metric map
%   load mri D
%   Vref = squeeze(D);
%   V = Vref;
%   % Add noise to a localized part
%   V(1:100,1:100,1:10) = imnoise(Vref(1:100,1:100,1:10),'salt & pepper',0.05);
%   figure;sliceViewer(V)
%   [score, qualityMap] = multissim3(V,Vref);
%   % Visualize the quality map at the first scale
%   figure;sliceViewer(qualityMap{1})
%
%   Example 3
%   ---------
%   % Set the desired ScaleWeights using the weights in reference [1]
%   load mri D
%   Vref = squeeze(D);
%   V = imnoise(Vref,'salt & pepper',0.05);
%   score = multissim3(V,Vref,'ScaleWeights',[0.0448,0.2856,0.3001,0.2363,0.1333]);
%
%   See also ssim, multissim, immse, psnr

%   Copyright 2019-2020 The MathWorks, Inc.

narginchk(2,10);

[V,Vref,numScales,scaleWeights,sigma,filtSize,C] = images.internal.parserMultissim('V','multissim3',3,varargin{:});

supportedHalideType = ~isa(V,'gpuArray');
s = settings;
useHalide = s.images.UseHalide.ActiveValue && supportedHalideType && (ndims(V) <= 3);

if useHalide
    lowpassFilter = []; % defined in Halide code
    sigma = double(sigma);
    filtSize = double(filtSize);
    gaussFilter = images.internal.createGaussianKernel(sigma, filtSize);
    C = C(:);
else
    gaussFilter = @(X) spatialGaussianFilter(X, double(sigma), double(filtSize), 'replicate');
    lowpassFilter = @(X)imfilter(X,ones(2,2,2)./8,'replicate','same');
end

numSpatialDims = min(3,ndims(V));
[score,qualityMap] = images.internal.algmultissim(V,Vref,gaussFilter,...
    lowpassFilter,C,numScales,scaleWeights,useHalide,numSpatialDims);

end

function [hcol,hrow,hslc] = createSeparableGaussianKernel(sigma, hsize)

hcol = images.internal.createGaussianKernel(sigma(1), hsize(1));
hrow = reshape(hcol,1,[]);
hslc = reshape(hcol,1,1,[]);

end

function A = spatialGaussianFilter(A, sigma, hsize, padding)

[hCol,hRow,hSlc] = createSeparableGaussianKernel(sigma, hsize);

A = imfilter(A, hRow, padding, 'conv', 'same');
A = imfilter(A, hCol, padding, 'conv', 'same');
A = imfilter(A, hSlc, padding, 'conv', 'same');
    
end


