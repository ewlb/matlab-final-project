function J = int16touint16(I) %#codegen
%INT16TOUINT16 converts int16 data (range = -32768 to 32767) to uint16
% data (range = 0 to 65535).

% Copyright 2013-2024 The MathWorks, Inc.

useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() ...
    && coder.const(~images.internal.coder.useSingleThread());

% allocate memory
J = coder.nullcopy(uint16(I));
numElems = numel(I);

switch(class(I))
    case 'int16'
        if useSharedLibrary
            % PC Targets (Host)
            J = images.internal.coder.buildable.Int16touint16Buildable.int16touint16core( ...
                I,J,numElems);
        else
            % Non-PC Targets
            if coder.isColumnMajor || (coder.isRowMajor() && numel(size(I))>3)
                for idx = 1:numElems
                    J(idx) = uint16(int32(I(idx)) + int32(32768));
                end
            else % Row-major
                if numel(size(I)) == 2
                    for i = 1:size(I,1)
                        for j = 1:size(I,2)
                            J(i,j) = uint16(int32(I(i,j)) + int32(32768));
                        end
                    end
                else % numel(size(I)) == 3
                    for i = 1:size(I,1)
                        for j = 1:size(I,2)
                            for k = 1:size(I,3)
                                J(i,j,k) = uint16(int32(I(i,j,k)) + int32(32768));
                            end
                        end
                    end
                end
            end
        end
    otherwise
        coder.internal.errorIf(true,'images:int16touint16:invalidType');
end
