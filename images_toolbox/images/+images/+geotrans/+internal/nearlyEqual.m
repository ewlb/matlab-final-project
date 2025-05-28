function tf = nearlyEqual(a,b)    %#codegen
    %nearlyEqual True if floating-point numbers are nearly equal.
    %   nearlyEqual(a,b) returns true if the floating-point numbers a and b are
    %   nearly equal.
    %
    %   For most numbers, a relative tolerance is used that allows numbers to
    %   differ by as much as 3-4 ULPs (for either single-precision or
    %   double-precision). This is a very tight tolerance.
    %
    %   When both numbers are extremely small, or when one or the other equals
    %   zero, a relative tolerance is either not defined or not appropriate,
    %   and so an absolute tolerance is used.
    %
    %   The inputs are expected to be the same size and class. This is not
    %   checked.
    %
    %   Reference: "Comparison", _The Floating-Point Guide_,
    %   https://floating-point-gui.de/errors/comparison/, downloaded by SLE on
    %   14-Jan-2022.

    %#codegen

    coder.inline('always');
    coder.internal.prefer_const(a,b);
            
    tf = false(size(a));
    for k = 1:numel(a)
        tf(k) = scalarsNearlyEqual(a(k),b(k));
    end
end

function tf = scalarsNearlyEqual(a,b)
    coder.inline('always');
    coder.internal.prefer_const(a,b);
                
    if (a == b)
        % Short-circuit; handles Inf values.
        tf = true;
        return
    end

    class_name = class(a);

    % The following relative tolerance allows the numbers to differ by up to 3
    % or 4 ULPs.
    epsilon = eps(class_name);
    smallest_normalized_number = realmin(class_name);

    abs_a = abs(a);
    abs_b = abs(b);
    d = abs(a - b);

    if (a == 0) || (b == 0) || (abs_a + abs_b < smallest_normalized_number)
        % Note: There are floating-point values smaller than realmin; these
        % are called "denormalized" numbers.
        % Relative error is undefined or not helpful in these situations.
        tf = d < (epsilon * smallest_normalized_number);
    else
        largest_number = realmax(class_name);
        tf = (d / min(abs_a + abs_b, largest_number)) < epsilon;
    end
end

% Copyright 2021-2022 The MathWorks, Inc.