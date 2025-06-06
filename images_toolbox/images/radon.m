function [P,r] = radon(I,theta,n)
%RADON Radon transform.
%   The RADON function computes the Radon transform, which is the
%   projection of the image intensity along a radial line oriented at a
%   specific angle.
%
%   R = RADON(I,THETA) returns the Radon transform of the intensity image I
%   for the angle THETA degrees. If THETA is a scalar, the result R is a
%   column vector containing the Radon transform for THETA degrees. If
%   THETA is a vector, then R is a matrix in which each column is the Radon
%   transform for one of the angles in THETA. If you omit THETA, it
%   defaults to 0:179.
%
%   [R,Xp] = RADON(...) returns a vector Xp containing the radial
%   coordinates corresponding to each row of R.
%
%   Class Support
%   -------------
%   I can be of class double, logical or of any integer class and must be
%   two-dimensional. THETA is a vector of class double.  Neither of the
%   inputs can be sparse.
%
%   Remarks
%   -------
%   The radial coordinates returned in Xp are the values along the x-prime
%   axis, which is oriented at THETA degrees counterclockwise from the
%   x-axis. The origin of both axes is the center pixel of the image, which
%   is defined as:
%
%        floor((size(I)+1)/2)
%
%   For example, in a 20-by-30 image, the center pixel is
%   (10,15).
%
%   Example
%   -------
%       prefstate = iptgetpref('ImshowAxesVisible');
%       iptsetpref('ImshowAxesVisible','on')
%       I = zeros(100,100);
%       I(25:75, 25:75) = 1;
%       theta = 0:180;
%       [R,xp] = radon(I,theta);
%       imshow(R,[],'Xdata',theta,'Ydata',xp,'InitialMagnification','fit')
%       xlabel('\theta (degrees)')
%       ylabel('x''')
%       colormap(gca,hot), colorbar
%       iptsetpref('ImshowAxesVisible',prefstate);
%
%   See also FAN2PARA, FANBEAM, IFANBEAM, IRADON, PARA2FAN, PHANTOM.

% Grandfathered syntax
%   R = RADON(I,THETA,N) returns a Radon transform with the
%   projection computed at N points. R has N rows. If you do not
%   specify N, the number of points the projection is computed at
%   is:
%
%        2*ceil(norm(size(I)-floor((size(I)-1)/2)-1))+3
%
%   This number is sufficient to compute the projection at unit
%   intervals, even along the diagonal.
%

%   Copyright 1993-2020 The MathWorks, Inc.

validateattributes(I,{'numeric','logical'},{'2d','nonsparse'},mfilename,'I',1);

if (nargin < 2)
    theta = 0:179;
else
    validateattributes(theta,{'double'},{'real','nonsparse','vector'},mfilename,'THETA',2);
end

[P,r] = images.internal.builtins.radonc(double(I),theta);

if (nargin == 3)
    validateattributes(n,{'double'},{'real','positive','scalar','integer'},mfilename,'n',3);
    if size(P,1) ~= n
        % Grandfathered syntax
        % Resize along the column direction using linear interpolation.
        new_r = linspace(min(r), max(r), n)';
        P = interp1(r(:), P, new_r(:), '*linear');
        P = P * length(r) / length(new_r);  % keeps scaling roughly the same
        r = new_r;
    end
end
