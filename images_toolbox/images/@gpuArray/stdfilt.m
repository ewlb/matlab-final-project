function J = stdfilt(I, varargin)
%STDFILT Local standard deviation of image.
%   J = STDFILT(I) returns a gpuArray J, where each output pixel contains
%   the standard deviation value of the 3-by-3 neighborhood around the
%   corresponding pixel in the input gpuArray image I. I can have any
%   dimension. The output image J is the same size as the input image I.
%
%   For pixels on the borders of I, STDFILT uses symmetric padding.  In
%   symmetric padding, the values of padding pixels are a mirror reflection
%   of the border pixels in I.
%
%   J = STDFILT(I,NHOOD) performs standard deviation filtering of the input
%   gpuArray image I where you specify the neighborhood in NHOOD.  NHOOD is
%   either a vector or a 2D matrix of zeros and ones where the nonzero
%   elements specify the neighbors.  NHOOD's size must be odd in each
%   dimension.
%
%   By default, STDFILT uses the neighborhood ones(3). STDFILT determines
%   the center element of the neighborhood by FLOOR((SIZE(NHOOD) + 1)/2).
%   For information about specifying neighborhoods, see Notes.
%
%   Class Support
%   -------------
%   I can be logical or numeric gpuArray and must be real.  NHOOD can
%   be logical or numeric and must contain zeros and/or ones.
%   J is double.
%
%   Remarks
%   -------
%   The GPU implementation of this function only supports 2D neighborhoods.
%
%   Notes
%   -----
%   To specify the neighborhoods of various shapes, such as a disk, use the
%   STREL function to create a structuring element object and then use the
%   GETNHOOD function to extract the neighborhood from the structuring
%   element object.
%
%   Examples
%   --------
%       I = gpuArray(imread('circuit.tif'));
%       J = stdfilt(I);
%       imshow(I);
%       figure, imshow(J,[]);
%
%   See also GPUARRAY/STD2, RANGEFILT, ENTROPYFILT, STREL, STREL/GETNHOOD,
%            GPUARRAY.

%   Copyright 2013-2024 The MathWorks, Inc.

narginchk(1,2);

if ~isgpuarray(I)
    % This has to be the two input syntax, with NHOOD on the GPU.
    % Call CPU version
    h = gather(varargin{1});
    J = stdfilt(I,h);
    return;
end

if nargin == 2
    h = gpuArray(varargin{1});

    validateattributes(h,...
        {'logical','uint8','int8','uint16','int16','uint32','int32','single','double'},...
        {'real','2d','nonsparse'},mfilename,'NHOOD',2);

    % h must contain zeros and/or ones.
    bad_elements = (h ~= 0) & (h ~= 1);
    if any(bad_elements,"all")
        error(message('images:stdfilt:invalidNeighborhoodValue'))
    end

    % h's size must be a factor of 2n-1 (odd).
    sizeH = size(h);
    if ~all(rem(sizeH,2))
        error(message('images:stdfilt:invalidNeighborhoodSize'))
    end

    if ~isa(h,'double')
        h = double(h);
    end

else
    h = gpuArray.ones(3);
end

validateattributes(I,...
    {'logical','uint8','int8','uint16','int16','uint32','int32','single','double'},...
    {'real','nonsparse'},mfilename,'I',1);


if ~isUnderlyingType(I,'double')
    I = double(I);
end

% Now the main algorithm copied from algstdfilt with minor modifications for
% performance. Note that I, conv1, and conv2 can all be large so we move
% them on last usage.
n = sum(h, "all");
if n == 1
    J = zeros(size(I), Like=matlab.lang.internal.move(I));
else
    n1 = n - 1;
    conv2 = imfilter(I, h/sqrt(n*n1), 'symmetric').^2;
    conv1 = imfilter(matlab.lang.internal.move(I).^2, h/n1 , 'symmetric');
    J = sqrt(max((matlab.lang.internal.move(conv1) - matlab.lang.internal.move(conv2)),0));
end

end
