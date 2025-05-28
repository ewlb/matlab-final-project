function [L, Centers] = imsegkmeans3(V,k, varargin)
%IMSEGKMEANS3 K-means clustering based volume segmentation.
%   L = imsegkmeans3(V,k) segments the input volume V into k clusters by
%   performing k-means clustering and returns the segmented labeled output
%   in L. Input V is either a grayscale or multi-channel volume.
%
%   [L, Centers] = imsegkmeans3(V,k) returns the K cluster centroid
%   locations in the variable Centers.
%   
%   L = imsegkmeans3(V,K,NAME1,VAL1,...) segments the volume using
%   name-value pairs to control features to be used for segmentation.
%   Parameter names can be abbreviated.
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
%   The input V must be of size MxNxPxC, with C=1 for grayscale and general
%   C for a multi-channel volume. V must be real and non-sparse. The output
%   Centers is a numeric matrix of size K-by-C i.e. Number of
%   Clusters-by-Number of Channels and of same class as V. The output L has
%   the same first three dimensions as input V. The class of L depends on
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
%   1D and 2D inputs will be treated as degenerate 3D cases and treated
%   like 3D volumes. If 2D behavior is intended, consider using imsegkmeans
%   instead.
% 
%   References
%   ----------
%   Arthur, D. and S. Vassilvitskii. k-means++: the advantages of careful
%   seeding, SODA '07: Proceedings of the eighteenth annual ACM-SIAM
%   symposium on Discrete algorithms, 2007
%
%   Example: Volume Segmentation
%   ----------------------------
%   % This example shows segmentation of a volume of brain MRI.
%
%   % Load 3D image
%   load mristack
%   V = mristack;
%   
%   L = imsegkmeans3(V,3);
%   volshow(L)
%
%
%   See also IMSEGKMEANS, SUPERPIXELS3, LAZYSNAPPING, WATERSHED. 

%   Copyright 2018 The MathWorks, Inc.

[L, Centers] = images.internal.algkmeans(V,k,'imsegkmeans3', varargin{:});
