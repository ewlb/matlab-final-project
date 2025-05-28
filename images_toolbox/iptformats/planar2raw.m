function cfa = planar2raw(in)

    arguments
        in (:, :, 4) { mustBeNumeric }
    end
    
    outHeight = 2*size(in, 1);
    outWidth = 2*size(in, 2);
    
    cfa = zeros([outHeight outWidth], class(in));
    
    cfa(1:2:end, 1:2:end) = in(:, :, 1);
    cfa(1:2:end, 2:2:end) = in(:, :, 2);
    cfa(2:2:end, 1:2:end) = in(:, :, 3);
    cfa(2:2:end, 2:2:end) = in(:, :, 4);
end

%   Copyright 2020-2022 The MathWorks, Inc.
