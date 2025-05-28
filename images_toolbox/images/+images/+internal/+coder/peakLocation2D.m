% Find the subpixel peak location for the matrix F.
%
% If the named argument RefinementMethod is "poly2", the default, then a
% 2-D 2nd-order polynomial fit will be used on the 3x3 neighborhood around
% the peak element to refine the peak location. 

function [xpeak,ypeak,F_max] = peakLocation2D(F) %#codegen
    arguments
        F  {mustBeFloat, mustBeNonempty}
    end

    % Find the location of the peak value of F. If the peak value occurs in
    % more than one location, pick the first one (in column-major order).
    [F_max,i] = max(F,[],'all');
    [yi,xi] = ind2sub(size(F),i);

    [M,N] = size(F);
    if (xi == 1) || (xi == N) || ...
            (yi == 1) || (yi == M)
        % If the peak value (or the first peak value found by max) is
        % located on an image border, don't attempt to refine it.
        xpeak = xi;
        ypeak = yi;
        return
    end

    % Fit a 2nd-order polynomial to 9 points
    % using 9 pixels centered on yi,xi
    u = F(yi-1:yi+1, xi-1:xi+1);
    u = u(:);
    x = [-1 -1 -1  0  0  0  1  1  1]';
    y = [-1  0  1 -1  0  1 -1  0  1]';

    % u(x,y) = A(1) + A(2)*x + A(3)*y + A(4)*x*y + A(5)*x^2 + A(6)*y^2
    X = [ones(9,1),  x,  y,  x.*y,  x.^2,  y.^2];

    % u = X*A
    A = X\u;

    % Get absolute maximum, where du/dx = du/dy = 0
    x_offset = (-A(3)*A(4)+2*A(6)*A(2)) / (A(4)^2-4*A(5)*A(6));
    y_offset = -1 / ( A(4)^2-4*A(5)*A(6))*(A(4)*A(2)-2*A(5)*A(3));

    % Restrict the maximum absolute value of the offsets to 0.5.
    % Ordinarily, such an offset wouldn't occur because the peak matrix
    % value would just be shifted over to the next element. So, an absolute
    % value higher than 0.5 is likely due to a small-neighborhood fitting
    % artifact.
    x_offset = min(abs(x_offset),0.5) * sign(x_offset);
    y_offset = min(abs(y_offset),0.5) * sign(y_offset);

    xpeak = double(xi + x_offset);
    ypeak = double(yi + y_offset);
end

% Copyright 2024 The MathWorks, Inc.