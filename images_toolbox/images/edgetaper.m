function J = edgetaper(varargin)
%EDGETAPER Taper edges using point-spread function.
%   J = EDGETAPER(I,PSF) blurs the edges of image I using the point-spread
%   function, PSF. The output image J is the weighted sum of the original
%   image I and its blurred version. The weighting array, determined by the
%   autocorrelation function of PSF, makes J equal to I in its central
%   region, and equal to the blurred version of I near the edges.
%
%   The EDGETAPER function reduces the ringing effect in image deblurring
%   methods that use the discrete Fourier transform, such as DECONWNR,
%   DECONVREG, and DECONVLUCY.
%
%   Note that the size of the PSF cannot exceed half of the image size in any
%   dimension.
%
%   Class Support
%   -------------
%   I and PSF can be uint8, uint16, int16, double, or single. J has the same
%   class as I.
%
%   Example
%   -------
%      original   = imread('cameraman.tif');
%      PSF = fspecial('gaussian',60,10); 
%      edgesTapered  = edgetaper(original,PSF);
%      figure, imshow(original,[])
%      figure, imshow(edgesTapered,[])
%
%   See also DECONVWNR, DECONVREG, DECONVLUCY, PADARRAY, PSF2OTF, OTF2PSF.


%   Copyright 1993-2018 The MathWorks, Inc.

[I, PSF, sizeI, classI, sizePSF, numNSdim] = parse_inputs(varargin{:});

% 1. Compute the weighting factor alpha used for image windowing,
% alpha=1 within the interior of the picture and alpha=0 on the edges.

% The rate of roll-off of alpha towards the edge is governed by the
% autocorrelation of the PSF along this dimension, and is thus automatically
% controlled by the PSF width in this dimension. 
idx0 = repmat({':'},[1 length(sizePSF)]);
lenNSdim = length(numNSdim);
beta = cell(1,lenNSdim);
for n = 1:lenNSdim % loop through non-singleton dimensions only

  % 1.a. Lets calculate the PSF projection along the n-th dimension
  PSFproj = zeros(1, size(PSF,numNSdim(n)));
  for m = 1:size(PSF,numNSdim(n))
    sliceidx = idx0;
    sliceidx{numNSdim(n)} = m;
    slice = PSF(sliceidx{:});
    PSFproj(m) = sum(slice(:));% always a vector
  end

  % 1.b. Weight factor beta is the autocorrelation of the projection
  z = real(ifftn(abs(fftn(PSFproj,[1 sizeI(numNSdim(n))-1])).^2));
  z = z([1:end 1])/max(z(:));% make sure it is symmetric on both sides
  beta{n} = z;
end

% 1.c. Compute the multi-dimensional, weighting factor alpha.
% It is done in steps to reduce memory consumption.
if n==1 % PSF has one non-singleton dimension
  alpha = 1 - beta{1};
elseif n==2 % PSF has two non-singleton dimension
  alpha = (1 - beta{1}(:))*(1-beta{2});
else % PSF has many non-singleton dimensions
  [beta{:}] = ndgrid(beta{:});
  alpha = 1 - beta{1};
  for k = 2:n
    alpha = alpha.*(1-beta{k});
  end
end

% 1.d. Expand alpha across all dimensions of image
% 1.d.1 Reshape alpha to the right dimensions to include singletons
idx1 = repmat({1},[1 length(sizePSF)]);
idx1(numNSdim) = repmat({':'},[1 n]);
alpha_xtnd(idx1{:}) = alpha; 
% 1.d.2 Unfold alpha to N-dimensions by replicating
idx2 = sizeI;
idx2(numNSdim) = 1;
alpha = repmat(alpha_xtnd,idx2);

% 2. Blur image I by PSF & weight it and I with factor alpha
otf = psf2otf(PSF,sizeI);
blurredI = real(ifftn(fftn(I).*otf));
J = alpha.*I + (1-alpha).*blurredI;

% Bound J image by the same range as I image
mami = [max(I(:)) min(I(:))];
J(J>mami(1)) = mami(1);
J(J<mami(2)) = mami(2);

% Convert to the original class & logic
if ~strcmp(classI,'double') && ~strcmp(classI,'single')
  J = images.internal.changeClass(classI,J);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  Function: parse_inputs
function [I, PSF, sizeI, classI, sizePSF, numNSdim] = parse_inputs(varargin)
% Outputs:  I     the input array (could be any numeric class, 2D, 3D, ND)
%           PSF   operator that applies blurring on the image
%           numNSdim non-singleton dimensions

narginchk(2,2);
I = varargin{1};
PSF = varargin{2};

% Check validity of the input parameters 
% Input image I
classI = class(I);
validateattributes(I,{'uint8','uint16','int16','double','single'},{'finite', ...
                    'real'},mfilename,'I',1);
if ~isfloat(I)
  I = im2single(I);
end

sizeI = size(I);
if prod(sizeI)<2
    error(message('images:edgetaper:imageMustHaveAtLeast2Elements'))
end

% PSF array
validateattributes(PSF,{'uint8','uint16','int16','double','single'},...
              {'finite','real'},mfilename,'PSF',2);
          
if all(PSF(:) == 0)
    error(message('images:edgetaper:psfMustHaveNonZeroElements'))
end

if (numel(PSF) < 2)
    error(message('images:edgetaper:psfMustHaveAtLeast2Elements'))
end

if ~isfloat(PSF)
  PSF = im2single(PSF);
end

if all(PSF(:)>=0) % Normalize positive PSF
  PSF = PSF/sum(PSF(:));
end

% PSF size cannot be larger than sizeI/2 because windowing is performed
% with PSF autocorrelation function
[sizeI, sizePSF] = padlength(sizeI, size(PSF));
numNSdim = find(sizePSF~=1);
if any(sizeI(numNSdim) <= 2*sizePSF(numNSdim))
    error(message('images:edgetaper:psfMustBeSmallerThanHalfImage'))
end
