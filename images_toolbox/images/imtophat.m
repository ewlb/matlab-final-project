function B = imtophat(A,SE) %#codegen
%IMTOPHAT Top-hat filtering.
%   IM2 = IMTOPHAT(IM,SE) performs morphological top hat filtering on the
%   grayscale or binary input image IM using the structuring element SE,
%   where SE is returned by STREL.  SE must be a single structuring
%   element object, not an array containing multiple structuring element
%   objects.
%
%   IM2 = IMTOPHAT(IM,NHOOD), where NHOOD is an array of 0s and 1s that
%   specifies the size and shape of the structuring element, is the same
%   as IM2 = IMTOPHAT(IM,STREL(NHOOD)).
%
%   Class Support
%   -------------
%   IM can be numeric or logical and must be nonsparse.  The output image
%   has the same class as the input image.  If the input is binary
%   (logical), then the structuring element must be flat.
%
%   Example
%   -------
%   % Tophat filtering can be used to correct uneven illumination when the
%   % background is dark.  This example uses tophat filtering with a disk
%   % to remove the uneven background illumination from the rice.png image,
%   % and then it uses imadjust and stretchlim to make the result more
%   % easily visible.
%
%   original = imread('rice.png');
%   figure, imshow(original)
%   se = strel('disk',12);
%   tophatFiltered = imtophat(original,se);
%   figure, imshow(tophatFiltered)
%   contrastAdjusted = imadjust(tophatFiltered);
%   figure, imshow(contrastAdjusted)
%
%   See also IMBOTHAT, STREL.

%   Copyright 1993-2020 The MathWorks, Inc.

[useAlternate, B] = morphop_fast('imtophat', A, SE);
if ~useAlternate
    return
end

validateattributes(A, ...
    {'numeric' 'logical'}, ...
    {'real' 'nonsparse'}, ...
    mfilename, 'IM', 1);

SE = images.internal.strelcheck(SE,mfilename,'SE',2);

strel_is_flat = all(all(isflat(SE)));

coder.internal.errorIf((islogical(A) && ~strel_is_flat), 'images:imtophat:binaryImageWithNonflatStrel');

if islogical(A)
    B = A & ~imopen(A,SE);
else
    B = A -  imopen(A,SE);
end
