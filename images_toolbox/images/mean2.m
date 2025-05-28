function y = mean2(x) %#codegen
%MEAN2 Average or mean of matrix elements.
%   B = MEAN2(A) computes the mean of the values in A.
%
%   Class Support
%   -------------
%   A can be numeric or logical. B is a scalar of class single if A is
%   single and double otherwise.
%
%   Example
%   -------
%       I = imread('liftingbody.png');
%       val = mean2(I)
%  
%   See also MEAN, STD, STD2.

%   Copyright 1993-2018 The MathWorks, Inc.

if coder.isColumnMajor
    y = sum(x(:),'default') / numel(x);
else
    if isempty(x)
        if isfloat(x)
            y = coder.internal.nan(class(x));
        else
            y = coder.internal.nan('double');
        end
        return
    end
    
    % Behavior of 'default' option in sum(): If input, X is floating point,
    % that is double or single, output has the same class as X. If X is not
    % floating point, output has class double.
    if isfloat(x)
        y = zeros(1,'like',x);
        classToCastInput = class(x);
    else
        y = double(zeros(1,'like',x));
        classToCastInput = 'double';
    end
    if numel(size(x)) == 2
        parfor i = 1:size(x,1)
            for j = 1:size(x,2)
                y = y + cast(x(i,j),classToCastInput);
            end
        end
    elseif numel(size(x)) == 3
        parfor i = 1:size(x,1)
            for j = 1:size(x,2)
                for k = 1:size(x,3)
                   y = y + cast(x(i,j,k),classToCastInput);
                end
            end
        end
    else
        for i = 1:numel(x)
            y = y + cast(x(i),classToCastInput);
        end
    end
    y = y/numel(x);
end
