function bout=grayslice(varargin)
%GRAYSLICE Create indexed image from intensity image by thresholding.
%   X=GRAYSLICE(I,N) thresholds the intensity image I using threshold values
%   0, 1/N, 2/N, ..., (N-1)/N, returning an indexed image in X.
%
%   X=GRAYSLICE(I,V), where V is a vector of values between the dynamic 
%   range of the image I based on its class type, thresholds I using the 
%   values of V as thresholds, returning an indexed image in X.
%
%   You can view the thresholded image using IMSHOW(X,MAP) with a colormap of
%   appropriate length.
%
%   Class Support
%   -------------
%   The input image I must be uint8, uint16, int16, single or double, and 
%   nonsparse. Note that the threshold values are always between 
%   the dynamic range of the image I, based on its class type. If image I 
%   of class int16, the threshold values are between the dynamic range of 
%   the class uint16.
%
%   The class of the output image X depends on the number of threshold values,
%   as specified by N or length(V). If the number of threshold values is less
%   than 256, then X is of class uint8, and the values in X range from 0 to 
%   N-1 or length(V). If the number of threshold values is 256 or greater, 
%   X is of class double, and the values in X range from 1 to N or length(V)+1.
%
%   Example
%   -------
%   % Use multilevel thresholding to enhance high intensity areas in the image.
%
%       I = imread('snowflakes.png');
%       X = grayslice(I,16);
%       figure, imshow(I), figure, imshow(X,jet(16))
%
%   See also GRAY2IND.

%   Copyright 1993-2020 The MathWorks, Inc.

narginchk(1,2);

matlab.images.internal.errorIfgpuArray(varargin{:});

I = varargin{1};
validateattributes(I,{'double','uint8','uint16','int16','single'},{'nonsparse','real'}, ...
              mfilename,'I',1);

if nargin == 1
  z = 10;
else
    z = varargin{2};
  validateattributes(z,{'double','uint8','uint16','int16','single'},{'nonsparse','real'}, ...
      mfilename,'z',2);
  if ~isa(z,'double')
      z = double(z);
  end
end

% Convert int16 data to uint16.
if isa(I,'int16')
  I = images.internal.builtins.int16touint16(I);
end

range = getrangefromclass(I);

if ( (numel(z) == 1) && ((round(z)==z) || (z>1)) )
   % arg2 is scalar: Integer number of equally spaced levels.
   n = z;
   if isinteger(I)
       z = range(2) * (0:(n-1))/n;
   else % I is double or single
      z = (0:(n-1))/n;
   end
else
   % arg2 is vector containing threshold levels
   n = length(z)+1;
   if isinteger(I)
       % uint8 or uint16
      zmax = range(2);
      zmin = range(1);
   else
       % double or single
      maxI = max(I(:));
      minI = min(I(:));
      % make sure that zmax and zmin are double
      zmax = max(1,double(maxI));
      zmin = min(0,double(minI));
   end
   newzmax = min(zmax,sort(z(:)));
   newzmax = newzmax';
   newzmax = max(zmin,newzmax);
   z = [zmin,newzmax]; % sort and threshold z
end

% Get output matrix of appropriate size and type
if n < 256
   b = repmat(uint8(0), size(I));
else
   b = zeros(size(I));
end

% Loop over all intervals, except the last
for i = 1:length(z)-1
   % j is the index value we will output, so it depend upon storage class
   if isa(b,'uint8')
      j = i-1;
   else
      j = i;
   end
   d = find(I>=z(i) & I<z(i+1));
   if ~isempty(d),
      b(d) = j;
   end
end

% Take care of that last interval
d = find(I >= z(end));
if ~isempty(d)
   % j is the index value we will output, so it depend upon storage class
   if isa(b, 'uint8'),
      j = length(z)-1;
   else
      j = length(z);
   end
   b(d) = j;
end

if nargout == 0
   imshow(b,jet(n))
   return
end
bout = b;
