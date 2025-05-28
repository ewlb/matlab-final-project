function J = uint16toint16(I) %#codegen
%UINT16TOINT16 converts uint16 data (range = 0 to 65535) to int16
% data (range = -32768 to 32767).

% Copyright 2013-2024 The MathWorks, Inc.

useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() ...
    && coder.const(~images.internal.coder.useSingleThread());

% allocate memory
J = coder.nullcopy(int16(I));
numElems = numel(I);

switch(class(I))
    case 'uint16'
        if useSharedLibrary
            % PC Targets (Host)
            J = images.internal.coder.buildable.Uint16toint16Buildable.uint16toint16core( ...
                I,J,numElems);
        else
            % Non-PC Targets
            if coder.isColumnMajor
                for idx = 1:numElems
                    J(idx) = int16(int32(I(idx)) - int32(32768));
                end
            else % Row-major
                if numel(size(I)) == 2
                    for i = 1:size(I,1)
                        for j = 1:size(I,2)
                            J(i,j) = int16(int32(I(i,j)) - int32(32768));
                        end
                    end
                elseif numel(size(I)) == 3
                    for i = 1:size(I,1)
                        for j = 1:size(I,2)
                            for k = 1:size(I,3)
                                J(i,j,k) = int16(int32(I(i,j,k)) - int32(32768));
                            end
                        end
                    end
                else
                    for idx = 1:numElems
                        J(idx) = int16(int32(I(idx)) - int32(32768));
                    end
                end
            end
        end
    otherwise
        coder.internal.errorIf(true,'images:uint16toint16:invalidType');
end
