function lightness = rgb2lightness(rgb)
%RGB2LIGHTNESS Convert RGB color values to lightness.
%
%   lightness = rgb2lightness(rgb) converts RGB values to lightness values
%   while eliminating color information. rgb must be an M-by-N-by-3 image
%   array. The lightness component is approximately same as the L* component 
%   in CIE 1976 L*a*b*.
%
%   Class Support
%   -------------
%   The type of rgb can be uint8, uint16, single, or double. The output
%   will be an M-by-N image array. The output type is single unless the
%   input type is double, in which case the output type is double.
%
%   Notes
%   ------
%   Input rgb must be in sRGB color space and the reference white point is
%   'd65'.
%
%   Example
%   -------
%   % Convert RGB image to Lightness and display the Lightness component as an image.
%
%     rgb = imread('peppers.png');
%     lightness = rgb2lightness(rgb);
%     imshow(lightness,[0 100]);
%
%   See also RGB2LAB, LAB2RGB, XYZ2LAB, LAB2XYZ, RGB2XYZ, XYZ2RGB.

%   Copyright 2018 The MathWorks, Inc.

%#codegen
%#ok<*EMCLS>
%#ok<*EMCA>

rgb = parseInputs(rgb);

if ~isfloat(rgb)
    I = im2single(rgb);
else
    I = rgb;
end
lightness = images.internal.algrgb2lightness(I);
end


function rgb  = parseInputs(rgb)
coder.internal.prefer_const(rgb);
% Validate rgb
validateattributes(rgb,{'single','double','uint8','uint16'},...
    {'real','nonsparse','nonempty'},mfilename,'RGB',1)
coder.internal.errorIf(((size(rgb,3)~=3 || ndims(rgb)~=3)),...
    'images:rgb2ntsc:invalidTruecolorImage');
end
