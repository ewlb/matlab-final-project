function im = raw2planar(cfa)

    arguments
        cfa (:, :, 1) { mustBeNumeric, validateDims(cfa) }
    end
    
    sz = size(cfa);
    im = zeros(sz/2, class(cfa));
    im(:, :, 1) = cfa(1:2:end, 1:2:end);
    im(:, :, 2) = cfa(1:2:end, 2:2:end);
    im(:, :, 3) = cfa(2:2:end, 1:2:end);
    im(:, :, 4) = cfa(2:2:end, 2:2:end);
end

function validateDims(in)

    sz = [size(in, 1) size(in, 2)];
    
    if any( mod(sz, 2) ~= 0 )
        errorID = 'images:rawfileio:DimsMustBeEven';
        errorMsg = getString(message(errorID));
        errorID = replace(errorID, 'rawfileio', mfilename);
        throw( MException(errorID, errorMsg) );
    end
end

%   Copyright 2020-2022 The MathWorks, Inc.