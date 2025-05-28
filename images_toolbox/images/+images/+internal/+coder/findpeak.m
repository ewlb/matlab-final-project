function [xpeak, ypeak, maxF] = findpeak(f,subpixel)
%FINDPEAK Find extremum of matrix.
%   [XPEAK,YPEAK,MAXF] = FINDPEAK(F,SUBPIXEL) finds the extremum of F,
%   MAXF, and its location (XPEAK, YPEAK). F is a matrix. MAXF is the maximum
%   absolute value of F, or an estimate of the extremum if a subpixel
%   extremum is requested.
%
%   SUBPIXEL is a boolean that controls if FINDPEAK attempts to estimate the
%   extremum location to subpixel precision. If SUBPIXEL is false, FINDPEAK
%   returns the coordinates of the maximum absolute value of F and MAXF is
%   max(abs(F(:))). If SUBPIXEL is true, FINDPEAK fits a 2nd order
%   polynomial to the 9 points surrounding the maximum absolute value of
%   F. In this case, MAXF is the absolute value of the polynomial evaluated
%   at its extremum.
%
%   Note: Even if SUBPIXEL is true, there are some cases that result
%   in FINDPEAK returning the coordinates of the maximum absolute value
%   of F:
%   * When the maximum absolute value of F is on the edge of matrix F.
%   * When the coordinates of the estimated polynomial extremum would fall
%     outside the coordinates of the points used to constrain the estimate.

%   Copyright 2019-2023 The MathWorks, Inc.
%   
%#codegen

coder.inline('always');

% get absolute peak pixel
if(coder.gpu.internal.isGpuEnabled)
    % apply reduction to find max absolute value
    reducedMax = gpucoder.reduce(f, @findmaxval,'preprocess', @abs);
    if(isempty(reducedMax))
        if(isa(f,'single'))
            xpeak = single(0);
            ypeak = single(0);
            maxF = single(0);
        else
            xpeak = 0;
            ypeak = 0;
            maxF = 0;
        end
        return
    end
    maxF = reducedMax(1);

    % initialize the index, imax, as last element
    imax = uint32(numel(f));

    coder.gpu.kernel;
    for i=1:numel(f)
        if( (f(i) == maxF) && (i < imax) )
            % if current index is a smaller value, write it to imax
            imax = gpucoder.atomicMin(imax,uint32(i));
        end
    end
     
    imax = double(imax);  
else
    [maxF, imax] = max(abs(f(:)));
end

[Ypeak, Xpeak] = ind2sub(size(f),imax(1));

    if(isa(f,'single'))
        xpeak = single(Xpeak);
        ypeak = single(Ypeak);
    else
        xpeak = Xpeak;
        ypeak = Ypeak;
    end

if ~subpixel || ...
    xpeak==1 || xpeak==size(f,2) || ypeak==1 || ypeak==size(f,1) % on edge
    return % return absolute peak
    
else
    % fit a 2nd order polynomial to 9 points  
    % using 9 pixels centered on irow,jcol    
    u = f(ypeak-1:ypeak+1, xpeak-1:xpeak+1);
    u = u(:);
    x = [-1 -1 -1  0  0  0  1  1  1]';
    y = [-1  0  1 -1  0  1 -1  0  1]';    

    % u(x,y) = A(1) + A(2)*x + A(3)*y + A(4)*x*y + A(5)*x^2 + A(6)*y^2
    X = [ones(9,1),  x,  y,  x.*y,  x.^2,  y.^2];
    
    % u = X*A
    A = X\u;
    
    % get absolute maximum, where du/dx = du/dy = 0
    xOffset = (-A(3)*A(4)+2*A(6)*A(2)) / (A(4)^2-4*A(5)*A(6));
    yOffset = -1 / ( A(4)^2-4*A(5)*A(6))*(A(4)*A(2)-2*A(5)*A(3));

    if abs(xOffset)>1 || abs(yOffset)>1
        % adjusted peak falls outside set of 9 points fit,
        return % return absolute peak
    end
    
    % return only one-tenth of a pixel precision
    xOffset = round(10*xOffset)/10;
    yOffset = round(10*yOffset)/10;
    
    xpeak = xpeak + xOffset;
    ypeak = ypeak + yOffset;
    
    % Calculate extremum of fitted function
    maxF = [1 xOffset yOffset xOffset*yOffset xOffset^2 yOffset^2] * A;
    maxF = abs(maxF);
end

function maxval = findmaxval(a,b)
maxval = max (a,b);