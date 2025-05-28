function B = imerode(A,se,varargin) %#codegen
%IMERODE Erode image.
%   IM2 = IMERODE(IM,SE) erodes the grayscale, binary, or packed binary image
%   IM, returning the eroded image, IM2.  SE is a structuring element
%   object, or array of structuring element objects, returned by the
%   STREL or OFFSETSTREL functions.
%
%   If IM is logical and the structuring element is flat, IMERODE
%   performs binary erosion; otherwise it performs grayscale erosion.  If
%   SE is an array of structuring element objects, IMERODE performs
%   multiple erosions of the input image, using each structuring element
%   in succession.
%
%   IM2 = IMERODE(IM,NHOOD) erodes the image IM, where NHOOD is an array
%   of 0s and 1s that specifies the structuring element.  This is
%   equivalent to the syntax IMERODE(IM,STREL(NHOOD)).  IMERODE uses this
%   calculation to determine the center element, or origin, of the
%   neighborhood:  FLOOR((SIZE(NHOOD) + 1)/2).
%
%   IM2 = IMERODE(IM,SE,PACKOPT,M) or IMERODE(IM,NHOOD,PACKOPT,M) specifies
%   whether IM is a packed binary image and, if it is, provides the row
%   dimension, M, of the original unpacked image.  PACKOPT can have
%   either of these values:
%
%       'ispacked'    IM is treated as a packed binary image as produced
%                     by BWPACK.  IM must be a 2-D uint32 array and SE
%                     must be a flat 2-D structuring element.  If the
%                     value of PACKOPT is 'ispacked', SHAPE must be
%                     'same'.
%
%       'notpacked'   IM is treated as a normal array.  This is the
%                     default value.
%
%   If PACKOPT is 'ispacked', you must specify a value for M.
%
%   IM2 = IMERODE(...,SHAPE) determines the size of the output image.
%   SHAPE can have either of these values:
%
%       'same'        Make the output image the same size as the input
%                     image.  This is the default value.  If the value of
%                     PACKOPT is 'ispacked', SHAPE must be 'same'.
%
%       'full'        Compute the full erosion.
%
%   Class Support
%   -------------
%   IM can be numeric or logical and it can be of any dimension.  If IM is
%   logical and the structuring element is flat, then output will be
%   logical; otherwise the output will have the same class as the input. If
%   the input is packed binary, then the output is also packed binary.
%
%   Example 1
%   ---------
%   % Erode the binary image in text.png with a vertical line
%       originalBW = imread('text.png');
%       se = strel('line',11,90);
%       erodedBW = imerode(originalBW,se);
%       imshowpair(originalBW,erodedBW,'montage');
%
%   Example 2
%   ---------
%   % Erode the grayscale image in cameraman.tif with a rolling ball
%       originalI = imread('cameraman.tif');
%       se = offsetstrel('ball',5,5);
%       erodedI = imerode(originalI,se);
%       imshowpair(originalI,erodedI,'montage')
%
%   Example 3
%   ---------
%   % Erode the mristack volume, using a cube of side 3
%       % Create a binary volume
%       load mristack
%       BW = mristack < 100;
%
%       % Erode the volume with a cubic structuring element
%       se = strel('cube',3);
%       erodedBW = imerode(BW, se);
%
%   See also BWHITMISS, BWPACK, BWUNPACK, CONV2, FILTER2, IMCLOSE,
%            IMDILATE, IMOPEN, STREL, OFFSETSTREL.

%   Copyright 1993-2018 The MathWorks, Inc.

narginchk(2,5);
[useAlternate, B_] = morphop_fast('imerode', A, se, varargin{:});
if useAlternate
    B = images.internal.morphop(A,se,'erode',mfilename,varargin{:});
else
    B = B_;
end
