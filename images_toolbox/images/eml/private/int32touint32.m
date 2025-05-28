function u = int32touint32(img) %#codegen
% INT32TOUINT32(I) converts int32 data (range = -2147483648 to 2147483647) to uint32
% data (range = 0 to 4294967295).

% Copyright 2013-2024 The MathWorks, Inc.

u = coder.nullcopy(uint32(img));
numElems = numel(img);

switch(class(img))
    case 'int32'
        if (coder.internal.preferMATLABHostCompiledLibraries())
            u = images.internal.coder.buildable.Int32touint32Buildable.int32touint32core( ...
                img, ...
                u, ...
                numElems);

        else % Non-PC Targets
            if coder.isColumnMajor
                for idx = 1:numElems
                    u(idx) = uint32(double(img(idx)) + 2147483648);
                end
            else % Row-major
                if numel(size(img)) == 2
                    for i = 1:size(img,1)
                        for j = 1:size(img,2)
                            u(i,j) = uint32(double(img(i,j)) + 2147483648);
                        end
                    end
                elseif numel(size(img)) == 3
                    for i = 1:size(img,1)
                        for j = 1:size(img,2)
                            for k = 1:size(img,3)
                                u(i,j,k) = uint32(double(img(i,j,k)) + 2147483648);
                            end
                        end
                    end
                else
                    for idx = 1:numElems
                        u(idx) = uint32(double(img(idx)) + 2147483648);
                    end
                end
            end
        end
    otherwise
        coder.internal.errorIf(true,'images:int32touint32:invalidType');
end
