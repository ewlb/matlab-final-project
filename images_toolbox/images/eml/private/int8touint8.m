function u = int8touint8(img) %#codegen
% INT8TOUINT8(I) converts int8 data (range = -128 to 127) to uint8
% data (range = 0 to 255).

% Copyright 2013-2024 The MathWorks, Inc.

u = coder.nullcopy(uint8(img));
numElems = numel(img);

switch(class(img))
    case 'int8'
        if coder.internal.preferMATLABHostCompiledLibraries()
            u = images.internal.coder.buildable.Int8touint8Buildable.int8touint8core( ...
                img, ...
                u, ...
                numElems);

        else % Non-PC Targets
            if coder.isColumnMajor
                for idx = 1:numElems
                    u(idx) = uint8(int16(img(idx)) + 128);
                end
            else % Row-major
                if numel(size(img)) == 2
                    for i = 1:size(img,1)
                        for j = 1:size(img,2)
                            u(i,j) = uint8(int16(img(i,j)) + 128);
                        end
                    end
                elseif numel(size(img)) == 3
                    for i = 1:size(img,1)
                        for j = 1:size(img,2)
                            for k = 1:size(img,3)
                                u(i,j,k) = uint8(int16(img(i,j,k)) + 128);
                            end
                        end
                    end
                else
                    for idx = 1:numElems
                        u(idx) = uint8(int16(img(idx)) + 128);
                    end
                end
            end
        end
    otherwise
        coder.internal.errorIf(true,'images:int8touint8:invalidType');
end
