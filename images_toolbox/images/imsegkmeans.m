function [L, Centers] = imsegkmeans(I,k, varargin)
%IMSEGKMEANS K-means clustering based image segmentation.
%   L = imsegkmeans(I,k) segments the input image I into k clusters by
%   performing k-means clustering and returns the segmented labeled output
%   in L. Input I is either a grayscale, RGB or a hyperspectral image.
%
%   [L, Centers] = imsegkmeans(I,k) returns the K cluster centroid
%   locations in the variable Centers.
%   
%   L = imsegkmeans(I,K,NAME1,VAL1,...) segments the image using name-value
%   pairs to control features to be used for segmentation. Parameter names
%   can be abbreviated.
%
%   Parameters include:
%
%   'NormalizeInput'           Boolean value that specifies whether to
%                              normalize the input data to be zero mean and
%                              unit variance. Each channel of the input is
%                              normalized individually. Available options
%                              are :
%
%                               true    : Normalize input. (Default)
%                               false   : Do not normalize the input.
%
%   'NumAttempts'              Number of times to repeat the clustering
%                              process using new initial cluster centroid
%                              positions. A positive integer, default is 3.
%
%   'MaxIterations'            Maximum number of iterations to be used as
%                              the algorithm termination criteria. A
%                              positive integer, default is 100.
%
%   'Threshold'                Threshold is the desired accuracy to use as
%                              an algorithm termination criteria. The
%                              algorithm stops as soon as each of the
%                              cluster centers moves less than the threshold
%                              in consecutive iterations. The default value
%                              is 1e-4.
%
%
%   Class Support
%   -------------
%   The input I must be real, non-sparse array of size MxNxC, where C
%   denotes the number of channels and could be used in the context of
%   grayscale, color or hyperspectral images. I must be of one of the
%   following classes: uint8, uint16, int8, int16 or single. The output
%   Centers is a numeric matrix of size K-by-C i.e. Number of
%   Clusters-by-Number of Channels, and same class as input I. The output L
%   has the same first two dimensions as input I. The class of L depends on
%   number of clusters (k), and is determined using the following table.
%
%       Class         Range
%       --------      --------------------------------
%       'uint8'       k <= 255
%       'uint16'      256 <= k <= 65535
%       'uint32'      65536 <= k <= 2^32-1
%       'double'      2^32 <= k 
%
%   Notes
%   -----
%   The function yields reproducible results. The output will not vary
%   in multiple runs given the same input and same input arguments.
%
%   References
%   ----------
%   Arthur, D. and S. Vassilvitskii. k-means++: the advantages of careful
%   seeding, SODA '07: Proceedings of the eighteenth annual ACM-SIAM
%   symposium on Discrete algorithms, 2007
%
%   Example 1
%   ---------
%   % This example demonstrates intensity based image segmentation using 
%   % kmeans 
%
%   % Read in image
%   Im = imread('cameraman.tif');
%   subplot(1,2,1) 
%   imshow(Im)
%   title('Original Image');
%   
%   [L,Centers] = imsegkmeans(Im,3);
%   B = labeloverlay(Im,L);
%   subplot(1,2,2)
%   imshow(B)
%   title('Labeled Image');
%
%   Example 2
%   ---------
%   % This example augments image intensity with gabor filter information 
%   % and spatial location data to obtain a better segmentation.
%
%   % Read in image
%   Im = imread('kobi.png');
%   Im = imresize(Im,0.25);
%   subplot(1,2,1)
%   imshow(Im)
%   title('Original Image');
%   Imgray = rgb2gray(im2single(Im));
% 
%   % Gabor Filtering
%   wavelength = 2.^(0:5) * 3;
%   orientation = 0:45:135;
%   g = gabor(wavelength,orientation);
%   gabormag = imgaborfilt(Imgray,g);
%   % Gaussian smoothing of gabor magnitude to remove local variations
%   for i = 1:length(g)
%         sigma = 0.5*g(i).Wavelength;
%       gabormag(:,:,i) = imgaussfilt(gabormag(:,:,i),3*sigma); 
%   end
% 
%   % Finding X and Y spatial features
%   [r,c] = size(Imgray);
%   [X,Y] = meshgrid(1:c, 1:r);
% 
%   % Augmenting input with gabor and spatial features
%   InpAug = cat(3, Imgray, gabormag, single(X), single(Y));
% 
%   % Performing segmentation using kmeans
%   L = imsegkmeans(InpAug,2,'NormalizeInput',true);
%   B = labeloverlay(Im,L);
%   subplot(1,2,2)
%   imshow(B)
%   title('Labeled Image');
%  
%   Example 3
%   ---------
%   % This example demonstrates Image compression using color quantization. 
%
%   % Read in image
%   Im = imread('peppers.png');
%
%   % Segment image using color quantization
%   [L,C] = imsegkmeans(Im,100);
%   out = label2rgb(L,im2double(C));
%
%   % Writing the output to a file resulting in ~2x+ image compression.
%   imwrite(Im,'peppersOriginal.png');
%   imwrite(out,'peppersQuantized.png');
%
%   % Display the output
%   figure,imshow(out)
%
%   See also IMSEGKMEANS3, LABEL2RGB, SUPERPIXELS, LAZYSNAPPING, WATERSHED, LABELMATRIX, imageSegmenter.

%   Copyright 2018 The MathWorks, Inc.

[L, Centers] = images.internal.algkmeans(I,k,'imsegkmeans', varargin{:});