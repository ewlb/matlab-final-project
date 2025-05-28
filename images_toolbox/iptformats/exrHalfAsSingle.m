function out = exrHalfAsSingle(in)

    arguments
        in {mustBeA(in,["numeric","cell"])}
    end

    if isnumeric(in)
        out = images.internal.builtins.convertToHalf(in,"single");
    else 
        cellfun(@(x) validateattributes(x,"numeric",{}),in);

        out = cell(size(in));
        for cnt = 1:numel(out)
            out{cnt} = images.internal.builtins.convertToHalf(in{cnt},"single");
        end
    end
end

%   Copyright 2022 The MathWorks, Inc.